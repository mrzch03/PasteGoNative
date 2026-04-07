import Foundation
import GRDB

/// Repository for clipboard item CRUD operations
struct ClipRepository {
    let db: DatabaseManager

    /// Insert a clip item, returns true if new, false if duplicate (bumped to top)
    @discardableResult
    func insert(_ item: ClipItem) throws -> Bool {
        try db.dbPool.write { db in
            let exists = try Bool.fetchOne(db, sql:
                "SELECT EXISTS(SELECT 1 FROM clip_items WHERE content_hash = ?)",
                arguments: [item.contentHash]) ?? false

            if exists {
                try db.execute(sql:
                    "UPDATE clip_items SET created_at = ? WHERE content_hash = ?",
                    arguments: [item.createdAt, item.contentHash])
                return false
            }

            try item.insert(db)
            return true
        }
    }

    /// Fetch clips with optional search, type filter, and pagination
    func fetchAll(search: String? = nil, clipType: ClipType? = nil,
                  limit: Int = 100, offset: Int = 0) throws -> [ClipItem] {
        try db.dbPool.read { db in
            var sql = "SELECT * FROM clip_items WHERE 1=1"
            var args: [DatabaseValueConvertible?] = []

            if let search, !search.isEmpty {
                sql += " AND content LIKE ?"
                args.append("%\(search)%")
            }
            if let clipType {
                sql += " AND clip_type = ?"
                args.append(clipType.rawValue)
            }

            sql += " ORDER BY is_pinned DESC, created_at DESC LIMIT ? OFFSET ?"
            args.append(limit)
            args.append(offset)

            return try ClipItem.fetchAll(db, sql: sql, arguments: StatementArguments(args)!)
        }
    }

    /// Delete a clip by ID
    func delete(id: String) throws {
        try db.dbPool.write { db in
            try db.execute(sql: "DELETE FROM clip_items WHERE id = ?", arguments: [id])
        }
    }

    /// Toggle pin status, returns new state
    func togglePin(id: String) throws -> Bool {
        try db.dbPool.write { db in
            try db.execute(sql:
                "UPDATE clip_items SET is_pinned = CASE WHEN is_pinned = 0 THEN 1 ELSE 0 END WHERE id = ?",
                arguments: [id])
            return try Bool.fetchOne(db, sql:
                "SELECT is_pinned FROM clip_items WHERE id = ?",
                arguments: [id]) ?? false
        }
    }

    /// Delete unpinned clips older than keepDays
    @discardableResult
    func clearOld(keepDays: Int) throws -> Int {
        try db.dbPool.write { db in
            let cutoff = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-Double(keepDays) * 86400))
            try db.execute(sql:
                "DELETE FROM clip_items WHERE is_pinned = 0 AND created_at < ?",
                arguments: [cutoff])
            return db.changesCount
        }
    }
}
