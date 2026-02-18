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
}
