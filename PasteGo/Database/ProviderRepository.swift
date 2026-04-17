import Foundation
import GRDB

/// Repository for AI provider CRUD operations
struct ProviderRepository {
    let db: DatabaseManager

    func fetchAll() throws -> [AiProvider] {
        try db.dbPool.read { db in
            try AiProvider.order(Column("name")).fetchAll(db)
        }
    }

    func upsert(_ provider: AiProvider) throws {
        try db.dbPool.write { db in
            if provider.isDefault {
                try db.execute(sql: "UPDATE ai_providers SET is_default = 0")
            }
            try provider.save(db)
        }
    }

    func delete(id: String) throws {
        try db.dbPool.write { db in
            try db.execute(sql: "DELETE FROM ai_providers WHERE id = ?", arguments: [id])
        }
    }
}
