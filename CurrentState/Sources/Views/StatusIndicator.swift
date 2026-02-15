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
        case .idle: return "Ready"
        case .loading: return "Working..."
        case .streaming: return "Streaming"
        case .error(let message):
            let truncated = message.prefix(30)
            return truncated.count < message.count ? "\(truncated)…" : message
        }
    }
}
