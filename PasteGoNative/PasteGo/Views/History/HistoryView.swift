import SwiftUI

/// Main history view: search + filters + clip list + selection bar
struct HistoryView: View {
    let clipboardVM: ClipboardViewModel
    let pasteService: PasteService
    var onStartGenerate: () -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBarView(
                search: Binding(
                    get: { clipboardVM.search },
                    set: { clipboardVM.search = $0; clipboardVM.fetchClips() }
                ),
                isFocused: $searchFocused
            )

            // Type filters
            TypeFilterBar(
                selected: Binding(
                    get: { clipboardVM.typeFilter },
                    set: { clipboardVM.typeFilter = $0; clipboardVM.fetchClips() }
                )
            )

            // Selection bar (when items are selected)
            if clipboardVM.selectedCount > 0 {
                SelectionBar(
                    selectedCount: clipboardVM.selectedCount,
                    totalCount: clipboardVM.clips.count,
                    onSelectAll: { clipboardVM.selectAll() },
                    onClearSelection: { clipboardVM.clearSelection() },
                    onMergeCopy: { mergeCopy() },
                    onDeleteSelected: { clipboardVM.deleteSelected() },
                    onGenerate: onStartGenerate
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Clip list
            if clipboardVM.clips.isEmpty {
                EmptyStateView()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(Array(clipboardVM.clips.enumerated()), id: \.element.id) { index, clip in
                                ClipItemRow(
                                    clip: clip,
                                    isSelected: clipboardVM.isSelected(clip.id),
                                    isFocused: clipboardVM.focusIndex == index,
                                    isExpanded: clipboardVM.isExpanded(clip.id),
                                    onToggleSelect: { clipboardVM.toggleSelect(clip.id) },
                                    onCopyAndPaste: { pasteService.copyAndPaste(content: clip.content) },
                                    onTogglePin: { clipboardVM.togglePin(id: clip.id) },
                                    onDelete: { clipboardVM.deleteClip(id: clip.id) },
                                    onToggleExpand: { clipboardVM.toggleExpand(clip.id) },
                                    onPreviewImage: { clipboardVM.previewImagePath = clip.imagePath }
                                )
                                .id(clip.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: clipboardVM.focusIndex) { _, newIndex in
                        if newIndex >= 0, newIndex < clipboardVM.clips.count {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(clipboardVM.clips[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: clipboardVM.selectedCount > 0)
        .overlay {
            // Image preview overlay
            if let imagePath = clipboardVM.previewImagePath {
                ImagePreviewOverlay(
                    imagePath: imagePath,
                    onDismiss: { clipboardVM.previewImagePath = nil }
                )
            }
        }
        .onKeyPress(.upArrow) { clipboardVM.moveFocusUp(); return .handled }
        .onKeyPress(.downArrow) { clipboardVM.moveFocusDown(); return .handled }
        .onKeyPress(.space) {
            clipboardVM.toggleFocusedSelection()
            return .handled
        }
        .onKeyPress(keys: [.init("f")], phases: .down) { press in
            if press.modifiers.contains(.command) {
                searchFocused = true
                return .handled
            }
            return .ignored
        }
    }

    private func mergeCopy() {
        let items = clipboardVM.getSelectedItems()
        guard !items.isEmpty else { return }
        let merged = items.map(\.content).joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(merged, forType: .string)
    }
}

/// Empty state placeholder
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("暂无剪贴板记录")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("复制文字或截图，内容会自动出现在这里")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
