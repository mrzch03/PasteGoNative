import SwiftUI

/// Main settings view with provider and template management
struct SettingsView: View {
    let settingsVM: SettingsViewModel
    var onBack: () -> Void

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

                Text("设置")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()
                Color.clear.frame(width: 50)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            ScrollView {
                VStack(spacing: 20) {
                    // AI Providers section
                    providerSection

                    // Templates section
                    templateSection

                    // Shortcuts info section
                    shortcutsSection
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear { settingsVM.fetchAll() }
    }

    // MARK: - Provider Section

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "AI 模型", showAdd: !settingsVM.isEditingProvider) {
                settingsVM.startAddProvider()
            }

            if settingsVM.isEditingProvider {
                ProviderFormView(settingsVM: settingsVM)
            } else if settingsVM.providers.isEmpty {
                emptyPlaceholder(icon: "cpu", message: "尚未配置 AI 模型", hint: "点击上方「添加」按钮开始配置")
            } else {
                ForEach(settingsVM.providers) { provider in
                    providerRow(provider)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private func providerRow(_ provider: AiProvider) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(kindColor(provider.kind))
                        .frame(width: 8, height: 8)
                    Text(provider.name)
                        .font(.system(size: 13, weight: .medium))
                    if provider.isDefault {
                        Text("默认")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                Text("\(provider.kind.label) · \(provider.model)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            HStack(spacing: 4) {
                iconButton("pencil") { settingsVM.startEditProvider(provider) }
                iconButton("trash", tint: .red) { settingsVM.deleteProvider(provider.id) }
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Template Section

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "模板", showAdd: !settingsVM.isEditingTemplate) {
                settingsVM.startAddTemplate()
            }

            if settingsVM.isEditingTemplate {
                TemplateFormView(settingsVM: settingsVM)
            } else if settingsVM.templates.isEmpty {
                emptyPlaceholder(icon: "doc.text", message: "尚未添加模板", hint: "点击上方「添加」按钮创建模板")
            } else {
                ForEach(settingsVM.templates) { template in
                    templateRow(template)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private func templateRow(_ template: Template) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(template.name)
                        .font(.system(size: 13, weight: .medium))
                    if let shortcut = template.shortcut {
                        Text(shortcut)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                Text(String(template.prompt.prefix(50)) + (template.prompt.count > 50 ? "..." : ""))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 4) {
                iconButton("pencil") { settingsVM.startEditTemplate(template) }
                iconButton("trash", tint: .red) { settingsVM.deleteTemplate(template.id) }
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Shortcuts Section

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "快捷键")

            VStack(spacing: 4) {
                shortcutRow(label: "快速打开/隐藏历史列表", shortcut: "Cmd + Shift + V")
                ForEach(settingsVM.templates.filter { $0.shortcut != nil }) { template in
                    shortcutRow(label: template.name, shortcut: template.shortcut ?? "")
                }
            }
            .padding(10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 12)
    }

    private func shortcutRow(label: String, shortcut: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(shortcut)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(title: String, showAdd: Bool = false, onAdd: (() -> Void)? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if showAdd, let onAdd {
                Button(action: onAdd) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("添加")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func emptyPlaceholder(icon: String, message: String, hint: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(hint)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func iconButton(_ icon: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(tint ?? .secondary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }

    private func kindColor(_ kind: ProviderKind) -> Color {
        switch kind {
        case .openai: Color(hex: "#10a37f")
        case .claude: Color(hex: "#d97706")
        case .kimi: Color(hex: "#6366f1")
        case .minimax: Color(hex: "#ec4899")
        case .ollama: Color(hex: "#8b5cf6")
        }
    }
}

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
