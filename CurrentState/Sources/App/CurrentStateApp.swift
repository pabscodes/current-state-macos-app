import SwiftUI

@main
struct CurrentStateApp: App {
    @StateObject private var appState = AppState()

    init() {
        UserDefaults.standard.register(defaults: [
            "currentstate.startupSkill": "/currentstate-app",
            "currentstate.autoGenerate": true,
        ])
    }

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

                Button("Refresh Briefing") {
                    appState.startNewBriefing()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Clear Conversation") {
                    appState.clearConversation()
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
