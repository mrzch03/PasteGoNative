import SwiftUI

/// Horizontal scrolling template card selector
struct TemplateCardSelector: View {
    let templates: [Template]
    let activeTemplateId: String?
    let isCustomMode: Bool
    let isGenerating: Bool
    var onSelectTemplate: (Template) -> Void
    var onSelectCustom: () -> Void
    var onNavigateSettings: () -> Void

    private let templateColors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .red, .cyan, .teal,
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Custom mode card
                TemplateCard(
                    emoji: "bubble.left.fill",
                    label: "自定义",
                    color: .purple,
                    isActive: isCustomMode,
                    action: onSelectCustom
                )

                // Template cards
                ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                    TemplateCard(
                        emoji: templateIcon(for: template),
                        label: template.name,
                        color: templateColors[index % templateColors.count],
                        isActive: activeTemplateId == template.id,
                        action: {
                            if !isGenerating {
                                onSelectTemplate(template)
                            }
                        }
                    )
                }

                // Settings card
                TemplateCard(
                    emoji: "gearshape",
                    label: "管理",
                    color: .gray,
                    isActive: false,
                    action: onNavigateSettings
                )
            }
            .padding(.horizontal, 16)
        }
    }

    private func templateIcon(for template: Template) -> String {
        switch template.id {
        case "tpl-translate": return "globe"
        default: return "doc.text"
        }
    }
}

/// A single template selection card
private struct TemplateCard: View {
    let emoji: String
    let label: String
    let color: Color
    let isActive: Bool
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: emoji)
                    .font(.system(size: 18))
                    .foregroundStyle(isActive ? .white : color)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? .white : .primary)
            }
            .frame(width: 70, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? color : color.opacity(isHovering ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isActive ? .clear : color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovering)
    }
}
