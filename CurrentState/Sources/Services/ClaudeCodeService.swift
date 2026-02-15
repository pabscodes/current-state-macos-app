import Foundation

/// Manages Claude Code subprocess lifecycle and streams parsed events.
final class ClaudeCodeService {

    /// Path to the claude CLI binary.
    private let claudePath: String

    init(claudePath: String = "/usr/local/bin/claude") {
        self.claudePath = claudePath
    }

    /// Stream events from a Claude Code subprocess.
    ///
    /// - Parameters:
    ///   - prompt: The message to send (e.g., "/currentstate" or a follow-up).
    ///   - sessionId: If provided, resumes an existing conversation.
    /// - Returns: An `AsyncThrowingStream` of `StreamEvent`s.
    func stream(prompt: String, sessionId: String?) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await runProcess(prompt: prompt, sessionId: sessionId, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private func runProcess(
        prompt: String,
        sessionId: String?,
        continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation
    ) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolvedClaudePath())

        var args = ["-p", prompt, "--output-format", "stream-json", "--verbose"]
        if let sessionId {
            args += ["--resume", sessionId]
        }
        process.arguments = args

        // Unset CLAUDECODE env var to allow nested invocation
        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "CLAUDECODE")
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        let handle = stdout.fileHandleForReading

        // Read line by line from stdout
        // Using a simple buffered approach
        var buffer = Data()
        let newline = UInt8(ascii: "\n")

        while process.isRunning || handle.availableData.count > 0 {
            let chunk = handle.availableData
            if chunk.isEmpty {
                // Process ended and no more data
                break
            }
            buffer.append(chunk)

            // Extract complete lines from buffer
            while let newlineIndex = buffer.firstIndex(of: newline) {
                let lineData = buffer[buffer.startIndex..<newlineIndex]
                buffer = Data(buffer[buffer.index(after: newlineIndex)...])

                if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                    let event = StreamParser.parse(line: line)
                    continuation.yield(event)
                }
            }
        }

        // Process any remaining data in buffer
        if !buffer.isEmpty, let line = String(data: buffer, encoding: .utf8), !line.isEmpty {
            let event = StreamParser.parse(line: line)
            continuation.yield(event)
        }

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ClaudeCodeError.processExited(code: process.terminationStatus, message: errorMessage)
        }
    }

    private func resolvedClaudePath() -> String {
        // Check common installation paths
        let candidates = [
            claudePath,
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return claudePath
    }
}

enum ClaudeCodeError: LocalizedError {
    case processExited(code: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .processExited(let code, let message):
            return "Claude Code exited with code \(code): \(message)"
        }
    }
}
