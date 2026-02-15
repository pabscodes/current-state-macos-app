import XCTest
@testable import Current_State

final class StreamParserTests: XCTestCase {

    // MARK: - Init Event

    func testParseInitEvent() {
        let json = """
        {"type":"system","subtype":"init","session_id":"abc-123","model":"claude-opus-4-6","tools":["Bash","Read"],"skills":["currentstate"]}
        """

        let event = StreamParser.parse(line: json)

        guard case .init_(let initEvent) = event else {
            XCTFail("Expected init event, got \(event)")
            return
        }
        XCTAssertEqual(initEvent.sessionId, "abc-123")
        XCTAssertEqual(initEvent.model, "claude-opus-4-6")
    }

    // MARK: - Assistant Event

    func testParseAssistantTextEvent() {
        let json = """
        {"type":"assistant","message":{"content":[{"type":"text","text":"## Saturday, Feb 15"}],"model":"claude-opus-4-6"},"session_id":"abc-123"}
        """

        let event = StreamParser.parse(line: json)

        guard case .assistantText(let text) = event else {
            XCTFail("Expected assistantText event, got \(event)")
            return
        }
        XCTAssertEqual(text, "## Saturday, Feb 15")
    }

    func testParseAssistantWithMultipleContentBlocks() {
        let json = """
        {"type":"assistant","message":{"content":[{"type":"text","text":"Hello "},{"type":"text","text":"world"}],"model":"claude-opus-4-6"},"session_id":"abc-123"}
        """

        let event = StreamParser.parse(line: json)

        guard case .assistantText(let text) = event else {
            XCTFail("Expected assistantText event, got \(event)")
            return
        }
        XCTAssertEqual(text, "Hello world")
    }

    func testParseAssistantWithToolUseContentIsIgnored() {
        // When assistant message contains tool_use blocks (no text), should be ignored
        let json = """
        {"type":"assistant","message":{"content":[{"type":"tool_use","id":"tool1","name":"Bash","input":{"command":"things today"}}],"model":"claude-opus-4-6"},"session_id":"abc-123"}
        """

        let event = StreamParser.parse(line: json)

        guard case .ignored = event else {
            XCTFail("Expected ignored event for tool_use content, got \(event)")
            return
        }
    }

    // MARK: - Result Event

    func testParseResultEvent() {
        let json = """
        {"type":"result","subtype":"success","is_error":false,"result":"Full response text","session_id":"abc-123","duration_ms":3130,"total_cost_usd":0.073}
        """

        let event = StreamParser.parse(line: json)

        guard case .result(let resultEvent) = event else {
            XCTFail("Expected result event, got \(event)")
            return
        }
        XCTAssertEqual(resultEvent.sessionId, "abc-123")
        XCTAssertEqual(resultEvent.fullText, "Full response text")
        XCTAssertFalse(resultEvent.isError)
        XCTAssertEqual(resultEvent.durationMs, 3130)
        XCTAssertEqual(resultEvent.costUsd!, 0.073, accuracy: 0.001)
    }

    func testParseResultErrorEvent() {
        let json = """
        {"type":"result","subtype":"error","is_error":true,"result":"","session_id":"abc-123"}
        """

        let event = StreamParser.parse(line: json)

        guard case .result(let resultEvent) = event else {
            XCTFail("Expected result event, got \(event)")
            return
        }
        XCTAssertTrue(resultEvent.isError)
    }

    // MARK: - Ignored Events

    func testUnknownTypeIsIgnored() {
        let json = """
        {"type":"tool_result","content":"[{task data}]"}
        """

        let event = StreamParser.parse(line: json)

        guard case .ignored = event else {
            XCTFail("Expected ignored event, got \(event)")
            return
        }
    }

    func testInvalidJSONIsIgnored() {
        let event = StreamParser.parse(line: "not json at all")

        guard case .ignored = event else {
            XCTFail("Expected ignored event, got \(event)")
            return
        }
    }

    func testEmptyLineIsIgnored() {
        let event = StreamParser.parse(line: "")

        guard case .ignored = event else {
            XCTFail("Expected ignored event, got \(event)")
            return
        }
    }

    // MARK: - Real-World Data

    func testParseRealInitEvent() {
        // Captured from live Claude Code v2.1.42 on 2026-02-15
        let json = """
        {"type":"system","subtype":"init","cwd":"/Users/pabloordonezbravo","session_id":"c45a70e1-0d9b-484e-a7b9-b8045d28d718","model":"claude-opus-4-6","tools":["Task","Bash","Read"],"claude_code_version":"2.1.42"}
        """

        let event = StreamParser.parse(line: json)

        guard case .init_(let initEvent) = event else {
            XCTFail("Expected init event")
            return
        }
        XCTAssertEqual(initEvent.sessionId, "c45a70e1-0d9b-484e-a7b9-b8045d28d718")
        XCTAssertEqual(initEvent.model, "claude-opus-4-6")
    }

    func testParseRealAssistantEvent() {
        // Captured from live Claude Code v2.1.42 on 2026-02-15
        let json = """
        {"type":"assistant","message":{"model":"claude-opus-4-6","id":"msg_01HSqZjiTJ8ybWxQEHMJQqEd","type":"message","role":"assistant","content":[{"type":"text","text":"Hello! How can I help you today?"}],"stop_reason":null,"usage":{"input_tokens":3,"output_tokens":1}},"session_id":"c45a70e1-0d9b-484e-a7b9-b8045d28d718"}
        """

        let event = StreamParser.parse(line: json)

        guard case .assistantText(let text) = event else {
            XCTFail("Expected assistantText event")
            return
        }
        XCTAssertEqual(text, "Hello! How can I help you today?")
    }
}
