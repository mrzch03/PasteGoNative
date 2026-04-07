import SwiftUI

/// Bottom chat-style input bar for custom AI prompts
struct ChatInputBar: View {
    @Binding var prompt: String
    let isGenerating: Bool
    let hasProviders: Bool
    var onSend: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("输入你的指令...", text: $prompt)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .disabled(isGenerating || !hasProviders)
                .onSubmit {
                    if !prompt.trimmingCharacters(in: .whitespaces).isEmpty && !isGenerating {
                        onSend()
                    }
                }

            Button(action: onSend) {
                Image(systemName: isGenerating ? "ellipsis" : "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        prompt.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating || !hasProviders
                            ? Color.secondary : Color.accentColor
                    )
            }
            .buttonStyle(.plain)
            .disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating || !hasProviders)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
