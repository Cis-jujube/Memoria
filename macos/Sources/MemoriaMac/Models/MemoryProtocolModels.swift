import Foundation

public enum RawEntryInputType: String, Codable, CaseIterable, Sendable {
    case text
    case voiceTranscript = "voice_transcript"
    case file
    case manual
    case importedClip = "imported_clip"
}

public struct RawEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let inputType: RawEntryInputType
    public let rawText: String
    public let sourceFileID: String?
    public let createdAt: String
    public let updatedAt: String

    public init(
        id: String,
        inputType: RawEntryInputType,
        rawText: String,
        sourceFileID: String?,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.inputType = inputType
        self.rawText = rawText
        self.sourceFileID = sourceFileID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum MemoryAtomType: String, Codable, CaseIterable, Sendable {
    case personalReflection = "personal_reflection"
    case idea
    case relationshipMemory = "relationship_memory"
    case personFact = "person_fact"
    case event
    case reminderSource = "reminder_source"
    case giftSignal = "gift_signal"
    case fileNote = "file_note"

    public var displayName: String {
        switch self {
        case .personalReflection:
            "Reflection"
        case .idea:
            "Idea"
        case .relationshipMemory:
            "Relationship"
        case .personFact:
            "Person Fact"
        case .event:
            "Event"
        case .reminderSource:
            "Reminder"
        case .giftSignal:
            "Gift Signal"
        case .fileNote:
            "File Note"
        }
    }

    public func displayName(for language: LanguagePreference) -> String {
        guard resolvedLanguage(language) == .zhCN else {
            return displayName
        }

        switch self {
        case .personalReflection:
            return "自我想法"
        case .idea:
            return "想法/灵感"
        case .relationshipMemory:
            return "关系记忆"
        case .personFact:
            return "朋友事实"
        case .event:
            return "人生事件"
        case .reminderSource:
            return "提醒线索"
        case .giftSignal:
            return "礼物线索"
        case .fileNote:
            return "文件备注"
        }
    }
}

public enum MemorySensitivity: String, Codable, CaseIterable, Sendable {
    case normal
    case `private`
    case sensitive
}

public enum MemoryAtomStatus: String, Codable, CaseIterable, Sendable {
    case confirmed
    case archived
    case disputed
}

public struct MemoryAtom: Identifiable, Equatable, Sendable {
    public let id: String
    public let sourceEntryID: String?
    public let type: MemoryAtomType
    public let title: String
    public let summary: String
    public let content: String
    public let sourceQuote: String?
    public let confidence: Double
    public let sensitivity: MemorySensitivity
    public let isAIInferred: Bool
    public let status: MemoryAtomStatus
    public let eventTime: String?
    public let validUntil: String?
    public let createdAt: String
    public let updatedAt: String
}

public enum PendingUpdateStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case approved
    case edited
    case rejected
    case failed
}

public enum PendingProposalType: String, Codable, CaseIterable, Sendable {
    case memoryAtom = "memory_atom"
    case personProfilePatch = "person_profile_patch"
}

public struct Theme: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let createdAt: String
    public let updatedAt: String

    public init(id: String, name: String, description: String?, createdAt: String, updatedAt: String) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct RelatedPersonProposal: Codable, Equatable, Sendable {
    public let displayName: String
    public let matchedPersonID: String?
    public let matchConfidence: Double
    public let relationType: String

    public init(
        displayName: String,
        matchedPersonID: String?,
        matchConfidence: Double,
        relationType: String
    ) {
        self.displayName = displayName
        self.matchedPersonID = matchedPersonID
        self.matchConfidence = min(max(matchConfidence, 0), 1)
        self.relationType = relationType
    }

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case matchedPersonID = "matched_person_id"
        case matchConfidence = "match_confidence"
        case relationType = "relation_type"
    }
}

public struct ThemeProposal: Codable, Equatable, Sendable {
    public let name: String
    public let confidence: Double

    public init(name: String, confidence: Double) {
        self.name = name
        self.confidence = min(max(confidence, 0), 1)
    }
}

public struct RelationshipEdgeProposal: Codable, Equatable, Sendable {
    public let sourcePersonID: String?
    public let sourceDisplayName: String
    public let targetPersonID: String?
    public let targetDisplayName: String
    public let label: String
    public let strength: Double
    public let relationKind: String
    public let tags: [String]
    public let aiPrimaryTag: String?
    public let confidence: Double
    public let isAIInferred: Bool
    public let sourceQuote: String

    public init(
        sourcePersonID: String?,
        sourceDisplayName: String,
        targetPersonID: String?,
        targetDisplayName: String,
        label: String,
        strength: Double,
        relationKind: String,
        tags: [String] = [],
        aiPrimaryTag: String? = nil,
        confidence: Double,
        isAIInferred: Bool = true,
        sourceQuote: String
    ) {
        self.sourcePersonID = sourcePersonID
        self.sourceDisplayName = sourceDisplayName
        self.targetPersonID = targetPersonID
        self.targetDisplayName = targetDisplayName
        self.label = label
        self.strength = min(max(strength, 0), 1)
        self.relationKind = relationKind
        self.tags = tags
        self.aiPrimaryTag = aiPrimaryTag
        self.confidence = min(max(confidence, 0), 1)
        self.isAIInferred = isAIInferred
        self.sourceQuote = sourceQuote
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourcePersonID = try container.decodeIfPresent(String.self, forKey: .sourcePersonID)
        sourceDisplayName = try container.decode(String.self, forKey: .sourceDisplayName)
        targetPersonID = try container.decodeIfPresent(String.self, forKey: .targetPersonID)
        targetDisplayName = try container.decode(String.self, forKey: .targetDisplayName)
        label = try container.decode(String.self, forKey: .label)
        strength = min(max(try container.decode(Double.self, forKey: .strength), 0), 1)
        relationKind = try container.decode(String.self, forKey: .relationKind)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        aiPrimaryTag = try container.decodeIfPresent(String.self, forKey: .aiPrimaryTag)
        confidence = min(max(try container.decode(Double.self, forKey: .confidence), 0), 1)
        isAIInferred = try container.decodeIfPresent(Bool.self, forKey: .isAIInferred) ?? true
        sourceQuote = try container.decode(String.self, forKey: .sourceQuote)
    }

    enum CodingKeys: String, CodingKey {
        case sourcePersonID = "source_person_id"
        case sourceDisplayName = "source_display_name"
        case targetPersonID = "target_person_id"
        case targetDisplayName = "target_display_name"
        case label
        case strength
        case relationKind = "relation_kind"
        case tags
        case aiPrimaryTag = "ai_primary_tag"
        case confidence
        case isAIInferred = "is_ai_inferred"
        case sourceQuote = "source_quote"
    }
}

public struct MemoryAtomProposal: Codable, Equatable, Sendable {
    public let proposalType: PendingProposalType
    public var memoryType: MemoryAtomType
    public var title: String
    public var summary: String
    public var content: String
    public var sourceQuote: String
    public var confidence: Double
    public var sensitivity: MemorySensitivity
    public var isAIInferred: Bool
    public var relatedPeople: [RelatedPersonProposal]
    public var themes: [ThemeProposal]
    public var relationshipEdgeProposals: [RelationshipEdgeProposal]? = nil
    public var followUpQuestions: [String]
    public var suggestedActions: [String]

    public init(
        proposalType: PendingProposalType,
        memoryType: MemoryAtomType,
        title: String,
        summary: String,
        content: String,
        sourceQuote: String,
        confidence: Double,
        sensitivity: MemorySensitivity,
        isAIInferred: Bool,
        relatedPeople: [RelatedPersonProposal],
        themes: [ThemeProposal],
        relationshipEdgeProposals: [RelationshipEdgeProposal]? = nil,
        followUpQuestions: [String],
        suggestedActions: [String]
    ) {
        self.proposalType = proposalType
        self.memoryType = memoryType
        self.title = title
        self.summary = summary
        self.content = content
        self.sourceQuote = sourceQuote
        self.confidence = min(max(confidence, 0), 1)
        self.sensitivity = sensitivity
        self.isAIInferred = isAIInferred
        self.relatedPeople = relatedPeople
        self.themes = themes
        self.relationshipEdgeProposals = relationshipEdgeProposals
        self.followUpQuestions = followUpQuestions
        self.suggestedActions = suggestedActions
    }

    enum CodingKeys: String, CodingKey {
        case proposalType = "proposal_type"
        case memoryType = "memory_type"
        case title
        case summary
        case content
        case sourceQuote = "source_quote"
        case confidence
        case sensitivity
        case isAIInferred = "is_ai_inferred"
        case relatedPeople = "related_people"
        case themes
        case relationshipEdgeProposals = "relationship_edge_proposals"
        case followUpQuestions = "follow_up_questions"
        case suggestedActions = "suggested_actions"
    }
}

public enum ProfilePatchMergeStrategy: String, Codable, CaseIterable, Sendable {
    case appendUnique = "append_unique"
}

public struct PersonProfilePatchProposal: Codable, Equatable, Sendable {
    public let targetPersonID: String?
    public let targetDisplayName: String
    public let profileCategory: PersonProfileCategory
    public let proposedValue: String
    public let sourceQuote: String
    public let confidence: Double
    public let sensitivity: MemorySensitivity
    public let isAIInferred: Bool
    public let mergeStrategy: ProfilePatchMergeStrategy

    public init(
        targetPersonID: String?,
        targetDisplayName: String,
        profileCategory: PersonProfileCategory,
        proposedValue: String,
        sourceQuote: String,
        confidence: Double,
        sensitivity: MemorySensitivity,
        isAIInferred: Bool,
        mergeStrategy: ProfilePatchMergeStrategy = .appendUnique
    ) {
        self.targetPersonID = targetPersonID
        self.targetDisplayName = targetDisplayName
        self.profileCategory = profileCategory
        self.proposedValue = proposedValue
        self.sourceQuote = sourceQuote
        self.confidence = min(max(confidence, 0), 1)
        self.sensitivity = sensitivity
        self.isAIInferred = isAIInferred
        self.mergeStrategy = mergeStrategy
    }

    enum CodingKeys: String, CodingKey {
        case targetPersonID = "target_person_id"
        case targetDisplayName = "target_display_name"
        case profileCategory = "profile_category"
        case proposedValue = "proposed_value"
        case sourceQuote = "source_quote"
        case confidence
        case sensitivity
        case isAIInferred = "is_ai_inferred"
        case mergeStrategy = "merge_strategy"
    }
}

public struct ExtractMemoryResponse: Codable, Equatable, Sendable {
    public let entrySummary: String
    public let memoryProposals: [MemoryAtomProposal]
    public let personFactProposals: [PersonProfilePatchProposal]
    public let reminderProposals: [String]
    public let giftSignalProposals: [String]
    public let conflicts: [String]
    public let followUpQuestions: [String]

    enum CodingKeys: String, CodingKey {
        case entrySummary = "entry_summary"
        case memoryProposals = "memory_proposals"
        case personFactProposals = "person_fact_proposals"
        case reminderProposals = "reminder_proposals"
        case giftSignalProposals = "gift_signal_proposals"
        case conflicts
        case followUpQuestions = "follow_up_questions"
    }
}

public enum AIContractError: LocalizedError, Equatable {
    case invalidJSON
    case missingSourceQuote
    case invalidProfilePatch
    case unsupportedProposalType(String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            "AI returned invalid JSON."
        case .missingSourceQuote:
            "AI proposal is missing a source quote."
        case .invalidProfilePatch:
            "AI profile patch is missing a target person or proposed value."
        case .unsupportedProposalType(let type):
            "Unsupported proposal type: \(type)."
        }
    }
}
