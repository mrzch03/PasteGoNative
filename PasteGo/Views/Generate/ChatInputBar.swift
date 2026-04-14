import SwiftUI

/// Bottom input bar for workbench prompts
struct ChatInputBar: View {
    @Binding var prompt: String
    let isGenerating: Bool
    let hasProviders: Bool
    var onSend: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("工作台指令", systemImage: "square.on.square")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if !hasProviders {
                    Text("未配置模型")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                TextField("输入你的指令，比如：总结重点、提取链接、翻译成英文…", text: $prompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .disabled(isGenerating || !hasProviders)
                    .onSubmit {
                        if !prompt.trimmingCharacters(in: .whitespaces).isEmpty && !isGenerating {
                            onSend()
                        }
                    }

                Button(action: onSend) {
                    Image(systemName: isGenerating ? "ellipsis.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 21))
                        .foregroundStyle(
                            prompt.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating || !hasProviders
                                ? Color.secondary : Color.accentColor
                        )
                }
                .buttonStyle(.plain)
                .disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating || !hasProviders)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }
}
