import SwiftUI

/// Form for adding/editing an AI provider
struct ProviderFormView: View {
    let settingsVM: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Kind selector cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ProviderKind.allCases, id: \.self) { kind in
                        kindCard(kind)
                    }
                }
            }

            // Form fields
            formField(label: "名称", placeholder: settingsVM.providerForm.kind.label) {
                TextField("", text: Binding(
                    get: { settingsVM.providerForm.name },
                    set: { settingsVM.providerForm.name = $0 }
                ))
                .textFieldStyle(.plain)
            }

            formField(label: "API 地址") {
                TextField("", text: Binding(
                    get: { settingsVM.providerForm.endpoint },
                    set: { settingsVM.providerForm.endpoint = $0 }
                ))
                .textFieldStyle(.plain)
            }

            formField(label: "模型", placeholder: settingsVM.providerForm.kind.defaultModels.first ?? "") {
                TextField("", text: Binding(
                    get: { settingsVM.providerForm.model },
                    set: { settingsVM.providerForm.model = $0 }
                ))
                .textFieldStyle(.plain)
            }

            if settingsVM.providerForm.kind.needsApiKey {
                formField(label: "API Key") {
                    SecureField("输入 API Key...", text: Binding(
                        get: { settingsVM.providerForm.apiKey },
                        set: { settingsVM.providerForm.apiKey = $0 }
                    ))
                    .textFieldStyle(.plain)
                }
            }

            // Default toggle
            Toggle(isOn: Binding(
                get: { settingsVM.providerForm.isDefault },
                set: { settingsVM.providerForm.isDefault = $0 }
            )) {
                Text("设为默认模型")
                    .font(.system(size: 12))
            }
            .toggleStyle(.checkbox)

            // Actions
            HStack {
                Spacer()
                Button("取消") {
                    settingsVM.isEditingProvider = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button("保存") {
                    settingsVM.saveProvider()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func kindCard(_ kind: ProviderKind) -> some View {
        let isActive = settingsVM.providerForm.kind == kind

        return Button {
            settingsVM.changeProviderKind(kind)
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: kind.color))
                    .frame(width: 6, height: 6)
                Text(kind.label)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? Color(hex: kind.color).opacity(0.15) : Color.primary.opacity(0.04))
            .foregroundStyle(isActive ? Color(hex: kind.color) : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func formField<Content: View>(label: String, placeholder: String = "", @ViewBuilder content: () -> Content) -> some View {
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
