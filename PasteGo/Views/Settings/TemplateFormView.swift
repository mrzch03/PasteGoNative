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

            Text("可选使用 {{materials}} 指定素材插入位置；不填写时系统会自动在末尾附加素材")
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
    @FocusState private var isFocused: Bool

    var body: some View {
        recorderLabel
            .contentShape(Rectangle())
            .focusable()
            .focused($isFocused)
            .onTapGesture(perform: beginRecording)
            .onChange(of: isRecording) { _, newValue in
                isFocused = newValue
            }
            .onKeyPress(phases: .down, action: handleKeyPress)
    }

    private var displayText: String {
        if isRecording {
            return "请按下快捷键组合..."
        }
        guard let shortcut else {
            return "点击此处录制快捷键"
        }
        return ShortcutDisplayFormatter.format(shortcut)
    }

    private var recorderLabel: some View {
        let fontDesign: Font.Design = shortcut != nil ? .monospaced : .default
        let foreground: Color = isRecording
            ? .accentColor
            : (shortcut != nil ? .primary : .secondary)

        return Text(displayText)
            .font(.system(size: 12, design: fontDesign))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(isRecording ? Color.accentColor.opacity(0.08) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func beginRecording() {
        isRecording = true
        isFocused = true
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        guard isRecording else { return .ignored }

        if press.key == .escape {
            isRecording = false
            return .handled
        }

        if press.key == .delete {
            shortcut = nil
            isRecording = false
            return .handled
        }

        let mods = press.modifiers
        guard mods.contains(.command) || mods.contains(.control) || mods.contains(.option) else {
            return .handled
        }

        guard let key = normalizedKey(from: press.characters) else {
            return .handled
        }

        var parts: [String] = []
        if mods.contains(.command) { parts.append("Cmd") }
        if mods.contains(.control) { parts.append("Ctrl") }
        if mods.contains(.option) { parts.append("Alt") }
        if mods.contains(.shift) { parts.append("Shift") }
        parts.append(key)

        shortcut = parts.joined(separator: "+")
        isRecording = false
        return .handled
    }

    private func normalizedKey(from characters: String) -> String? {
        let trimmed = characters.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed == " " {
            return "SPACE"
        }

        if trimmed.count == 1, let scalar = trimmed.unicodeScalars.first {
            if CharacterSet.alphanumerics.contains(scalar) {
                return String(trimmed.uppercased())
            }
        }

        switch trimmed.lowercased() {
        case "return", "\r": return "ENTER"
        case "tab", "\t": return "TAB"
        case "space": return "SPACE"
        default: return nil
        }
    }
}
