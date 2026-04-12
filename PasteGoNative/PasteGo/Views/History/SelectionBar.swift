import SwiftUI

/// Floating bar showing selection count and bulk actions
struct SelectionBar: View {
    let selectedCount: Int
    let totalCount: Int
    var onSelectAll: () -> Void
    var onClearSelection: () -> Void
    var onMergeCopy: () -> Void
    var onDeleteSelected: () -> Void
    var onGenerate: () -> Void

    @State private var mergeCopied = false

    var body: some View {
        HStack(spacing: 12) {
            // Selection info
            HStack(spacing: 4) {
                Text("\(selectedCount)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("项已选")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Actions
            HStack(spacing: 6) {
                // Select all / Deselect all
                if selectedCount < totalCount {
                    barButton(icon: "checkmark.square", tooltip: "全选", action: onSelectAll)
                } else {
                    barButton(icon: "xmark.square", tooltip: "取消全选", action: onClearSelection)
                }

                // Merge copy
                barButton(
                    icon: mergeCopied ? "checkmark" : "doc.on.doc",
                    tooltip: mergeCopied ? "已复制" : "合并复制",
                    action: {
                        onMergeCopy()
                        mergeCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            mergeCopied = false
                        }
                    }
                )

                // Delete selected
                barButton(icon: "trash", tooltip: "删除选中", tint: .red, action: onDeleteSelected)

                // Open workbench
                Button(action: onGenerate) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.on.square")
                            .font(.system(size: 11))
                        Text("工作台")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func barButton(icon: String, tooltip: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(tint ?? .secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}
