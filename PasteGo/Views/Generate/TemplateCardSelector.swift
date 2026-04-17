import SwiftUI

/// Horizontal scrolling quick action selector
struct TemplateCardSelector: View {
    let templates: [Template]
    let activeTemplateId: String?
    let isGenerating: Bool
    let canTriggerTemplates: Bool
    var onSelectTemplate: (Template) -> Void
    var onNavigateSettings: () -> Void

    private let templateColors: [Color] = [
        Color(red: 0.24, green: 0.46, blue: 0.86),
        Color(red: 0.28, green: 0.56, blue: 0.52),
        Color(red: 0.74, green: 0.49, blue: 0.24),
        Color(red: 0.49, green: 0.43, blue: 0.72),
        Color(red: 0.73, green: 0.45, blue: 0.57),
        Color(red: 0.50, green: 0.46, blue: 0.41),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                    TemplateChip(
                        emoji: templateIcon(for: template),
                        label: template.name,
                        color: templateColors[index % templateColors.count],
                        isActive: activeTemplateId == template.id,
                        isEnabled: canTriggerTemplates,
                        action: {
                            if canTriggerTemplates && !isGenerating {
                                onSelectTemplate(template)
                            }
                        }
                    )
                }

                TemplateChip(
                    emoji: "gearshape",
                    label: "管理快捷操作",
                    color: Color.secondary.opacity(0.9),
                    isActive: false,
                    isEnabled: true,
                    action: onNavigateSettings
                )
            }
            .padding(.vertical, 2)
        }
    }

    private func templateIcon(for template: Template) -> String {
        switch template.id {
        case "tpl-translate": return "globe"
        default: return "doc.text"
        }
    }
}

private struct TemplateChip: View {
    let emoji: String
    let label: String
    let color: Color
    let isActive: Bool
    let isEnabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: emoji)
                    .font(.system(size: 11))
                    .foregroundStyle(isActive ? color : .secondary)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? .primary : .primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                isActive
                    ? color.opacity(0.12)
                    : Color.primary.opacity(0.05)
            )
            .overlay {
                Capsule()
                    .strokeBorder(isActive ? color.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
            }
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}
