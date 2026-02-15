import Foundation

/// Manages Claude Code subprocess lifecycle and streams parsed events.
final class ClaudeCodeService: Sendable {

    /// Stream events from a Claude Code subprocess.
    ///
    /// The returned stream owns the subprocess. When the consumer cancels
    /// (e.g. by dropping the `for await` loop), the subprocess is terminated.
    func stream(prompt: String, sessionId: String?) -> AsyncThrowingStream<StreamEvent, Error> {
        // Thread-safe box so the onTermination handler can reach the process
        // created inside the detached task.
        let processBox = ProcessBox()

        return AsyncThrowingStream { continuation in
            let task = Task.detached { [self] in
                do {
                    let executablePath = try self.resolvedClaudePath()
                    let args = self.buildArgs(prompt: prompt, sessionId: sessionId)

                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: executablePath)
                    process.arguments = args

                    // Unset CLAUDECODE env var to prevent "nested session" error
                    var env = ProcessInfo.processInfo.environment
                    env.removeValue(forKey: "CLAUDECODE")
                    process.environment = env

                    let stdout = Pipe()
                    let stderr = Pipe()
                    process.standardOutput = stdout
                    process.standardError = stderr

                    // Publish process so onTermination can kill it
                    processBox.set(process)

                    // Ensure cleanup on all exit paths
                    defer {
                        if process.isRunning { process.terminate() }
                    }

                    try process.run()

                    let handle = stdout.fileHandleForReading
                    var buffer = Data()
                    let newline = UInt8(ascii: "\n")

                    // Blocking read loop — readData(ofLength:) returns empty Data
                    // only at true EOF (pipe closed), unlike availableData which
                    // can return empty while the pipe is still open.
                    while true {
                        let chunk = handle.readData(ofLength: 65_536)
                        if chunk.isEmpty { break }

                        try Task.checkCancellation()

                        buffer.append(chunk)

                        while let newlineIndex = buffer.firstIndex(of: newline) {
                            let lineData = buffer[buffer.startIndex..<newlineIndex]
                            buffer = Data(buffer[buffer.index(after: newlineIndex)...])

                            if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                                let event = StreamParser.parse(line: line)
                                continuation.yield(event)
                            }
                        }
                    }

                    // Flush any remaining partial line
                    if !buffer.isEmpty, let line = String(data: buffer, encoding: .utf8), !line.isEmpty {
                        let event = StreamParser.parse(line: line)
                        continuation.yield(event)
                    }

                    process.waitUntilExit()

                    if process.terminationStatus != 0 && !Task.isCancelled {
                        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        throw ClaudeCodeError.processExited(code: process.terminationStatus, message: errorMessage)
                    }

                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            // Single onTermination: cancel the Swift task (sets flag + interrupts
            // cooperative checks) AND terminate the subprocess (closes pipe →
            // unblocks the blocking readData call).
            continuation.onTermination = { @Sendable _ in
                task.cancel()
                processBox.terminate()
            }
        }
    }

    // MARK: - Private

    private func buildArgs(prompt: String, sessionId: String?) -> [String] {
        var args = ["-p", prompt, "--output-format", "stream-json", "--verbose"]
        if let sessionId {
            args += ["--resume", sessionId]
        }
        return args
    }

    /// Resolve the path to the Claude CLI binary.
    /// Checks common install locations then falls back to `which`.
    /// Throws `ClaudeCodeError.binaryNotFound` if the binary cannot be found.
    private func resolvedClaudePath() throws -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Fallback: ask the shell
        let whichProcess = Process()
        let whichPipe = Pipe()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["claude"]
        whichProcess.standardOutput = whichPipe
        whichProcess.standardError = FileHandle.nullDevice
        try? whichProcess.run()
        whichProcess.waitUntilExit()

        if whichProcess.terminationStatus == 0 {
            let data = whichPipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty,
               FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        throw ClaudeCodeError.binaryNotFound
    }
}

// MARK: - Thread-safe Process reference

/// Allows the `onTermination` handler (which runs on an arbitrary thread)
/// to terminate a `Process` that is created inside a `Task.detached` block.
private final class ProcessBox: @unchecked Sendable {
    private var _process: Process?
    private let lock = NSLock()

    func set(_ process: Process) {
        lock.lock()
        _process = process
        lock.unlock()
    }

    func terminate() {
        lock.lock()
        let p = _process
        lock.unlock()
        if let p, p.isRunning {
            p.terminate()
        }
    }
}

// MARK: - Errors

enum ClaudeCodeError: LocalizedError {
    case binaryNotFound
    case processExited(code: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Claude Code CLI not found. Install it with: npm install -g @anthropic-ai/claude-code"
        case .processExited(let code, let message):
            return "Claude Code exited with code \(code): \(message)"
        }
    }
}
