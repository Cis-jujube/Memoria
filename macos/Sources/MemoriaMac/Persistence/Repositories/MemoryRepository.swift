import Foundation

public struct MemoryRepository {
    private let database: LocalSQLiteStore

    public init(database: LocalSQLiteStore) {
        self.database = database
    }

    public func fetch(id: String) throws -> MemoryAtom? {
        try database.query(
            """
            SELECT id, source_entry_id, type, title, summary, content, source_quote, confidence, sensitivity, is_ai_inferred, status, event_time, valid_until, created_at, updated_at
            FROM memory_atoms
            WHERE id = ?
            """,
            [id]
        ) { statement in
            mapMemoryAtom(statement)
        }.first
    }

    public func listConfirmed(includeSensitive: Bool = true) throws -> [MemoryAtom] {
        var sql = """
        SELECT id, source_entry_id, type, title, summary, content, source_quote, confidence, sensitivity, is_ai_inferred, status, event_time, valid_until, created_at, updated_at
        FROM memory_atoms
        WHERE status = 'confirmed'
        """
        if !includeSensitive {
            sql += " AND sensitivity = 'normal'"
        }
        sql += " ORDER BY created_at DESC"
        return try database.query(sql) { statement in
            mapMemoryAtom(statement)
        }
    }

    public func linkedThemeNames(memoryID: String) throws -> [String] {
        try database.query(
            """
            SELECT themes.name
            FROM themes
            JOIN memory_theme_links ON memory_theme_links.theme_id = themes.id
            WHERE memory_theme_links.memory_id = ?
            ORDER BY memory_theme_links.rowid ASC
            """,
            [memoryID]
        ) { statement in
            columnText(statement, 0)
        }
    }

    public func linkedPersonIDs(memoryID: String) throws -> [String] {
        try database.query(
            """
            SELECT person_id
            FROM memory_person_links
            WHERE memory_id = ?
            ORDER BY rowid ASC
            """,
            [memoryID]
        ) { statement in
            columnText(statement, 0)
        }
    }

    public func memories(forPersonID personID: String) throws -> [MemoryAtom] {
        try database.query(
            """
            SELECT memory_atoms.id, memory_atoms.source_entry_id, memory_atoms.type, memory_atoms.title, memory_atoms.summary, memory_atoms.content, memory_atoms.source_quote, memory_atoms.confidence, memory_atoms.sensitivity, memory_atoms.is_ai_inferred, memory_atoms.status, memory_atoms.event_time, memory_atoms.valid_until, memory_atoms.created_at, memory_atoms.updated_at
            FROM memory_atoms
            JOIN memory_person_links ON memory_person_links.memory_id = memory_atoms.id
            WHERE memory_person_links.person_id = ?
            AND memory_atoms.status = 'confirmed'
            ORDER BY memory_atoms.created_at DESC
            """,
            [personID]
        ) { statement in
            mapMemoryAtom(statement)
        }
    }

    public func search(
        query: String,
        type: MemoryAtomType? = nil,
        personID: String? = nil,
        themeName: String? = nil,
        includeSensitive: Bool = false
    ) throws -> [MemoryAtom] {
        var sql = """
        SELECT DISTINCT memory_atoms.id, memory_atoms.source_entry_id, memory_atoms.type, memory_atoms.title, memory_atoms.summary, memory_atoms.content, memory_atoms.source_quote, memory_atoms.confidence, memory_atoms.sensitivity, memory_atoms.is_ai_inferred, memory_atoms.status, memory_atoms.event_time, memory_atoms.valid_until, memory_atoms.created_at, memory_atoms.updated_at
        FROM memory_atoms
        """
        var values: [String?] = []

        if personID != nil {
            sql += " JOIN memory_person_links mpl ON mpl.memory_id = memory_atoms.id"
        }
        if themeName != nil {
            sql += " JOIN memory_theme_links mtl ON mtl.memory_id = memory_atoms.id JOIN themes ON themes.id = mtl.theme_id"
        }

        sql += " WHERE memory_atoms.status = 'confirmed'"

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            sql += " AND (memory_atoms.title LIKE ? OR memory_atoms.summary LIKE ? OR memory_atoms.content LIKE ? OR memory_atoms.source_quote LIKE ?)"
            let pattern = "%\(trimmedQuery)%"
            values.append(contentsOf: [pattern, pattern, pattern, pattern])
        }
        if let type {
            sql += " AND memory_atoms.type = ?"
            values.append(type.rawValue)
        }
        if let personID {
            sql += " AND mpl.person_id = ?"
            values.append(personID)
        }
        if let themeName {
            sql += " AND themes.name = ?"
            values.append(themeName)
        }
        if !includeSensitive {
            sql += " AND memory_atoms.sensitivity = 'normal'"
        }

        sql += " ORDER BY memory_atoms.created_at DESC"

        return try database.query(sql, values) { statement in
            mapMemoryAtom(statement)
        }
    }
}
