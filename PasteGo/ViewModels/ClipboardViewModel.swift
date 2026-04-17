import Foundation
import SwiftUI

/// Filter option for clip types
enum ClipTypeFilter: String, CaseIterable {
    case all
    case text
    case code
    case url
    case image

    var label: String {
        switch self {
        case .all: "全部"
        case .text: "文本"
        case .code: "代码"
        case .url: "链接"
        case .image: "图片"
        }
    }

    var icon: String {
        switch self {
        case .all: "tray.full"
        case .text: "doc.text"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .url: "link"
        case .image: "photo"
        }
    }

    var clipType: ClipType? {
        switch self {
        case .all: nil
        case .text: .text
        case .code: .code
        case .url: .url
        case .image: .image
        }
    }
}

/// ViewModel for the clipboard history view
@Observable
final class ClipboardViewModel {
    var clips: [ClipItem] = []
    var search: String = ""
    var typeFilter: ClipTypeFilter = .all
    var selectedIds: Set<String> = []
    var focusIndex: Int = -1
    var expandedIds: Set<String> = []
    var previewImagePath: String?
    var isLoading = false

    private let clipRepo: ClipRepository

    init(clipRepo: ClipRepository) {
        self.clipRepo = clipRepo
    }

    var selectedCount: Int { selectedIds.count }

    // MARK: - Data operations

    func fetchClips() {
        do {
            clips = try clipRepo.fetchAll(
                search: search.isEmpty ? nil : search,
                clipType: typeFilter.clipType
            )
        } catch {
            print("Failed to fetch clips: \(error)")
        }
    }

    func deleteClip(id: String) {
        do {
            try clipRepo.delete(id: id)
            clips.removeAll { $0.id == id }
            selectedIds.remove(id)
        } catch {
            print("Failed to delete clip: \(error)")
        }
    }

    func markUsed(id: String) {
        do {
            try clipRepo.bumpUpdatedAt(id: id)
            fetchClips()
        } catch {
            print("Failed to mark clip as used: \(error)")
        }
    }

    func togglePin(id: String) {
        do {
            let newState = try clipRepo.togglePin(id: id)
            if let idx = clips.firstIndex(where: { $0.id == id }) {
                clips[idx].isPinned = newState
            }
            // Re-sort since pin status affects order
            fetchClips()
        } catch {
            print("Failed to toggle pin: \(error)")
        }
    }

    func clearOldClips(keepDays: Int = 30) {
        do {
            try clipRepo.clearOld(keepDays: keepDays)
            fetchClips()
        } catch {
            print("Failed to clear old clips: \(error)")
        }
    }

    // MARK: - Selection

    func isSelected(_ id: String) -> Bool {
        selectedIds.contains(id)
    }

    func toggleSelect(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    func selectAll() {
        selectedIds = Set(clips.map(\.id))
    }

    func clearSelection() {
        selectedIds.removeAll()
    }

    func selectOnly(id: String) {
        selectedIds = [id]
    }

    func deselect(_ id: String) {
        selectedIds.remove(id)
    }

    func selectFirstMatchingText(_ text: String) {
        guard let item = clips.first(where: { $0.content == text }) else { return }
        selectOnly(id: item.id)
    }

    func deleteSelected() {
        for id in selectedIds {
            deleteClip(id: id)
        }
        selectedIds.removeAll()
    }

    func getSelectedItems() -> [ClipItem] {
        clips.filter { selectedIds.contains($0.id) }
    }

    func latestItem() -> ClipItem? {
        do {
            return try clipRepo.fetchLatest()
        } catch {
            print("Failed to fetch latest clip: \(error)")
            return clips.max(by: { $0.createdAt < $1.createdAt })
        }
    }

    // MARK: - Expand/Collapse

    func isExpanded(_ id: String) -> Bool {
        expandedIds.contains(id)
    }

    func toggleExpand(_ id: String) {
        if expandedIds.contains(id) {
            expandedIds.remove(id)
        } else {
            expandedIds.insert(id)
        }
    }

    // MARK: - Keyboard navigation

    func moveFocusDown() {
        focusIndex = min(focusIndex + 1, clips.count - 1)
    }

    func moveFocusUp() {
        focusIndex = max(focusIndex - 1, 0)
    }

    func toggleFocusedSelection() {
        guard focusIndex >= 0, focusIndex < clips.count else { return }
        toggleSelect(clips[focusIndex].id)
    }

    // MARK: - Clipboard change handler

    func handleNewClip(_ item: ClipItem) {
        fetchClips()
    }
}
