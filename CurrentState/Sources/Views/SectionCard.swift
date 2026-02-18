import SwiftUI
import MarkdownUI

/// Renders an individual briefing section with its markdown content,
/// loading state overlay, and context menu for per-section refresh.
struct SectionCard: View {
    let section: BriefingSection
    var onRefresh: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Markdown(section.content)
                .markdownTheme(.currentState)
                .textSelection(.enabled)
                .opacity(section.loadingState == .refreshing ? 0.5 : 1.0)
                .overlay {
                    if section.loadingState == .refreshing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(8)
                    }
                }

            // Stale indicator for cached sections
            if section.loadingState == .cached {
                let age = Date().timeIntervalSince(section.lastUpdated)
                if age > 300 { // > 5 minutes
                    Text("Updated \(relativeTime(age)) ago")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }

            if case .error(let message) = section.loadingState {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.top, 4)
            }
        }
        .contextMenu {
            if let onRefresh {
                Button("Refresh This Section") {
                    onRefresh()
                }
            }
        }
    }

    private func relativeTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}
