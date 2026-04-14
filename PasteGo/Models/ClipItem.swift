import Foundation
import GRDB

/// Content type for clipboard items
enum ClipType: String, Codable, CaseIterable, DatabaseValueConvertible {
    case text
    case code
    case url
    case image

    var label: String {
        switch self {
        case .text: "文本"
        case .code: "代码"
        case .url: "链接"
        case .image: "图片"
        }
    }

    var icon: String {
        switch self {
        case .text: "doc.text"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .url: "link"
        case .image: "photo"
        }
    }
}

/// A single clipboard history item
struct ClipItem: Identifiable, Equatable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "clip_items"

    var id: String
    var content: String
    var contentHash: String
    var clipType: ClipType
    var sourceApp: String?
    var imagePath: String?
    var isPinned: Bool
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case contentHash = "content_hash"
        case clipType = "clip_type"
        case sourceApp = "source_app"
        case imagePath = "image_path"
        case isPinned = "is_pinned"
        case createdAt = "created_at"
    }

    init(id: String = UUID().uuidString,
         content: String,
         contentHash: String,
         clipType: ClipType = .text,
         sourceApp: String? = nil,
         imagePath: String? = nil,
         isPinned: Bool = false,
         createdAt: String? = nil) {
        self.id = id
        self.content = content
        self.contentHash = contentHash
        self.clipType = clipType
        self.sourceApp = sourceApp
        self.imagePath = imagePath
        self.isPinned = isPinned
        self.createdAt = createdAt ?? ISO8601DateFormatter().string(from: Date())
    }

    // GRDB: encode isPinned as integer
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["content"] = content
        container["content_hash"] = contentHash
        container["clip_type"] = clipType.rawValue
        container["source_app"] = sourceApp
        container["image_path"] = imagePath
        container["is_pinned"] = isPinned ? 1 : 0
        container["created_at"] = createdAt
    }

    init(row: Row) {
        id = row["id"]
        content = row["content"]
        contentHash = row["content_hash"]
        clipType = ClipType(rawValue: row["clip_type"]) ?? .text
        sourceApp = row["source_app"]
        imagePath = row["image_path"]
        isPinned = (row["is_pinned"] as Int) != 0
        createdAt = row["created_at"]
    }
}
