import Foundation

/// A single section of a daily briefing with its content and state.
struct BriefingSection: Identifiable, Codable, Sendable {
    let id: SectionID
    var content: String
    var lastUpdated: Date
    var loadingState: LoadingState

    enum LoadingState: Codable, Equatable, Sendable {
        case cached
        case refreshing
        case streaming
        case complete
        case error(String)
    }

    /// Content with the leading markdown heading stripped, to avoid duplicating
    /// the card header title that already shows `id.displayTitle`.
    var strippedContent: String {
        let lines = content.components(separatedBy: "\n")
        guard let firstIdx = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return content
        }
        guard lines[firstIdx].trimmingCharacters(in: .whitespaces).hasPrefix("#") else {
            return content
        }
        var remaining = lines
        remaining.remove(at: firstIdx)
        return remaining.joined(separator: "\n").trimmingCharacters(in: .newlines)
    }
}
