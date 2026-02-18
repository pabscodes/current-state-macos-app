import XCTest
@testable import Current_State

final class BriefingCacheTests: XCTestCase {

    private var tempDir: URL!
    private var cache: BriefingCache!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        cache = BriefingCache(directory: tempDir)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - 1. Load returns empty when no cache exists

    func testLoadReturnsEmptyWhenNoCacheExists() async {
        let briefing = await cache.load()
        XCTAssertTrue(briefing.isEmpty)
        XCTAssertNil(briefing.sessionId)
        XCTAssertNil(briefing.lastFullRefresh)
    }

    // MARK: - 2. Save and load round-trip

    func testSaveAndLoadRoundTrip() async {
        let now = Date()
        var briefing = CachedBriefing.empty
        briefing.sessionId = "test-session"
        briefing.lastFullRefresh = now
        briefing.sections[.picture] = CachedBriefing.SectionCache(
            content: "### The Picture\n- Bullet one",
            lastUpdated: now
        )
        briefing.sections[.watchList] = CachedBriefing.SectionCache(
            content: "### Watch List\n- Item",
            lastUpdated: now
        )

        await cache.save(briefing)
        let loaded = await cache.load()

        XCTAssertEqual(loaded.sessionId, "test-session")
        XCTAssertEqual(loaded.sections.count, 2)
        XCTAssertEqual(loaded.sections[.picture]?.content, "### The Picture\n- Bullet one")
        XCTAssertEqual(loaded.sections[.watchList]?.content, "### Watch List\n- Item")
    }

    // MARK: - 3. Update single section

    func testUpdateSingleSection() async {
        // Seed initial data
        var briefing = CachedBriefing.empty
        briefing.sections[.picture] = CachedBriefing.SectionCache(
            content: "Old content",
            lastUpdated: Date().addingTimeInterval(-3600)
        )
        await cache.save(briefing)

        // Update just the picture section
        await cache.updateSection(.picture, content: "New content")

        let loaded = await cache.load()
        XCTAssertEqual(loaded.sections[.picture]?.content, "New content")
    }

    // MARK: - 4. Update session ID

    func testUpdateSessionId() async {
        await cache.save(CachedBriefing.empty)
        await cache.updateSessionId("new-session-123")

        let loaded = await cache.load()
        XCTAssertEqual(loaded.sessionId, "new-session-123")
    }

    // MARK: - 5. Clear removes cache

    func testClearRemovesCache() async {
        var briefing = CachedBriefing.empty
        briefing.sections[.header] = CachedBriefing.SectionCache(content: "test", lastUpdated: Date())
        await cache.save(briefing)

        // Verify it was saved
        let loaded = await cache.load()
        XCTAssertFalse(loaded.isEmpty)

        // Clear and verify
        await cache.clear()
        let afterClear = await cache.load()
        XCTAssertTrue(afterClear.isEmpty)
    }
}
