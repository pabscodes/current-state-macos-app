import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content area: dashboard (sections) + messages (chat)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        // Section-based dashboard (if sections exist)
                        if !appState.sections.isEmpty {
                            DashboardView()
                                .id("dashboard")
                        }

                        // Chat messages (passthrough content + follow-ups)
                        ForEach(appState.messages) { message in
                            // Skip empty assistant messages that were just placeholders
                            if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }

                        // Error banner
                        if let errorMessage = appState.errorMessage {
                            ErrorBanner(message: errorMessage) {
                                appState.startNewBriefing()
                            }
                        }

                        // Loading indicator (only when no sections exist yet)
                        if appState.streamingState == .loading && appState.sections.isEmpty {
                            LoadingIndicator()
                                .id("loading")
                        }
                    }
                    .padding()
                }
                .onChange(of: appState.scrollTrigger) {
                    if let last = appState.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: appState.messages.count) {
                    if let last = appState.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input bar
            InputBar(placeholder: inputPlaceholder) { text in
                appState.sendMessage(text)
            }
            .disabled(appState.streamingState == .loading || appState.streamingState == .streaming || appState.errorMessage != nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

            // Load cached sections first (instant)
            await appState.loadCachedBriefing()

            // Then start a fresh briefing in background
            let autoGenerate = UserDefaults.standard.bool(forKey: "currentstate.autoGenerate")
            if autoGenerate && appState.messages.isEmpty && appState.streamingState == .idle {
                appState.startNewBriefing()
            }
        }
    }

    private var inputPlaceholder: String {
        if appState.streamingState == .loading || appState.streamingState == .streaming {
            return "Generating..."
        }
        if !appState.sections.isEmpty || appState.messages.contains(where: { $0.role == .assistant && !$0.content.isEmpty }) {
            return "Ask a follow-up..."
        }
        return "Type a message..."
    }

    private var header: some View {
        HStack {
            // Show date/time from header section; fall back to system date
            if let headerSection = appState.sections[.header] {
                Text(headerSection.content
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "## ", with: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(Date(), style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status indicator
            StatusIndicator(state: appState.streamingState)

            Button(action: { appState.startNewBriefing() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("New Briefing (⌘N)")

            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings (⌘,)")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct ErrorBanner: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.subheadline)
                .lineLimit(3)

            Spacer()

            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct LoadingIndicator: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            Text("Preparing your briefing")
                .foregroundStyle(.secondary)
            Text(String(repeating: ".", count: (dotCount % 3) + 1))
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .leading)
        }
        .font(.subheadline)
        .onReceive(timer) { _ in
            dotCount += 1
        }
    }
}
