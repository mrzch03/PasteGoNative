import Foundation
import GRDB

/// Repository for AI template CRUD operations
struct TemplateRepository {
    let db: DatabaseManager

    func fetchAll() throws -> [Template] {
        try db.dbPool.read { db in
            try Template.order(Column("category"), Column("name")).fetchAll(db)
        }
    }

    func upsert(_ template: Template) throws {
        try db.dbPool.write { db in
            try template.save(db)
        }
    }

    func delete(id: String) throws {
        try db.dbPool.write { db in
            try db.execute(sql: "DELETE FROM templates WHERE id = ?", arguments: [id])
        }
    }
}
