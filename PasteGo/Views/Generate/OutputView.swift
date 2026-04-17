import SwiftUI
import MarkdownUI

/// Displays AI streaming output with markdown rendering and think block support
struct OutputView: View {
    let output: String
    let isGenerating: Bool
    @Binding var thinkExpanded: Bool
    let parsed: (thinking: String, content: String)

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("生成结果")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12, weight: .semibold))
                }
                Spacer()
                if !output.isEmpty && !isGenerating {
                    copyButton
                }
            }

            if !parsed.thinking.isEmpty {
                ThinkBlockView(
                    thinking: parsed.thinking,
                    isExpanded: $thinkExpanded
                )
            }

            VStack(alignment: .leading) {
                if !parsed.content.isEmpty {
                    Markdown(parsed.content)
                        .markdownTheme(.pasteGo)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                } else if isGenerating && parsed.thinking.isEmpty {
                    Text("等待响应...")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }

                if isGenerating {
                    BlinkingCursor()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .padding(.horizontal, 4)
    }

    private var copyButton: some View {
        Button {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(parsed.content.isEmpty ? output : parsed.content, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                Text(copied ? "已复制" : "复制结果")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(copied ? Color.green : Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.045))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private extension Theme {
    static let pasteGo = Theme.gitHub
        .text {
            ForegroundColor(.primary)
            BackgroundColor(nil)
            FontSize(16)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
            BackgroundColor(Color.primary.opacity(0.06))
        }
        .paragraph { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.22))
                .markdownMargin(top: 0, bottom: 12)
                .markdownTextStyle {
                    BackgroundColor(nil)
                }
        }
        .codeBlock { configuration in
            ScrollView(.horizontal) {
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(0.225))
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.85))
                        BackgroundColor(nil)
                    }
                    .padding(12)
            }
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .markdownMargin(top: 0, bottom: 12)
        }
}

/// Collapsible think block
struct ThinkBlockView: View {
    let thinking: String
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.spring(response: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                    Text("思考过程")
                        .font(.system(size: 11, weight: .medium))
                    if !isExpanded {
                        Text(String(thinking.prefix(40)) + "...")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(thinking)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Blinking cursor indicator
struct BlinkingCursor: View {
    @State private var visible = true

    var body: some View {
        Text("▊")
            .font(.system(size: 13))
            .foregroundStyle(Color.accentColor)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}
