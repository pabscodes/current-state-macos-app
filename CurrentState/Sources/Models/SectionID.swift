import Foundation

/// Identifies each independent section of a daily briefing.
enum SectionID: String, CaseIterable, Codable, Identifiable, Sendable {
    case header
    case picture
    case watchList = "watch_list"
    case whatMatters = "what_matters"
    case looseEnds = "loose_ends"
    case inboxTriage = "inbox_triage"
    case wellbeing
    case healthCheckin = "health_checkin"

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .header: return "Header"
        case .picture: return "The Picture"
        case .watchList: return "Watch List"
        case .whatMatters: return "What Matters Today"
        case .looseEnds: return "Loose Ends"
        case .inboxTriage: return "Inbox & Triage"
        case .wellbeing: return "Wellbeing"
        case .healthCheckin: return "Health Check-in"
        }
    }

    /// Canonical display order for the dashboard.
    /// .header is excluded — it's handled specially by MainView.
    static let displayOrder: [SectionID] = [
        .picture, .whatMatters, .watchList,
        .looseEnds, .inboxTriage, .wellbeing, .healthCheckin,
    ]
}
