import SwiftUI

/// Horizontal filter chips for content types
struct TypeFilterBar: View {
    @Binding var selected: ClipTypeFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ClipTypeFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        label: filter.label,
                        icon: filter.icon,
                        isActive: selected == filter
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selected = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

/// A single filter chip button
private struct FilterChip: View {
    let label: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
            .foregroundStyle(isActive ? Color.accentColor : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
