import SwiftUI
import os

@MainActor
final class AppState: ObservableObject {
    private static let logger = Logger(subsystem: "com.pabscodes.currentstate", category: "AppState")
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
        Self.logger.info("startNewBriefing called")
        currentTask?.cancel()
        messages = []
        currentSessionId = nil
        sessionStore.clear()
        streamingState = .loading

        let skill = UserDefaults.standard.string(forKey: "currentstate.startupSkill") ?? "/currentstate"
        Self.logger.info("Using skill: \(skill)")

        currentTask = Task {
            Self.logger.info("Task started, calling sendToClaudeCode")
            await sendToClaudeCode(prompt: skill, isNewSession: true)
            Self.logger.info("sendToClaudeCode returned")
        }
    }

    func clearConversation() {
        currentTask?.cancel()
        messages = []
        currentSessionId = nil
        sessionStore.clear()
        streamingState = .idle
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
                    messages[messageIndex].content += text
                    scrollTrigger = UUID()

                case .result(let resultEvent):
                    Self.logger.info("Received result event, isError: \(resultEvent.isError)")
                    currentSessionId = resultEvent.sessionId
                    sessionStore.save(resultEvent.sessionId)

                    if resultEvent.isError {
                        removeEmptyPartialMessage(at: messageIndex)
                        streamingState = .error("Claude returned an error. Check your prompt and try again.")
                    } else {
                        streamingState = .idle
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
