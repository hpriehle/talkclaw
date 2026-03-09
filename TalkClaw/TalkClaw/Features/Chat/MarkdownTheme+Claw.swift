import MarkdownUI
import SwiftUI

// MARK: - Code Block with Copy Button

private struct CodeBlockView: View {
    let configuration: CodeBlockConfiguration
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row: language label + copy button
            HStack {
                if let language = configuration.language, !language.isEmpty {
                    Text(language.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accent)
                } else {
                    Spacer().frame(height: 0)
                }

                Spacer()

                Button {
                    UIPasteboard.general.string = configuration.content
                    withAnimation(.easeInOut(duration: 0.2)) { showCopied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation(.easeInOut(duration: 0.2)) { showCopied = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        Text(showCopied ? "Copied" : "Copy")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(showCopied ? Theme.Colors.success : Theme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(13)
                        ForegroundColor(Theme.Colors.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
        .background(Theme.Colors.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
    }
}

extension MarkdownUI.Theme {
    static let claw = MarkdownUI.Theme()
        // -- Inline styles --
        .text {
            ForegroundColor(Theme.Colors.bubbleText)
            FontSize(17)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
            ForegroundColor(Theme.Colors.accent)
            BackgroundColor(Theme.Colors.surface3)
        }
        .strong {
            FontWeight(.semibold)
        }
        .link {
            ForegroundColor(Theme.Colors.accent)
        }

        // -- Headings --
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(24)
                    ForegroundColor(Theme.Colors.textPrimary)
                }
                .markdownMargin(top: 16, bottom: 8)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(20)
                    ForegroundColor(Theme.Colors.textPrimary)
                }
                .markdownMargin(top: 14, bottom: 6)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(17)
                    ForegroundColor(Theme.Colors.textPrimary)
                }
                .markdownMargin(top: 12, bottom: 4)
        }
        .heading4 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(15)
                    ForegroundColor(Theme.Colors.textSecondary)
                }
                .markdownMargin(top: 10, bottom: 4)
        }
        .heading5 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(13)
                    ForegroundColor(Theme.Colors.textSecondary)
                }
                .markdownMargin(top: 8, bottom: 4)
        }
        .heading6 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(13)
                    ForegroundColor(Theme.Colors.textTertiary)
                }
                .markdownMargin(top: 8, bottom: 4)
        }

        // -- Paragraph --
        .paragraph { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.2))
                .markdownMargin(top: 0, bottom: 8)
        }

        // -- Code block --
        .codeBlock { configuration in
            CodeBlockView(configuration: configuration)
                .markdownMargin(top: 4, bottom: 8)
        }

        // -- Blockquote --
        .blockquote { configuration in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.Colors.accent.opacity(0.5))
                    .frame(width: 3)

                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(Theme.Colors.textSecondary)
                        FontSize(15)
                    }
                    .padding(.leading, 10)
            }
            .markdownMargin(top: 4, bottom: 8)
        }

        // -- Lists --
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 2, bottom: 2)
        }
        .bulletedListMarker { configuration in
            Text("•")
                .foregroundStyle(Theme.Colors.textSecondary)
                .font(.system(size: 17))
        }
        .numberedListMarker { configuration in
            Text("\(configuration.itemNumber).")
                .foregroundStyle(Theme.Colors.textSecondary)
                .font(.system(size: 15, design: .monospaced))
                .monospacedDigit()
        }
        .taskListMarker { configuration in
            Image(systemName: configuration.isCompleted ? "checkmark.square.fill" : "square")
                .foregroundStyle(configuration.isCompleted ? Theme.Colors.accent : Theme.Colors.textTertiary)
                .font(.system(size: 15))
        }

        // -- Table --
        .table { configuration in
            configuration.label
                .markdownTableBorderStyle(
                    .init(color: Theme.Colors.borderDefault)
                )
                .markdownMargin(top: 4, bottom: 8)
        }
        .tableCell { configuration in
            configuration.label
                .markdownTextStyle {
                    if configuration.row == 0 {
                        FontWeight(.semibold)
                        ForegroundColor(Theme.Colors.textPrimary)
                    } else {
                        ForegroundColor(Theme.Colors.textSecondary)
                    }
                    FontSize(14)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }

        // -- Thematic break --
        .thematicBreak {
            Divider()
                .overlay(Theme.Colors.separator)
                .markdownMargin(top: 8, bottom: 8)
        }
}
