import Foundation
@testable import Current_State

/// Test mock that returns preconfigured events without spawning any subprocess.
final class MockClaudeCodeService: ClaudeCodeServiceProtocol, @unchecked Sendable {
    var eventsToReturn: [StreamEvent] = []
    var eventsPerCall: [[StreamEvent]] = []
    var errorToThrow: Error?

    private(set) var callCount = 0
    private(set) var lastPrompt: String?
    private(set) var lastSessionId: String?
    private(set) var allPrompts: [String] = []
    private(set) var allSessionIds: [String?] = []

    func stream(prompt: String, sessionId: String?) -> AsyncThrowingStream<StreamEvent, Error> {
        callCount += 1
        lastPrompt = prompt
        lastSessionId = sessionId
        allPrompts.append(prompt)
        allSessionIds.append(sessionId)

        let events: [StreamEvent]
        if !eventsPerCall.isEmpty, callCount <= eventsPerCall.count {
            events = eventsPerCall[callCount - 1]
        } else {
            events = eventsToReturn
        }
        let error = errorToThrow

        return AsyncThrowingStream { continuation in
            if let error {
                continuation.finish(throwing: error)
                return
            }
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}
