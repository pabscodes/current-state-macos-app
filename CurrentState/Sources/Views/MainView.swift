import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Content area: messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(appState.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        // Error banner
                        if let errorMessage = appState.errorMessage {
                            ErrorBanner(message: errorMessage) {
                                appState.startNewBriefing()
                            }
                        }

                        // Loading indicator
                        if appState.streamingState == .loading {
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
            }

            Divider()

            // Input bar
            InputBar { text in
                appState.sendMessage(text)
            }
            .disabled(appState.streamingState == .loading || appState.streamingState == .streaming)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
            if appState.messages.isEmpty && appState.streamingState == .idle {
                appState.startNewBriefing()
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Current State")
                .font(.headline)

            Spacer()

            // Status indicator
            StatusIndicator(state: appState.streamingState)

            Button(action: { appState.startNewBriefing() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("New Briefing (⌘N)")
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
