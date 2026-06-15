import Foundation
import SQLite3

public struct PendingUpdateRepository {
    private let database: LocalSQLiteStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(database: LocalSQLiteStore) {
        self.database = database
    }

    @discardableResult
    public func createMemoryAtomProposal(
        sourceEntryID: String?,
        proposal: MemoryAtomProposal
    ) throws -> PendingUpdate {
        guard !proposal.sourceQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIContractError.missingSourceQuote
        }

        let timestamp = nowString()
        let payload = try String(data: encoder.encode(proposal), encoding: .utf8).requireValue("Could not encode proposal")
        let update = PendingUpdate(
            id: "pending-\(UUID().uuidString)",
            sourceEntryID: sourceEntryID,
            proposalType: .memoryAtom,
            payloadJSON: payload,
            confidence: proposal.confidence,
            status: .pending,
            createdAt: timestamp
        )
        try insert(update)
        return update
    }

    @discardableResult
    public func createPersonProfilePatchProposal(
        sourceEntryID: String?,
        proposal: PersonProfilePatchProposal
    ) throws -> PendingUpdate {
        try AIContractValidator().validateProfilePatch(proposal)

        let timestamp = nowString()
        let payload = try String(data: encoder.encode(proposal), encoding: .utf8).requireValue("Could not encode proposal")
        let update = PendingUpdate(
            id: "pending-\(UUID().uuidString)",
            sourceEntryID: sourceEntryID,
            proposalType: .personProfilePatch,
            payloadJSON: payload,
            confidence: proposal.confidence,
            status: .pending,
            createdAt: timestamp
        )
        try insert(update)
        return update
    }

    public func listReviewable() throws -> [PendingUpdate] {
        try database.query(
            """
            SELECT id, source_entry_id, proposal_type, payload_json, confidence, status, created_at, decided_at, error_message
            FROM pending_updates
            WHERE status IN ('pending','edited','failed')
            ORDER BY created_at DESC
            """
        ) { statement in
            mapPendingUpdate(statement)
        }
    }

    public func fetch(id: String) throws -> PendingUpdate? {
        try database.query(
            """
            SELECT id, source_entry_id, proposal_type, payload_json, confidence, status, created_at, decided_at, error_message
            FROM pending_updates
            WHERE id = ?
            """,
            [id]
        ) { statement in
            mapPendingUpdate(statement)
        }.first
    }

    @discardableResult
    public func edit(
        id: String,
        title: String,
        summary: String,
        content: String
    ) throws -> PendingUpdate {
        guard let update = try fetch(id: id) else {
            throw PendingUpdateError.notFound
        }
        guard update.status == .pending || update.status == .edited else {
            throw PendingUpdateError.notReviewable
        }
        var proposal = try decoder.decode(MemoryAtomProposal.self, from: Data(update.payloadJSON.utf8))
        proposal.title = title
        proposal.summary = summary
        proposal.content = content
        let payload = try String(data: encoder.encode(proposal), encoding: .utf8).requireValue("Could not encode edited proposal")
        try database.execute(
            """
            UPDATE pending_updates
            SET payload_json = ?, confidence = ?, status = 'edited'
            WHERE id = ?
            """,
            [payload, String(proposal.confidence), id]
        )
        return try fetch(id: id).requireValue("Edited pending update not found")
    }

    @discardableResult
    public func approve(id: String) throws -> MemoryAtom {
        try database.withTransaction {
            guard let update = try fetch(id: id) else {
                throw PendingUpdateError.notFound
            }
            guard update.status == .pending || update.status == .edited else {
                throw PendingUpdateError.notReviewable
            }
            if update.proposalType == .personProfilePatch {
                return try approvePersonProfilePatch(update)
            }
            guard update.proposalType == .memoryAtom else {
                throw AIContractError.unsupportedProposalType(update.proposalType.rawValue)
            }
            let proposal = try decoder.decode(MemoryAtomProposal.self, from: Data(update.payloadJSON.utf8))
            guard !proposal.sourceQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIContractError.missingSourceQuote
            }

            let timestamp = nowString()
            let memoryID = "mem-\(UUID().uuidString)"
            try database.execute(
                """
                INSERT INTO memory_atoms
                (id, source_entry_id, type, title, summary, content, source_quote, confidence, sensitivity, is_ai_inferred, status, event_time, valid_until, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'confirmed', NULL, NULL, ?, ?)
                """,
                [
                    memoryID,
                    update.sourceEntryID,
                    proposal.memoryType.rawValue,
                    proposal.title,
                    proposal.summary,
                    proposal.content,
                    proposal.sourceQuote,
                    String(proposal.confidence),
                    proposal.sensitivity.rawValue,
                    proposal.isAIInferred ? "1" : "0",
                    timestamp,
                    timestamp
                ]
            )

            for theme in proposal.themes {
                let themeID = try upsertTheme(name: theme.name)
                try database.execute(
                    """
                    INSERT OR IGNORE INTO memory_theme_links (memory_id, theme_id, created_at)
                    VALUES (?, ?, ?)
                    """,
                    [memoryID, themeID, timestamp]
                )
            }

            for person in proposal.relatedPeople {
                guard let personID = person.matchedPersonID,
                      try database.scalarInt("SELECT COUNT(*) FROM people WHERE id = ?", [personID]) > 0 else {
                    continue
                }
                let relationType = ["about", "mentioned", "involves", "inferred"].contains(person.relationType)
                    ? person.relationType
                    : "mentioned"
                try database.execute(
                    """
                    INSERT OR IGNORE INTO memory_person_links (memory_id, person_id, relation_type, created_at)
                    VALUES (?, ?, ?, ?)
                    """,
                    [memoryID, personID, relationType, timestamp]
                )
            }

            try createRelationshipEdgesIfApproved(
                proposal: proposal,
                memoryID: memoryID,
                timestamp: timestamp
            )
            try createReminderIfApproved(
                proposal: proposal,
                memoryID: memoryID
            )

            try database.execute(
                "UPDATE pending_updates SET status = 'approved', decided_at = ? WHERE id = ?",
                [timestamp, id]
            )
            try database.execute(
                """
                INSERT INTO audit_events (id, event_type, subject_id, detail_json, created_at)
                VALUES (?, 'pending_update_approved', ?, ?, ?)
                """,
                ["audit-\(UUID().uuidString)", memoryID, "{\"pending_update_id\":\"\(id)\"}", timestamp]
            )

            guard let memory = try MemoryRepository(database: database).fetch(id: memoryID) else {
                throw PendingUpdateError.notFound
            }
            return memory
        }
    }

    private func approvePersonProfilePatch(_ update: PendingUpdate) throws -> MemoryAtom {
        let patch = try decoder.decode(PersonProfilePatchProposal.self, from: Data(update.payloadJSON.utf8))
        try AIContractValidator().validateProfilePatch(patch)
        let person = try database.applyProfilePatch(patch)
        let timestamp = nowString()
        let memoryID = "mem-\(UUID().uuidString)"
        let categoryTitle = patch.profileCategory.title(for: .zhCN)
        let title = "\(person.displayName) 的\(categoryTitle)"

        try database.execute(
            """
            INSERT INTO memory_atoms
            (id, source_entry_id, type, title, summary, content, source_quote, confidence, sensitivity, is_ai_inferred, status, event_time, valid_until, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'confirmed', NULL, NULL, ?, ?)
            """,
            [
                memoryID,
                update.sourceEntryID,
                MemoryAtomType.personFact.rawValue,
                title,
                patch.proposedValue,
                patch.proposedValue,
                patch.sourceQuote,
                String(patch.confidence),
                patch.sensitivity.rawValue,
                patch.isAIInferred ? "1" : "0",
                timestamp,
                timestamp
            ]
        )
        try database.execute(
            """
            INSERT OR IGNORE INTO memory_person_links (memory_id, person_id, relation_type, created_at)
            VALUES (?, ?, 'about', ?)
            """,
            [memoryID, person.id, timestamp]
        )
        let themeID = try upsertTheme(name: categoryTitle)
        try database.execute(
            """
            INSERT OR IGNORE INTO memory_theme_links (memory_id, theme_id, created_at)
            VALUES (?, ?, ?)
            """,
            [memoryID, themeID, timestamp]
        )
        try database.execute(
            "UPDATE pending_updates SET status = 'approved', decided_at = ? WHERE id = ?",
            [timestamp, update.id]
        )
        try database.execute(
            """
            INSERT INTO audit_events (id, event_type, subject_id, detail_json, created_at)
            VALUES (?, 'person_profile_patch_approved', ?, ?, ?)
            """,
            [
                "audit-\(UUID().uuidString)",
                person.id,
                "{\"pending_update_id\":\"\(update.id)\",\"memory_id\":\"\(memoryID)\",\"profile_category\":\"\(patch.profileCategory.rawValue)\"}",
                timestamp
            ]
        )

        guard let memory = try MemoryRepository(database: database).fetch(id: memoryID) else {
            throw PendingUpdateError.notFound
        }
        return memory
    }

    public func reject(id: String) throws {
        try database.execute(
            "UPDATE pending_updates SET status = 'rejected', decided_at = ? WHERE id = ?",
            [nowString(), id]
        )
    }

    private func insert(_ update: PendingUpdate) throws {
        try database.execute(
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

    private func upsertTheme(name: String) throws -> String {
        if let existing = try database.scalarString("SELECT id FROM themes WHERE name = ?", [name]) {
            return existing
        }

        let timestamp = nowString()
        let id = "theme-\(UUID().uuidString)"
        try database.execute(
            "INSERT INTO themes (id, name, description, created_at, updated_at) VALUES (?, ?, NULL, ?, ?)",
            [id, name, timestamp, timestamp]
        )
        return id
    }

    private func createRelationshipEdgesIfApproved(
        proposal: MemoryAtomProposal,
        memoryID: String,
        timestamp: String
    ) throws {
        guard proposal.memoryType == .relationshipMemory || proposal.memoryType == .personFact else {
            return
        }
        guard let edgeProposals = proposal.relationshipEdgeProposals, !edgeProposals.isEmpty else {
            return
        }

        let fallbackSourceID = proposal.relatedPeople.compactMap(\.matchedPersonID).first
        for edgeProposal in edgeProposals {
            guard !edgeProposal.sourceQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            let sourceID = edgeProposal.sourcePersonID ?? fallbackSourceID
            guard let sourceID,
                  try database.scalarInt("SELECT COUNT(*) FROM people WHERE id = ?", [sourceID]) > 0 else {
                continue
            }

            let sourceName = try database.scalarString("SELECT display_name FROM people WHERE id = ?", [sourceID]) ?? edgeProposal.sourceDisplayName
            let resolvedTarget = try resolvedTarget(for: edgeProposal)
            let edge = RelationshipEdge(
                id: "edge-\(UUID().uuidString)",
                sourceID: sourceID,
                sourceName: sourceName,
                targetID: resolvedTarget.id,
                targetName: resolvedTarget.name,
                label: edgeProposal.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "关系线索" : edgeProposal.label,
                strength: edgeProposal.strength,
                relationKind: edgeProposal.relationKind.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "friend" : edgeProposal.relationKind,
                sourceMemoryID: memoryID,
                confidence: edgeProposal.confidence,
                isAIInferred: edgeProposal.isAIInferred,
                tags: edgeProposal.tags,
                aiPrimaryTag: edgeProposal.aiPrimaryTag
            )
            try database.upsertRelationshipEdge(edge)
            try database.execute(
                """
                INSERT INTO audit_events (id, event_type, subject_id, detail_json, created_at)
                VALUES (?, 'relationship_edge_derived', ?, ?, ?)
                """,
                [
                    "audit-\(UUID().uuidString)",
                    edge.id,
                    try auditDetailJSON(sourceMemoryID: memoryID, sourceQuote: edgeProposal.sourceQuote),
                    timestamp
                ]
            )
        }
    }

    private func createReminderIfApproved(
        proposal: MemoryAtomProposal,
        memoryID: String
    ) throws {
        guard proposal.memoryType == .reminderSource || (proposal.memoryType == .event && proposal.hasScheduleSignals) else {
            return
        }

        let joined = [proposal.title, proposal.summary, proposal.content, proposal.sourceQuote].joined(separator: " ")
        let reminder = TransferReminder(
            id: "reminder-\(memoryID)",
            title: proposal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Memoria reminder" : proposal.title,
            personName: proposal.relatedPeople.first?.displayName ?? "Memoria",
            dueLabel: inferDueLabel(from: joined),
            dueDate: inferDueDate(from: joined),
            timeLabel: inferTimeLabel(from: joined),
            context: proposal.summary,
            location: ""
        )
        try database.upsertReminder(reminder)
    }

    private func inferDueLabel(from text: String) -> String {
        let normalized = text.lowercased()
        if normalized.contains("今天") || normalized.contains("today") {
            return "今天"
        }
        if normalized.contains("明天") || normalized.contains("tomorrow") {
            return "明天"
        }
        if normalized.contains("后天") {
            return "后天"
        }
        if normalized.contains("本周") || normalized.contains("这周") || normalized.contains("this week") {
            return "本周"
        }
        if normalized.contains("下周") || normalized.contains("next week") {
            return "下周"
        }
        if let date = inferDueDate(from: text) {
            return date
        }
        return "未定日期"
    }

    private func inferDueDate(from text: String) -> String? {
        if let date = firstRegexMatch(in: text, pattern: #"\d{4}-\d{2}-\d{2}"#) {
            return date
        }

        let normalized = text.lowercased()
        if normalized.contains("今天") || normalized.contains("today") {
            return memoriaDateOnlyString(daysFromNow: 0)
        }
        if normalized.contains("明天") || normalized.contains("tomorrow") {
            return memoriaDateOnlyString(daysFromNow: 1)
        }
        if normalized.contains("后天") {
            return memoriaDateOnlyString(daysFromNow: 2)
        }

        if let weekday = inferredWeekday(from: normalized) {
            return dateOnlyStringForNextWeekday(weekday)
        }

        return nil
    }

    private func inferTimeLabel(from text: String) -> String {
        if let time = firstRegexMatch(in: text, pattern: #"\b([01]?\d|2[0-3]):[0-5]\d\b"#) {
            return time
        }
        if let hour = firstRegexCapture(in: text, pattern: #"(\d{1,2})\s*(点|时)"#),
           let hourInt = Int(hour), (0...23).contains(hourInt) {
            return String(format: "%02d:00", hourInt)
        }
        return ""
    }

    private func inferredWeekday(from text: String) -> Int? {
        let pairs: [(String, Int)] = [
            ("周日", 1), ("星期日", 1), ("sunday", 1),
            ("周一", 2), ("星期一", 2), ("monday", 2),
            ("周二", 3), ("星期二", 3), ("tuesday", 3),
            ("周三", 4), ("星期三", 4), ("wednesday", 4),
            ("周四", 5), ("星期四", 5), ("thursday", 5),
            ("周五", 6), ("星期五", 6), ("friday", 6),
            ("周六", 7), ("星期六", 7), ("saturday", 7)
        ]
        return pairs.first { text.contains($0.0) }?.1
    }

    private func dateOnlyStringForNextWeekday(_ weekday: Int) -> String {
        let calendar = Calendar.current
        let today = Date()
        let todayWeekday = calendar.component(.weekday, from: today)
        let delta = (weekday - todayWeekday + 7) % 7
        let days = delta == 0 ? 7 : delta
        let date = calendar.date(byAdding: .day, value: days, to: today) ?? today
        return memoriaDateOnlyString(from: date)
    }

    private func firstRegexMatch(in text: String, pattern: String) -> String? {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func firstRegexCapture(in text: String, pattern: String) -> String? {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: nsRange),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func resolvedTarget(for proposal: RelationshipEdgeProposal) throws -> (id: String, name: String) {
        if let targetPersonID = proposal.targetPersonID,
           try database.scalarInt("SELECT COUNT(*) FROM people WHERE id = ?", [targetPersonID]) > 0 {
            let name = try database.scalarString("SELECT display_name FROM people WHERE id = ?", [targetPersonID]) ?? proposal.targetDisplayName
            return (targetPersonID, name)
        }

        let name = proposal.targetDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return ("external-\(UUID().uuidString)", name.isEmpty ? "Unknown" : name)
    }

    private func auditDetailJSON(sourceMemoryID: String, sourceQuote: String) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: [
                "source_memory_id": sourceMemoryID,
                "source_quote": sourceQuote
            ],
            options: [.sortedKeys]
        )
        return try String(data: data, encoding: .utf8).requireValue("Could not encode audit detail")
    }
}

public enum PendingUpdateError: LocalizedError {
    case notFound
    case notReviewable

    public var errorDescription: String? {
        switch self {
        case .notFound:
            "Pending update not found."
        case .notReviewable:
            "Pending update has already been decided."
        }
    }
}

func mapPendingUpdate(_ statement: OpaquePointer?) -> PendingUpdate {
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

private extension Optional where Wrapped == String {
    func requireValue(_ message: String) throws -> String {
        guard let self else {
            throw SQLiteStoreError.missingValue(message)
        }
        return self
    }
}

private extension Optional where Wrapped == PendingUpdate {
    func requireValue(_ message: String) throws -> PendingUpdate {
        guard let self else {
            throw PendingUpdateError.notFound
        }
        return self
    }
}
