import SwiftUI
import MarkdownUI

/// Collapsible hero card for "The Picture" section.
/// Starts expanded; tapping the header row collapses/expands with a spring animation.
struct PictureCard: View {
    let section: BriefingSection
    var onRefresh: (() -> Void)?

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow

            if isExpanded {
                Divider()

                Markdown(section.content)
                    .markdownTheme(.currentState)
                    .textSelection(.enabled)
                    .opacity(isLoading ? 0.5 : 1.0)
                    .padding(14)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                if case .error(let message) = section.loadingState {
                    errorFooter(message: message)
                }
            }
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(section.id.displayTitle)
                .font(.headline)

            if !isExpanded {
                Text(firstNonEmptyLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

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
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
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

    private var firstNonEmptyLine: String {
        section.content
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            ?? ""
    }

    private var isLoading: Bool {
        section.loadingState == .refreshing || section.loadingState == .streaming
    }
}
