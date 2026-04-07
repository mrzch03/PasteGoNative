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
            // Header
            HStack {
                Text("生成结果")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !output.isEmpty && !isGenerating {
                    Button {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(parsed.content.isEmpty ? output : parsed.content, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                            Text(copied ? "已复制" : "复制结果")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(copied ? .green : .accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            // Think block
            if !parsed.thinking.isEmpty {
                ThinkBlockView(
                    thinking: parsed.thinking,
                    isExpanded: $thinkExpanded
                )
                .padding(.horizontal, 12)
            }

            // Main content (Markdown)
            VStack(alignment: .leading) {
                if !parsed.content.isEmpty {
                    Markdown(parsed.content)
                        .markdownTheme(.gitHub)
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
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
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
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.02))
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
