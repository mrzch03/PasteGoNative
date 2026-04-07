import SwiftUI

/// Form for adding/editing a template
struct TemplateFormView: View {
    let settingsVM: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Name
            formField(label: "名称") {
                TextField("例如: 翻译、总结...", text: Binding(
                    get: { settingsVM.templateForm.name },
                    set: { settingsVM.templateForm.name = $0 }
                ))
                .textFieldStyle(.plain)
            }

            // Prompt
            formField(label: "提示词") {
                TextEditor(text: Binding(
                    get: { settingsVM.templateForm.prompt },
                    set: { settingsVM.templateForm.prompt = $0 }
                ))
                .font(.system(size: 13))
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
            }

            Text("使用 {{materials}} 作为素材占位符")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            // Shortcut recorder
            formField(label: "全局快捷键（可选）") {
                HStack {
                    ShortcutRecorderField(
                        shortcut: Binding(
                            get: { settingsVM.templateForm.shortcut },
                            set: { settingsVM.templateForm.shortcut = $0 }
                        ),
                        isRecording: Binding(
                            get: { settingsVM.isRecordingShortcut },
                            set: { settingsVM.isRecordingShortcut = $0 }
                        )
                    )

                    if settingsVM.templateForm.shortcut != nil {
                        Button {
                            settingsVM.templateForm.shortcut = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("点击后按下组合键即可录入，需包含 Cmd/Ctrl 等修饰键")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            // Actions
            HStack {
                Spacer()
                Button("取消") {
                    settingsVM.isEditingTemplate = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button("保存") {
                    settingsVM.saveTemplate()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            content()
                .font(.system(size: 13))
                .padding(8)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

/// Simple shortcut recorder field
struct ShortcutRecorderField: View {
    @Binding var shortcut: String?
    @Binding var isRecording: Bool

    var body: some View {
        Text(isRecording ? "请按下快捷键组合..." : (shortcut ?? "点击此处录制快捷键"))
            .font(.system(size: 12, design: shortcut != nil ? .monospaced : .default))
            .foregroundStyle(isRecording ? Color.accentColor : (shortcut != nil ? Color.primary : Color.secondary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                isRecording = true
            }
            .onKeyPress(phases: .down) { press in
                guard isRecording else { return .ignored }

                // Need at least one modifier
                let mods = press.modifiers
                guard mods.contains(.command) || mods.contains(.control) || mods.contains(.option) else {
                    return .ignored
                }

                var parts: [String] = []
                if mods.contains(.command) || mods.contains(.control) { parts.append("CmdOrCtrl") }
                if mods.contains(.option) { parts.append("Alt") }
                if mods.contains(.shift) { parts.append("Shift") }

                let key = press.characters.uppercased()
                if !key.isEmpty && key != " " {
                    parts.append(key)
                    shortcut = parts.joined(separator: "+")
                    isRecording = false
                    return .handled
                }
                return .ignored
            }
    }
}
