import XCTest
@testable import Current_State

@MainActor
final class AppStateTests: XCTestCase {

    // MARK: - Test Isolation

    /// Temporary directory used for BriefingCache in all tests that don't specify their own.
    /// Prevents tests from writing to the real ~/Library/Application Support/CurrentState/ cache.
    private var tempCacheDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempCacheDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempCacheDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempCacheDir)
        tempCacheDir = nil
        try await super.tearDown()
    }

    /// Creates an AppState backed by the isolated temp-dir cache.
    private func makeAppState(claudeService: MockClaudeCodeService) -> AppState {
        AppState(claudeService: claudeService, briefingCache: BriefingCache(directory: tempCacheDir))
    }

    // MARK: - Init Safety

    func testInitDoesNotAutoStart() {
        let mock = MockClaudeCodeService()
        _ = makeAppState(claudeService: mock)

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

        // Set the startup skill explicitly so the test doesn't depend on UserDefaults state
        UserDefaults.standard.set("/currentstate-app", forKey: "currentstate.startupSkill")
        defer { UserDefaults.standard.removeObject(forKey: "currentstate.startupSkill") }

        let appState = makeAppState(claudeService: mock)
        appState.startNewBriefing()

        // Wait for the internal Task to complete
        await Task.yield()
        // Give the runloop a moment to process
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mock.callCount, 1)
        XCTAssertEqual(mock.lastPrompt, "/currentstate-app")
        XCTAssertNil(mock.lastSessionId, "First briefing should not pass a session ID")
        XCTAssertEqual(appState.currentSessionId, "session-1")
        XCTAssertEqual(appState.streamingState, .idle)

        // Should have one assistant message with accumulated text (passthrough, no delimiters)
        let assistantMessages = appState.messages.filter { $0.role == .assistant }
        XCTAssertEqual(assistantMessages.count, 1)
        XCTAssertEqual(assistantMessages.first?.content, "Hello")
    }

    // MARK: - Error Handling

    func testStreamingErrorSetsErrorState() async {
        let mock = MockClaudeCodeService()
        mock.errorToThrow = ClaudeCodeError.binaryNotFound

        let appState = makeAppState(claudeService: mock)
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

        let appState = makeAppState(claudeService: mock)
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

        UserDefaults.standard.set("/currentstate-app", forKey: "currentstate.startupSkill")
        defer { UserDefaults.standard.removeObject(forKey: "currentstate.startupSkill") }

        let appState = makeAppState(claudeService: mock)
        appState.startNewBriefing()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        appState.sendMessage("follow-up")

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mock.callCount, 2)
        XCTAssertEqual(mock.allPrompts, ["/currentstate-app", "follow-up"])
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

        let appState = makeAppState(claudeService: mock)
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

        let appState = makeAppState(claudeService: mock)

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
        let appState = makeAppState(claudeService: mock)

        // Idle state → nil
        XCTAssertNil(appState.errorMessage)

        // Error state → extracts message
        appState.streamingState = .error("Something went wrong")
        XCTAssertEqual(appState.errorMessage, "Something went wrong")

        // Back to idle → nil again
        appState.streamingState = .idle
        XCTAssertNil(appState.errorMessage)
    }

    // MARK: - Result isError Handling

    func testResultIsErrorSetsErrorState() async {
        let mock = MockClaudeCodeService()
        mock.eventsToReturn = [
            .init_(.init(sessionId: "s1", model: "m")),
            .assistantText("partial"),
            .result(.init(sessionId: "s1", fullText: "", isError: true, durationMs: nil, costUsd: nil)),
        ]

        let appState = makeAppState(claudeService: mock)
        appState.startNewBriefing()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        if case .error(let message) = appState.streamingState {
            XCTAssertTrue(message.contains("error"), "Error message should mention error, got: \(message)")
        } else {
            XCTFail("Expected error state, got \(appState.streamingState)")
        }
    }

    func testResultIsErrorRemovesEmptyPartialMessage() async {
        let mock = MockClaudeCodeService()
        mock.eventsToReturn = [
            .init_(.init(sessionId: "s1", model: "m")),
            .result(.init(sessionId: "s1", fullText: "", isError: true, durationMs: nil, costUsd: nil)),
        ]

        let appState = makeAppState(claudeService: mock)
        appState.startNewBriefing()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        let assistantMessages = appState.messages.filter { $0.role == .assistant }
        XCTAssertEqual(assistantMessages.count, 0, "Empty assistant message should be removed on isError")
    }

    func testResultIsErrorKeepsPartialMessageWithContent() async {
        let mock = MockClaudeCodeService()
        mock.eventsToReturn = [
            .init_(.init(sessionId: "s1", model: "m")),
            .assistantText("Some partial content"),
            .result(.init(sessionId: "s1", fullText: "", isError: true, durationMs: nil, costUsd: nil)),
        ]

        let appState = makeAppState(claudeService: mock)
        appState.startNewBriefing()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        let assistantMessages = appState.messages.filter { $0.role == .assistant }
        XCTAssertEqual(assistantMessages.count, 1, "Partial message with content should be preserved")
        XCTAssertEqual(assistantMessages.first?.content, "Some partial content")
    }

    func testStreamErrorRemovesEmptyPartialMessage() async {
        let mock = MockClaudeCodeService()
        mock.errorToThrow = ClaudeCodeError.processExited(code: 1, message: "fail")

        let appState = makeAppState(claudeService: mock)
        appState.startNewBriefing()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        let assistantMessages = appState.messages.filter { $0.role == .assistant }
        XCTAssertEqual(assistantMessages.count, 0, "Empty assistant message should be removed on stream error")
    }

    func testBinaryNotFoundErrorMessage() async {
        let mock = MockClaudeCodeService()
        mock.errorToThrow = ClaudeCodeError.binaryNotFound

        let appState = makeAppState(claudeService: mock)
        appState.startNewBriefing()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        if case .error(let message) = appState.streamingState {
            XCTAssertTrue(message.contains("Settings"), "Error message should mention Settings, got: \(message)")
            XCTAssertTrue(message.contains("Claude Code CLI not found"), "Error message should mention CLI not found, got: \(message)")
        } else {
            XCTFail("Expected error state, got \(appState.streamingState)")
        }
    }

    // MARK: - Clear Conversation

    func testClearConversation() async {
        let mock = MockClaudeCodeService()
        mock.eventsToReturn = [
            .init_(.init(sessionId: "s1", model: "m")),
            .assistantText("Hello"),
            .result(.init(sessionId: "s1", fullText: "Hello", isError: false, durationMs: nil, costUsd: nil)),
        ]

        let appState = makeAppState(claudeService: mock)
        appState.startNewBriefing()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertFalse(appState.messages.isEmpty)
        XCTAssertNotNil(appState.currentSessionId)

        appState.clearConversation()

        XCTAssertTrue(appState.messages.isEmpty, "Messages should be empty after clear")
        XCTAssertNil(appState.currentSessionId, "Session should be nil after clear")
        XCTAssertEqual(appState.streamingState, .idle, "State should be idle after clear")
        XCTAssertTrue(appState.sections.isEmpty, "Sections should be empty after clear")
        XCTAssertFalse(appState.hasCachedBriefing, "hasCachedBriefing should be false after clear")
    }

    // MARK: - Custom Startup Skill

    func testStartNewBriefingUsesCustomSkill() async {
        let mock = MockClaudeCodeService()
        mock.eventsToReturn = [
            .init_(.init(sessionId: "s1", model: "m")),
            .assistantText("Custom"),
            .result(.init(sessionId: "s1", fullText: "Custom", isError: false, durationMs: nil, costUsd: nil)),
        ]

        UserDefaults.standard.set("/mycustomskill", forKey: "currentstate.startupSkill")
        defer { UserDefaults.standard.removeObject(forKey: "currentstate.startupSkill") }

        let appState = makeAppState(claudeService: mock)
        appState.startNewBriefing()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(mock.lastPrompt, "/mycustomskill", "Should use custom startup skill from UserDefaults")
    }

    // MARK: - Section-Based Briefing (NEW)

    func testSectionDelimitersPopulateSections() async {
        let mock = MockClaudeCodeService()
        mock.eventsToReturn = [
            .init_(.init(sessionId: "s1", model: "m")),
            .assistantText("<<<SECTION:header>>>\n## Monday, Feb 17\n<<</SECTION:header>>>\n<<<SECTION:picture>>>\n### The Picture\n- Bullet one\n<<</SECTION:picture>>>"),
            .result(.init(sessionId: "s1", fullText: "", isError: false, durationMs: nil, costUsd: nil)),
        ]

        let appState = makeAppState(claudeService: mock)
        appState.startNewBriefing()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(appState.sections.count, 2, "Should have 2 sections")
        XCTAssertNotNil(appState.sections[.header])
        XCTAssertNotNil(appState.sections[.picture])
        XCTAssertTrue(appState.sections[.header]?.content.contains("Monday") ?? false)
        XCTAssertTrue(appState.sections[.picture]?.content.contains("Bullet one") ?? false)
        XCTAssertEqual(appState.sections[.header]?.loadingState, .complete)
        XCTAssertEqual(appState.sections[.picture]?.loadingState, .complete)
    }

    func testBackwardCompatWithoutDelimiters() async {
        let mock = MockClaudeCodeService()
        mock.eventsToReturn = [
            .init_(.init(sessionId: "s1", model: "m")),
            .assistantText("Plain briefing without delimiters"),
            .result(.init(sessionId: "s1", fullText: "Plain briefing without delimiters", isError: false, durationMs: nil, costUsd: nil)),
        ]

        let appState = makeAppState(claudeService: mock)
        appState.startNewBriefing()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        // No sections populated — content goes to messages via passthrough
        XCTAssertTrue(appState.sections.isEmpty, "No sections should exist without delimiters")
        let assistantMessages = appState.messages.filter { $0.role == .assistant }
        XCTAssertEqual(assistantMessages.count, 1)
        XCTAssertEqual(assistantMessages.first?.content, "Plain briefing without delimiters")
    }

    func testLoadCachedBriefing() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cache = BriefingCache(directory: tempDir)

        // Seed cache data
        var briefing = CachedBriefing.empty
        briefing.sessionId = "cached-session"
        briefing.sections[.picture] = CachedBriefing.SectionCache(
            content: "### Cached Picture", lastUpdated: Date()
        )
        await cache.save(briefing)

        let mock = MockClaudeCodeService()
        let appState = AppState(claudeService: mock, briefingCache: cache)

        await appState.loadCachedBriefing()

        XCTAssertTrue(appState.hasCachedBriefing)
        XCTAssertEqual(appState.sections.count, 1)
        XCTAssertEqual(appState.sections[.picture]?.content, "### Cached Picture")
        XCTAssertEqual(appState.sections[.picture]?.loadingState, .cached)
        XCTAssertEqual(appState.currentSessionId, "cached-session")
    }

    func testNewBriefingMarksCachedSectionsAsRefreshing() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cache = BriefingCache(directory: tempDir)
        var briefing = CachedBriefing.empty
        briefing.sections[.picture] = CachedBriefing.SectionCache(
            content: "Old content", lastUpdated: Date()
        )
        await cache.save(briefing)

        let mock = MockClaudeCodeService()
        // Return nothing so startNewBriefing stays in loading
        mock.eventsToReturn = []

        let appState = AppState(claudeService: mock, briefingCache: cache)
        await appState.loadCachedBriefing()

        XCTAssertEqual(appState.sections[.picture]?.loadingState, .cached)

        appState.startNewBriefing()

        // Before the stream completes, cached sections should be marked refreshing
        XCTAssertEqual(appState.sections[.picture]?.loadingState, .refreshing)
        // But content is still visible
        XCTAssertEqual(appState.sections[.picture]?.content, "Old content")
    }

    func testSectionsPersistAfterCompletion() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cache = BriefingCache(directory: tempDir)
        let mock = MockClaudeCodeService()
        mock.eventsToReturn = [
            .init_(.init(sessionId: "s1", model: "m")),
            .assistantText("<<<SECTION:picture>>>\n### New Picture\n<<</SECTION:picture>>>"),
            .result(.init(sessionId: "s1", fullText: "", isError: false, durationMs: nil, costUsd: nil)),
        ]

        let appState = AppState(claudeService: mock, briefingCache: cache)
        appState.startNewBriefing()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(100))

        // Verify the cache was written
        let loaded = await cache.load()
        XCTAssertFalse(loaded.isEmpty, "Cache should have been persisted after briefing completion")
        XCTAssertEqual(loaded.sections[.picture]?.content, "### New Picture")
        XCTAssertEqual(loaded.sessionId, "s1")
    }

    func testClearConversationResetsSections() async {
        let mock = MockClaudeCodeService()
        mock.eventsToReturn = [
            .init_(.init(sessionId: "s1", model: "m")),
            .assistantText("<<<SECTION:header>>>\n## Monday\n<<</SECTION:header>>>"),
            .result(.init(sessionId: "s1", fullText: "", isError: false, durationMs: nil, costUsd: nil)),
        ]

        let appState = makeAppState(claudeService: mock)
        appState.startNewBriefing()

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertFalse(appState.sections.isEmpty)

        appState.clearConversation()

        XCTAssertTrue(appState.sections.isEmpty, "Sections should be cleared")
        XCTAssertFalse(appState.hasCachedBriefing, "hasCachedBriefing should be reset")
        XCTAssertTrue(appState.refreshingSectionIds.isEmpty, "refreshingSectionIds should be empty")
    }
}
