import Foundation

/// Persists the current Claude Code session ID across app restarts.
struct SessionStore {
    private let key = "currentstate.sessionId"

    func save(_ sessionId: String) {
        UserDefaults.standard.set(sessionId, forKey: key)
    }

    func load() -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
