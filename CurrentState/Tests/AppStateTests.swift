import XCTest
@testable import Current_State

@MainActor
final class AppStateTests: XCTestCase {

    // MARK: - Init Safety

    func testInitDoesNotAutoStart() {
        let mock = MockClaudeCodeService()
        _ = AppState(claudeService: mock)

        XCTAssertEqual(mock.callCount, 0, "AppState.init() must not call the service")
    }

    // MARK: - Briefing Flow

    func testStartNewBriefingSendsCorrectPrompt() async {
        let mock = MockClaudeCodeService()
        mock.eventsToReturn = [
            .init_(.init(sessionId: "session-1", model: "claude-opus-4-6")),
            .assistantText("Hello"),
            .result(.init(sessionId: "session-1", fullText: "Hello", isError: false, durationMs: 100, costUsd: 0.01)),
        ]

        let appState = AppState(claudeService: mock)
        appState.startNewBriefing()

        // Wait for the internal Task to complete
        await Task.yield()
        // Give the runloop a moment to process
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mock.callCount, 1)
        XCTAssertEqual(mock.lastPrompt, "/currentstate")
        XCTAssertNil(mock.lastSessionId, "First briefing should not pass a session ID")
        XCTAssertEqual(appState.currentSessionId, "session-1")
        XCTAssertEqual(appState.streamingState, .idle)

        // Should have one assistant message with accumulated text
        let assistantMessages = appState.messages.filter { $0.role == .assistant }
        XCTAssertEqual(assistantMessages.count, 1)
        XCTAssertEqual(assistantMessages.first?.content, "Hello")
    }

    // MARK: - Error Handling

    func testStreamingErrorSetsErrorState() async {
        let mock = MockClaudeCodeService()
        mock.errorToThrow = ClaudeCodeError.binaryNotFound

        let appState = AppState(claudeService: mock)
        appState.startNewBriefing()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        if case .error(let message) = appState.streamingState {
            XCTAssertTrue(message.contains("Claude Code CLI not found"), "Error message should mention CLI not found, got: \(message)")
        } else {
            XCTFail("Expected error state, got \(appState.streamingState)")
        }
    }

    // MARK: - Scroll Trigger

    func testScrollTriggerUpdatesOnStreamingText() async {
        let mock = MockClaudeCodeService()
        mock.eventsToReturn = [
            .init_(.init(sessionId: "s1", model: "m")),
            .assistantText("chunk1"),
            .assistantText("chunk2"),
            .result(.init(sessionId: "s1", fullText: "chunk1chunk2", isError: false, durationMs: nil, costUsd: nil)),
        ]

        let appState = AppState(claudeService: mock)
        let initialTrigger = appState.scrollTrigger

        appState.startNewBriefing()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertNotEqual(appState.scrollTrigger, initialTrigger, "scrollTrigger should change after streaming text")
    }

    // MARK: - Multi-Turn Conversation

    func testSendMessagePassesSessionId() async {
        let mock = MockClaudeCodeService()
        mock.eventsPerCall = [
            // Call 1: briefing
            [
                .init_(.init(sessionId: "s1", model: "claude-opus-4-6")),
                .assistantText("Briefing"),
                .result(.init(sessionId: "s1", fullText: "Briefing", isError: false, durationMs: 100, costUsd: 0.01)),
            ],
            // Call 2: follow-up
            [
                .init_(.init(sessionId: "s1", model: "claude-opus-4-6")),
                .assistantText("Response"),
                .result(.init(sessionId: "s1", fullText: "Response", isError: false, durationMs: 50, costUsd: 0.005)),
            ],
        ]

        let appState = AppState(claudeService: mock)
        appState.startNewBriefing()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        appState.sendMessage("follow-up")

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mock.callCount, 2)
        XCTAssertEqual(mock.allPrompts, ["/currentstate", "follow-up"])
        XCTAssertEqual(mock.allSessionIds.count, 2)
        XCTAssertNil(mock.allSessionIds[0], "First call should have nil sessionId")
        XCTAssertEqual(mock.allSessionIds[1], "s1", "Second call should pass session ID from init event")
    }

    func testMultiTurnAccumulatesMessages() async {
        let mock = MockClaudeCodeService()
        mock.eventsPerCall = [
            [
                .init_(.init(sessionId: "s1", model: "m")),
                .assistantText("Briefing text"),
                .result(.init(sessionId: "s1", fullText: "Briefing text", isError: false, durationMs: nil, costUsd: nil)),
            ],
            [
                .init_(.init(sessionId: "s1", model: "m")),
                .assistantText("Follow-up response"),
                .result(.init(sessionId: "s1", fullText: "Follow-up response", isError: false, durationMs: nil, costUsd: nil)),
            ],
        ]

        let appState = AppState(claudeService: mock)
        appState.startNewBriefing()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        appState.sendMessage("follow-up question")

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(appState.messages.count, 3, "Should have briefing + user + follow-up response")
        XCTAssertEqual(appState.messages[0].role, .assistant)
        XCTAssertEqual(appState.messages[0].content, "Briefing text")
        XCTAssertEqual(appState.messages[1].role, .user)
        XCTAssertEqual(appState.messages[1].content, "follow-up question")
        XCTAssertEqual(appState.messages[2].role, .assistant)
        XCTAssertEqual(appState.messages[2].content, "Follow-up response")
    }

    func testNewBriefingClearsConversation() async {
        let mock = MockClaudeCodeService()
        mock.eventsPerCall = [
            [
                .init_(.init(sessionId: "s1", model: "m")),
                .assistantText("First briefing"),
                .result(.init(sessionId: "s1", fullText: "First briefing", isError: false, durationMs: nil, costUsd: nil)),
            ],
            [
                .init_(.init(sessionId: "s1", model: "m")),
                .assistantText("Response"),
                .result(.init(sessionId: "s1", fullText: "Response", isError: false, durationMs: nil, costUsd: nil)),
            ],
            [
                .init_(.init(sessionId: "s2", model: "m")),
                .assistantText("Second briefing"),
                .result(.init(sessionId: "s2", fullText: "Second briefing", isError: false, durationMs: nil, costUsd: nil)),
            ],
        ]

        let appState = AppState(claudeService: mock)

        // First briefing
        appState.startNewBriefing()
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        // Follow-up
        appState.sendMessage("question")
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(appState.messages.count, 3)
        XCTAssertEqual(appState.currentSessionId, "s1")

        // New briefing — should clear everything
        appState.startNewBriefing()
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(appState.messages.count, 1, "New briefing should clear previous messages")
        XCTAssertEqual(appState.messages[0].role, .assistant)
        XCTAssertEqual(appState.messages[0].content, "Second briefing")
        XCTAssertEqual(appState.currentSessionId, "s2", "Session should be new after startNewBriefing")
    }

    // MARK: - Error Message Computed Property

    func testErrorMessageComputedProperty() {
        let mock = MockClaudeCodeService()
        let appState = AppState(claudeService: mock)

        // Idle state → nil
        XCTAssertNil(appState.errorMessage)

        // Error state → extracts message
        appState.streamingState = .error("Something went wrong")
        XCTAssertEqual(appState.errorMessage, "Something went wrong")

        // Back to idle → nil again
        appState.streamingState = .idle
        XCTAssertNil(appState.errorMessage)
    }
}
