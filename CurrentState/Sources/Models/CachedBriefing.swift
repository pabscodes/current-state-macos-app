import Foundation

/// Root object for JSON-persisted briefing cache.
struct CachedBriefing: Codable, Sendable {
    var sections: [SectionID: SectionCache]
    var sessionId: String?
    var lastFullRefresh: Date?

    struct SectionCache: Codable, Sendable {
        let content: String
        let lastUpdated: Date
    }

    static let empty = CachedBriefing(sections: [:], sessionId: nil, lastFullRefresh: nil)

    var isEmpty: Bool { sections.isEmpty }
}
