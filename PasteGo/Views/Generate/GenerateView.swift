import SwiftUI
import MarkdownUI

enum GenerateMode: String, CaseIterable {
    case workbench
    case shortcuts

    var title: String {
        switch self {
        case .workbench: "工作台"
        case .shortcuts: "快捷操作"
        }
    }
}

/// AI generation view with a workbench and quick actions
struct GenerateView: View {
    let generateVM: GenerateViewModel
    let selectedItems: [ClipItem]
    var onRemoveMaterial: (String) -> Void
    var onNavigateSettings: () -> Void

    @State private var mode: GenerateMode = .workbench

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ModePicker(mode: $mode)

                    if mode == .workbench {
                        WorkbenchSection(
                            providerName: generateVM.defaultProvider?.name,
                            selectedItems: selectedItems,
                            onRemoveMaterial: onRemoveMaterial
                        )
                    } else {
                        ShortcutActionsSection(
                            generateVM: generateVM,
                            providerName: generateVM.defaultProvider?.name,
                            templates: generateVM.templates,
                            activeTemplateId: generateVM.activeTemplateId,
                            isGenerating: generateVM.shortcutIsGenerating,
                            onSelectTemplate: { template in
                                guard let sourceText = generateVM.quickActionSourceText,
                                      !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                    generateVM.setShortcutError("请先通过快捷操作快捷键获取一段“当前处理的内容”。")
                                    return
                                }

                                let item = ClipItem(
                                    content: sourceText,
                                    contentHash: UUID().uuidString,
                                    clipType: generateVM.quickActionSourceType ?? ContentTypeDetector.detect(sourceText)
                                )
                                generateVM.generate(items: [item], template: template, customPrompt: "")
                            },
                            onNavigateSettings: onNavigateSettings
                        )
                    }

                    if mode == .shortcuts, let error = generateVM.shortcutError {
                        GenerateErrorBanner(error: error)
                    }

                    if displayedHasContent || displayedIsGenerating {
                        OutputView(
                            output: displayedOutput,
                            isGenerating: displayedIsGenerating,
                            thinkExpanded: Binding(
                                get: { displayedThinkExpanded },
                                set: { setDisplayedThinkExpanded($0) }
                            ),
                            parsed: displayedParsedOutput
                        )
                    } else {
                        GeneratePlaceholderCard()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }

            if mode == .workbench {
                ChatInputBar(
                    prompt: Binding(
                        get: { generateVM.customPrompt },
                        set: { generateVM.customPrompt = $0 }
                    ),
                    isGenerating: generateVM.workbenchIsGenerating,
                    hasProviders: !generateVM.providers.isEmpty,
                    onSend: {
                        generateVM.generate(items: selectedItems, template: nil, customPrompt: generateVM.customPrompt)
                    }
                )
            }
        }
        .onAppear {
            syncModeFromState()
        }
        .onChange(of: generateVM.activeTemplateId) { _, _ in
            syncModeFromState()
        }
        .onChange(of: generateVM.isCustomMode) { _, _ in
            syncModeFromState()
        }
        .onChange(of: mode) { _, newValue in
            if newValue == .workbench {
                generateVM.activeTemplateId = nil
                generateVM.isCustomMode = true
            }
        }
    }

    private func syncModeFromState() {
        mode = generateVM.activeTemplateId == nil ? .workbench : .shortcuts
    }

    private var displayedOutput: String {
        mode == .workbench ? generateVM.workbenchOutput : generateVM.shortcutOutput
    }

    private var displayedIsGenerating: Bool {
        mode == .workbench ? generateVM.workbenchIsGenerating : generateVM.shortcutIsGenerating
    }

    private var displayedHasContent: Bool {
        !displayedOutput.isEmpty || displayedIsGenerating
    }

    private var displayedParsedOutput: (thinking: String, content: String) {
        mode == .workbench ? generateVM.workbenchParsedOutput : generateVM.shortcutParsedOutput
    }

    private var displayedThinkExpanded: Bool {
        mode == .workbench ? generateVM.workbenchThinkExpanded : generateVM.shortcutThinkExpanded
    }

    private func setDisplayedThinkExpanded(_ value: Bool) {
        if mode == .workbench {
            generateVM.workbenchThinkExpanded = value
        } else {
            generateVM.shortcutThinkExpanded = value
        }
    }

}

struct ModePicker: View {
    @Binding var mode: GenerateMode

    var body: some View {
        HStack(spacing: 6) {
            ForEach(GenerateMode.allCases, id: \.rawValue) { item in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        mode = item
                    }
                } label: {
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(mode == item ? Color.accentColor : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(mode == item ? Color.accentColor.opacity(0.11) : Color.primary.opacity(0.04))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(mode == item ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct WorkbenchSection: View {
    let providerName: String?
    let selectedItems: [ClipItem]
    var onRemoveMaterial: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(providerName.map { "当前使用 \($0)" } ?? "先配置模型，再开始生成")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            MaterialsBar(items: selectedItems, onRemove: onRemoveMaterial)
        }
        .padding(.horizontal, 4)
    }
}

struct ShortcutActionsSection: View {
    let generateVM: GenerateViewModel
    let providerName: String?
    let templates: [Template]
    let activeTemplateId: String?
    let isGenerating: Bool
    var onSelectTemplate: (Template) -> Void
    var onNavigateSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(providerName.map { "当前使用 \($0)" } ?? "先配置模型，再开始生成")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Text("快捷操作只处理当前选中的文本。你可以在其他应用里先选中文本，再点击下面的动作，或者直接使用对应全局快捷键。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            ShortcutPreviewCard(
                sourceText: generateVM.quickActionSourceText,
                sourceType: generateVM.quickActionSourceType
            )

            TemplateCardSelector(
                templates: templates,
                activeTemplateId: activeTemplateId,
                isGenerating: isGenerating,
                canTriggerTemplates: canRunQuickActions,
                onSelectTemplate: onSelectTemplate,
                onNavigateSettings: onNavigateSettings
            )
        }
        .padding(.horizontal, 4)
    }

    private var canRunQuickActions: Bool {
        guard let sourceText = generateVM.quickActionSourceText else { return false }
        return !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct ShortcutPreviewCard: View {
    let sourceText: String?
    let sourceType: ClipType?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("当前将处理的内容")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("当前选中文本")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
            }

            if let sourceText, !sourceText.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: (sourceType ?? .text).icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(previewTint)
                        .frame(width: 22, height: 22)
                        .background(previewTint.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text((sourceType ?? .text).label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text(String(sourceText.prefix(180)))
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(10)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                }
            } else {
                Text("这里会显示上一次执行快捷操作时捕获到的选中文本。触发动作后，PasteGo 会复制当前选中的文本，并让生成结果与这份内容保持对应。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    }
                }
        }
    }

    private var previewTint: Color {
        switch sourceType {
        case .code: return .green
        case .url: return .orange
        case .image: return .pink
        case .text, nil: return Color.accentColor
        }
    }
}

struct GenerateErrorBanner: View {
    let error: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.red)

            Text(error)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.red.opacity(0.92))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.red.opacity(0.12), lineWidth: 1)
        )
    }
}

struct GeneratePlaceholderCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("结果会显示在这里")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("在“工作台”里组合素材并输入指令，或者切到“快捷操作”执行翻译等单次动作。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

/// Shows selected materials as chips
struct MaterialsBar: View {
    let items: [ClipItem]
    var onRemove: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("已选素材")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(items.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
            }

            if items.isEmpty {
                Text("还没有选中内容。去历史记录里勾选文本后，这里会自动同步。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(items) { item in
                            MaterialChip(item: item, onRemove: { onRemove(item.id) })
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct MaterialChip: View {
    let item: ClipItem
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.clipType.icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(chipTint)
                .frame(width: 18, height: 18)
                .background(chipTint.opacity(0.12))
                .clipShape(Circle())

            Text(item.clipType == .image ? "图片素材" : String(item.content.prefix(34)))
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.045))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var chipTint: Color {
        switch item.clipType {
        case .text: return Color(red: 0.16, green: 0.47, blue: 0.92)
        case .code: return Color(red: 0.1, green: 0.62, blue: 0.43)
        case .url: return Color(red: 0.93, green: 0.54, blue: 0.18)
        case .image: return Color(red: 0.88, green: 0.34, blue: 0.52)
        }
    }
}
