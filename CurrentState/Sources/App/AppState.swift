import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var messages: [Message] = []
    @Published var streamingState: StreamingState = .idle
    @Published var currentSessionId: String?
    @Published var scrollTrigger = UUID()

    private let claudeService: any ClaudeCodeServiceProtocol
    private let sessionStore = SessionStore()
    private var currentTask: Task<Void, Never>?

    enum StreamingState: Equatable {
        case idle
        case loading       // subprocess started, no text yet
        case streaming     // receiving assistant text
        case error(String) // something went wrong
    }

    init(claudeService: any ClaudeCodeServiceProtocol = ClaudeCodeService()) {
        self.claudeService = claudeService
    }

    var errorMessage: String? {
        if case .error(let message) = streamingState {
            return message
        }
        return nil
    }

    func startNewBriefing() {
        currentTask?.cancel()
        messages = []
        currentSessionId = nil
        sessionStore.clear()
        streamingState = .loading

        currentTask = Task {
            await sendToClaudeCode(prompt: "/currentstate", isNewSession: true)
        }
    }

    func sendMessage(_ text: String) {
        currentTask?.cancel()
        let userMessage = Message(role: .user, content: text)
        messages.append(userMessage)
        streamingState = .loading

        currentTask = Task {
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
                    scrollTrigger = UUID()

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
        } catch is CancellationError {
            // New task has taken over — don't touch UI state
        } catch {
            streamingState = .error(error.localizedDescription)
        }
    }
}
