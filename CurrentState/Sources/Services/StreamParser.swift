import Foundation

/// Parses newline-delimited JSON from Claude Code's stream-json output.
struct StreamParser {

    /// Parse a single line of NDJSON into a StreamEvent.
    static func parse(line: String) -> StreamEvent {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return .ignored
        }

        switch type {
        case "system":
            return parseInit(json)
        case "assistant":
            return parseAssistant(json)
        case "result":
            return parseResult(json)
        default:
            return .ignored
        }
    }

    // MARK: - Private

    private static func parseInit(_ json: [String: Any]) -> StreamEvent {
        guard let subtype = json["subtype"] as? String, subtype == "init",
              let sessionId = json["session_id"] as? String else {
            return .ignored
        }
        let model = json["model"] as? String ?? "unknown"
        return .init_(StreamEvent.InitEvent(sessionId: sessionId, model: model))
    }

    private static func parseAssistant(_ json: [String: Any]) -> StreamEvent {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else {
            return .ignored
        }

        let text = content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()

        guard !text.isEmpty else { return .ignored }
        return .assistantText(text)
    }

    private static func parseResult(_ json: [String: Any]) -> StreamEvent {
        let sessionId = json["session_id"] as? String ?? ""
        let fullText = json["result"] as? String ?? ""
        let isError = json["is_error"] as? Bool ?? false
        let durationMs = json["duration_ms"] as? Int
        let costUsd = json["total_cost_usd"] as? Double

        return .result(StreamEvent.ResultEvent(
            sessionId: sessionId,
            fullText: fullText,
            isError: isError,
            durationMs: durationMs,
            costUsd: costUsd
        ))
    }
}
