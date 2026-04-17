import Foundation
import GRDB

/// Manages the SQLite database via GRDB
final class DatabaseManager: Sendable {
    let dbPool: DatabasePool

    /// Default database path: ~/Library/Application Support/com.pastego.dev/pastego.db
    static var defaultPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.pastego.dev")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pastego.db").path
    }

    /// Images directory
    static var imagesDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.pastego.dev/images")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init(path: String? = nil) throws {
        let dbPath = path ?? Self.defaultPath
        dbPool = try DatabasePool(path: dbPath)
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_createTables") { db in
            // clip_items
            try db.create(table: "clip_items", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("content", .text).notNull()
                t.column("content_hash", .text).notNull().unique()
                t.column("clip_type", .text).notNull().defaults(to: "text")
                t.column("source_app", .text)
                t.column("image_path", .text)
                t.column("is_pinned", .integer).notNull().defaults(to: 0)
                t.column("created_at", .text).notNull()
            }
            try db.create(index: "idx_clip_items_created_at", on: "clip_items",
                         columns: ["created_at"], ifNotExists: true)
            try db.create(index: "idx_clip_items_hash", on: "clip_items",
                         columns: ["content_hash"], ifNotExists: true)
            try db.create(index: "idx_clip_items_type", on: "clip_items",
                         columns: ["clip_type"], ifNotExists: true)

            // ai_providers
            try db.create(table: "ai_providers", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("kind", .text).notNull()
                t.column("endpoint", .text).notNull()
                t.column("model", .text).notNull()
                t.column("api_key", .text).notNull().defaults(to: "")
                t.column("is_default", .integer).notNull().defaults(to: 0)
            }

            // templates
            try db.create(table: "templates", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("prompt", .text).notNull()
                t.column("category", .text).notNull().defaults(to: "general")
                t.column("shortcut", .text)
            }

            // Insert default template
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM templates") ?? 0
            if count == 0 {
                try db.execute(sql: """
                    INSERT INTO templates (id, name, prompt, category, shortcut)
                    VALUES ('tpl-translate', '翻译',
                            '你是一名专业翻译助手。请先判断“原文”的主要语言：如果原文是中文，则翻译成自然、准确的英文；如果原文是其他语言，则翻译成简体中文。只输出译文，不要解释，不要重复原文，不要说明你采用了什么规则。\n\n原文：\n{{materials}}',
                            'general', 'cmd+shift+t')
                    """)
            }
        }

        migrator.registerMigration("v2_backfillTranslateTemplate") { db in
            try db.execute(sql: """
                UPDATE templates
                SET shortcut = 'cmd+shift+t'
                WHERE id = 'tpl-translate' AND (shortcut IS NULL OR TRIM(shortcut) = '')
                """)

            try db.execute(sql: """
                UPDATE templates
                SET prompt = '你是一名专业翻译助手。请先判断“原文”的主要语言：如果原文是中文，则翻译成自然、准确的英文；如果原文是其他语言，则翻译成简体中文。只输出译文，不要解释，不要重复原文，不要说明你采用了什么规则。\n\n原文：\n{{materials}}'
                WHERE id = 'tpl-translate'
                  AND prompt = '请将以下内容翻译为中文（如已是中文则翻译为英文）：\n\n{{materials}}'
                """)
        }

        migrator.registerMigration("v3_refreshTranslateTemplatePrompt") { db in
            try db.execute(sql: """
                UPDATE templates
                SET prompt = '你是一名专业翻译助手。请先判断“原文”的主要语言：如果原文是中文，则翻译成自然、准确的英文；如果原文是其他语言，则翻译成简体中文。只输出译文，不要解释，不要重复原文，不要说明你采用了什么规则。\n\n原文：\n{{materials}}'
                WHERE id = 'tpl-translate'
                """)
        }

        try migrator.migrate(dbPool)
    }
}
