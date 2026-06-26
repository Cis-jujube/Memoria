import Foundation
import SQLite3

public final class LocalSQLiteStore {
    private var db: OpaquePointer?

    public init(
        filename: String = "memoria.sqlite3",
        directory: URL? = nil,
        seedDemoData: Bool = true
    ) throws {
        let appDirectory: URL
        if let directory {
            appDirectory = directory
        } else {
            let supportDirectory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            appDirectory = supportDirectory.appending(path: "Memoria", directoryHint: .isDirectory)
        }

        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        let url = appDirectory.appending(path: filename)

        if sqlite3_open(url.path, &db) != SQLITE_OK {
            throw SQLiteStoreError.open(message: lastErrorMessage)
        }
        try execute("PRAGMA foreign_keys = ON")
        try migrate()
        try seedDefaultThemesIfNeeded()
        try seedDefaultRelationshipTagPrioritiesIfNeeded()
        if seedDemoData {
            try seedIfNeeded()
        }
    }

    deinit {
        sqlite3_close(db)
    }

    public func loadSnapshot() throws -> DashboardSnapshot {
        let people = try loadPeople()
        let hasLocalPeople = !people.isEmpty
        return DashboardSnapshot(
            people: people,
            pendingUpdates: try loadPendingUpdates(),
            memoryAtoms: try loadMemoryAtoms(),
            themes: try loadThemes(),
            reminders: try loadReminders(),
            gifts: try loadGiftIdeas(),
            files: hasLocalPeople ? DashboardSnapshot.demo.files : [],
            relationshipEdges: hasLocalPeople ? try loadRelationshipEdges() : [],
            relationshipTagPriorities: try loadRelationshipTagPriorities()
        )
    }

    public func loadSettings() throws -> NativeSettings {
        NativeSettings(
            model: DeepSeekModel(rawValue: try setting("deepseek_model") ?? "") ?? .flash,
            deepThinking: (try setting("deep_thinking")) == "true",
            language: LanguagePreference(rawValue: try setting("language") ?? "") ?? .system,
            hasAPIKey: false
        )
    }

    public func saveSettings(_ settings: NativeSettings) throws {
        try upsertSetting("deepseek_model", settings.model.rawValue)
        try upsertSetting("deep_thinking", settings.deepThinking ? "true" : "false")
        try upsertSetting("language", settings.language.rawValue)
    }

    public func tableNames() throws -> Set<String> {
        Set(try query("SELECT name FROM sqlite_master WHERE type IN ('table','view')") { statement in
            columnText(statement, 0)
        })
    }

    public func loadDeveloperLogSnapshot(runtimeEntries: [DeveloperLogEntry] = []) throws -> DeveloperLogSnapshot {
        let existingTables = try tableNames()
        let databaseMetrics = try developerLogTables.map { tableName in
            DeveloperLogMetric(
                label: tableName,
                value: existingTables.contains(tableName) ? try scalarInt("SELECT COUNT(*) FROM \(tableName)") : 0
            )
        }
        let recentEntries = try loadRecentDeveloperAuditEvents() + loadRecentDeveloperAIRuns()

        return DeveloperLogSnapshot(
            generatedAt: memoriaTimestamp(),
            databaseMetrics: databaseMetrics,
            runtimeEntries: runtimeEntries,
            recentEntries: recentEntries.sorted { $0.createdAt > $1.createdAt }
        )
    }

    public func deleteAllData() throws {
        try withTransaction {
            let existingTables = try tableNames()
            for table in [
                "memory_person_links",
                "memory_theme_links",
                "pending_updates",
                "pending_updates_legacy",
                "memory_atoms",
                "themes",
                "relationship_tag_priorities",
                "raw_entries",
                "audit_events",
                "ai_runs",
                "reminders",
                "gift_ideas",
                "relationship_edges",
                "people",
                "memories",
                "app_settings"
            ] {
                if existingTables.contains(table) {
                    try execute("DELETE FROM \(table)")
                }
            }
        }
    }

    public func updatePersonGroup(personID: String, group: GroupFilter) throws {
        try updatePersonGroups(personID: personID, groups: [group])
    }

    public func updatePersonGroups(personID: String, groups: [GroupFilter]) throws {
        let normalized = normalizeGroupLabels(groups)
        guard let primary = normalized.first else { return }
        try execute(
            "UPDATE people SET group_label = ?, group_labels_json = ? WHERE id = ?",
            [primary.rawValue, encodeGroupLabels(normalized), personID]
        )
    }

    public func upsertPerson(_ person: FriendPerson) throws {
        let values: [String?] = [
            person.displayName,
            person.nickname,
            person.englishName,
            person.relationLabel,
            person.groupLabel.rawValue,
            encodeGroupLabels(person.groupLabels),
            person.location,
            person.hometown,
            person.languages,
            person.contactInfo,
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
            person.initials,
            person.school,
            person.major,
            person.company,
            person.roleTitle,
            person.researchExperience,
            person.internshipExperience,
            person.familyNotes,
            person.partnerName,
            String(person.manualClosenessLevel),
            person.closenessSignals,
            encodeCategoryNotes(person.categoryNotes)
        ]

        if try scalarInt("SELECT COUNT(*) FROM people WHERE id = ?", [person.id]) > 0 {
            try execute(
                """
                UPDATE people
                SET display_name = ?, nickname = ?, english_name = ?, relation_label = ?, group_label = ?,
                    group_labels_json = ?, location = ?, hometown = ?, languages = ?, contact_info = ?,
                    birthday = ?, dietary_restrictions = ?, favorite_foods = ?, disliked_things = ?,
                    zodiac_sign = ?, mbti = ?, interests = ?, books = ?, sports = ?, profile_tags = ?,
                    last_signal = ?, initials = ?, school = ?, major = ?, company = ?, role_title = ?,
                    research_experience = ?, internship_experience = ?, family_notes = ?, partner_name = ?,
                    manual_closeness_level = ?, closeness_signals = ?, category_notes_json = ?
                WHERE id = ?
                """,
                values + [person.id]
            )
        } else {
            try execute(
                """
                INSERT INTO people
                (id, display_name, nickname, english_name, relation_label, group_label, group_labels_json, location, hometown, languages, contact_info, birthday, dietary_restrictions, favorite_foods, disliked_things, zodiac_sign, mbti, interests, books, sports, profile_tags, last_signal, initials, school, major, company, role_title, research_experience, internship_experience, family_notes, partner_name, manual_closeness_level, closeness_signals, category_notes_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                person.id,
                ] + values
            )
        }
    }

    @discardableResult
    public func applyProfilePatch(_ patch: PersonProfilePatchProposal) throws -> FriendPerson {
        let people = try loadSnapshot().people
        guard let person = people.first(where: { candidate in
            if let targetPersonID = patch.targetPersonID, candidate.id == targetPersonID {
                return true
            }
            return candidate.displayName.localizedCaseInsensitiveCompare(patch.targetDisplayName) == .orderedSame ||
                candidate.nickname.localizedCaseInsensitiveCompare(patch.targetDisplayName) == .orderedSame ||
                candidate.englishName.localizedCaseInsensitiveCompare(patch.targetDisplayName) == .orderedSame
        }) else {
            throw AIContractError.invalidProfilePatch
        }

        var notes = person.categoryNotes
        notes[patch.profileCategory] = mergedProfileNote(
            existing: notes[patch.profileCategory] ?? "",
            proposed: patch.proposedValue
        )
        let updated = FriendPerson(
            id: person.id,
            displayName: person.displayName,
            nickname: person.nickname,
            englishName: person.englishName,
            relationLabel: person.relationLabel,
            groupLabel: person.groupLabel,
            groupLabels: person.groupLabels,
            location: person.location,
            hometown: person.hometown,
            languages: person.languages,
            contactInfo: person.contactInfo,
            birthday: person.birthday,
            dietaryRestrictions: person.dietaryRestrictions,
            favoriteFoods: person.favoriteFoods,
            dislikedThings: person.dislikedThings,
            zodiacSign: person.zodiacSign,
            mbti: person.mbti,
            interests: person.interests,
            books: person.books,
            sports: person.sports,
            profileTags: person.profileTags,
            lastSignal: patch.proposedValue,
            initials: person.initials,
            school: person.school,
            major: person.major,
            company: person.company,
            roleTitle: person.roleTitle,
            researchExperience: person.researchExperience,
            internshipExperience: person.internshipExperience,
            familyNotes: person.familyNotes,
            partnerName: person.partnerName,
            manualClosenessLevel: person.manualClosenessLevel,
            closenessSignals: person.closenessSignals,
            categoryNotes: notes
        )
        try upsertPerson(updated)
        return updated
    }

    public func deletePerson(_ person: FriendPerson) throws {
        try withTransaction {
            try execute("DELETE FROM relationship_edges WHERE source_id = ? OR target_id = ?", [person.id, person.id])
            try execute("DELETE FROM gift_ideas WHERE person_name = ?", [person.displayName])
            try execute("DELETE FROM reminders WHERE person_name = ?", [person.displayName])
            try execute("DELETE FROM people WHERE id = ?", [person.id])
        }
    }

    public func upsertMemoryAtom(_ memory: MemoryAtom) throws {
        try execute(
            """
            INSERT OR REPLACE INTO memory_atoms
            (id, source_entry_id, type, title, summary, content, source_quote, confidence, sensitivity, is_ai_inferred, status, event_time, valid_until, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                memory.id,
                memory.sourceEntryID,
                memory.type.rawValue,
                memory.title,
                memory.summary,
                memory.content,
                memory.sourceQuote,
                String(memory.confidence),
                memory.sensitivity.rawValue,
                memory.isAIInferred ? "1" : "0",
                memory.status.rawValue,
                memory.eventTime,
                memory.validUntil,
                memory.createdAt,
                nowString()
            ]
        )
    }

    public func deleteMemoryAtom(id: String) throws {
        try withTransaction {
            try execute("DELETE FROM memory_person_links WHERE memory_id = ?", [id])
            try execute("DELETE FROM memory_theme_links WHERE memory_id = ?", [id])
            try execute("DELETE FROM memory_atoms WHERE id = ?", [id])
        }
    }

    public func updateMemoryAtomStatus(id: String, status: MemoryAtomStatus) throws {
        try execute(
            "UPDATE memory_atoms SET status = ?, updated_at = ? WHERE id = ?",
            [status.rawValue, nowString(), id]
        )
    }

    public func replaceThemeLinks(memoryID: String, themeNames: [String]) throws {
        try withTransaction {
            try execute("DELETE FROM memory_theme_links WHERE memory_id = ?", [memoryID])
            for themeName in normalizedNames(themeNames) {
                let theme = try upsertTheme(name: themeName, description: nil)
                try execute(
                    """
                    INSERT OR IGNORE INTO memory_theme_links (memory_id, theme_id, created_at)
                    VALUES (?, ?, ?)
                    """,
                    [memoryID, theme.id, nowString()]
                )
            }
        }
    }

    public func upsertTheme(name: String, description: String?) throws -> Theme {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw SQLiteStoreError.message("Theme name cannot be empty.")
        }
        if let existing = try theme(named: trimmedName) {
            let updated = Theme(
                id: existing.id,
                name: trimmedName,
                description: trimmedDescription?.isEmpty == false ? trimmedDescription : existing.description,
                createdAt: existing.createdAt,
                updatedAt: nowString()
            )
            try updateTheme(updated)
            return updated
        }
        let now = nowString()
        let theme = Theme(
            id: "theme-\(UUID().uuidString)",
            name: trimmedName,
            description: trimmedDescription?.isEmpty == false ? trimmedDescription : nil,
            createdAt: now,
            updatedAt: now
        )
        try execute(
            """
            INSERT INTO themes (id, name, description, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            [theme.id, theme.name, theme.description, theme.createdAt, theme.updatedAt]
        )
        return theme
    }

    public func updateTheme(_ theme: Theme) throws {
        try execute(
            "UPDATE themes SET name = ?, description = ?, updated_at = ? WHERE id = ?",
            [theme.name, theme.description, nowString(), theme.id]
        )
    }

    public func deleteTheme(id: String) throws {
        try withTransaction {
            try execute("DELETE FROM memory_theme_links WHERE theme_id = ?", [id])
            try execute("DELETE FROM themes WHERE id = ?", [id])
        }
    }

    public func upsertRelationshipEdge(_ edge: RelationshipEdge) throws {
        try execute(
            """
            INSERT OR REPLACE INTO relationship_edges
            (id, source_id, source_name, target_id, target_name, label, strength, relation_kind, source_memory_id, confidence, is_ai_inferred, tags_json, ai_primary_tag, manual_primary_tag, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                edge.id,
                edge.sourceID,
                edge.sourceName,
                edge.targetID,
                edge.targetName,
                edge.label,
                String(edge.strength),
                edge.relationKind,
                edge.sourceMemoryID,
                String(edge.confidence),
                edge.isAIInferred ? "1" : "0",
                encodeStringArray(edge.tags),
                edge.aiPrimaryTag,
                edge.manualPrimaryTag,
                nowString()
            ]
        )
    }

    public func deleteRelationshipEdge(id: String) throws {
        try execute("DELETE FROM relationship_edges WHERE id = ?", [id])
    }

    public func upsertRelationshipTagPriority(_ priority: RelationshipTagPriority) throws {
        try execute(
            """
            INSERT OR REPLACE INTO relationship_tag_priorities (tag, rank, updated_at)
            VALUES (?, ?, ?)
            """,
            [priority.tag, String(priority.rank), priority.updatedAt]
        )
    }

    public func importTransferBundle(_ bundle: MemoriaTransferBundle) throws {
        try withTransaction {
            for priority in bundle.relationshipTagPriorities {
                try upsertRelationshipTagPriority(priority.relationshipTagPriority)
            }

            for theme in bundle.themes {
                try upsertTheme(theme)
            }

            for person in bundle.people {
                try upsertPerson(person.friendPerson)
            }

            for memory in bundle.memoryAtoms {
                try upsertMemoryAtom(memory)
            }

            for link in bundle.memoryPersonLinks {
                guard try scalarInt("SELECT COUNT(*) FROM memory_atoms WHERE id = ?", [link.memoryID]) > 0,
                      try scalarInt("SELECT COUNT(*) FROM people WHERE id = ?", [link.personID]) > 0 else {
                    continue
                }
                let relationType = ["about", "mentioned", "involves", "inferred"].contains(link.relationType)
                    ? link.relationType
                    : "mentioned"
                try execute(
                    """
                    INSERT OR IGNORE INTO memory_person_links (memory_id, person_id, relation_type, created_at)
                    VALUES (?, ?, ?, ?)
                    """,
                    [link.memoryID, link.personID, relationType, nowString()]
                )
            }

            for link in bundle.memoryThemeLinks {
                guard try scalarInt("SELECT COUNT(*) FROM memory_atoms WHERE id = ?", [link.memoryID]) > 0,
                      let themeID = try scalarString("SELECT id FROM themes WHERE name = ?", [link.themeName]) else {
                    continue
                }
                try execute(
                    """
                    INSERT OR IGNORE INTO memory_theme_links (memory_id, theme_id, created_at)
                    VALUES (?, ?, ?)
                    """,
                    [link.memoryID, themeID, nowString()]
                )
            }

            for edge in bundle.relationshipEdges {
                try upsertRelationshipEdge(edge.relationshipEdge)
            }

            for reminder in bundle.reminders {
                try upsertReminder(reminder)
            }

            try upsertGiftIdeas(bundle.gifts.map(\.giftIdea))
        }
    }

    public func upsertGiftIdeas(_ ideas: [GiftIdea]) throws {
        for gift in ideas {
            try execute(
                """
                INSERT OR REPLACE INTO gift_ideas
                (id, title, person_name, price_band, rationale, risk, confirmation_question, match_score, surprise_score, risk_level, practicality, emotional_value, needs_more_info)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    gift.id,
                    gift.title,
                    gift.personName,
                    gift.priceBand,
                    gift.rationale,
                    gift.risk,
                    gift.confirmationQuestion,
                    String(gift.matchScore),
                    String(gift.surpriseScore),
                    gift.riskLevel,
                    gift.practicality,
                    gift.emotionalValue,
                    gift.needsMoreInfo ? "1" : "0"
                ]
            )
        }
    }

    public func upsertReminder(_ reminder: TransferReminder) throws {
        try execute(
            """
            INSERT OR REPLACE INTO reminders (id, title, person_name, due_label, due_date, time_label, context, location)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                reminder.id,
                reminder.title,
                reminder.personName,
                reminder.dueLabel,
                reminder.dueDate,
                reminder.timeLabel,
                reminder.context,
                reminder.location
            ]
        )
    }

    public func deleteReminder(id: String) throws {
        try execute("DELETE FROM reminders WHERE id = ?", [id])
    }

    public func replaceProfileCategoryNote(personID: String, category: PersonProfileCategory, value: String) throws {
        guard let person = try loadSnapshot().people.first(where: { $0.id == personID }) else {
            throw AIContractError.invalidProfilePatch
        }
        var notes = person.categoryNotes
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notes.removeValue(forKey: category)
        } else {
            notes[category] = value
        }
        try execute(
            "UPDATE people SET category_notes_json = ?, last_signal = ? WHERE id = ?",
            [encodeCategoryNotes(notes), value, personID]
        )
    }

    func execute(_ sql: String, _ values: [String?] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(message: lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }
        try bind(values, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteStoreError.step(message: lastErrorMessage)
        }
    }

    func query<T>(_ sql: String, _ values: [String?] = [], map: (OpaquePointer?) -> T) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(message: lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }
        try bind(values, to: statement)
        var rows: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(map(statement))
        }
        return rows
    }

    func withTransaction<T>(_ work: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let value = try work()
            try execute("COMMIT")
            return value
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    func scalarInt(_ sql: String, _ values: [String?] = []) throws -> Int {
        try query(sql, values) { statement in
            Int(sqlite3_column_int(statement, 0))
        }.first ?? 0
    }

    func scalarString(_ sql: String, _ values: [String?] = []) throws -> String? {
        try query(sql, values) { statement in
            columnOptionalText(statement, 0)
        }.first ?? nil
    }

    private func migrate() throws {
        try execute("CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL)")
        try execute("CREATE TABLE IF NOT EXISTS app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        try migratePeopleAndDerivedTables()
        try migrateLegacyPendingUpdatesIfNeeded()
        try applySchemaV2()
        try execute(
            "INSERT OR IGNORE INTO schema_migrations (version, applied_at) VALUES (?, ?)",
            ["2", nowString()]
        )
    }

    private func migratePeopleAndDerivedTables() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS people (
            id TEXT PRIMARY KEY,
            display_name TEXT NOT NULL,
            nickname TEXT NOT NULL DEFAULT '',
            english_name TEXT NOT NULL DEFAULT '',
            relation_label TEXT NOT NULL,
            group_label TEXT NOT NULL,
            group_labels_json TEXT NOT NULL DEFAULT '',
            location TEXT NOT NULL,
            hometown TEXT NOT NULL DEFAULT '',
            languages TEXT NOT NULL DEFAULT '',
            contact_info TEXT NOT NULL DEFAULT '',
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
            initials TEXT NOT NULL,
            school TEXT NOT NULL DEFAULT '',
            major TEXT NOT NULL DEFAULT '',
            company TEXT NOT NULL DEFAULT '',
            role_title TEXT NOT NULL DEFAULT '',
            research_experience TEXT NOT NULL DEFAULT '',
            internship_experience TEXT NOT NULL DEFAULT '',
            family_notes TEXT NOT NULL DEFAULT '',
            partner_name TEXT NOT NULL DEFAULT '',
            manual_closeness_level INTEGER NOT NULL DEFAULT 3,
            closeness_signals TEXT NOT NULL DEFAULT '',
            category_notes_json TEXT NOT NULL DEFAULT '{}'
        )
        """)
        for column in [
            "nickname",
            "english_name",
            "group_labels_json",
            "hometown",
            "languages",
            "contact_info",
            "dietary_restrictions",
            "favorite_foods",
            "disliked_things",
            "zodiac_sign",
            "mbti",
            "interests",
            "books",
            "sports",
            "profile_tags",
            "school",
            "major",
            "company",
            "role_title",
            "research_experience",
            "internship_experience",
            "family_notes",
            "partner_name",
            "closeness_signals",
            "category_notes_json"
        ] {
            try addTextColumnIfMissing("people", column)
        }
        try addIntegerColumnIfMissing("people", "manual_closeness_level", defaultValue: 3)
        try execute("CREATE TABLE IF NOT EXISTS memories (id TEXT PRIMARY KEY, body TEXT NOT NULL, created_at TEXT NOT NULL)")
        try execute("""
        CREATE TABLE IF NOT EXISTS reminders (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            person_name TEXT NOT NULL,
            due_label TEXT NOT NULL,
            due_date TEXT,
            time_label TEXT NOT NULL DEFAULT '',
            context TEXT NOT NULL DEFAULT '',
            location TEXT NOT NULL DEFAULT ''
        )
        """)
        try addNullableTextColumnIfMissing("reminders", "due_date")
        for column in ["time_label", "context", "location"] {
            try addTextColumnIfMissing("reminders", column)
        }
        try execute("""
        CREATE TABLE IF NOT EXISTS gift_ideas (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            person_name TEXT NOT NULL,
            price_band TEXT NOT NULL,
            rationale TEXT NOT NULL,
            risk TEXT NOT NULL DEFAULT '',
            confirmation_question TEXT NOT NULL DEFAULT '',
            match_score INTEGER NOT NULL DEFAULT 70,
            surprise_score INTEGER NOT NULL DEFAULT 60,
            risk_level TEXT NOT NULL DEFAULT '中',
            practicality TEXT NOT NULL DEFAULT '中',
            emotional_value TEXT NOT NULL DEFAULT '中',
            needs_more_info INTEGER NOT NULL DEFAULT 1
        )
        """)
        for column in ["risk", "confirmation_question", "risk_level", "practicality", "emotional_value"] {
            try addTextColumnIfMissing("gift_ideas", column)
        }
        try addIntegerColumnIfMissing("gift_ideas", "match_score", defaultValue: 70)
        try addIntegerColumnIfMissing("gift_ideas", "surprise_score", defaultValue: 60)
        try addIntegerColumnIfMissing("gift_ideas", "needs_more_info", defaultValue: 1)
        try execute("""
        CREATE TABLE IF NOT EXISTS relationship_edges (
            id TEXT PRIMARY KEY,
            source_id TEXT NOT NULL,
            source_name TEXT NOT NULL,
            target_id TEXT NOT NULL,
            target_name TEXT NOT NULL,
            label TEXT NOT NULL,
            strength REAL NOT NULL DEFAULT 0.5,
            relation_kind TEXT NOT NULL DEFAULT 'friend',
            source_memory_id TEXT,
            confidence REAL NOT NULL DEFAULT 0,
            is_ai_inferred INTEGER NOT NULL DEFAULT 0,
            tags_json TEXT NOT NULL DEFAULT '[]',
            ai_primary_tag TEXT,
            manual_primary_tag TEXT,
            created_at TEXT NOT NULL DEFAULT '',
            updated_at TEXT NOT NULL DEFAULT ''
        )
        """)
        for column in ["source_id", "source_name", "target_id", "target_name", "label", "relation_kind", "created_at", "updated_at"] {
            try addTextColumnIfMissing("relationship_edges", column)
        }
        try addNullableTextColumnIfMissing("relationship_edges", "source_memory_id")
        try addTextColumnIfMissing("relationship_edges", "tags_json")
        try addNullableTextColumnIfMissing("relationship_edges", "ai_primary_tag")
        try addNullableTextColumnIfMissing("relationship_edges", "manual_primary_tag")
        try addRealColumnIfMissing("relationship_edges", "confidence", defaultValue: 0)
        try addIntegerColumnIfMissing("relationship_edges", "is_ai_inferred", defaultValue: 0)
        try execute("""
        CREATE TABLE IF NOT EXISTS relationship_tag_priorities (
            tag TEXT PRIMARY KEY,
            rank INTEGER NOT NULL,
            updated_at TEXT NOT NULL
        )
        """)
        try execute("""
        CREATE TABLE IF NOT EXISTS audit_events (
            id TEXT PRIMARY KEY,
            event_type TEXT NOT NULL,
            subject_id TEXT,
            detail_json TEXT,
            created_at TEXT NOT NULL
        )
        """)
    }

    private func migrateLegacyPendingUpdatesIfNeeded() throws {
        guard try tableExists("pending_updates") else { return }
        let columns = try tableColumns("pending_updates")
        guard !columns.contains("proposal_type") else { return }

        try execute("ALTER TABLE pending_updates RENAME TO pending_updates_legacy")
    }

    private func applySchemaV2() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS raw_entries (
            id TEXT PRIMARY KEY,
            input_type TEXT NOT NULL CHECK (input_type IN ('text','voice_transcript','file','manual','imported_clip')),
            raw_text TEXT NOT NULL,
            source_file_id TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS memory_atoms (
            id TEXT PRIMARY KEY,
            source_entry_id TEXT,
            type TEXT NOT NULL CHECK (type IN ('personal_reflection','idea','relationship_memory','person_fact','event','reminder_source','gift_signal','file_note')),
            title TEXT NOT NULL,
            summary TEXT NOT NULL,
            content TEXT NOT NULL,
            source_quote TEXT,
            confidence REAL NOT NULL DEFAULT 1.0,
            sensitivity TEXT NOT NULL DEFAULT 'normal' CHECK (sensitivity IN ('normal','private','sensitive')),
            is_ai_inferred INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'confirmed' CHECK (status IN ('confirmed','archived','disputed')),
            event_time TEXT,
            valid_until TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (source_entry_id) REFERENCES raw_entries(id) ON DELETE SET NULL
        )
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS pending_updates (
            id TEXT PRIMARY KEY,
            source_entry_id TEXT,
            proposal_type TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            confidence REAL NOT NULL DEFAULT 0.0,
            status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','edited','rejected','failed')),
            created_at TEXT NOT NULL,
            decided_at TEXT,
            error_message TEXT,
            FOREIGN KEY (source_entry_id) REFERENCES raw_entries(id) ON DELETE SET NULL
        )
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS themes (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            description TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS memory_person_links (
            memory_id TEXT NOT NULL,
            person_id TEXT NOT NULL,
            relation_type TEXT NOT NULL CHECK (relation_type IN ('about','mentioned','involves','inferred')),
            created_at TEXT NOT NULL,
            PRIMARY KEY (memory_id, person_id, relation_type),
            FOREIGN KEY (memory_id) REFERENCES memory_atoms(id) ON DELETE CASCADE,
            FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE
        )
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS memory_theme_links (
            memory_id TEXT NOT NULL,
            theme_id TEXT NOT NULL,
            created_at TEXT NOT NULL,
            PRIMARY KEY (memory_id, theme_id),
            FOREIGN KEY (memory_id) REFERENCES memory_atoms(id) ON DELETE CASCADE,
            FOREIGN KEY (theme_id) REFERENCES themes(id) ON DELETE CASCADE
        )
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS ai_runs (
            id TEXT PRIMARY KEY,
            workflow_name TEXT NOT NULL,
            model TEXT NOT NULL,
            input_summary TEXT,
            output_json TEXT,
            status TEXT NOT NULL CHECK (status IN ('started','succeeded','failed')),
            error_message TEXT,
            created_at TEXT NOT NULL
        )
        """)

        try migrateLegacyPendingRows()
        try createIndexes()
    }

    private func migrateLegacyPendingRows() throws {
        guard try tableExists("pending_updates_legacy"),
              try scalarInt("SELECT COUNT(*) FROM pending_updates_legacy") > 0,
              try scalarInt("SELECT COUNT(*) FROM pending_updates") == 0 else {
            return
        }

        let legacyRows = try query("SELECT id, type, summary, evidence, person_name, created_label FROM pending_updates_legacy") { statement in
            (
                id: columnText(statement, 0),
                type: columnText(statement, 1),
                summary: columnText(statement, 2),
                evidence: columnText(statement, 3),
                personName: columnText(statement, 4),
                createdLabel: columnText(statement, 5)
            )
        }

        for row in legacyRows {
            let proposal = MemoryAtomProposal(
                proposalType: .memoryAtom,
                memoryType: .relationshipMemory,
                title: row.personName.isEmpty ? row.type : row.personName,
                summary: row.summary,
                content: row.summary,
                sourceQuote: row.evidence.isEmpty ? row.summary : row.evidence,
                confidence: 0.55,
                sensitivity: .normal,
                isAIInferred: true,
                relatedPeople: [],
                themes: [],
                followUpQuestions: [],
                suggestedActions: []
            )
            let payload = try String(data: JSONEncoder().encode(proposal), encoding: .utf8).requireValue("Could not encode pending payload")
            try execute(
                """
                INSERT OR IGNORE INTO pending_updates
                (id, source_entry_id, proposal_type, payload_json, confidence, status, created_at, decided_at, error_message)
                VALUES (?, NULL, ?, ?, ?, 'pending', ?, NULL, NULL)
                """,
                [
                    row.id,
                    PendingProposalType.memoryAtom.rawValue,
                    payload,
                    String(proposal.confidence),
                    nowString()
                ]
            )
        }
    }

    private func createIndexes() throws {
        try execute("CREATE INDEX IF NOT EXISTS idx_raw_entries_created_at ON raw_entries(created_at)")
        try execute("CREATE INDEX IF NOT EXISTS idx_memory_atoms_type ON memory_atoms(type)")
        try execute("CREATE INDEX IF NOT EXISTS idx_memory_atoms_created_at ON memory_atoms(created_at)")
        try execute("CREATE INDEX IF NOT EXISTS idx_memory_atoms_sensitivity ON memory_atoms(sensitivity)")
        try execute("CREATE INDEX IF NOT EXISTS idx_pending_updates_status ON pending_updates(status)")
        try execute("CREATE INDEX IF NOT EXISTS idx_pending_updates_created_at ON pending_updates(created_at)")
        try execute("CREATE INDEX IF NOT EXISTS idx_memory_person_links_person ON memory_person_links(person_id)")
        try execute("CREATE INDEX IF NOT EXISTS idx_memory_theme_links_theme ON memory_theme_links(theme_id)")
        try execute("CREATE INDEX IF NOT EXISTS idx_relationship_edges_source ON relationship_edges(source_id)")
        try execute("CREATE INDEX IF NOT EXISTS idx_relationship_edges_target ON relationship_edges(target_id)")
        try execute("CREATE INDEX IF NOT EXISTS idx_relationship_tag_priorities_rank ON relationship_tag_priorities(rank)")
    }

    private func seedIfNeeded() throws {
        if try scalarInt("SELECT COUNT(*) FROM people") == 0 {
            for person in DashboardSnapshot.demo.people {
                try execute(
                    """
                    INSERT INTO people
                    (id, display_name, nickname, english_name, relation_label, group_label, group_labels_json, location, hometown, languages, contact_info, birthday, dietary_restrictions, favorite_foods, disliked_things, zodiac_sign, mbti, interests, books, sports, profile_tags, last_signal, initials, school, major, company, role_title, research_experience, internship_experience, family_notes, partner_name, manual_closeness_level, closeness_signals, category_notes_json)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    [
                        person.id,
                        person.displayName,
                        person.nickname,
                        person.englishName,
                        person.relationLabel,
                        person.groupLabel.rawValue,
                        encodeGroupLabels(person.groupLabels),
                        person.location,
                        person.hometown,
                        person.languages,
                        person.contactInfo,
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
                        person.initials,
                        person.school,
                        person.major,
                        person.company,
                        person.roleTitle,
                        person.researchExperience,
                        person.internshipExperience,
                        person.familyNotes,
                        person.partnerName,
                        String(person.manualClosenessLevel),
                        person.closenessSignals,
                        encodeCategoryNotes(person.categoryNotes)
                    ]
                )
            }
        }
        try backfillDemoPeopleProfileFields()

        if try scalarInt("SELECT COUNT(*) FROM pending_updates") == 0,
           try scalarInt("SELECT COUNT(*) FROM memory_atoms") == 0 {
            for update in DashboardSnapshot.demo.pendingUpdates {
                try execute(
                    """
                    INSERT INTO pending_updates
                    (id, source_entry_id, proposal_type, payload_json, confidence, status, created_at, decided_at, error_message)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    [
                        update.id,
                        update.sourceEntryID,
                        update.proposalType.rawValue,
                        update.payloadJSON,
                        String(update.confidence),
                        update.status.rawValue,
                        update.createdAt,
                        update.decidedAt,
                        update.errorMessage
                    ]
                )
            }
        }

        if try scalarInt("SELECT COUNT(*) FROM reminders") == 0 {
            for reminder in DashboardSnapshot.demo.reminders {
                try execute(
                    """
                    INSERT INTO reminders (id, title, person_name, due_label, due_date, time_label, context, location)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    [
                        reminder.id,
                        reminder.title,
                        reminder.personName,
                        reminder.dueLabel,
                        reminder.dueDate,
                        reminder.timeLabel,
                        reminder.context,
                        reminder.location
                    ]
                )
            }
        }

        if try scalarInt("SELECT COUNT(*) FROM gift_ideas") == 0 {
            for gift in DashboardSnapshot.demo.gifts {
                try execute(
                    """
                    INSERT INTO gift_ideas
                    (id, title, person_name, price_band, rationale, risk, confirmation_question, match_score, surprise_score, risk_level, practicality, emotional_value, needs_more_info)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    [
                        gift.id,
                        gift.title,
                        gift.personName,
                        gift.priceBand,
                        gift.rationale,
                        gift.risk,
                        gift.confirmationQuestion,
                        String(gift.matchScore),
                        String(gift.surpriseScore),
                        gift.riskLevel,
                        gift.practicality,
                        gift.emotionalValue,
                        gift.needsMoreInfo ? "1" : "0"
                    ]
                )
            }
        }
        try upsertDemoActionFixtures()
        try upsertDemoRelationshipEdges()

        if try scalarInt("SELECT COUNT(*) FROM memory_atoms") == 0 {
            for memory in DashboardSnapshot.demo.memoryAtoms {
                try execute(
                    """
                    INSERT INTO memory_atoms
                    (id, source_entry_id, type, title, summary, content, source_quote, confidence, sensitivity, is_ai_inferred, status, event_time, valid_until, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    [
                        memory.id,
                        memory.sourceEntryID,
                        memory.type.rawValue,
                        memory.title,
                        memory.summary,
                        memory.content,
                        memory.sourceQuote,
                        String(memory.confidence),
                        memory.sensitivity.rawValue,
                        memory.isAIInferred ? "1" : "0",
                        memory.status.rawValue,
                        memory.eventTime,
                        memory.validUntil,
                        memory.createdAt,
                        memory.updatedAt
                    ]
                )
            }
        }
    }

    private func upsertDemoRelationshipEdges() throws {
        for edge in DashboardSnapshot.demo.relationshipEdges {
            try execute(
                """
                INSERT OR IGNORE INTO relationship_edges
                (id, source_id, source_name, target_id, target_name, label, strength, relation_kind, source_memory_id, confidence, is_ai_inferred, tags_json, ai_primary_tag, manual_primary_tag, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    edge.id,
                    edge.sourceID,
                    edge.sourceName,
                    edge.targetID,
                    edge.targetName,
                    edge.label,
                    String(edge.strength),
                    edge.relationKind,
                    edge.sourceMemoryID,
                    String(edge.confidence),
                    edge.isAIInferred ? "1" : "0",
                    encodeStringArray(edge.tags),
                    edge.aiPrimaryTag,
                    edge.manualPrimaryTag,
                    nowString(),
                    nowString()
                ]
            )
        }
    }

    private func upsertDemoActionFixtures() throws {
        for reminder in DashboardSnapshot.demo.reminders {
            try execute(
                """
                INSERT OR REPLACE INTO reminders (id, title, person_name, due_label, time_label, context, location)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    reminder.id,
                    reminder.title,
                    reminder.personName,
                    reminder.dueLabel,
                    reminder.timeLabel,
                    reminder.context,
                    reminder.location
                ]
            )
        }

        for gift in DashboardSnapshot.demo.gifts {
            try execute(
                """
                INSERT OR REPLACE INTO gift_ideas
                (id, title, person_name, price_band, rationale, risk, confirmation_question, match_score, surprise_score, risk_level, practicality, emotional_value, needs_more_info)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    gift.id,
                    gift.title,
                    gift.personName,
                    gift.priceBand,
                    gift.rationale,
                    gift.risk,
                    gift.confirmationQuestion,
                    String(gift.matchScore),
                    String(gift.surpriseScore),
                    gift.riskLevel,
                    gift.practicality,
                    gift.emotionalValue,
                    gift.needsMoreInfo ? "1" : "0"
                ]
            )
        }
    }

    private func backfillDemoPeopleProfileFields() throws {
        for person in DashboardSnapshot.demo.people {
            try execute(
                """
                UPDATE people
                SET group_labels_json = ?
                WHERE id = ?
                AND (group_labels_json = '' OR group_labels_json = '[]')
                """,
                [encodeGroupLabels(person.groupLabels), person.id]
            )
            try execute(
                """
                UPDATE people
                SET nickname = ?, english_name = ?, hometown = ?, languages = ?, contact_info = ?,
                    dietary_restrictions = ?, favorite_foods = ?, disliked_things = ?, zodiac_sign = ?, mbti = ?,
                    interests = ?, books = ?, sports = ?, profile_tags = ?, last_signal = ?, initials = ?,
                    school = ?, major = ?, company = ?, role_title = ?, research_experience = ?,
                    internship_experience = ?, family_notes = ?, partner_name = ?, manual_closeness_level = ?,
                    closeness_signals = ?, category_notes_json = ?
                WHERE id = ?
                AND (category_notes_json = '' OR category_notes_json = '{}')
                """,
                [
                    person.nickname,
                    person.englishName,
                    person.hometown,
                    person.languages,
                    person.contactInfo,
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
                    person.initials,
                    person.school,
                    person.major,
                    person.company,
                    person.roleTitle,
                    person.researchExperience,
                    person.internshipExperience,
                    person.familyNotes,
                    person.partnerName,
                    String(person.manualClosenessLevel),
                    person.closenessSignals,
                    encodeCategoryNotes(person.categoryNotes),
                    person.id
                ]
            )
        }
    }

    private func loadPeople() throws -> [FriendPerson] {
        try query(
            """
            SELECT id, display_name, nickname, english_name, relation_label, group_label, group_labels_json, location, hometown, languages, contact_info, birthday, dietary_restrictions, favorite_foods, disliked_things, zodiac_sign, mbti, interests, books, sports, profile_tags, last_signal, initials, school, major, company, role_title, research_experience, internship_experience, family_notes, partner_name, manual_closeness_level, closeness_signals, category_notes_json
            FROM people
            ORDER BY display_name
            """
        ) { statement in
            FriendPerson(
                id: columnText(statement, 0),
                displayName: columnText(statement, 1),
                nickname: columnText(statement, 2),
                englishName: columnText(statement, 3),
                relationLabel: columnText(statement, 4),
                groupLabel: GroupFilter(rawValue: columnText(statement, 5)) ?? .classmates,
                groupLabels: decodeGroupLabels(columnText(statement, 6), fallback: GroupFilter(rawValue: columnText(statement, 5)) ?? .classmates),
                location: columnText(statement, 7),
                hometown: columnText(statement, 8),
                languages: columnText(statement, 9),
                contactInfo: columnText(statement, 10),
                birthday: columnText(statement, 11),
                dietaryRestrictions: columnText(statement, 12),
                favoriteFoods: columnText(statement, 13),
                dislikedThings: columnText(statement, 14),
                zodiacSign: columnText(statement, 15),
                mbti: columnText(statement, 16),
                interests: columnText(statement, 17),
                books: columnText(statement, 18),
                sports: columnText(statement, 19),
                profileTags: columnText(statement, 20),
                lastSignal: columnText(statement, 21),
                initials: columnText(statement, 22),
                school: columnText(statement, 23),
                major: columnText(statement, 24),
                company: columnText(statement, 25),
                roleTitle: columnText(statement, 26),
                researchExperience: columnText(statement, 27),
                internshipExperience: columnText(statement, 28),
                familyNotes: columnText(statement, 29),
                partnerName: columnText(statement, 30),
                manualClosenessLevel: Int(sqlite3_column_int(statement, 31)),
                closenessSignals: columnText(statement, 32),
                categoryNotes: decodeCategoryNotes(columnText(statement, 33))
            )
        }
    }

    private func loadPendingUpdates() throws -> [PendingUpdate] {
        try query(
            """
            SELECT id, source_entry_id, proposal_type, payload_json, confidence, status, created_at, decided_at, error_message
            FROM pending_updates
            WHERE status IN ('pending','edited','failed')
            ORDER BY created_at DESC
            """
        ) { statement in
            PendingUpdate(
                id: columnText(statement, 0),
                sourceEntryID: columnOptionalText(statement, 1),
                proposalType: PendingProposalType(rawValue: columnText(statement, 2)) ?? .memoryAtom,
                payloadJSON: columnText(statement, 3),
                confidence: sqlite3_column_double(statement, 4),
                status: PendingUpdateStatus(rawValue: columnText(statement, 5)) ?? .pending,
                createdAt: columnText(statement, 6),
                decidedAt: columnOptionalText(statement, 7),
                errorMessage: columnOptionalText(statement, 8)
            )
        }
    }

    private func loadMemoryAtoms() throws -> [MemoryAtom] {
        try query(
            """
            SELECT id, source_entry_id, type, title, summary, content, source_quote, confidence, sensitivity, is_ai_inferred, status, event_time, valid_until, created_at, updated_at
            FROM memory_atoms
            WHERE status = 'confirmed'
            ORDER BY created_at DESC
            """
        ) { statement in
            mapMemoryAtom(statement)
        }
    }

    private func loadReminders() throws -> [ReminderItem] {
        try query("SELECT id, title, person_name, due_label, due_date, time_label, context, location FROM reminders ORDER BY rowid") { statement in
            ReminderItem(
                id: columnText(statement, 0),
                title: columnText(statement, 1),
                personName: columnText(statement, 2),
                dueLabel: columnText(statement, 3),
                dueDate: columnOptionalText(statement, 4),
                timeLabel: columnText(statement, 5),
                context: columnText(statement, 6),
                location: columnText(statement, 7)
            )
        }
    }

    private func loadGiftIdeas() throws -> [GiftIdea] {
        try query(
            """
            SELECT id, title, person_name, price_band, rationale, risk, confirmation_question, match_score, surprise_score, risk_level, practicality, emotional_value, needs_more_info
            FROM gift_ideas
            ORDER BY rowid
            """
        ) { statement in
            GiftIdea(
                id: columnText(statement, 0),
                title: columnText(statement, 1),
                personName: columnText(statement, 2),
                priceBand: columnText(statement, 3),
                rationale: columnText(statement, 4),
                risk: columnText(statement, 5),
                confirmationQuestion: columnText(statement, 6),
                matchScore: Int(sqlite3_column_int(statement, 7)),
                surpriseScore: Int(sqlite3_column_int(statement, 8)),
                riskLevel: columnText(statement, 9),
                practicality: columnText(statement, 10),
                emotionalValue: columnText(statement, 11),
                needsMoreInfo: sqlite3_column_int(statement, 12) == 1
            )
        }
    }

    private func loadRelationshipEdges() throws -> [RelationshipEdge] {
        try query(
            """
            SELECT id, source_id, source_name, target_id, target_name, label, strength, relation_kind, source_memory_id, confidence, is_ai_inferred, tags_json, ai_primary_tag, manual_primary_tag
            FROM relationship_edges
            ORDER BY rowid
            """
        ) { statement in
            RelationshipEdge(
                id: columnText(statement, 0),
                sourceID: columnText(statement, 1),
                sourceName: columnText(statement, 2),
                targetID: columnText(statement, 3),
                targetName: columnText(statement, 4),
                label: columnText(statement, 5),
                strength: sqlite3_column_double(statement, 6),
                relationKind: columnText(statement, 7),
                sourceMemoryID: columnOptionalText(statement, 8),
                confidence: sqlite3_column_double(statement, 9),
                isAIInferred: sqlite3_column_int(statement, 10) == 1,
                tags: decodeStringArray(columnText(statement, 11)),
                aiPrimaryTag: columnOptionalText(statement, 12),
                manualPrimaryTag: columnOptionalText(statement, 13)
            )
        }
    }

    private func loadThemes() throws -> [Theme] {
        try query(
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

    private func theme(named name: String) throws -> Theme? {
        try query(
            "SELECT id, name, description, created_at, updated_at FROM themes WHERE name = ? LIMIT 1",
            [name]
        ) { statement in
            Theme(
                id: columnText(statement, 0),
                name: columnText(statement, 1),
                description: columnOptionalText(statement, 2),
                createdAt: columnText(statement, 3),
                updatedAt: columnText(statement, 4)
            )
        }.first
    }

    private func loadRelationshipTagPriorities() throws -> [RelationshipTagPriority] {
        let priorities = try query(
            """
            SELECT tag, rank, updated_at
            FROM relationship_tag_priorities
            ORDER BY rank ASC, tag ASC
            """
        ) { statement in
            RelationshipTagPriority(
                tag: columnText(statement, 0),
                rank: Int(sqlite3_column_int(statement, 1)),
                updatedAt: columnText(statement, 2)
            )
        }
        return priorities.isEmpty ? defaultRelationshipTagPriorities : priorities
    }

    private func upsertTheme(_ theme: TransferTheme) throws {
        let timestamp = nowString()
        try execute(
            """
            INSERT OR IGNORE INTO themes (id, name, description, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            [theme.id, theme.name, theme.description, theme.createdAt, theme.updatedAt]
        )
        try execute(
            """
            UPDATE themes
            SET description = COALESCE(?, description), updated_at = ?
            WHERE name = ?
            """,
            [theme.description, timestamp, theme.name]
        )
    }

    private func upsertMemoryAtom(_ memory: TransferMemoryAtom) throws {
        let sourceEntryID = try resolvedSourceEntryID(memory.sourceEntryID)
        try execute(
            """
            INSERT OR REPLACE INTO memory_atoms
            (id, source_entry_id, type, title, summary, content, source_quote, confidence, sensitivity, is_ai_inferred, status, event_time, valid_until, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                memory.id,
                sourceEntryID,
                memory.type,
                memory.title,
                memory.summary,
                memory.content,
                memory.sourceQuote,
                String(memory.confidence),
                memory.sensitivity,
                memory.isAIInferred ? "1" : "0",
                memory.status,
                memory.eventTime,
                memory.validUntil,
                memory.createdAt,
                memory.updatedAt
            ]
        )
    }

    private func resolvedSourceEntryID(_ sourceEntryID: String?) throws -> String? {
        guard let sourceEntryID,
              try scalarInt("SELECT COUNT(*) FROM raw_entries WHERE id = ?", [sourceEntryID]) > 0 else {
            return nil
        }
        return sourceEntryID
    }

    private func seedDefaultThemesIfNeeded() throws {
        let timestamp = nowString()
        for preset in defaultSelfIndexThemePresets {
            try execute(
                """
                INSERT OR IGNORE INTO themes (id, name, description, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                [
                    "theme-\(stableIdentifier(from: preset.name))",
                    preset.name,
                    preset.description,
                    timestamp,
                    timestamp
                ]
            )
        }
    }

    private func seedDefaultRelationshipTagPrioritiesIfNeeded() throws {
        let existingCount = try scalarInt("SELECT COUNT(*) FROM relationship_tag_priorities")
        guard existingCount == 0 else { return }
        let timestamp = nowString()
        for priority in defaultRelationshipTagPriorities {
            try execute(
                """
                INSERT INTO relationship_tag_priorities (tag, rank, updated_at)
                VALUES (?, ?, ?)
                """,
                [priority.tag, String(priority.rank), timestamp]
            )
        }
    }

    private func setting(_ key: String) throws -> String? {
        try scalarString("SELECT value FROM app_settings WHERE key = ?", [key])
    }

    private func upsertSetting(_ key: String, _ value: String) throws {
        try execute("INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)", [key, value])
    }

    private func tableExists(_ table: String) throws -> Bool {
        try scalarInt("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?", [table]) > 0
    }

    private func tableColumns(_ table: String) throws -> Set<String> {
        Set(try query("PRAGMA table_info(\(table))") { statement in
            columnText(statement, 1)
        })
    }

    private func addTextColumnIfMissing(_ table: String, _ column: String) throws {
        let columns = try tableColumns(table)
        guard !columns.contains(column) else { return }
        try execute("ALTER TABLE \(table) ADD COLUMN \(column) TEXT NOT NULL DEFAULT ''")
    }

    private func addNullableTextColumnIfMissing(_ table: String, _ column: String) throws {
        let columns = try tableColumns(table)
        guard !columns.contains(column) else { return }
        try execute("ALTER TABLE \(table) ADD COLUMN \(column) TEXT")
    }

    private func addIntegerColumnIfMissing(_ table: String, _ column: String, defaultValue: Int) throws {
        let columns = try tableColumns(table)
        guard !columns.contains(column) else { return }
        try execute("ALTER TABLE \(table) ADD COLUMN \(column) INTEGER NOT NULL DEFAULT \(defaultValue)")
    }

    private func addRealColumnIfMissing(_ table: String, _ column: String, defaultValue: Double) throws {
        let columns = try tableColumns(table)
        guard !columns.contains(column) else { return }
        try execute("ALTER TABLE \(table) ADD COLUMN \(column) REAL NOT NULL DEFAULT \(defaultValue)")
    }

    private func bind(_ values: [String?], to statement: OpaquePointer?) throws {
        for (index, value) in values.enumerated() {
            if let value {
                sqlite3_bind_text(statement, Int32(index + 1), value, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(statement, Int32(index + 1))
            }
        }
    }

    private var lastErrorMessage: String {
        guard let db, let message = sqlite3_errmsg(db) else { return "Unknown SQLite error" }
        return String(cString: message)
    }
}

func mapMemoryAtom(_ statement: OpaquePointer?) -> MemoryAtom {
    MemoryAtom(
        id: columnText(statement, 0),
        sourceEntryID: columnOptionalText(statement, 1),
        type: MemoryAtomType(rawValue: columnText(statement, 2)) ?? .personalReflection,
        title: columnText(statement, 3),
        summary: columnText(statement, 4),
        content: columnText(statement, 5),
        sourceQuote: columnOptionalText(statement, 6),
        confidence: sqlite3_column_double(statement, 7),
        sensitivity: MemorySensitivity(rawValue: columnText(statement, 8)) ?? .normal,
        isAIInferred: sqlite3_column_int(statement, 9) == 1,
        status: MemoryAtomStatus(rawValue: columnText(statement, 10)) ?? .confirmed,
        eventTime: columnOptionalText(statement, 11),
        validUntil: columnOptionalText(statement, 12),
        createdAt: columnText(statement, 13),
        updatedAt: columnText(statement, 14)
    )
}

private let developerLogTables = [
    "raw_entries",
    "pending_updates",
    "memory_atoms",
    "people",
    "themes",
    "reminders",
    "gift_ideas",
    "relationship_edges",
    "audit_events",
    "ai_runs"
]

private extension LocalSQLiteStore {
    func loadRecentDeveloperAuditEvents() throws -> [DeveloperLogEntry] {
        try query(
            """
            SELECT id, event_type, subject_id, detail_json, created_at
            FROM audit_events
            ORDER BY created_at DESC
            LIMIT 24
            """
        ) { statement in
            let id = columnText(statement, 0)
            let eventType = columnText(statement, 1)
            let subjectID = columnOptionalText(statement, 2)
            let detailJSON = columnOptionalText(statement, 3)
            let createdAt = columnText(statement, 4)
            return DeveloperLogEntry(
                id: id,
                title: eventType,
                detail: developerAuditDetailSummary(subjectID: subjectID, detailJSON: detailJSON),
                createdAt: createdAt
            )
        }
    }

    func loadRecentDeveloperAIRuns() throws -> [DeveloperLogEntry] {
        try query(
            """
            SELECT id, workflow_name, model, input_summary, status, error_message, created_at
            FROM ai_runs
            ORDER BY created_at DESC
            LIMIT 24
            """
        ) { statement in
            let id = columnText(statement, 0)
            let workflowName = columnText(statement, 1)
            let model = columnText(statement, 2)
            let inputSummary = columnOptionalText(statement, 3)
            let status = columnText(statement, 4)
            let errorMessage = columnOptionalText(statement, 5)
            let createdAt = columnText(statement, 6)
            let detailParts = [
                "model: \(redactedDeveloperLogText(model))",
                inputSummary.map { "input: \(redactedDeveloperLogText($0))" },
                errorMessage.map { "error: \(redactedDeveloperLogText($0))" }
            ].compactMap(\.self)
            return DeveloperLogEntry(
                id: id,
                title: "ai_run.\(workflowName).\(status)",
                detail: detailParts.joined(separator: " · "),
                createdAt: createdAt,
                level: status == "failed" ? .error : .info
            )
        }
    }
}

private func developerAuditDetailSummary(subjectID: String?, detailJSON: String?) -> String {
    var parts: [String] = []
    if let subjectID, !subjectID.isEmpty {
        parts.append("subject: \(redactedDeveloperLogText(subjectID))")
    }
    guard let detailJSON,
          let data = detailJSON.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let dictionary = object as? [String: Any] else {
        return parts.isEmpty ? "No detail payload." : parts.joined(separator: " · ")
    }

    let keys = dictionary.keys
        .filter { !$0.localizedCaseInsensitiveContains("key") && !$0.localizedCaseInsensitiveContains("token") }
        .sorted()
    if !keys.isEmpty {
        parts.append("detail keys: \(keys.joined(separator: ", "))")
    }
    return parts.isEmpty ? "No detail payload." : parts.joined(separator: " · ")
}

private func redactedDeveloperLogText(_ text: String) -> String {
    var redacted = text.replacingOccurrences(of: "api_key", with: "credential", options: .caseInsensitive)
    redacted = redacted.replacingOccurrences(of: "apikey", with: "credential", options: .caseInsensitive)
    redacted = redacted.replacingOccurrences(of: "token", with: "credential", options: .caseInsensitive)
    return redacted
}

func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String {
    guard let value = sqlite3_column_text(statement, index) else { return "" }
    return String(cString: value)
}

func columnOptionalText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL,
          let value = sqlite3_column_text(statement, index) else {
        return nil
    }
    let text = String(cString: value)
    return text.isEmpty ? nil : text
}

func nowString() -> String {
    memoriaTimestamp()
}

private func encodeCategoryNotes(_ notes: [PersonProfileCategory: String]) -> String {
    let keyedNotes = Dictionary(uniqueKeysWithValues: notes.map { ($0.key.rawValue, $0.value) })
    guard let data = try? JSONEncoder().encode(keyedNotes),
          let json = String(data: data, encoding: .utf8) else {
        return "{}"
    }
    return json
}

private func decodeCategoryNotes(_ json: String) -> [PersonProfileCategory: String] {
    guard let data = json.data(using: .utf8),
          let keyedNotes = try? JSONDecoder().decode([String: String].self, from: data) else {
        return [:]
    }

    return keyedNotes.reduce(into: [PersonProfileCategory: String]()) { result, pair in
        guard let category = PersonProfileCategory(rawValue: pair.key) else { return }
        result[category] = pair.value
    }
}

private func mergedProfileNote(existing: String, proposed: String) -> String {
    let trimmedExisting = existing.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedProposed = proposed.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedProposed.isEmpty else { return trimmedExisting }
    guard !trimmedExisting.isEmpty else { return trimmedProposed }
    if trimmedExisting.localizedCaseInsensitiveContains(trimmedProposed) {
        return trimmedExisting
    }
    return "\(trimmedExisting)\n\(trimmedProposed)"
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum SQLiteStoreError: LocalizedError {
    case open(message: String)
    case prepare(message: String)
    case step(message: String)
    case missingValue(String)
    case message(String)

    public var errorDescription: String? {
        switch self {
        case .open(let message), .prepare(let message), .step(let message):
            message
        case .missingValue(let message), .message(let message):
            message
        }
    }
}

private func normalizedNames(_ values: [String]) -> [String] {
    values.reduce(into: [String]()) { result, value in
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !result.contains(trimmed) else { return }
        result.append(trimmed)
    }
}

private func encodeGroupLabels(_ groups: [GroupFilter]) -> String {
    let rawValues = normalizeGroupLabels(groups).map(\.rawValue)
    guard let data = try? JSONEncoder().encode(rawValues),
          let json = String(data: data, encoding: .utf8) else {
        return "[]"
    }
    return json
}

private func encodeStringArray(_ values: [String]) -> String {
    let normalized = values.reduce(into: [String]()) { result, value in
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !result.contains(trimmed) else { return }
        result.append(trimmed)
    }
    guard let data = try? JSONEncoder().encode(normalized),
          let json = String(data: data, encoding: .utf8) else {
        return "[]"
    }
    return json
}

private func decodeStringArray(_ json: String) -> [String] {
    guard let data = json.data(using: .utf8),
          let values = try? JSONDecoder().decode([String].self, from: data) else {
        return []
    }
    return values.reduce(into: [String]()) { result, value in
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !result.contains(trimmed) else { return }
        result.append(trimmed)
    }
}

private func stableIdentifier(from value: String) -> String {
    let scalars = value.unicodeScalars.map { String(format: "%04X", $0.value) }
    return scalars.joined(separator: "-").lowercased()
}

private func decodeGroupLabels(_ json: String, fallback: GroupFilter) -> [GroupFilter] {
    guard let data = json.data(using: .utf8),
          let rawValues = try? JSONDecoder().decode([String].self, from: data) else {
        return [fallback]
    }
    let groups = rawValues.compactMap(GroupFilter.init(rawValue:))
    return normalizeGroupLabels(groups.isEmpty ? [fallback] : groups)
}

private func normalizeGroupLabels(_ groups: [GroupFilter]) -> [GroupFilter] {
    groups.reduce(into: [GroupFilter]()) { result, group in
        guard !result.contains(group) else { return }
        result.append(group)
    }
}

private extension Optional where Wrapped == String {
    func requireValue(_ message: String) throws -> String {
        guard let self else {
            throw SQLiteStoreError.missingValue(message)
        }
        return self
    }
}
