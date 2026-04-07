import SwiftUI
import MarkdownUI

/// AI generation view with template selection and streaming output
struct GenerateView: View {
    let generateVM: GenerateViewModel
    let selectedItems: [ClipItem]
    var onBack: () -> Void
    var onNavigateSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("返回")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("AI 生成")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()
                // Spacer for centering
                Color.clear.frame(width: 50)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Materials bar
                    MaterialsBar(items: selectedItems)

                    // Template cards
                    TemplateCardSelector(
                        templates: generateVM.templates,
                        activeTemplateId: generateVM.activeTemplateId,
                        isCustomMode: generateVM.isCustomMode,
                        isGenerating: generateVM.isGenerating,
                        onSelectTemplate: { template in
                            generateVM.generate(items: selectedItems, template: template, customPrompt: "")
                        },
                        onSelectCustom: {
                            generateVM.isCustomMode = true
                            generateVM.activeTemplateId = nil
                        },
                        onNavigateSettings: onNavigateSettings
                    )

                    // Provider hint
                    if let provider = generateVM.defaultProvider {
                        Text("将使用 \(provider.name) 生成")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                    }

                    // Error
                    if let error = generateVM.error {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 12)
                    }

                    // Output
                    if !generateVM.output.isEmpty || generateVM.isGenerating {
                        OutputView(
                            output: generateVM.output,
                            isGenerating: generateVM.isGenerating,
                            thinkExpanded: Binding(
                                get: { generateVM.thinkExpanded },
                                set: { generateVM.thinkExpanded = $0 }
                            ),
                            parsed: generateVM.parsedOutput
                        )
                    }
                }
                .padding(.bottom, 16)
            }

            // Chat input bar (custom mode)
            if generateVM.isCustomMode {
                ChatInputBar(
                    prompt: Binding(
                        get: { generateVM.customPrompt },
                        set: { generateVM.customPrompt = $0 }
                    ),
                    isGenerating: generateVM.isGenerating,
                    hasProviders: !generateVM.providers.isEmpty,
                    onSend: {
                        generateVM.generate(items: selectedItems, template: nil, customPrompt: generateVM.customPrompt)
                    }
                )
            }
        }
    }
}

/// Shows selected materials as chips
struct MaterialsBar: View {
    let items: [ClipItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("已选素材 (\(items.count))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(items) { item in
                        Text(item.clipType == .image ? "图片" : String(item.content.prefix(30)))
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}
