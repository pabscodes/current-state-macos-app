import Foundation
import os

/// Thread-safe file-based cache for briefing sections.
/// Stores to `~/Library/Application Support/CurrentState/briefing-cache.json`.
actor BriefingCache {
    private static let logger = Logger(subsystem: "com.pabscodes.currentstate", category: "BriefingCache")

    private let fileURL: URL

    init(directory: URL? = nil) {
        if let directory {
            self.fileURL = directory.appendingPathComponent("briefing-cache.json")
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("CurrentState")
            self.fileURL = dir.appendingPathComponent("briefing-cache.json")
        }
    }

    /// Load cached briefing from disk. Returns `.empty` if no cache exists.
    func load() -> CachedBriefing {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Self.logger.info("No cache file found at \(self.fileURL.path)")
            return .empty
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let briefing = try JSONDecoder.cachingDecoder.decode(CachedBriefing.self, from: data)
            Self.logger.info("Loaded cache with \(briefing.sections.count) sections")
            return briefing
        } catch {
            Self.logger.error("Failed to load cache: \(error.localizedDescription)")
            return .empty
        }
    }

    /// Atomically write the full briefing to disk.
    func save(_ briefing: CachedBriefing) {
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let data = try JSONEncoder.cachingEncoder.encode(briefing)
            try data.write(to: fileURL, options: .atomic)
            Self.logger.info("Saved cache with \(briefing.sections.count) sections")
        } catch {
            Self.logger.error("Failed to save cache: \(error.localizedDescription)")
        }
    }

    /// Update a single section in the cache.
    func updateSection(_ id: SectionID, content: String) {
        var briefing = load()
        briefing.sections[id] = CachedBriefing.SectionCache(content: content, lastUpdated: Date())
        save(briefing)
    }

    /// Update the session ID for resume support.
    func updateSessionId(_ id: String) {
        var briefing = load()
        briefing.sessionId = id
        save(briefing)
    }

    /// Delete the cache file.
    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
        Self.logger.info("Cache cleared")
    }
}

// MARK: - Coder Helpers

private extension JSONDecoder {
    static let cachingDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private extension JSONEncoder {
    static let cachingEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
