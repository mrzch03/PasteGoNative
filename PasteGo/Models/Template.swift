import Foundation
import GRDB

/// An AI prompt template
struct Template: Identifiable, Equatable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "templates"

    var id: String
    var name: String
    var prompt: String
    var category: String
    var shortcut: String?

    init(id: String = UUID().uuidString, name: String = "", prompt: String = "",
         category: String = "general", shortcut: String? = nil) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.category = category
        self.shortcut = shortcut
    }
}
