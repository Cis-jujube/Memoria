import Foundation

public struct MemoriaTransferBundle: Codable, Sendable {
    public let schemaVersion: Int
    public let exportedAt: String
    public let appMetadata: [String: String]
    public let people: [TransferPerson]
    public let memoryAtoms: [TransferMemoryAtom]
    public let themes: [TransferTheme]
    public let memoryPersonLinks: [TransferMemoryPersonLink]
    public let memoryThemeLinks: [TransferMemoryThemeLink]
    public let relationshipEdges: [TransferRelationshipEdge]
    public let relationshipTagPriorities: [TransferRelationshipTagPriority]
    public let reminders: [TransferReminder]
    public let gifts: [TransferGift]
    public let files: [TransferFile]

    public init(
        schemaVersion: Int = 1,
        exportedAt: String = memoriaTimestamp(),
        appMetadata: [String: String] = [:],
        people: [TransferPerson],
        memoryAtoms: [TransferMemoryAtom],
        themes: [TransferTheme],
        memoryPersonLinks: [TransferMemoryPersonLink],
        memoryThemeLinks: [TransferMemoryThemeLink],
        relationshipEdges: [TransferRelationshipEdge],
        relationshipTagPriorities: [TransferRelationshipTagPriority],
        reminders: [TransferReminder],
        gifts: [TransferGift],
        files: [TransferFile]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.appMetadata = appMetadata
        self.people = people
        self.memoryAtoms = memoryAtoms
        self.themes = themes
        self.memoryPersonLinks = memoryPersonLinks
        self.memoryThemeLinks = memoryThemeLinks
        self.relationshipEdges = relationshipEdges
        self.relationshipTagPriorities = relationshipTagPriorities
        self.reminders = reminders
        self.gifts = gifts
        self.files = files
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case exportedAt = "exported_at"
        case appMetadata = "app_metadata"
        case people
        case memoryAtoms = "memory_atoms"
        case themes
        case memoryPersonLinks = "memory_person_links"
        case memoryThemeLinks = "memory_theme_links"
        case relationshipEdges = "relationship_edges"
        case relationshipTagPriorities = "relationship_tag_priorities"
        case reminders
        case gifts
        case files
    }
}

public struct TransferImportPreview: Identifiable, Sendable {
    public let id = UUID()
    public let filename: String
    public let bundle: MemoriaTransferBundle
    public let profilePatchProposals: [PersonProfilePatchProposal]
    public let peopleToCreate: Int
    public let peopleToUpdate: Int
    public let potentialDuplicateNames: [String]
    public let memoriesToCreate: Int
    public let memoriesToUpdate: Int
    public let themesToCreate: Int
    public let relationshipEdgesToCreate: Int
    public let relationshipEdgesToUpdate: Int

    public var totalChanges: Int {
        peopleToCreate + peopleToUpdate + profilePatchesToReview + memoriesToCreate + memoriesToUpdate + themesToCreate + relationshipEdgesToCreate + relationshipEdgesToUpdate
    }

    public var profilePatchesToReview: Int {
        profilePatchProposals.count
    }

    public init(
        filename: String,
        bundle: MemoriaTransferBundle,
        profilePatchProposals: [PersonProfilePatchProposal] = [],
        peopleToCreate: Int,
        peopleToUpdate: Int,
        potentialDuplicateNames: [String],
        memoriesToCreate: Int,
        memoriesToUpdate: Int,
        themesToCreate: Int,
        relationshipEdgesToCreate: Int,
        relationshipEdgesToUpdate: Int
    ) {
        self.filename = filename
        self.bundle = bundle
        self.profilePatchProposals = profilePatchProposals
        self.peopleToCreate = peopleToCreate
        self.peopleToUpdate = peopleToUpdate
        self.potentialDuplicateNames = potentialDuplicateNames
        self.memoriesToCreate = memoriesToCreate
        self.memoriesToUpdate = memoriesToUpdate
        self.themesToCreate = themesToCreate
        self.relationshipEdgesToCreate = relationshipEdgesToCreate
        self.relationshipEdgesToUpdate = relationshipEdgesToUpdate
    }
}

public struct TransferPerson: Codable, Sendable {
    public let id: String
    public let displayName: String
    public let nickname: String
    public let englishName: String
    public let relationLabel: String
    public let groupLabel: String
    public let groupLabels: [String]
    public let location: String
    public let hometown: String
    public let languages: String
    public let contactInfo: String
    public let birthday: String
    public let dietaryRestrictions: String
    public let favoriteFoods: String
    public let dislikedThings: String
    public let zodiacSign: String
    public let mbti: String
    public let interests: String
    public let books: String
    public let sports: String
    public let profileTags: String
    public let lastSignal: String
    public let initials: String
    public let school: String
    public let major: String
    public let company: String
    public let roleTitle: String
    public let researchExperience: String
    public let internshipExperience: String
    public let familyNotes: String
    public let partnerName: String
    public let manualClosenessLevel: Int
    public let closenessSignals: String
    public let categoryNotes: [String: String]

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case nickname
        case englishName = "english_name"
        case relationLabel = "relation_label"
        case groupLabel = "group_label"
        case groupLabels = "group_labels"
        case location
        case hometown
        case languages
        case contactInfo = "contact_info"
        case birthday
        case dietaryRestrictions = "dietary_restrictions"
        case favoriteFoods = "favorite_foods"
        case dislikedThings = "disliked_things"
        case zodiacSign = "zodiac_sign"
        case mbti
        case interests
        case books
        case sports
        case profileTags = "profile_tags"
        case lastSignal = "last_signal"
        case initials
        case school
        case major
        case company
        case roleTitle = "role_title"
        case researchExperience = "research_experience"
        case internshipExperience = "internship_experience"
        case familyNotes = "family_notes"
        case partnerName = "partner_name"
        case manualClosenessLevel = "manual_closeness_level"
        case closenessSignals = "closeness_signals"
        case categoryNotes = "category_notes"
    }
}

public struct TransferMemoryAtom: Codable, Sendable {
    public let id: String
    public let sourceEntryID: String?
    public let type: String
    public let title: String
    public let summary: String
    public let content: String
    public let sourceQuote: String?
    public let confidence: Double
    public let sensitivity: String
    public let isAIInferred: Bool
    public let status: String
    public let eventTime: String?
    public let validUntil: String?
    public let createdAt: String
    public let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case sourceEntryID = "source_entry_id"
        case type
        case title
        case summary
        case content
        case sourceQuote = "source_quote"
        case confidence
        case sensitivity
        case isAIInferred = "is_ai_inferred"
        case status
        case eventTime = "event_time"
        case validUntil = "valid_until"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct TransferTheme: Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let createdAt: String
    public let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct TransferMemoryPersonLink: Codable, Sendable {
    public let memoryID: String
    public let personID: String
    public let relationType: String

    enum CodingKeys: String, CodingKey {
        case memoryID = "memory_id"
        case personID = "person_id"
        case relationType = "relation_type"
    }
}

public struct TransferMemoryThemeLink: Codable, Sendable {
    public let memoryID: String
    public let themeName: String

    enum CodingKeys: String, CodingKey {
        case memoryID = "memory_id"
        case themeName = "theme_name"
    }
}

public struct TransferRelationshipEdge: Codable, Sendable {
    public let id: String
    public let sourceID: String
    public let sourceName: String
    public let targetID: String
    public let targetName: String
    public let label: String
    public let strength: Double
    public let relationKind: String
    public let sourceMemoryID: String?
    public let confidence: Double
    public let isAIInferred: Bool
    public let tags: [String]
    public let aiPrimaryTag: String?
    public let manualPrimaryTag: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sourceID = "source_id"
        case sourceName = "source_name"
        case targetID = "target_id"
        case targetName = "target_name"
        case label
        case strength
        case relationKind = "relation_kind"
        case sourceMemoryID = "source_memory_id"
        case confidence
        case isAIInferred = "is_ai_inferred"
        case tags
        case aiPrimaryTag = "ai_primary_tag"
        case manualPrimaryTag = "manual_primary_tag"
    }
}

public struct TransferRelationshipTagPriority: Codable, Sendable {
    public let tag: String
    public let rank: Int
    public let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case tag
        case rank
        case updatedAt = "updated_at"
    }
}

public struct TransferReminder: Codable, Sendable {
    public let id: String
    public let title: String
    public let personName: String
    public let dueLabel: String
    public let dueDate: String?
    public let timeLabel: String
    public let context: String
    public let location: String

    public init(
        id: String,
        title: String,
        personName: String,
        dueLabel: String,
        dueDate: String? = nil,
        timeLabel: String,
        context: String,
        location: String
    ) {
        self.id = id
        self.title = title
        self.personName = personName
        self.dueLabel = dueLabel
        self.dueDate = dueDate
        self.timeLabel = timeLabel
        self.context = context
        self.location = location
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case personName = "person_name"
        case dueLabel = "due_label"
        case dueDate = "due_date"
        case timeLabel = "time_label"
        case context
        case location
    }
}

public struct TransferGift: Codable, Sendable {
    public let id: String
    public let title: String
    public let personName: String
    public let priceBand: String
    public let rationale: String
    public let risk: String
    public let confirmationQuestion: String
    public let matchScore: Int
    public let surpriseScore: Int
    public let riskLevel: String
    public let practicality: String
    public let emotionalValue: String
    public let needsMoreInfo: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case personName = "person_name"
        case priceBand = "price_band"
        case rationale
        case risk
        case confirmationQuestion = "confirmation_question"
        case matchScore = "match_score"
        case surpriseScore = "surprise_score"
        case riskLevel = "risk_level"
        case practicality
        case emotionalValue = "emotional_value"
        case needsMoreInfo = "needs_more_info"
    }
}

public struct TransferFile: Codable, Sendable {
    public let id: String
    public let filename: String
    public let status: String
    public let progress: Double
}

public extension TransferPerson {
    init(person: FriendPerson) {
        self.init(
            id: person.id,
            displayName: person.displayName,
            nickname: person.nickname,
            englishName: person.englishName,
            relationLabel: person.relationLabel,
            groupLabel: person.groupLabel.rawValue,
            groupLabels: person.groupLabels.map(\.rawValue),
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
            lastSignal: person.lastSignal,
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
            categoryNotes: Dictionary(uniqueKeysWithValues: person.categoryNotes.map { ($0.key.rawValue, $0.value) })
        )
    }

    var friendPerson: FriendPerson {
        let primaryGroup = GroupFilter(rawValue: groupLabel) ?? .classmates
        let groups = groupLabels.compactMap(GroupFilter.init(rawValue:))
        let notes = categoryNotes.reduce(into: [PersonProfileCategory: String]()) { result, pair in
            guard let category = PersonProfileCategory(rawValue: pair.key) else { return }
            result[category] = pair.value
        }
        return FriendPerson(
            id: id,
            displayName: displayName,
            nickname: nickname,
            englishName: englishName,
            relationLabel: relationLabel,
            groupLabel: primaryGroup,
            groupLabels: groups.isEmpty ? [primaryGroup] : groups,
            location: location,
            hometown: hometown,
            languages: languages,
            contactInfo: contactInfo,
            birthday: birthday,
            dietaryRestrictions: dietaryRestrictions,
            favoriteFoods: favoriteFoods,
            dislikedThings: dislikedThings,
            zodiacSign: zodiacSign,
            mbti: mbti,
            interests: interests,
            books: books,
            sports: sports,
            profileTags: profileTags,
            lastSignal: lastSignal,
            initials: initials,
            school: school,
            major: major,
            company: company,
            roleTitle: roleTitle,
            researchExperience: researchExperience,
            internshipExperience: internshipExperience,
            familyNotes: familyNotes,
            partnerName: partnerName,
            manualClosenessLevel: manualClosenessLevel,
            closenessSignals: closenessSignals,
            categoryNotes: notes
        )
    }
}

public extension TransferMemoryAtom {
    init(memory: MemoryAtom) {
        self.init(
            id: memory.id,
            sourceEntryID: memory.sourceEntryID,
            type: memory.type.rawValue,
            title: memory.title,
            summary: memory.summary,
            content: memory.content,
            sourceQuote: memory.sourceQuote,
            confidence: memory.confidence,
            sensitivity: memory.sensitivity.rawValue,
            isAIInferred: memory.isAIInferred,
            status: memory.status.rawValue,
            eventTime: memory.eventTime,
            validUntil: memory.validUntil,
            createdAt: memory.createdAt,
            updatedAt: memory.updatedAt
        )
    }
}

public extension TransferTheme {
    init(theme: Theme) {
        self.init(
            id: theme.id,
            name: theme.name,
            description: theme.description,
            createdAt: theme.createdAt,
            updatedAt: theme.updatedAt
        )
    }
}

public extension TransferRelationshipEdge {
    init(edge: RelationshipEdge) {
        self.init(
            id: edge.id,
            sourceID: edge.sourceID,
            sourceName: edge.sourceName,
            targetID: edge.targetID,
            targetName: edge.targetName,
            label: edge.label,
            strength: edge.strength,
            relationKind: edge.relationKind,
            sourceMemoryID: edge.sourceMemoryID,
            confidence: edge.confidence,
            isAIInferred: edge.isAIInferred,
            tags: edge.tags,
            aiPrimaryTag: edge.aiPrimaryTag,
            manualPrimaryTag: edge.manualPrimaryTag
        )
    }

    var relationshipEdge: RelationshipEdge {
        RelationshipEdge(
            id: id,
            sourceID: sourceID,
            sourceName: sourceName,
            targetID: targetID,
            targetName: targetName,
            label: label,
            strength: strength,
            relationKind: relationKind,
            sourceMemoryID: sourceMemoryID,
            confidence: confidence,
            isAIInferred: isAIInferred,
            tags: tags,
            aiPrimaryTag: aiPrimaryTag,
            manualPrimaryTag: manualPrimaryTag
        )
    }
}

public extension TransferRelationshipTagPriority {
    init(priority: RelationshipTagPriority) {
        self.init(tag: priority.tag, rank: priority.rank, updatedAt: priority.updatedAt)
    }

    var relationshipTagPriority: RelationshipTagPriority {
        RelationshipTagPriority(tag: tag, rank: rank, updatedAt: updatedAt)
    }
}

public extension TransferReminder {
    init(reminder: ReminderItem) {
        self.init(
            id: reminder.id,
            title: reminder.title,
            personName: reminder.personName,
            dueLabel: reminder.dueLabel,
            dueDate: reminder.dueDate,
            timeLabel: reminder.timeLabel,
            context: reminder.context,
            location: reminder.location
        )
    }
}

public extension TransferGift {
    init(gift: GiftIdea) {
        self.init(
            id: gift.id,
            title: gift.title,
            personName: gift.personName,
            priceBand: gift.priceBand,
            rationale: gift.rationale,
            risk: gift.risk,
            confirmationQuestion: gift.confirmationQuestion,
            matchScore: gift.matchScore,
            surpriseScore: gift.surpriseScore,
            riskLevel: gift.riskLevel,
            practicality: gift.practicality,
            emotionalValue: gift.emotionalValue,
            needsMoreInfo: gift.needsMoreInfo
        )
    }

    var giftIdea: GiftIdea {
        GiftIdea(
            id: id,
            title: title,
            personName: personName,
            priceBand: priceBand,
            rationale: rationale,
            risk: risk,
            confirmationQuestion: confirmationQuestion,
            matchScore: matchScore,
            surpriseScore: surpriseScore,
            riskLevel: riskLevel,
            practicality: practicality,
            emotionalValue: emotionalValue,
            needsMoreInfo: needsMoreInfo
        )
    }
}

public extension TransferFile {
    init(file: ImportedFile) {
        self.init(id: file.id, filename: file.filename, status: file.status, progress: file.progress)
    }
}
