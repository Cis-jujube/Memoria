import Foundation

public struct ThemeRepository {
    private let database: LocalSQLiteStore

    public init(database: LocalSQLiteStore) {
        self.database = database
    }

    public func list() throws -> [Theme] {
        try database.query(
            "SELECT id, name, description, created_at, updated_at FROM themes ORDER BY name"
        ) { statement in
            Theme(
                id: columnText(statement, 0),
                name: columnText(statement, 1),
                description: columnOptionalText(statement, 2),
                createdAt: columnText(statement, 3),
                updatedAt: columnText(statement, 4)
            )
        }
    }
}
