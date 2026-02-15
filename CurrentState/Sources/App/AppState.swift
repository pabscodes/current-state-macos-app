import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var messages: [Message] = []
    @Published var streamingState: StreamingState = .idle
    @Published var currentSessionId: String?

    private let claudeService = ClaudeCodeService()
    private let sessionStore = SessionStore()

    enum StreamingState: Equatable {
        case idle
        case loading       // subprocess started, no text yet
        case streaming     // receiving assistant text
        case error(String) // something went wrong
    }

    init() {
        // Auto-generate briefing on launch
        startNewBriefing()
    }

    func startNewBriefing() {
        messages = []
        currentSessionId = nil
        sessionStore.clear()
        streamingState = .loading

        Task {
            await sendToClaudeCode(prompt: "/currentstate", isNewSession: true)
        }
    }

    func sendMessage(_ text: String) {
        let userMessage = Message(role: .user, content: text)
        messages.append(userMessage)
        streamingState = .loading

        Task {
            await sendToClaudeCode(prompt: text, isNewSession: false)
        }
    }

    private func sendToClaudeCode(prompt: String, isNewSession: Bool) async {
        let assistantMessage = Message(role: .assistant, content: "")
        messages.append(assistantMessage)
        let messageIndex = messages.count - 1

        let sessionId = isNewSession ? nil : currentSessionId

        do {
            for try await event in claudeService.stream(prompt: prompt, sessionId: sessionId) {
                switch event {
                case .init_(let initEvent):
                    currentSessionId = initEvent.sessionId
                    sessionStore.save(initEvent.sessionId)

                case .assistantText(let text):
                    if streamingState == .loading {
                        streamingState = .streaming
                    }
                    messages[messageIndex].content += text

                case .result(let resultEvent):
                    currentSessionId = resultEvent.sessionId
                    sessionStore.save(resultEvent.sessionId)
                    streamingState = .idle

                case .ignored:
                    break
                }
            }

            if streamingState != .idle {
                streamingState = .idle
            }
        } catch {
            streamingState = .error(error.localizedDescription)
        }
    }
}
