import AppKit

struct PasteboardSnapshot {
    struct ItemSnapshot {
        let dataByType: [(NSPasteboard.PasteboardType, Data)]
    }

    let items: [ItemSnapshot]

    static func capture(from pasteboard: NSPasteboard = .general) -> PasteboardSnapshot {
        let snapshots = (pasteboard.pasteboardItems ?? []).map { item in
            let entries = item.types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
            return ItemSnapshot(dataByType: entries)
        }

        return PasteboardSnapshot(items: snapshots)
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()

        guard !items.isEmpty else { return }

        let restoredItems = items.map { snapshot -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in snapshot.dataByType {
                item.setData(data, forType: type)
            }
            return item
        }

        pasteboard.writeObjects(restoredItems)
    }
}
