import Foundation

public struct BulkFriendImportParseResult: Sendable {
    public let bundle: MemoriaTransferBundle
    public let profilePatchProposals: [PersonProfilePatchProposal]
}

public enum BulkFriendImportError: LocalizedError, Equatable {
    case emptyInput
    case missingDisplayName

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Import text is empty."
        case .missingDisplayName:
            return "Every imported friend row needs a display_name."
        }
    }
}

public struct BulkFriendImportParser: Sendable {
    public init() {}

    public func parse(
        text: String,
        filename: String,
        existingPeople: [FriendPerson]
    ) throws -> BulkFriendImportParseResult {
        let rows = try parseRows(text)
        let people = try rows.map { row in
            try transferPerson(from: row, existingPeople: existingPeople)
        }
        let patches = rows.flatMap { row in
            profilePatches(from: row, existingPeople: existingPeople)
        }

        let bundle = MemoriaTransferBundle(
            appMetadata: [
                "source": filename,
                "import_type": "bulk_friend_csv"
            ],
            people: people,
            memoryAtoms: [],
            themes: [],
            memoryPersonLinks: [],
            memoryThemeLinks: [],
            relationshipEdges: [],
            relationshipTagPriorities: [],
            reminders: [],
            gifts: [],
            files: []
        )
        return BulkFriendImportParseResult(bundle: bundle, profilePatchProposals: patches)
    }

    private func parseRows(_ text: String) throws -> [[String: String]] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BulkFriendImportError.emptyInput }

        let lines = trimmed
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let first = lines.first else { throw BulkFriendImportError.emptyInput }

        if first.localizedCaseInsensitiveContains("display_name") || first.localizedCaseInsensitiveContains("name,") {
            let headers = parseCSVLine(first).map(normalizeHeader)
            return try lines.dropFirst().map { line in
                let values = parseCSVLine(line)
                let row = Dictionary(uniqueKeysWithValues: headers.enumerated().map { index, header in
                    (header, index < values.count ? values[index].trimmingCharacters(in: .whitespacesAndNewlines) : "")
                })
                guard !(row["display_name"] ?? "").isEmpty else { throw BulkFriendImportError.missingDisplayName }
                return row
            }
        }

        return try lines.map { line in
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard let name = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                throw BulkFriendImportError.missingDisplayName
            }
            return [
                "display_name": name,
                "notes": parts.dropFirst().first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            ]
        }
    }

    private func transferPerson(from row: [String: String], existingPeople: [FriendPerson]) throws -> TransferPerson {
        guard let displayName = row["display_name"]?.trimmingCharacters(in: .whitespacesAndNewlines), !displayName.isEmpty else {
            throw BulkFriendImportError.missingDisplayName
        }
        if let existing = resolveExistingPerson(row: row, existingPeople: existingPeople) {
            return TransferPerson(person: existing)
        }

        let group = parseGroup(row["group"])
        let person = FriendPerson(
            id: "import-\(stableImportIdentifier(displayName))",
            displayName: displayName,
            nickname: row["nickname"] ?? "",
            englishName: row["english_name"] ?? "",
            relationLabel: row["relation_label"]?.nilIfBlank ?? "Imported friend",
            groupLabel: group,
            location: row["location"] ?? "",
            contactInfo: row["contact"] ?? "",
            birthday: row["birthday"] ?? "",
            dietaryRestrictions: row["dietary_allergy"] ?? "",
            favoriteFoods: row["food_preference"] ?? "",
            dislikedThings: "",
            zodiacSign: "",
            mbti: "",
            interests: row["interests"] ?? "",
            books: "",
            sports: "",
            profileTags: row["notes"] ?? "",
            lastSignal: row["notes"]?.nilIfBlank ?? "Imported from bulk friend list",
            initials: initials(for: displayName),
            categoryNotes: [:]
        )
        return TransferPerson(person: person)
    }

    private func profilePatches(from row: [String: String], existingPeople: [FriendPerson]) -> [PersonProfilePatchProposal] {
        guard let displayName = row["display_name"]?.trimmingCharacters(in: .whitespacesAndNewlines), !displayName.isEmpty else {
            return []
        }
        let existing = resolveExistingPerson(row: row, existingPeople: existingPeople)
        let personID = existing?.id ?? "import-\(stableImportIdentifier(displayName))"
        let sourceQuote = sourceQuote(for: row)
        let fields: [(String, PersonProfileCategory)] = [
            ("contact", .contact),
            ("birthday", .anniversaries),
            ("food_preference", .foodPreference),
            ("dietary_allergy", .dietaryAllergy),
            ("interests", .interests),
            ("notes", .currentState)
        ]

        return fields.compactMap { key, category in
            guard let value = row[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return nil
            }
            return PersonProfilePatchProposal(
                targetPersonID: personID,
                targetDisplayName: displayName,
                profileCategory: category,
                proposedValue: value,
                sourceQuote: sourceQuote,
                confidence: 0.82,
                sensitivity: .normal,
                isAIInferred: false
            )
        }
    }

    private func resolveExistingPerson(row: [String: String], existingPeople: [FriendPerson]) -> FriendPerson? {
        let candidates = [
            row["display_name"],
            row["nickname"],
            row["english_name"],
            row["contact"]
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .map(normalizeIdentity)

        return existingPeople.first { person in
            let existingValues = [
                person.displayName,
                person.nickname,
                person.englishName,
                person.contactInfo
            ]
            .filter { !$0.isEmpty }
            .map(normalizeIdentity)
            return existingValues.contains { candidates.contains($0) }
        }
    }

    private func parseGroup(_ rawValue: String?) -> GroupFilter {
        let normalized = normalizeIdentity(rawValue ?? "")
        switch normalized {
        case "classmates", "classmate", "同学":
            return .classmates
        case "studyabroad", "exchange", "交换", "海外":
            return .studyAbroad
        case "homefriends", "oldfriends", "老朋友":
            return .homeFriends
        case "internship", "career", "实习", "职业":
            return .internship
        default:
            return .classmates
        }
    }
}

private func parseCSVLine(_ line: String) -> [String] {
    var values: [String] = []
    var current = ""
    var insideQuotes = false
    var iterator = line.makeIterator()
    while let character = iterator.next() {
        if character == "\"" {
            insideQuotes.toggle()
        } else if character == "," && !insideQuotes {
            values.append(current)
            current = ""
        } else {
            current.append(character)
        }
    }
    values.append(current)
    return values
}

private func normalizeHeader(_ header: String) -> String {
    let normalized = header.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch normalized {
    case "name", "姓名", "名字":
        return "display_name"
    case "phone", "wechat", "微信", "联系方式":
        return "contact"
    case "birthday", "生日":
        return "birthday"
    case "food", "favorite_foods", "喜欢吃":
        return "food_preference"
    case "allergy", "dietary_restrictions", "不吃", "忌口":
        return "dietary_allergy"
    case "interest", "兴趣":
        return "interests"
    case "note", "备注":
        return "notes"
    default:
        return normalized
    }
}

private func normalizeIdentity(_ value: String) -> String {
    value
        .lowercased()
        .filter { $0.isLetter || $0.isNumber }
}

private func stableImportIdentifier(_ value: String) -> String {
    let normalized = normalizeIdentity(value)
    return normalized.isEmpty ? UUID().uuidString.lowercased() : normalized
}

private func initials(for displayName: String) -> String {
    let parts = displayName.split(separator: " ")
    let initials = parts.prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
    return initials.isEmpty ? String(displayName.prefix(2)).uppercased() : initials
}

private func sourceQuote(for row: [String: String]) -> String {
    row.sorted { $0.key < $1.key }
        .filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .map { "\($0.key)=\($0.value)" }
        .joined(separator: ", ")
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
