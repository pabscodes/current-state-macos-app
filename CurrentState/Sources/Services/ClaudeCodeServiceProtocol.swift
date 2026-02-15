import Foundation

protocol ClaudeCodeServiceProtocol: Sendable {
    func stream(prompt: String, sessionId: String?) -> AsyncThrowingStream<StreamEvent, Error>
}
