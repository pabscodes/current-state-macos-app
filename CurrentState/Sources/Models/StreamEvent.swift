import Foundation

/// Parsed events from Claude Code's stream-json output.
enum StreamEvent {
    case init_(InitEvent)
    case assistantText(String)
    case result(ResultEvent)
    case ignored

    struct InitEvent {
        let sessionId: String
        let model: String
    }

    struct ResultEvent {
        let sessionId: String
        let fullText: String
        let isError: Bool
        let durationMs: Int?
        let costUsd: Double?
    }
}
