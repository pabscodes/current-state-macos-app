import SwiftUI
import MarkdownUI

/// Renders an individual briefing section with a header row (title + timestamp + refresh),
/// Liquid Glass background, and markdown content.
struct SectionCard: View {
    let section: BriefingSection
    var onRefresh: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow

            Divider()

            Markdown(section.content)
                .markdownTheme(.currentState)
                .textSelection(.enabled)
                .opacity(isLoading ? 0.5 : 1.0)
                .padding(14)

            if case .error(let message) = section.loadingState {
                errorFooter(message: message)
            }
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text(section.id.displayTitle)
                .font(.headline)

            Spacer()

            Text(section.lastUpdated, style: .time)
                .font(.caption.italic())
                .foregroundStyle(.secondary)

            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
            } else if let onRefresh {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func errorFooter(message: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private var isLoading: Bool {
        section.loadingState == .refreshing || section.loadingState == .streaming
    }
}
