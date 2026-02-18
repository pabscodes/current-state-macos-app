import XCTest
@testable import Current_State

final class SectionStreamParserTests: XCTestCase {

    // MARK: - 1. Complete section in one chunk

    func testCompleteSectionInOneChunk() {
        let parser = SectionStreamParser()
        let input = "<<<SECTION:picture>>>\n### The Picture\n- Bullet one\n<<</SECTION:picture>>>"

        let events = parser.feed(input)

        XCTAssertTrue(events.contains(.sectionStarted(.picture)))
        // Find the completed event
        let completed = events.compactMap { event -> String? in
            if case .sectionCompleted(.picture, let content) = event { return content }
            return nil
        }
        XCTAssertEqual(completed.count, 1)
        XCTAssertTrue(completed[0].contains("### The Picture"))
        XCTAssertTrue(completed[0].contains("- Bullet one"))
    }

    // MARK: - 2. Section split across multiple chunks

    func testSectionSplitAcrossChunks() {
        let parser = SectionStreamParser()

        var events = parser.feed("<<<SECTION:picture>>>\n### The ")
        XCTAssertTrue(events.contains(.sectionStarted(.picture)))

        events = parser.feed("Picture\n- Line one\n")
        // May or may not have incremental content events

        events = parser.feed("- Line two\n<<</SECTION:picture>>>")
        let completed = events.compactMap { event -> String? in
            if case .sectionCompleted(.picture, let content) = event { return content }
            return nil
        }
        XCTAssertEqual(completed.count, 1)
        XCTAssertTrue(completed[0].contains("### The Picture"))
        XCTAssertTrue(completed[0].contains("- Line two"))
    }

    // MARK: - 3. Multiple sections in sequence

    func testMultipleSectionsInSequence() {
        let parser = SectionStreamParser()
        let input = """
        <<<SECTION:picture>>>
        ### The Picture
        - Bullet
        <<</SECTION:picture>>>
        <<<SECTION:watch_list>>>
        ### Watch List
        - Item
        <<</SECTION:watch_list>>>
        """

        let events = parser.feed(input)

        let startedIds = events.compactMap { event -> SectionID? in
            if case .sectionStarted(let id) = event { return id }
            return nil
        }
        XCTAssertTrue(startedIds.contains(.picture))
        XCTAssertTrue(startedIds.contains(.watchList))

        let completedIds = events.compactMap { event -> SectionID? in
            if case .sectionCompleted(let id, _) = event { return id }
            return nil
        }
        XCTAssertTrue(completedIds.contains(.picture))
        XCTAssertTrue(completedIds.contains(.watchList))
    }

    // MARK: - 4. Delimiter split at chunk boundary

    func testDelimiterSplitAtChunkBoundary() {
        let parser = SectionStreamParser()

        // Feed the opening tag split across two chunks
        var events = parser.feed("<<<SECTION:pic")
        // Should not have started a section yet — tag is incomplete
        let started = events.compactMap { event -> SectionID? in
            if case .sectionStarted(let id) = event { return id }
            return nil
        }
        XCTAssertTrue(started.isEmpty, "Should not start section with incomplete delimiter")

        events = parser.feed("ture>>>\nContent here\n<<</SECTION:picture>>>")
        let completedIds = events.compactMap { event -> SectionID? in
            if case .sectionCompleted(let id, _) = event { return id }
            return nil
        }
        XCTAssertTrue(completedIds.contains(.picture))
    }

    // MARK: - 5. Text before first section (passthrough)

    func testTextBeforeFirstSection() {
        let parser = SectionStreamParser()
        let input = "Some preamble text here.\n<<<SECTION:header>>>\n## Monday\n<<</SECTION:header>>>"

        let events = parser.feed(input)

        let passthroughs = events.compactMap { event -> String? in
            if case .passthrough(let text) = event { return text }
            return nil
        }
        XCTAssertTrue(passthroughs.contains(where: { $0.contains("Some preamble text") }))

        let completedIds = events.compactMap { event -> SectionID? in
            if case .sectionCompleted(let id, _) = event { return id }
            return nil
        }
        XCTAssertTrue(completedIds.contains(.header))
    }

    // MARK: - 6. Text between sections

    func testTextBetweenSections() {
        let parser = SectionStreamParser()
        let input = """
        <<<SECTION:header>>>
        ## Monday
        <<</SECTION:header>>>
        Some interstitial text.
        <<<SECTION:picture>>>
        ### The Picture
        <<</SECTION:picture>>>
        """

        let events = parser.feed(input)

        let passthroughs = events.compactMap { event -> String? in
            if case .passthrough(let text) = event { return text }
            return nil
        }
        XCTAssertTrue(passthroughs.contains(where: { $0.contains("interstitial") }))
    }

    // MARK: - 7. Unknown section ID

    func testUnknownSectionId() {
        let parser = SectionStreamParser()
        let input = "<<<SECTION:unknown_thing>>>\nContent\n<<</SECTION:unknown_thing>>>"

        let events = parser.feed(input)

        // Unknown section IDs should be skipped, content becomes passthrough
        let startedIds = events.compactMap { event -> SectionID? in
            if case .sectionStarted(let id) = event { return id }
            return nil
        }
        XCTAssertTrue(startedIds.isEmpty, "Unknown section ID should not start a section")
    }

    // MARK: - 8. Stream ends without closing delimiter (flush)

    func testFlushWithoutClosingDelimiter() {
        let parser = SectionStreamParser()

        _ = parser.feed("<<<SECTION:picture>>>\n### The Picture\n- Partial content")
        let flushEvents = parser.flush()

        let completed = flushEvents.compactMap { event -> String? in
            if case .sectionCompleted(.picture, let content) = event { return content }
            return nil
        }
        XCTAssertEqual(completed.count, 1)
        XCTAssertTrue(completed[0].contains("Partial content"))
    }

    // MARK: - 9. Empty section content

    func testEmptySectionContent() {
        let parser = SectionStreamParser()
        let input = "<<<SECTION:header>>><<</SECTION:header>>>"

        let events = parser.feed(input)

        let completed = events.compactMap { event -> String? in
            if case .sectionCompleted(.header, let content) = event { return content }
            return nil
        }
        XCTAssertEqual(completed.count, 1)
        XCTAssertEqual(completed[0], "")
    }

    // MARK: - 10. Special characters in content

    func testSpecialCharactersInContent() {
        let parser = SectionStreamParser()
        let input = "<<<SECTION:picture>>>\n| # | Item | Cost ($) |\n|---|------|----------|\n| 1 | Test & verify | $100 |\n<<</SECTION:picture>>>"

        let events = parser.feed(input)

        let completed = events.compactMap { event -> String? in
            if case .sectionCompleted(.picture, let content) = event { return content }
            return nil
        }
        XCTAssertEqual(completed.count, 1)
        XCTAssertTrue(completed[0].contains("$100"))
        XCTAssertTrue(completed[0].contains("&"))
    }

    // MARK: - 11. Incremental content events

    func testIncrementalContentEvents() {
        let parser = SectionStreamParser()

        _ = parser.feed("<<<SECTION:picture>>>\n")

        // Feed a large chunk that exceeds the 40-char buffer threshold
        let largeContent = String(repeating: "A", count: 100) + "\n"
        let events = parser.feed(largeContent)

        let contentEvents = events.compactMap { event -> String? in
            if case .sectionContent(.picture, let text) = event { return text }
            return nil
        }
        // Should have emitted incremental content (keeping last 40 chars buffered)
        XCTAssertFalse(contentEvents.isEmpty, "Should emit incremental content for large chunks")
    }

    // MARK: - 12. Reset clears state

    func testResetClearsState() {
        let parser = SectionStreamParser()

        _ = parser.feed("<<<SECTION:picture>>>\n### The Picture")
        parser.reset()

        // After reset, feeding a new stream should work cleanly
        let events = parser.feed("<<<SECTION:header>>>\n## Tuesday\n<<</SECTION:header>>>")

        let startedIds = events.compactMap { event -> SectionID? in
            if case .sectionStarted(let id) = event { return id }
            return nil
        }
        XCTAssertTrue(startedIds.contains(.header))
        XCTAssertFalse(startedIds.contains(.picture), "Reset should have cleared the picture section state")
    }
}
