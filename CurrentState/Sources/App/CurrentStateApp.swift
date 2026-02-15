import SwiftUI

@main
struct CurrentStateApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .frame(minWidth: 500, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 600, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Briefing") {
                    appState.startNewBriefing()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
