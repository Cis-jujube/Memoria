import Foundation

public struct RawEntryRepository {
    private let database: LocalSQLiteStore

    public init(database: LocalSQLiteStore) {
        self.database = database
    }

    @discardableResult
    public func create(
        inputType: RawEntryInputType,
        rawText: String,
        sourceFileID: String? = nil
    ) throws -> RawEntry {
        let timestamp = nowString()
        let entry = RawEntry(
            id: "entry-\(UUID().uuidString)",
            inputType: inputType,
            rawText: rawText,
            sourceFileID: sourceFileID,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try database.execute(
            """
            INSERT INTO raw_entries (id, input_type, raw_text, source_file_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [
                entry.id,
                entry.inputType.rawValue,
                entry.rawText,
                entry.sourceFileID,
                entry.createdAt,
                entry.updatedAt
            ]
        )
        return entry
    }

    public func fetch(id: String) throws -> RawEntry? {
        try database.query(
            """
            SELECT id, input_type, raw_text, source_file_id, created_at, updated_at
            FROM raw_entries
            WHERE id = ?
            """,
            [id]
        ) { statement in
            RawEntry(
                id: columnText(statement, 0),
                inputType: RawEntryInputType(rawValue: columnText(statement, 1)) ?? .text,
                rawText: columnText(statement, 2),
                sourceFileID: columnOptionalText(statement, 3),
                createdAt: columnText(statement, 4),
                updatedAt: columnText(statement, 5)
            )
        }.first
    }
}
