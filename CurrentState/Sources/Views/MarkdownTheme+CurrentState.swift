@preconcurrency import MarkdownUI
import SwiftUI

extension Theme {
    @MainActor static var currentState: Theme {
        Theme()
            .text {
                ForegroundColor(.primary)
                FontSize(14)
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.85))
                BackgroundColor(Color(.textBackgroundColor).opacity(0.5))
            }
            .codeBlock { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .relativeLineSpacing(.em(0.25))
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.85))
                        }
                        .padding(12)
                }
                .background(Color(.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .markdownMargin(top: 8, bottom: 8)
            }
            .heading2 { configuration in
                VStack(alignment: .leading, spacing: 4) {
                    configuration.label
                        .markdownTextStyle {
                            FontWeight(.semibold)
                            FontSize(.em(1.3))
                        }
                    Divider()
                }
                .markdownMargin(top: 16, bottom: 8)
            }
            .blockquote { configuration in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: 3)
                    configuration.label
                        .markdownTextStyle {
                            ForegroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                }
                .markdownMargin(top: 8, bottom: 8)
            }
            .link {
                ForegroundColor(Color.accentColor)
            }
    }
}
