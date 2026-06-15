import Foundation
import SQLite3

final class LocalSQLiteStore {
    private var db: OpaquePointer?

    init(filename: String = "memoria.sqlite3") throws {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let url = directory.appending(path: filename)

        if sqlite3_open(url.path, &db) != SQLITE_OK {
            throw SQLiteStoreError.open(message: lastErrorMessage)
        }

        try migrate()
        try seedIfNeeded()
    }

    deinit {
        sqlite3_close(db)
    }

    func loadSnapshot() throws -> DashboardSnapshot {
        DashboardSnapshot(
            people: try loadPeople(),
            pendingUpdates: try loadPendingUpdates(),
            reminders: try loadReminders(),
            gifts: try loadGiftIdeas(),
            files: DashboardSnapshot.demo.files
        )
    }

    func loadSettings() throws -> NativeSettings {
        NativeSettings(
            model: DeepSeekModel(rawValue: try setting("deepseek_model") ?? "") ?? .flash,
            deepThinking: (try setting("deep_thinking")) == "true",
            language: LanguagePreference(rawValue: try setting("language") ?? "") ?? .system,
            hasAPIKey: false
        )
    }

    func saveSettings(_ settings: NativeSettings) throws {
        try upsertSetting("deepseek_model", settings.model.rawValue)
        try upsertSetting("deep_thinking", settings.deepThinking ? "true" : "false")
        try upsertSetting("language", settings.language.rawValue)
    }

    func addMemory(text: String) throws -> String {
        let id = "memory-\(UUID().uuidString)"
        try execute(
            "INSERT INTO memories (id, body, created_at) VALUES (?, ?, ?)",
            [id, text, ISO8601DateFormatter().string(from: Date())]
        )
        return id
    }

    func addPendingUpdate(_ update: PendingUpdate) throws {
        try execute(
            """
            INSERT OR REPLACE INTO pending_updates
            (id, type, summary, evidence, person_name, created_label)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [
                update.id,
                update.type,
                update.summary,
                update.evidence,
                update.personName,
                update.createdLabel
            ]
        )
    }

    func removePendingUpdate(id: String) throws {
        try execute("DELETE FROM pending_updates WHERE id = ?", [id])
    }

    private func migrate() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version INTEGER PRIMARY KEY,
            applied_at TEXT NOT NULL
        )
        """)
        try execute("""
        CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """)
        try execute("""
        CREATE TABLE IF NOT EXISTS people (
            id TEXT PRIMARY KEY,
            display_name TEXT NOT NULL,
            relation_label TEXT NOT NULL,
            group_label TEXT NOT NULL,
            location TEXT NOT NULL,
            birthday TEXT NOT NULL,
            dietary_restrictions TEXT NOT NULL DEFAULT '',
            favorite_foods TEXT NOT NULL DEFAULT '',
            disliked_things TEXT NOT NULL DEFAULT '',
            zodiac_sign TEXT NOT NULL DEFAULT '',
            mbti TEXT NOT NULL DEFAULT '',
            interests TEXT NOT NULL DEFAULT '',
            books TEXT NOT NULL DEFAULT '',
            sports TEXT NOT NULL DEFAULT '',
            profile_tags TEXT NOT NULL DEFAULT '',
            last_signal TEXT NOT NULL,
            initials TEXT NOT NULL
        )
        """)
        try addTextColumnIfMissing("people", "dietary_restrictions")
        try addTextColumnIfMissing("people", "favorite_foods")
        try addTextColumnIfMissing("people", "disliked_things")
        try addTextColumnIfMissing("people", "zodiac_sign")
        try addTextColumnIfMissing("people", "mbti")
        try addTextColumnIfMissing("people", "interests")
        try addTextColumnIfMissing("people", "books")
        try addTextColumnIfMissing("people", "sports")
        try addTextColumnIfMissing("people", "profile_tags")
        try backfillDemoProfileFields()
        try execute("""
        CREATE TABLE IF NOT EXISTS memories (
            id TEXT PRIMARY KEY,
            body TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
        """)
        try execute("""
        CREATE TABLE IF NOT EXISTS pending_updates (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            summary TEXT NOT NULL,
            evidence TEXT NOT NULL,
            person_name TEXT NOT NULL,
            created_label TEXT NOT NULL
        )
        """)
        try execute("""
        CREATE TABLE IF NOT EXISTS reminders (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            person_name TEXT NOT NULL,
            due_label TEXT NOT NULL
        )
        """)
        try execute("""
        CREATE TABLE IF NOT EXISTS gift_ideas (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            person_name TEXT NOT NULL,
            price_band TEXT NOT NULL,
            rationale TEXT NOT NULL
        )
        """)
    }

    private func backfillDemoProfileFields() throws {
        for person in DashboardSnapshot.demo.people {
            try execute(
                """
                UPDATE people
                SET dietary_restrictions = ?, favorite_foods = ?, disliked_things = ?, zodiac_sign = ?, mbti = ?, interests = ?, books = ?, sports = ?, profile_tags = ?
                WHERE id = ?
                AND dietary_restrictions = ''
                AND favorite_foods = ''
                AND disliked_things = ''
                AND zodiac_sign = ''
                AND mbti = ''
                AND interests = ''
                AND books = ''
                AND sports = ''
                AND profile_tags = ''
                """,
                [
                    person.dietaryRestrictions,
                    person.favoriteFoods,
                    person.dislikedThings,
                    person.zodiacSign,
                    person.mbti,
                    person.interests,
                    person.books,
                    person.sports,
                    person.profileTags,
                    person.id
                ]
            )
        }
    }

    private func seedIfNeeded() throws {
        guard try scalarInt("SELECT COUNT(*) FROM people") == 0 else {
            return
        }

        for person in DashboardSnapshot.demo.people {
            try execute(
                """
                INSERT INTO people
                (id, display_name, relation_label, group_label, location, birthday, dietary_restrictions, favorite_foods, disliked_things, zodiac_sign, mbti, interests, books, sports, profile_tags, last_signal, initials)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    person.id,
                    person.displayName,
                    person.relationLabel,
                    person.groupLabel.rawValue,
                    person.location,
                    person.birthday,
                    person.dietaryRestrictions,
                    person.favoriteFoods,
                    person.dislikedThings,
                    person.zodiacSign,
                    person.mbti,
                    person.interests,
                    person.books,
                    person.sports,
                    person.profileTags,
                    person.lastSignal,
                    person.initials
                ]
            )
        }

        for update in DashboardSnapshot.demo.pendingUpdates {
            try addPendingUpdate(update)
        }

        for reminder in DashboardSnapshot.demo.reminders {
            try execute(
                "INSERT INTO reminders (id, title, person_name, due_label) VALUES (?, ?, ?, ?)",
                [reminder.id, reminder.title, reminder.personName, reminder.dueLabel]
            )
        }

        for gift in DashboardSnapshot.demo.gifts {
            try execute(
                "INSERT INTO gift_ideas (id, title, person_name, price_band, rationale) VALUES (?, ?, ?, ?, ?)",
                [gift.id, gift.title, gift.personName, gift.priceBand, gift.rationale]
            )
        }
    }

    private func loadPeople() throws -> [FriendPerson] {
        try query(
            "SELECT id, display_name, relation_label, group_label, location, birthday, dietary_restrictions, favorite_foods, disliked_things, zodiac_sign, mbti, interests, books, sports, profile_tags, last_signal, initials FROM people ORDER BY display_name"
        ) { statement in
            FriendPerson(
                id: columnText(statement, 0),
                displayName: columnText(statement, 1),
                relationLabel: columnText(statement, 2),
                groupLabel: GroupFilter(rawValue: columnText(statement, 3)) ?? .all,
                location: columnText(statement, 4),
                birthday: columnText(statement, 5),
                dietaryRestrictions: columnText(statement, 6),
                favoriteFoods: columnText(statement, 7),
                dislikedThings: columnText(statement, 8),
                zodiacSign: columnText(statement, 9),
                mbti: columnText(statement, 10),
                interests: columnText(statement, 11),
                books: columnText(statement, 12),
                sports: columnText(statement, 13),
                profileTags: columnText(statement, 14),
                lastSignal: columnText(statement, 15),
                initials: columnText(statement, 16)
            )
        }
    }

    private func loadPendingUpdates() throws -> [PendingUpdate] {
        try query(
            "SELECT id, type, summary, evidence, person_name, created_label FROM pending_updates ORDER BY rowid DESC"
        ) { statement in
            PendingUpdate(
                id: columnText(statement, 0),
                type: columnText(statement, 1),
                summary: columnText(statement, 2),
                evidence: columnText(statement, 3),
                personName: columnText(statement, 4),
                createdLabel: columnText(statement, 5)
            )
        }
    }

    private func loadReminders() throws -> [ReminderItem] {
        try query("SELECT id, title, person_name, due_label FROM reminders ORDER BY rowid") { statement in
            ReminderItem(
                id: columnText(statement, 0),
                title: columnText(statement, 1),
                personName: columnText(statement, 2),
                dueLabel: columnText(statement, 3)
            )
        }
    }

    private func loadGiftIdeas() throws -> [GiftIdea] {
        try query("SELECT id, title, person_name, price_band, rationale FROM gift_ideas ORDER BY rowid") { statement in
            GiftIdea(
                id: columnText(statement, 0),
                title: columnText(statement, 1),
                personName: columnText(statement, 2),
                priceBand: columnText(statement, 3),
                rationale: columnText(statement, 4)
            )
        }
    }

    private func setting(_ key: String) throws -> String? {
        try query("SELECT value FROM app_settings WHERE key = ?", [key]) { statement in
            columnText(statement, 0)
        }.first
    }

    private func upsertSetting(_ key: String, _ value: String) throws {
        try execute(
            "INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)",
            [key, value]
        )
    }

    private func addTextColumnIfMissing(_ table: String, _ column: String) throws {
        let columns = try query("PRAGMA table_info(\(table))") { statement in
            columnText(statement, 1)
        }
        guard !columns.contains(column) else { return }
        try execute("ALTER TABLE \(table) ADD COLUMN \(column) TEXT NOT NULL DEFAULT ''")
    }

    private func scalarInt(_ sql: String) throws -> Int {
        try query(sql) { statement in
            Int(sqlite3_column_int(statement, 0))
        }.first ?? 0
    }

    private func execute(_ sql: String, _ values: [String] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(message: lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        for (index, value) in values.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), value, -1, SQLITE_TRANSIENT)
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteStoreError.step(message: lastErrorMessage)
        }
    }

    private func query<T>(
        _ sql: String,
        _ values: [String] = [],
        map: (OpaquePointer?) -> T
    ) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(message: lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        for (index, value) in values.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), value, -1, SQLITE_TRANSIENT)
        }

        var rows: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(map(statement))
        }
        return rows
    }

    private var lastErrorMessage: String {
        guard let db,
              let message = sqlite3_errmsg(db) else {
            return "Unknown SQLite error"
        }
        return String(cString: message)
    }
}

private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String {
    guard let value = sqlite3_column_text(statement, index) else {
        return ""
    }
    return String(cString: value)
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLiteStoreError: LocalizedError {
    case open(message: String)
    case prepare(message: String)
    case step(message: String)

    var errorDescription: String? {
        switch self {
        case .open(let message), .prepare(let message), .step(let message):
            message
        }
    }
}
