import SwiftUI

struct StatusIndicator: View {
    let state: AppState.StreamingState

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var color: Color {
        switch state {
        case .idle: .green
        case .loading: .orange
        case .streaming: .blue
        case .error: .red
        }
    }

    private var label: String {
        switch state {
        case .idle: "Ready"
        case .loading: "Working..."
        case .streaming: "Streaming"
        case .error: "Error"
        }
    }
}
