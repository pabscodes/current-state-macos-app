import SwiftUI
import os

@MainActor
final class AppState: ObservableObject {
    private static let logger = Logger(subsystem: "com.pabscodes.currentstate", category: "AppState")

    // MARK: - Published Properties

    @Published var messages: [Message] = []
    @Published var streamingState: StreamingState = .idle
    @Published var currentSessionId: String?
    @Published var scrollTrigger = UUID()

    /// Per-section briefing data, keyed by SectionID.
    @Published var sections: [SectionID: BriefingSection] = [:]

    /// Whether we loaded cached content (enables instant-on UX).
    @Published var hasCachedBriefing: Bool = false

    /// Sections currently being individually refreshed.
    @Published var refreshingSectionIds: Set<SectionID> = []

    // MARK: - Private Members

    private let claudeService: any ClaudeCodeServiceProtocol
    private let sessionStore = SessionStore()
    private let briefingCache: BriefingCache
    private let sectionParser = SectionStreamParser()
    private var currentTask: Task<Void, Never>?
    private var refreshTasks: [SectionID: Task<Void, Never>] = [:]

    enum StreamingState: Equatable {
        case idle
        case loading       // subprocess started, no text yet
        case streaming     // receiving assistant text
        case error(String) // something went wrong
    }

    init(
        claudeService: any ClaudeCodeServiceProtocol = ClaudeCodeService(),
        briefingCache: BriefingCache = BriefingCache()
    ) {
        self.claudeService = claudeService
        self.briefingCache = briefingCache
    }

    var errorMessage: String? {
        if case .error(let message) = streamingState {
            return message
        }
        return nil
    }

    // MARK: - Cache Loading

    /// Loads cached sections from disk. Called once on launch for instant content.
    func loadCachedBriefing() async {
        let cached = await briefingCache.load()
        guard !cached.isEmpty else { return }

        for (id, sectionCache) in cached.sections {
            sections[id] = BriefingSection(
                id: id,
                content: sectionCache.content,
                lastUpdated: sectionCache.lastUpdated,
                loadingState: .cached
            )
        }
        if let sessionId = cached.sessionId {
            currentSessionId = sessionId
            sessionStore.save(sessionId)
        }
        hasCachedBriefing = true
        Self.logger.info("Loaded \(cached.sections.count) cached sections")
    }

    // MARK: - Briefing Flow

    func startNewBriefing() {
        Self.logger.info("startNewBriefing called")
        currentTask?.cancel()

        // If we have cached sections, keep them visible but mark as refreshing
        if hasCachedBriefing {
            for id in sections.keys {
                sections[id]?.loadingState = .refreshing
            }
        }

        messages = []
        currentSessionId = nil
        sessionStore.clear()
        streamingState = .loading
        sectionParser.reset()

        let skill = UserDefaults.standard.string(forKey: "currentstate.startupSkill") ?? "/currentstate-app"
        Self.logger.info("Using skill: \(skill)")

        currentTask = Task {
            Self.logger.info("Task started, calling sendBriefingRequest")
            await sendBriefingRequest(prompt: skill, isNewSession: true)
            Self.logger.info("sendBriefingRequest returned")
        }
    }

    func clearConversation() {
        currentTask?.cancel()
        for task in refreshTasks.values { task.cancel() }
        refreshTasks.removeAll()
        messages = []
        sections = [:]
        hasCachedBriefing = false
        refreshingSectionIds = []
        currentSessionId = nil
        sessionStore.clear()
        streamingState = .idle
        sectionParser.reset()
    }

    func sendMessage(_ text: String) {
        currentTask?.cancel()
        let userMessage = Message(role: .user, content: text)
        messages.append(userMessage)
        streamingState = .loading
        sectionParser.reset()

        currentTask = Task {
            await sendBriefingRequest(prompt: text, isNewSession: false)

            // Smart refresh: detect user action and refresh affected sections
            if let action = UserAction.detect(from: text) {
                smartRefresh(after: action)
            }
        }
    }

    // MARK: - Section Refresh

    /// Refresh a single section by sending `/currentstate-app --section <id>` via `--resume`.
    func refreshSection(_ id: SectionID) {
        guard currentSessionId != nil else {
            Self.logger.warning("Cannot refresh section without session ID")
            return
        }

        refreshTasks[id]?.cancel()
        refreshingSectionIds.insert(id)
        sections[id]?.loadingState = .refreshing

        let prompt = "/currentstate-app --section \(id.rawValue)"

        refreshTasks[id] = Task {
            let parser = SectionStreamParser()
            let assistantMessage = Message(role: .assistant, content: "")
            messages.append(assistantMessage)
            let messageIndex = messages.count - 1

            do {
                for try await event in claudeService.stream(prompt: prompt, sessionId: currentSessionId) {
                    switch event {
                    case .init_(let initEvent):
                        currentSessionId = initEvent.sessionId
                        sessionStore.save(initEvent.sessionId)

                    case .assistantText(let text):
                        let sectionEvents = parser.feed(text)
                        processSectionEvents(sectionEvents, messageIndex: messageIndex)

                    case .result(let resultEvent):
                        currentSessionId = resultEvent.sessionId
                        sessionStore.save(resultEvent.sessionId)
                        let remaining = parser.flush()
                        processSectionEvents(remaining, messageIndex: messageIndex)

                        if !resultEvent.isError {
                            // Persist the updated section
                            if let section = sections[id], section.loadingState == .complete {
                                await briefingCache.updateSection(id, content: section.content)
                            }
                        }

                    case .ignored:
                        break
                    }
                }
            } catch is CancellationError {
                Self.logger.info("Section refresh cancelled for \(id.rawValue)")
            } catch {
                Self.logger.error("Section refresh error for \(id.rawValue): \(error.localizedDescription)")
                sections[id]?.loadingState = .error(error.localizedDescription)
            }

            refreshingSectionIds.remove(id)
            refreshTasks[id] = nil

            // Clean up empty assistant message from section refresh
            removeEmptyPartialMessage(at: messageIndex)
        }
    }

    /// Maps a user action to affected sections and refreshes each.
    func smartRefresh(after action: UserAction) {
        Self.logger.info("Smart refresh triggered for action, affecting \(action.affectedSections.count) sections")
        for sectionId in action.affectedSections {
            refreshSection(sectionId)
        }
    }

    // MARK: - Core Stream Processing

    private func sendBriefingRequest(prompt: String, isNewSession: Bool) async {
        let assistantMessage = Message(role: .assistant, content: "")
        messages.append(assistantMessage)
        let messageIndex = messages.count - 1

        let sessionId = isNewSession ? nil : currentSessionId

        do {
            Self.logger.info("Starting stream for prompt: \(prompt, privacy: .private)")
            for try await event in claudeService.stream(prompt: prompt, sessionId: sessionId) {
                switch event {
                case .init_(let initEvent):
                    Self.logger.info("Received init event, sessionId: \(initEvent.sessionId)")
                    currentSessionId = initEvent.sessionId
                    sessionStore.save(initEvent.sessionId)

                case .assistantText(let text):
                    Self.logger.info("Received assistant text (\(text.count) chars)")
                    if streamingState == .loading {
                        streamingState = .streaming
                    }

                    // Route ALL text through section parser — it handles both
                    // delimited sections and passthrough (backward compat)
                    let sectionEvents = sectionParser.feed(text)
                    processSectionEvents(sectionEvents, messageIndex: messageIndex)
                    scrollTrigger = UUID()

                case .result(let resultEvent):
                    Self.logger.info("Received result event, isError: \(resultEvent.isError)")
                    currentSessionId = resultEvent.sessionId
                    sessionStore.save(resultEvent.sessionId)

                    // Flush the parser
                    let remaining = sectionParser.flush()
                    processSectionEvents(remaining, messageIndex: messageIndex)

                    if resultEvent.isError {
                        removeEmptyPartialMessage(at: messageIndex)
                        streamingState = .error("Claude returned an error. Check your prompt and try again.")
                    } else {
                        streamingState = .idle
                        // Persist all complete sections
                        await persistAllSections()
                    }

                case .ignored:
                    Self.logger.info("Received ignored event")
                    break
                }
            }

            if streamingState != .idle && streamingState != .error("") {
                if case .error = streamingState {
                    // Already in error state from isError handling — don't override
                } else {
                    streamingState = .idle
                }
            }
        } catch is CancellationError {
            Self.logger.info("Stream cancelled")
        } catch {
            Self.logger.error("Stream error: \(error.localizedDescription)")
            removeEmptyPartialMessage(at: messageIndex)
            streamingState = .error(actionableMessage(for: error))
        }
    }

    // MARK: - Section Event Processing

    private func processSectionEvents(_ events: [SectionEvent], messageIndex: Int) {
        for event in events {
            switch event {
            case .sectionStarted(let id):
                Self.logger.info("Section started: \(id.rawValue)")
                sections[id] = BriefingSection(
                    id: id,
                    content: "",
                    lastUpdated: Date(),
                    loadingState: .streaming
                )

            case .sectionContent(let id, let text):
                sections[id]?.content += text

            case .sectionCompleted(let id, let content):
                Self.logger.info("Section completed: \(id.rawValue) (\(content.count) chars)")
                sections[id] = BriefingSection(
                    id: id,
                    content: content,
                    lastUpdated: Date(),
                    loadingState: .complete
                )

            case .passthrough(let text):
                // No delimiters — append to the flat message (backward compat with /currentstate)
                if messageIndex < messages.count {
                    messages[messageIndex].content += text
                }
            }
        }
    }

    // MARK: - Persistence

    private func persistAllSections() async {
        var cached = CachedBriefing.empty
        cached.sessionId = currentSessionId
        cached.lastFullRefresh = Date()

        for (id, section) in sections where section.loadingState == .complete {
            cached.sections[id] = CachedBriefing.SectionCache(
                content: section.content,
                lastUpdated: section.lastUpdated
            )
        }

        await briefingCache.save(cached)
        Self.logger.info("Persisted \(cached.sections.count) sections to cache")
    }

    // MARK: - Helpers

    private func removeEmptyPartialMessage(at index: Int) {
        guard index < messages.count,
              messages[index].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        messages.remove(at: index)
    }

    private func actionableMessage(for error: Error) -> String {
        if let claudeError = error as? ClaudeCodeError {
            switch claudeError {
            case .binaryNotFound:
                return "Claude Code CLI not found. Check the path in Settings (⌘,) or install with: npm install -g @anthropic-ai/claude-code"
            case .processExited(let code, _):
                return "Claude Code exited unexpectedly (code \(code)). Try again or restart the app."
            }
        }
        return "Something went wrong. Please try again."
    }
}
