@preconcurrency import MarkdownUI
import SwiftUI

extension Theme {
    @MainActor static var currentState: Theme {
        Theme()
            // MARK: - Text
            .text {
                ForegroundColor(.primary)
                FontSize(15)
            }

            // MARK: - Paragraphs
            .paragraph { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(0.3))
                    .markdownMargin(top: 0, bottom: 12)
            }

            // MARK: - Headings
            .heading1 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 16, bottom: 10)
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(.em(1.3))
                    }
            }
            .heading2 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 14, bottom: 8)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.15))
                    }
            }
            .heading3 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 20, bottom: 10)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.2))
                    }
            }
            .heading4 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 16, bottom: 8)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.05))
                        ForegroundColor(.secondary)
                    }
            }

            // MARK: - Lists
            .listItem { configuration in
                configuration.label
                    .markdownMargin(top: .em(0.3))
            }

            // MARK: - Inline code
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.85))
                BackgroundColor(Color(.textBackgroundColor).opacity(0.5))
            }

            // MARK: - Code blocks
            .codeBlock { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .relativeLineSpacing(.em(0.3))
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.85))
                        }
                        .padding(14)
                }
                .background(Color(.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .markdownMargin(top: 8, bottom: 12)
            }

            // MARK: - Tables
            .table { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(
                        .init(.horizontalBorders, color: .primary.opacity(0.15), width: 0.5)
                    )
                    .markdownTableBackgroundStyle(
                        .alternatingRows(
                            Color.clear,
                            Color.primary.opacity(0.03),
                            header: Color.primary.opacity(0.06)
                        )
                    )
                    .markdownMargin(top: 4, bottom: 16)
            }
            .tableCell { configuration in
                configuration.label
                    .markdownTextStyle {
                        if configuration.row == 0 {
                            FontWeight(.semibold)
                        }
                        BackgroundColor(nil)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .relativeLineSpacing(.em(0.25))
            }

            // MARK: - Blockquotes
            .blockquote { configuration in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(width: 3)
                    configuration.label
                        .markdownTextStyle {
                            ForegroundColor(.secondary)
                            FontSize(.em(0.95))
                        }
                        .padding(.leading, 12)
                }
                .markdownMargin(top: 8, bottom: 12)
            }

            // MARK: - Links
            .link {
                ForegroundColor(Color.accentColor)
            }

            // MARK: - Thematic break (hr)
            .thematicBreak {
                Divider()
                    .markdownMargin(top: 16, bottom: 16)
            }
    }
}
