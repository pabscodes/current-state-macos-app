import Foundation

/// Maps user actions (detected from chat messages) to the briefing sections they affect.
enum UserAction: Sendable {
    case taskCompleted
    case triageCompleted
    case calendarChanged
    case healthDataProvided

    /// The sections that should be refreshed when this action occurs.
    var affectedSections: [SectionID] {
        switch self {
        case .taskCompleted:
            return [.whatMatters, .picture, .looseEnds]
        case .triageCompleted:
            return [.inboxTriage, .whatMatters]
        case .calendarChanged:
            return [.watchList, .whatMatters, .picture]
        case .healthDataProvided:
            return [.wellbeing, .healthCheckin]
        }
    }

    /// Attempts to detect a user action from message text via keyword matching.
    static func detect(from text: String) -> UserAction? {
        let lower = text.lowercased()

        if lower.contains("done") || lower.contains("completed") || lower.contains("finished") {
            return .taskCompleted
        }
        if lower.contains("skip") || lower.contains("sat") || lower.contains("next week")
            || lower.contains("reschedule")
        {
            return .triageCompleted
        }
        if lower.contains("block") || lower.contains("calendar") || lower.contains("schedule") {
            return .calendarChanged
        }
        if lower.contains("ate") || lower.contains("energy") || lower.contains("sleep")
            || lower.contains("pain")
        {
            return .healthDataProvided
        }

        return nil
    }
}
