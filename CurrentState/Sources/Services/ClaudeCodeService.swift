import Foundation
import os

/// Manages Claude Code subprocess lifecycle and streams parsed events.
final class ClaudeCodeService: ClaudeCodeServiceProtocol {

    private static let logger = Logger(subsystem: "com.pabscodes.currentstate", category: "ClaudeCodeService")

    func stream(prompt: String, sessionId: String?) -> AsyncThrowingStream<StreamEvent, Error> {
        let processBox = ProcessBox()

        return AsyncThrowingStream { continuation in
            do {
                let executablePath = try self.resolvedClaudePath()
                let args = self.buildArgs(prompt: prompt, sessionId: sessionId)

                Self.logger.info("Launching: \(executablePath) \(args.joined(separator: " "), privacy: .private)")

                let process = Process()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = args
                process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
                process.standardInput = FileHandle.nullDevice

                // Strip CLAUDECODE env var to prevent "nested session" error.
                // Augment PATH so claude's subagents can find homebrew tools
                // (things, python3.12, etc.) — macOS apps launch with a minimal PATH.
                var env = ProcessInfo.processInfo.environment
                env.removeValue(forKey: "CLAUDECODE")
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                let extraPaths = [
                    "\(home)/.local/bin",
                    "/opt/homebrew/bin",
                    "/opt/homebrew/sbin",
                    "/usr/local/bin",
                ]
                let existingPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
                env["PATH"] = (extraPaths + [existingPath]).joined(separator: ":")
                process.environment = env

                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr

                processBox.set(process)

                // Serial queue ensures readabilityHandler and terminationHandler
                // never run concurrently — eliminates the race condition.
                let queue = DispatchQueue(label: "com.pabscodes.currentstate.stream")
                let lineBuffer = LineBuffer()
                let newline = UInt8(ascii: "\n")
                var eofSeen = false

                stdout.fileHandleForReading.readabilityHandler = { [lineBuffer] handle in
                    queue.async {
                        let chunk = handle.availableData

                        if chunk.isEmpty {
                            // EOF — pipe closed
                            eofSeen = true
                            handle.readabilityHandler = nil

                            let remaining = lineBuffer.flush()
                            if let line = String(data: remaining, encoding: .utf8), !line.isEmpty {
                                let event = StreamParser.parse(line: line)
                                continuation.yield(event)
                            }
                            return
                        }

                        lineBuffer.append(chunk)

                        while let lineData = lineBuffer.nextLine(delimiter: newline) {
                            if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                                let event = StreamParser.parse(line: line)
                                continuation.yield(event)
                            }
                        }
                    }
                }

                process.terminationHandler = { proc in
                    queue.async {
                        // If EOF wasn't seen yet, flush remaining data
                        if !eofSeen {
                            stdout.fileHandleForReading.readabilityHandler = nil
                            let remaining = lineBuffer.flush()
                            if let line = String(data: remaining, encoding: .utf8), !line.isEmpty {
                                let event = StreamParser.parse(line: line)
                                continuation.yield(event)
                            }
                        }

                        if proc.terminationStatus != 0 {
                            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                            Self.logger.error("Process exited with code \(proc.terminationStatus): \(errorMessage, privacy: .private)")
                            continuation.finish(throwing: ClaudeCodeError.processExited(
                                code: proc.terminationStatus, message: errorMessage
                            ))
                        } else {
                            Self.logger.info("Process exited normally")
                            continuation.finish()
                        }
                    }
                }

                try process.run()
                Self.logger.info("Process started, PID: \(process.processIdentifier)")

            } catch {
                Self.logger.error("Failed to launch: \(error.localizedDescription)")
                continuation.finish(throwing: error)
            }

            continuation.onTermination = { @Sendable _ in
                processBox.terminate()
            }
        }
    }

    // MARK: - Private

    private func buildArgs(prompt: String, sessionId: String?) -> [String] {
        var args = ["-p", prompt, "--output-format", "stream-json", "--verbose", "--dangerously-skip-permissions"]
        if let sessionId {
            args += ["--resume", sessionId]
        }
        return args
    }

    private func resolvedClaudePath() throws -> String {
        let customPath = UserDefaults.standard.string(forKey: "currentstate.claudePath") ?? ""
        if !customPath.isEmpty, FileManager.default.isExecutableFile(atPath: customPath) {
            return customPath
        }

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

// MARK: - Line buffer

private final class LineBuffer: @unchecked Sendable {
    private var data = Data()

    func append(_ chunk: Data) {
        data.append(chunk)
    }

    func nextLine(delimiter: UInt8) -> Data? {
        guard let index = data.firstIndex(of: delimiter) else { return nil }
        let lineData = data[data.startIndex..<index]
        data = Data(data[data.index(after: index)...])
        return Data(lineData)
    }

    func flush() -> Data {
        let remaining = data
        data = Data()
        return remaining
    }
}

// MARK: - Thread-safe Process reference

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
