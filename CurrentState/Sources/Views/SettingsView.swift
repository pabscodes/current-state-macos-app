import SwiftUI

struct SettingsView: View {
    @AppStorage("currentstate.claudePath") private var claudePath = ""
    @AppStorage("currentstate.startupSkill") private var startupSkill = "/currentstate"
    @AppStorage("currentstate.autoGenerate") private var autoGenerate = true

    var body: some View {
        Form {
            TextField("Claude CLI Path", text: $claudePath, prompt: Text("Auto-detect"))
            TextField("Startup Skill", text: $startupSkill, prompt: Text("/currentstate"))
            Toggle("Auto-generate briefing on launch", isOn: $autoGenerate)
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 200)
    }
}
