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
    public var classification: PendingUpdateClassificationContext?

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
        suggestedActions: [String],
        classification: PendingUpdateClassificationContext? = nil
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
        self.classification = classification
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
        case classification
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
    public let valueStruct: ProfileValueStruct?
    public let sourceQuote: String
    public let confidence: Double
    public let sensitivity: MemorySensitivity
    public let isAIInferred: Bool
    public let mergeStrategy: ProfilePatchMergeStrategy
    public let classification: PendingUpdateClassificationContext?

    public init(
        targetPersonID: String?,
        targetDisplayName: String,
        profileCategory: PersonProfileCategory,
        proposedValue: String,
        valueStruct: ProfileValueStruct? = nil,
        sourceQuote: String,
        confidence: Double,
        sensitivity: MemorySensitivity,
        isAIInferred: Bool,
        mergeStrategy: ProfilePatchMergeStrategy = .appendUnique,
        classification: PendingUpdateClassificationContext? = nil
    ) {
        self.targetPersonID = targetPersonID
        self.targetDisplayName = targetDisplayName
        self.profileCategory = profileCategory
        self.proposedValue = proposedValue
        self.valueStruct = valueStruct
        self.sourceQuote = sourceQuote
        self.confidence = min(max(confidence, 0), 1)
        self.sensitivity = sensitivity
        self.isAIInferred = isAIInferred
        self.mergeStrategy = mergeStrategy
        self.classification = classification
    }

    enum CodingKeys: String, CodingKey {
        case targetPersonID = "target_person_id"
        case targetDisplayName = "target_display_name"
        case profileCategory = "profile_category"
        case proposedValue = "proposed_value"
        case valueStruct = "value_struct"
        case sourceQuote = "source_quote"
        case confidence
        case sensitivity
        case isAIInferred = "is_ai_inferred"
        case mergeStrategy = "merge_strategy"
        case classification
    }
}

public extension PersonProfilePatchProposal {
    func pendingUpdateEnvelope() -> PendingUpdatePayloadEnvelope<PersonProfilePatchProposal> {
        PendingUpdatePayloadEnvelope(
            proposalKind: .personProfilePatch,
            proposal: self,
            structuredContext: PendingUpdateStructuredReviewContext(
                sourceKind: "person_profile_patch",
                sourceProposalID: nil,
                reminder: nil,
                giftSignal: nil,
                valueStruct: valueStruct,
                classification: classification
            ),
            reviewExplanation: PendingUpdateReviewExplanation(
                targetMatchReason: targetDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "目标人物需要用户确认。"
                    : "原文匹配到 \(targetDisplayName)。",
                categoryReason: "这条建议会写入朋友档案的 \(profileCategory.title(for: .zhCN))。",
                dateParseReason: profileCategory == .anniversaries ? "生日/纪念日需要区分事实日期、提醒日期和是否每年重复。" : nil,
                riskReason: sensitivity == .normal ? "未发现额外敏感风险。" : "这条包含私密或敏感信息，列表默认遮罩。",
                confidenceReason: isAIInferred ? "包含 AI 推断，确认前不会保存成事实。" : "来源是用户原文。"
            ),
            freshness: .current(),
            approvalResult: nil,
            undo: nil
        )
    }
}

public enum GiftSocialRisk: String, Codable, CaseIterable, Sendable {
    case surpriseSensitive = "surprise_sensitive"
    case budgetUncertain = "budget_uncertain"
    case preferenceUncertain = "preference_uncertain"
    case relationshipSensitive = "relationship_sensitive"
    case avoidTopic = "avoid_topic"
    case timingSensitive = "timing_sensitive"
    case duplicateGiftRisk = "duplicate_gift_risk"
}

public struct ProfileValueStruct: Codable, Equatable, Sendable {
    public let kind: String?
    public let dateLabel: String?
    public let month: Int?
    public let day: Int?
    public let year: Int?
    public let item: String?
    public let severity: String?
    public let channel: String?
    public let value: String?
    public let visibility: String?

    public init(
        kind: String? = nil,
        dateLabel: String? = nil,
        month: Int? = nil,
        day: Int? = nil,
        year: Int? = nil,
        item: String? = nil,
        severity: String? = nil,
        channel: String? = nil,
        value: String? = nil,
        visibility: String? = nil
    ) {
        self.kind = kind
        self.dateLabel = dateLabel
        self.month = month
        self.day = day
        self.year = year
        self.item = item
        self.severity = severity
        self.channel = channel
        self.value = value
        self.visibility = visibility
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case dateLabel = "date_label"
        case month
        case day
        case year
        case item
        case severity
        case channel
        case value
        case visibility
    }
}

public struct ClassificationPropositionUnit: Codable, Equatable, Sendable {
    public let unitID: String
    public let sourceSpan: String
    public let propositionalContent: String
    public let attitudeHolder: String
    public let intentionalMode: String
    public let directionOfFit: String?
    public let evidentiality: String
    public let confidenceBasis: String
    public let domainObject: String
    public let candidateWorkflow: String?
    public let candidateStorageTargets: [String]
    public let proposalKind: String

    public init(
        unitID: String,
        sourceSpan: String,
        propositionalContent: String,
        attitudeHolder: String,
        intentionalMode: String,
        directionOfFit: String? = nil,
        evidentiality: String,
        confidenceBasis: String,
        domainObject: String,
        candidateWorkflow: String?,
        candidateStorageTargets: [String],
        proposalKind: String
    ) {
        self.unitID = unitID
        self.sourceSpan = sourceSpan
        self.propositionalContent = propositionalContent
        self.attitudeHolder = attitudeHolder
        self.intentionalMode = intentionalMode
        self.directionOfFit = directionOfFit
        self.evidentiality = evidentiality
        self.confidenceBasis = confidenceBasis
        self.domainObject = domainObject
        self.candidateWorkflow = candidateWorkflow
        self.candidateStorageTargets = candidateStorageTargets
        self.proposalKind = proposalKind
    }

    enum CodingKeys: String, CodingKey {
        case unitID = "unit_id"
        case sourceSpan = "source_span"
        case propositionalContent = "propositional_content"
        case attitudeHolder = "attitude_holder"
        case intentionalMode = "intentional_mode"
        case directionOfFit = "direction_of_fit"
        case evidentiality
        case confidenceBasis = "confidence_basis"
        case domainObject = "domain_object"
        case candidateWorkflow = "candidate_workflow"
        case candidateStorageTargets = "candidate_storage_targets"
        case proposalKind = "proposal_kind"
    }
}

public struct ClassificationCandidateInterpretation: Codable, Equatable, Sendable {
    public let workflowPrimary: String
    public let reason: String

    public init(workflowPrimary: String, reason: String) {
        self.workflowPrimary = workflowPrimary
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case workflowPrimary = "workflow_primary"
        case reason
    }
}

public struct PendingUpdateClassificationContext: Codable, Equatable, Sendable {
    public let propositionUnits: [ClassificationPropositionUnit]
    public let semanticPrimaryUnitID: String?
    public let workflowPrimaryUnitID: String?
    public let secondaryUnitIDs: [String]
    public let semanticPrimary: String?
    public let workflowPrimary: String?
    public let secondaryWorkflows: [String]
    public let storageTargets: [String]
    public let retentionPolicy: String
    public let illocutionaryForce: String?
    public let domainFrame: String?
    public let operation: String?
    public let opportunityType: String?
    public let assetValue: [String]
    public let sensitivityDomain: String
    public let severity: String
    public let privacyDisplayRisk: String
    public let visibilityPreference: String
    public let requiresDiscreetReview: Bool
    public let ambiguousSlots: [String]
    public let candidateInterpretations: [ClassificationCandidateInterpretation]
    public let blockedDecision: String?
    public let confirmationQuestion: String?
    public let reasonSummary: String
    public let confusionGuard: [String]
    public let opportunityConsent: [String: String]?
    public let relationshipStage: [String: String]?
    public let priorityScoreAudit: [String: String]?
    public let opportunityLifecycle: [String: String]?
    public let networkPath: [String: String]?
    public let giveFirstOffer: [String: String]?

    public init(
        propositionUnits: [ClassificationPropositionUnit],
        semanticPrimaryUnitID: String?,
        workflowPrimaryUnitID: String?,
        secondaryUnitIDs: [String] = [],
        semanticPrimary: String?,
        workflowPrimary: String?,
        secondaryWorkflows: [String] = [],
        storageTargets: [String],
        retentionPolicy: String,
        illocutionaryForce: String? = nil,
        domainFrame: String? = nil,
        operation: String? = nil,
        opportunityType: String? = "none",
        assetValue: [String] = [],
        sensitivityDomain: String = "none",
        severity: String = "none",
        privacyDisplayRisk: String = "none",
        visibilityPreference: String = "default",
        requiresDiscreetReview: Bool = false,
        ambiguousSlots: [String] = [],
        candidateInterpretations: [ClassificationCandidateInterpretation] = [],
        blockedDecision: String? = nil,
        confirmationQuestion: String? = nil,
        reasonSummary: String,
        confusionGuard: [String] = [],
        opportunityConsent: [String: String]? = nil,
        relationshipStage: [String: String]? = nil,
        priorityScoreAudit: [String: String]? = nil,
        opportunityLifecycle: [String: String]? = nil,
        networkPath: [String: String]? = nil,
        giveFirstOffer: [String: String]? = nil
    ) {
        self.propositionUnits = propositionUnits
        self.semanticPrimaryUnitID = semanticPrimaryUnitID
        self.workflowPrimaryUnitID = workflowPrimaryUnitID
        self.secondaryUnitIDs = secondaryUnitIDs
        self.semanticPrimary = semanticPrimary
        self.workflowPrimary = workflowPrimary
        self.secondaryWorkflows = secondaryWorkflows
        self.storageTargets = storageTargets
        self.retentionPolicy = retentionPolicy
        self.illocutionaryForce = illocutionaryForce
        self.domainFrame = domainFrame
        self.operation = operation
        self.opportunityType = opportunityType
        self.assetValue = assetValue
        self.sensitivityDomain = sensitivityDomain
        self.severity = severity
        self.privacyDisplayRisk = privacyDisplayRisk
        self.visibilityPreference = visibilityPreference
        self.requiresDiscreetReview = requiresDiscreetReview
        self.ambiguousSlots = ambiguousSlots
        self.candidateInterpretations = candidateInterpretations
        self.blockedDecision = blockedDecision
        self.confirmationQuestion = confirmationQuestion
        self.reasonSummary = reasonSummary
        self.confusionGuard = confusionGuard
        self.opportunityConsent = opportunityConsent
        self.relationshipStage = relationshipStage
        self.priorityScoreAudit = priorityScoreAudit
        self.opportunityLifecycle = opportunityLifecycle
        self.networkPath = networkPath
        self.giveFirstOffer = giveFirstOffer
    }

    enum CodingKeys: String, CodingKey {
        case propositionUnits = "proposition_units"
        case semanticPrimaryUnitID = "semantic_primary_unit_id"
        case workflowPrimaryUnitID = "workflow_primary_unit_id"
        case secondaryUnitIDs = "secondary_unit_ids"
        case semanticPrimary = "semantic_primary"
        case workflowPrimary = "workflow_primary"
        case secondaryWorkflows = "secondary_workflows"
        case storageTargets = "storage_targets"
        case retentionPolicy = "retention_policy"
        case illocutionaryForce = "illocutionary_force"
        case domainFrame = "domain_frame"
        case operation
        case opportunityType = "opportunity_type"
        case assetValue = "asset_value"
        case sensitivityDomain = "sensitivity_domain"
        case severity
        case privacyDisplayRisk = "privacy_display_risk"
        case visibilityPreference = "visibility_preference"
        case requiresDiscreetReview = "requires_discreet_review"
        case ambiguousSlots = "ambiguous_slots"
        case candidateInterpretations = "candidate_interpretations"
        case blockedDecision = "blocked_decision"
        case confirmationQuestion = "confirmation_question"
        case reasonSummary = "reason_summary"
        case confusionGuard = "confusion_guard"
        case opportunityConsent = "opportunity_consent"
        case relationshipStage = "relationship_stage"
        case priorityScoreAudit = "priority_score_audit"
        case opportunityLifecycle = "opportunity_lifecycle"
        case networkPath = "network_path"
        case giveFirstOffer = "give_first_offer"
    }
}

public struct PendingUpdateNotificationPolicy: Codable, Equatable, Sendable {
    public let deliveryMode: String
    public let policySource: String
    public let triggerAtOrNull: String?
    public let offsetOrNull: String?
    public let nextTriggerAtOrNull: String?
    public let timezone: String
    public let requiresConfirmation: Bool
    public let defaultAllowed: Bool

    public init(
        deliveryMode: String,
        policySource: String,
        triggerAtOrNull: String?,
        offsetOrNull: String?,
        nextTriggerAtOrNull: String?,
        timezone: String,
        requiresConfirmation: Bool,
        defaultAllowed: Bool
    ) {
        self.deliveryMode = deliveryMode
        self.policySource = policySource
        self.triggerAtOrNull = triggerAtOrNull
        self.offsetOrNull = offsetOrNull
        self.nextTriggerAtOrNull = nextTriggerAtOrNull
        self.timezone = timezone
        self.requiresConfirmation = requiresConfirmation
        self.defaultAllowed = defaultAllowed
    }

    public static func unspecified(timezone: String = "Asia/Shanghai") -> PendingUpdateNotificationPolicy {
        PendingUpdateNotificationPolicy(
            deliveryMode: "unspecified",
            policySource: "system_default_disallowed",
            triggerAtOrNull: nil,
            offsetOrNull: nil,
            nextTriggerAtOrNull: nil,
            timezone: timezone,
            requiresConfirmation: true,
            defaultAllowed: false
        )
    }

    enum CodingKeys: String, CodingKey {
        case deliveryMode = "delivery_mode"
        case policySource = "policy_source"
        case triggerAtOrNull = "trigger_at_or_null"
        case offsetOrNull = "offset_or_null"
        case nextTriggerAtOrNull = "next_trigger_at_or_null"
        case timezone
        case requiresConfirmation = "requires_confirmation"
        case defaultAllowed = "default_allowed"
    }
}

public indirect enum PendingUpdateObservedValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: PendingUpdateObservedValue])
    case array([PendingUpdateObservedValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode([String: PendingUpdateObservedValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([PendingUpdateObservedValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                PendingUpdateObservedValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported observed_value JSON")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public struct PendingUpdateConfirmationBlocker: Codable, Equatable, Sendable {
    public let code: String
    public let field: String
    public let requiredFor: String
    public let observedValue: PendingUpdateObservedValue?
    public let question: String

    public init(
        code: String,
        field: String,
        requiredFor: String,
        observedValue: String?,
        question: String
    ) {
        self.code = code
        self.field = field
        self.requiredFor = requiredFor
        self.observedValue = observedValue.map(PendingUpdateObservedValue.string)
        self.question = question
    }

    enum CodingKeys: String, CodingKey {
        case code
        case field
        case requiredFor = "required_for"
        case observedValue = "observed_value"
        case question
    }
}

public struct ReminderProposal: Codable, Equatable, Sendable {
    public let proposalID: String
    public let title: String
    public let targetPersonID: String?
    public let targetDisplayName: String?
    public let candidatePersonIDs: [String]
    public let dueAt: String?
    public let dueLabel: String
    public let sourceEntryID: String?
    public let sourceQuote: String
    public let sourceQuoteStart: Int?
    public let sourceQuoteEnd: Int?
    public let confidence: Double
    public let isAIInferred: Bool
    public let legacyText: String
    public let scheduleSubtype: String?
    public let scheduleExecutionState: String?
    public let timeRole: String?
    public let timeExpressionKind: String?
    public let timePrecision: String?
    public let rawTimeExpression: String?
    public let referenceDate: String?
    public let referenceDatetime: String?
    public let timezone: String?
    public let startAt: String?
    public let endAt: String?
    public let deadlineRelation: String?
    public let remindAt: String?
    public let commitmentLevel: String?
    public let notificationPolicy: PendingUpdateNotificationPolicy?
    public let needsSlotConfirmation: Bool
    public let confirmationBlockers: [PendingUpdateConfirmationBlocker]
    public let confirmationReasons: [String]
    public let requiresUserApproval: Bool
    public let reasonSummary: String?
    public let confusionGuard: [String]
    public let classification: PendingUpdateClassificationContext?
    public let actor: String?
    public let action: String?
    public let targetPerson: String?
    public let location: String?
    public let resolvedWindow: [String: String]?
    public let resolvedTime: [String: String]?
    public let recurrenceRule: [String: String]?
    public let mutationMatch: [String: String]?
    public let contextualGuard: [String: String]?

    public init(
        proposalID: String,
        title: String,
        targetPersonID: String?,
        targetDisplayName: String?,
        candidatePersonIDs: [String],
        dueAt: String?,
        dueLabel: String,
        sourceEntryID: String?,
        sourceQuote: String,
        sourceQuoteStart: Int? = nil,
        sourceQuoteEnd: Int? = nil,
        confidence: Double,
        isAIInferred: Bool,
        legacyText: String,
        scheduleSubtype: String? = nil,
        scheduleExecutionState: String? = nil,
        timeRole: String? = nil,
        timeExpressionKind: String? = nil,
        timePrecision: String? = nil,
        rawTimeExpression: String? = nil,
        referenceDate: String? = nil,
        referenceDatetime: String? = nil,
        timezone: String? = nil,
        startAt: String? = nil,
        endAt: String? = nil,
        deadlineRelation: String? = nil,
        remindAt: String? = nil,
        commitmentLevel: String? = nil,
        notificationPolicy: PendingUpdateNotificationPolicy? = nil,
        needsSlotConfirmation: Bool = false,
        confirmationBlockers: [PendingUpdateConfirmationBlocker] = [],
        confirmationReasons: [String] = [],
        requiresUserApproval: Bool = true,
        reasonSummary: String? = nil,
        confusionGuard: [String] = [],
        classification: PendingUpdateClassificationContext? = nil,
        actor: String? = nil,
        action: String? = nil,
        targetPerson: String? = nil,
        location: String? = nil,
        resolvedWindow: [String: String]? = nil,
        resolvedTime: [String: String]? = nil,
        recurrenceRule: [String: String]? = nil,
        mutationMatch: [String: String]? = nil,
        contextualGuard: [String: String]? = nil
    ) {
        self.proposalID = proposalID
        self.title = title
        self.targetPersonID = targetPersonID
        self.targetDisplayName = targetDisplayName
        self.candidatePersonIDs = candidatePersonIDs
        self.dueAt = dueAt
        self.dueLabel = dueLabel
        self.sourceEntryID = sourceEntryID
        self.sourceQuote = sourceQuote
        self.sourceQuoteStart = sourceQuoteStart
        self.sourceQuoteEnd = sourceQuoteEnd
        self.confidence = min(max(confidence, 0), 1)
        self.isAIInferred = isAIInferred
        self.legacyText = legacyText
        self.scheduleSubtype = scheduleSubtype
        self.scheduleExecutionState = scheduleExecutionState
        self.timeRole = timeRole
        self.timeExpressionKind = timeExpressionKind
        self.timePrecision = timePrecision
        self.rawTimeExpression = rawTimeExpression
        self.referenceDate = referenceDate
        self.referenceDatetime = referenceDatetime
        self.timezone = timezone
        self.startAt = startAt
        self.endAt = endAt
        self.deadlineRelation = deadlineRelation
        self.remindAt = remindAt
        self.commitmentLevel = commitmentLevel
        self.notificationPolicy = notificationPolicy
        self.needsSlotConfirmation = needsSlotConfirmation
        self.confirmationBlockers = confirmationBlockers
        self.confirmationReasons = confirmationReasons.isEmpty ? confirmationBlockers.map(\.code) : confirmationReasons
        self.requiresUserApproval = requiresUserApproval
        self.reasonSummary = reasonSummary
        self.confusionGuard = confusionGuard
        self.classification = classification
        self.actor = actor
        self.action = action
        self.targetPerson = targetPerson
        self.location = location
        self.resolvedWindow = resolvedWindow
        self.resolvedTime = resolvedTime
        self.recurrenceRule = recurrenceRule
        self.mutationMatch = mutationMatch
        self.contextualGuard = contextualGuard
    }

    public static func legacy(_ text: String, index: Int) -> ReminderProposal {
        ReminderProposal(
            proposalID: "legacy-reminder-\(index + 1)",
            title: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Reminder candidate" : text,
            targetPersonID: nil,
            targetDisplayName: nil,
            candidatePersonIDs: [],
            dueAt: nil,
            dueLabel: "未定日期",
            sourceEntryID: nil,
            sourceQuote: text,
            confidence: 0.7,
            isAIInferred: true,
            legacyText: text,
            scheduleSubtype: "task",
            scheduleExecutionState: "draft_schedule_candidate",
            timeRole: "ambiguous",
            timeExpressionKind: "missing_time",
            timePrecision: "unresolved",
            rawTimeExpression: nil,
            referenceDate: memoriaDateOnlyString(),
            referenceDatetime: memoriaTimestamp(),
            timezone: "Asia/Shanghai",
            commitmentLevel: "intended",
            notificationPolicy: .unspecified(),
            needsSlotConfirmation: true,
            confirmationBlockers: [
                PendingUpdateConfirmationBlocker(
                    code: "time_slot",
                    field: "raw_time_expression",
                    requiredFor: "executable_reminder",
                    observedValue: nil,
                    question: "你希望我什么时候提醒你？"
                )
            ],
            requiresUserApproval: true,
            reasonSummary: "旧版提醒文本缺少完整日程字段，保留为待确认候选。",
            confusionGuard: ["legacy_text_requires_confirmation"]
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        proposalID = try container.decode(String.self, forKey: .proposalID)
        title = try container.decode(String.self, forKey: .title)
        targetPersonID = try container.decodeIfPresent(String.self, forKey: .targetPersonID)
        targetDisplayName = try container.decodeIfPresent(String.self, forKey: .targetDisplayName)
        candidatePersonIDs = try container.decode([String].self, forKey: .candidatePersonIDs)
        dueAt = try container.decodeIfPresent(String.self, forKey: .dueAt)
        dueLabel = try container.decode(String.self, forKey: .dueLabel)
        sourceEntryID = try container.decodeIfPresent(String.self, forKey: .sourceEntryID)
        sourceQuote = try container.decode(String.self, forKey: .sourceQuote)
        sourceQuoteStart = try container.decodeIfPresent(Int.self, forKey: .sourceQuoteStart)
        sourceQuoteEnd = try container.decodeIfPresent(Int.self, forKey: .sourceQuoteEnd)
        confidence = min(max(try container.decode(Double.self, forKey: .confidence), 0), 1)
        isAIInferred = try container.decode(Bool.self, forKey: .isAIInferred)
        legacyText = try container.decode(String.self, forKey: .legacyText)
        scheduleSubtype = try container.decodeIfPresent(String.self, forKey: .scheduleSubtype)
        scheduleExecutionState = try container.decodeIfPresent(String.self, forKey: .scheduleExecutionState)
        timeRole = try container.decodeIfPresent(String.self, forKey: .timeRole)
        timeExpressionKind = try container.decodeIfPresent(String.self, forKey: .timeExpressionKind)
        timePrecision = try container.decodeIfPresent(String.self, forKey: .timePrecision)
        rawTimeExpression = try container.decodeIfPresent(String.self, forKey: .rawTimeExpression)
        referenceDate = try container.decodeIfPresent(String.self, forKey: .referenceDate)
        referenceDatetime = try container.decodeIfPresent(String.self, forKey: .referenceDatetime)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        startAt = try container.decodeIfPresent(String.self, forKey: .startAt)
        endAt = try container.decodeIfPresent(String.self, forKey: .endAt)
        deadlineRelation = try container.decodeIfPresent(String.self, forKey: .deadlineRelation)
        remindAt = try container.decodeIfPresent(String.self, forKey: .remindAt)
        commitmentLevel = try container.decodeIfPresent(String.self, forKey: .commitmentLevel)
        notificationPolicy = try container.decodeIfPresent(PendingUpdateNotificationPolicy.self, forKey: .notificationPolicy)
        needsSlotConfirmation = try container.decodeIfPresent(Bool.self, forKey: .needsSlotConfirmation) ?? false
        confirmationBlockers = try container.decodeIfPresent([PendingUpdateConfirmationBlocker].self, forKey: .confirmationBlockers) ?? []
        confirmationReasons = try container.decodeIfPresent([String].self, forKey: .confirmationReasons) ?? confirmationBlockers.map(\.code)
        requiresUserApproval = try container.decodeIfPresent(Bool.self, forKey: .requiresUserApproval) ?? true
        reasonSummary = try container.decodeIfPresent(String.self, forKey: .reasonSummary)
        confusionGuard = try container.decodeIfPresent([String].self, forKey: .confusionGuard) ?? []
        classification = try container.decodeIfPresent(PendingUpdateClassificationContext.self, forKey: .classification)
        actor = try container.decodeIfPresent(String.self, forKey: .actor)
        action = try container.decodeIfPresent(String.self, forKey: .action)
        targetPerson = try container.decodeIfPresent(String.self, forKey: .targetPerson)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        resolvedWindow = try container.decodeIfPresent([String: String].self, forKey: .resolvedWindow)
        resolvedTime = try container.decodeIfPresent([String: String].self, forKey: .resolvedTime)
        recurrenceRule = try container.decodeIfPresent([String: String].self, forKey: .recurrenceRule)
        mutationMatch = try container.decodeIfPresent([String: String].self, forKey: .mutationMatch)
        contextualGuard = try container.decodeIfPresent([String: String].self, forKey: .contextualGuard)
    }

    public func memoryAtomProposal() -> MemoryAtomProposal {
        let personName = targetDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let relatedPeople: [RelatedPersonProposal] = personName.isEmpty ? [] : [
            RelatedPersonProposal(
                displayName: personName,
                matchedPersonID: targetPersonID,
                matchConfidence: targetPersonID == nil ? 0.62 : 0.9,
                relationType: "about"
            )
        ]
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let dueText = dueAt ?? dueLabel
        let summary = legacyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "提醒：\(normalizedTitle)"
            : legacyText

        return MemoryAtomProposal(
            proposalType: .memoryAtom,
            memoryType: .reminderSource,
            title: normalizedTitle.isEmpty ? "行程提醒" : normalizedTitle,
            summary: summary,
            content: [normalizedTitle, dueText, sourceQuote]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n"),
            sourceQuote: sourceQuote,
            confidence: confidence,
            sensitivity: .normal,
            isAIInferred: isAIInferred,
            relatedPeople: relatedPeople,
            themes: [ThemeProposal(name: "提醒事项", confidence: 0.86)],
            followUpQuestions: needsSlotConfirmation
                ? Array(Set(confirmationBlockers.map(\.question))).sorted()
                : (dueAt == nil ? ["请先确认具体提醒日期。"] : []),
            suggestedActions: []
        )
    }

    public func pendingUpdateEnvelope() -> PendingUpdatePayloadEnvelope<MemoryAtomProposal> {
        PendingUpdatePayloadEnvelope(
            proposalKind: .memoryAtom,
            proposal: memoryAtomProposal(),
            structuredContext: PendingUpdateStructuredReviewContext(
                sourceKind: "reminder_proposal",
                sourceProposalID: proposalID,
                reminder: PendingUpdateReminderContext(
                    title: title,
                    targetPersonID: targetPersonID,
                    targetDisplayName: targetDisplayName,
                    candidatePersonIDs: candidatePersonIDs,
                    dueAt: dueAt,
                    dueLabel: dueLabel,
                    dateParseReason: dueAt == nil ? "原文没有可直接确认的具体日期，批准前需要用户确认。" : "原文包含可解释的日期。",
                    scheduleSubtype: scheduleSubtype,
                    scheduleExecutionState: scheduleExecutionState,
                    timeRole: timeRole,
                    timeExpressionKind: timeExpressionKind,
                    timePrecision: timePrecision,
                    rawTimeExpression: rawTimeExpression,
                    referenceDate: referenceDate,
                    referenceDatetime: referenceDatetime,
                    timezone: timezone,
                    startAt: startAt,
                    endAt: endAt,
                    deadlineRelation: deadlineRelation,
                    remindAt: remindAt,
                    commitmentLevel: commitmentLevel,
                    notificationPolicy: notificationPolicy,
                    needsSlotConfirmation: needsSlotConfirmation,
                    confirmationBlockers: confirmationBlockers,
                    confirmationReasons: confirmationReasons,
                    requiresUserApproval: requiresUserApproval,
                    reasonSummary: reasonSummary,
                    confusionGuard: confusionGuard,
                    actor: actor,
                    action: action,
                    targetPerson: targetPerson,
                    location: location,
                    resolvedWindow: resolvedWindow,
                    resolvedTime: resolvedTime,
                    recurrenceRule: recurrenceRule,
                    mutationMatch: mutationMatch,
                    contextualGuard: contextualGuard
                ),
                giftSignal: nil,
                valueStruct: nil,
                classification: classification
            ),
            reviewExplanation: PendingUpdateReviewExplanation(
                targetMatchReason: targetDisplayName == nil ? "原文没有明确目标人物。" : "原文提到 \(targetDisplayName ?? "")。",
                categoryReason: "这句话包含提醒或待办动作，因此进入行程安排。",
                dateParseReason: reasonSummary ?? (dueAt == nil ? "日期未定，需要确认具体时间。" : "日期来自结构化提醒字段。"),
                riskReason: "未发现送礼或关系敏感风险。",
                confidenceReason: isAIInferred ? "包含 AI 推断，确认前不会保存成事实。" : "来源是用户原文。"
            ),
            freshness: .current(),
            approvalResult: nil,
            undo: nil
        )
    }

    enum CodingKeys: String, CodingKey {
        case proposalID = "proposal_id"
        case title
        case targetPersonID = "target_person_id"
        case targetDisplayName = "target_display_name"
        case candidatePersonIDs = "candidate_person_ids"
        case dueAt = "due_at"
        case dueLabel = "due_label"
        case sourceEntryID = "source_entry_id"
        case sourceQuote = "source_quote"
        case sourceQuoteStart = "source_quote_start"
        case sourceQuoteEnd = "source_quote_end"
        case confidence
        case isAIInferred = "is_ai_inferred"
        case legacyText = "legacy_text"
        case scheduleSubtype = "schedule_subtype"
        case scheduleExecutionState = "schedule_execution_state"
        case timeRole = "time_role"
        case timeExpressionKind = "time_expression_kind"
        case timePrecision = "time_precision"
        case rawTimeExpression = "raw_time_expression"
        case referenceDate = "reference_date"
        case referenceDatetime = "reference_datetime"
        case timezone
        case startAt = "start_at"
        case endAt = "end_at"
        case deadlineRelation = "deadline_relation"
        case remindAt = "remind_at"
        case commitmentLevel = "commitment_level"
        case notificationPolicy = "notification_policy"
        case needsSlotConfirmation = "needs_slot_confirmation"
        case confirmationBlockers = "confirmation_blockers"
        case confirmationReasons = "confirmation_reasons"
        case requiresUserApproval = "requires_user_approval"
        case reasonSummary = "reason_summary"
        case confusionGuard = "confusion_guard"
        case classification
        case actor
        case action
        case targetPerson = "target_person"
        case location
        case resolvedWindow = "resolved_window"
        case resolvedTime = "resolved_time"
        case recurrenceRule = "recurrence_rule"
        case mutationMatch = "mutation_match"
        case contextualGuard = "contextual_guard"
    }
}

public struct GiftSignalProposal: Codable, Equatable, Sendable {
    public let proposalID: String
    public let targetPersonID: String?
    public let targetDisplayName: String?
    public let candidatePersonIDs: [String]
    public let signalSummary: String
    public let occasion: String?
    public let budgetHint: String?
    public let riskTags: [GiftSocialRisk]
    public let risk: String
    public let confirmationQuestion: String
    public let sourceQuote: String
    public let sourceQuoteStart: Int?
    public let sourceQuoteEnd: Int?
    public let confidence: Double
    public let isAIInferred: Bool
    public let legacyText: String
    public let classification: PendingUpdateClassificationContext?

    public init(
        proposalID: String,
        targetPersonID: String?,
        targetDisplayName: String?,
        candidatePersonIDs: [String],
        signalSummary: String,
        occasion: String?,
        budgetHint: String?,
        riskTags: [GiftSocialRisk],
        risk: String,
        confirmationQuestion: String,
        sourceQuote: String,
        sourceQuoteStart: Int? = nil,
        sourceQuoteEnd: Int? = nil,
        confidence: Double,
        isAIInferred: Bool,
        legacyText: String,
        classification: PendingUpdateClassificationContext? = nil
    ) {
        self.proposalID = proposalID
        self.targetPersonID = targetPersonID
        self.targetDisplayName = targetDisplayName
        self.candidatePersonIDs = candidatePersonIDs
        self.signalSummary = signalSummary
        self.occasion = occasion
        self.budgetHint = budgetHint
        self.riskTags = riskTags
        self.risk = risk
        self.confirmationQuestion = confirmationQuestion
        self.sourceQuote = sourceQuote
        self.sourceQuoteStart = sourceQuoteStart
        self.sourceQuoteEnd = sourceQuoteEnd
        self.confidence = min(max(confidence, 0), 1)
        self.isAIInferred = isAIInferred
        self.legacyText = legacyText
        self.classification = classification
    }

    public static func legacy(_ text: String, index: Int) -> GiftSignalProposal {
        GiftSignalProposal(
            proposalID: "legacy-gift-\(index + 1)",
            targetPersonID: nil,
            targetDisplayName: nil,
            candidatePersonIDs: [],
            signalSummary: text,
            occasion: "unknown",
            budgetHint: nil,
            riskTags: [],
            risk: "需要确认对象、预算和场合后再用于礼物建议。",
            confirmationQuestion: "这条礼物线索应该关联给谁？",
            sourceQuote: text,
            confidence: 0.7,
            isAIInferred: true,
            legacyText: text,
            classification: nil
        )
    }

    public func memoryAtomProposal() -> MemoryAtomProposal {
        let personName = targetDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let relatedPeople: [RelatedPersonProposal] = personName.isEmpty ? [] : [
            RelatedPersonProposal(
                displayName: personName,
                matchedPersonID: targetPersonID,
                matchConfidence: targetPersonID == nil ? 0.62 : 0.9,
                relationType: "about"
            )
        ]
        let summary = signalSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        return MemoryAtomProposal(
            proposalType: .memoryAtom,
            memoryType: .giftSignal,
            title: personName.isEmpty ? "礼物线索" : "\(personName) 的礼物线索",
            summary: summary.isEmpty ? legacyText : summary,
            content: [
                summary,
                budgetHint.map { "预算：\($0)" },
                occasion.map { "场合：\($0)" },
                risk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "风险：\(risk)",
                confirmationQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "确认问题：\(confirmationQuestion)"
            ]
                .compactMap { $0 }
                .joined(separator: "\n"),
            sourceQuote: sourceQuote,
            confidence: confidence,
            sensitivity: riskTags.contains(.relationshipSensitive) ? .sensitive : .normal,
            isAIInferred: isAIInferred,
            relatedPeople: relatedPeople,
            themes: [ThemeProposal(name: "礼物线索", confidence: 0.86)],
            followUpQuestions: [confirmationQuestion].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            suggestedActions: [],
            classification: classification
        )
    }

    public func pendingUpdateEnvelope() -> PendingUpdatePayloadEnvelope<MemoryAtomProposal> {
        PendingUpdatePayloadEnvelope(
            proposalKind: .memoryAtom,
            proposal: memoryAtomProposal(),
            structuredContext: PendingUpdateStructuredReviewContext(
                sourceKind: "gift_signal_proposal",
                sourceProposalID: proposalID,
                reminder: nil,
                giftSignal: PendingUpdateGiftSignalContext(
                    targetPersonID: targetPersonID,
                    targetDisplayName: targetDisplayName,
                    candidatePersonIDs: candidatePersonIDs,
                    signalSummary: signalSummary,
                    occasion: occasion,
                    budgetHint: budgetHint,
                    riskTags: riskTags,
                    risk: risk,
                    confirmationQuestion: confirmationQuestion
                ),
                valueStruct: nil,
                classification: classification
            ),
            reviewExplanation: PendingUpdateReviewExplanation(
                targetMatchReason: targetDisplayName == nil ? "礼物对象还需要确认。" : "原文提到 \(targetDisplayName ?? "")。",
                categoryReason: "这句话描述可用于送礼判断的偏好、场合或风险，因此进入朋友档案管理。",
                dateParseReason: nil,
                riskReason: riskTags.isEmpty ? risk : "包含 \(riskTags.map(\.rawValue).joined(separator: ", "))，送礼前需要单独确认。",
                confidenceReason: isAIInferred ? "包含 AI 推断，确认前不会保存成事实。" : "来源是用户原文。"
            ),
            freshness: .current(),
            approvalResult: nil,
            undo: nil
        )
    }

    enum CodingKeys: String, CodingKey {
        case proposalID = "proposal_id"
        case targetPersonID = "target_person_id"
        case targetDisplayName = "target_display_name"
        case candidatePersonIDs = "candidate_person_ids"
        case signalSummary = "signal_summary"
        case occasion
        case budgetHint = "budget_hint"
        case riskTags = "risk_tags"
        case risk
        case confirmationQuestion = "confirmation_question"
        case sourceQuote = "source_quote"
        case sourceQuoteStart = "source_quote_start"
        case sourceQuoteEnd = "source_quote_end"
        case confidence
        case isAIInferred = "is_ai_inferred"
        case legacyText = "legacy_text"
        case classification
    }
}

public struct ExtractMemoryResponse: Codable, Equatable, Sendable {
    public let schemaVersion: String?
    public let contractName: String?
    public let entrySummary: String
    public let memoryProposals: [MemoryAtomProposal]
    public let personFactProposals: [PersonProfilePatchProposal]
    public let reminderProposals: [ReminderProposal]
    public let giftSignalProposals: [GiftSignalProposal]
    public let conflicts: [String]
    public let followUpQuestions: [String]

    public init(
        schemaVersion: String? = nil,
        contractName: String? = nil,
        entrySummary: String,
        memoryProposals: [MemoryAtomProposal],
        personFactProposals: [PersonProfilePatchProposal],
        reminderProposals: [ReminderProposal],
        giftSignalProposals: [GiftSignalProposal],
        conflicts: [String],
        followUpQuestions: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.contractName = contractName
        self.entrySummary = entrySummary
        self.memoryProposals = memoryProposals
        self.personFactProposals = personFactProposals
        self.reminderProposals = reminderProposals
        self.giftSignalProposals = giftSignalProposals
        self.conflicts = conflicts
        self.followUpQuestions = followUpQuestions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
        contractName = try container.decodeIfPresent(String.self, forKey: .contractName)
        entrySummary = try container.decode(String.self, forKey: .entrySummary)
        memoryProposals = try container.decode([MemoryAtomProposal].self, forKey: .memoryProposals)
        personFactProposals = try container.decode([PersonProfilePatchProposal].self, forKey: .personFactProposals)
        if schemaVersion == "1.1" {
            reminderProposals = try container.decode([ReminderProposal].self, forKey: .reminderProposals)
            giftSignalProposals = try container.decode([GiftSignalProposal].self, forKey: .giftSignalProposals)
        } else {
            reminderProposals = try container.decodeFlexibleReminderProposals(forKey: .reminderProposals)
            giftSignalProposals = try container.decodeFlexibleGiftSignalProposals(forKey: .giftSignalProposals)
        }
        conflicts = try container.decode([String].self, forKey: .conflicts)
        followUpQuestions = try container.decode([String].self, forKey: .followUpQuestions)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(schemaVersion, forKey: .schemaVersion)
        try container.encodeIfPresent(contractName, forKey: .contractName)
        try container.encode(entrySummary, forKey: .entrySummary)
        try container.encode(memoryProposals, forKey: .memoryProposals)
        try container.encode(personFactProposals, forKey: .personFactProposals)
        try container.encode(reminderProposals, forKey: .reminderProposals)
        try container.encode(giftSignalProposals, forKey: .giftSignalProposals)
        try container.encode(conflicts, forKey: .conflicts)
        try container.encode(followUpQuestions, forKey: .followUpQuestions)
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case contractName = "contract_name"
        case entrySummary = "entry_summary"
        case memoryProposals = "memory_proposals"
        case personFactProposals = "person_fact_proposals"
        case reminderProposals = "reminder_proposals"
        case giftSignalProposals = "gift_signal_proposals"
        case conflicts
        case followUpQuestions = "follow_up_questions"
    }
}

public struct PendingUpdatePayloadEnvelope<Proposal: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public let payloadSchemaVersion: String
    public let payloadContractName: String
    public let proposalKind: PendingProposalType
    public var proposal: Proposal
    public var structuredContext: PendingUpdateStructuredReviewContext?
    public var reviewExplanation: PendingUpdateReviewExplanation?
    public var freshness: PendingUpdateFreshness?
    public var approvalResult: PendingUpdateApprovalResult?
    public var undo: PendingUpdateUndo?

    public init(
        payloadSchemaVersion: String = "1.1",
        payloadContractName: String = "pending_update_payload",
        proposalKind: PendingProposalType,
        proposal: Proposal,
        structuredContext: PendingUpdateStructuredReviewContext? = nil,
        reviewExplanation: PendingUpdateReviewExplanation? = nil,
        freshness: PendingUpdateFreshness? = nil,
        approvalResult: PendingUpdateApprovalResult? = nil,
        undo: PendingUpdateUndo? = nil
    ) {
        self.payloadSchemaVersion = payloadSchemaVersion
        self.payloadContractName = payloadContractName
        self.proposalKind = proposalKind
        self.proposal = proposal
        self.structuredContext = structuredContext
        self.reviewExplanation = reviewExplanation
        self.freshness = freshness
        self.approvalResult = approvalResult
        self.undo = undo
    }

    enum CodingKeys: String, CodingKey {
        case payloadSchemaVersion = "payload_schema_version"
        case payloadContractName = "payload_contract_name"
        case proposalKind = "proposal_kind"
        case proposal
        case structuredContext = "structured_context"
        case reviewExplanation = "review_explanation"
        case freshness
        case approvalResult = "approval_result"
        case undo
    }
}

public struct PendingUpdateStructuredReviewContext: Codable, Equatable, Sendable {
    public let sourceKind: String
    public let sourceProposalID: String?
    public let reminder: PendingUpdateReminderContext?
    public let giftSignal: PendingUpdateGiftSignalContext?
    public let valueStruct: ProfileValueStruct?
    public let classification: PendingUpdateClassificationContext?

    public init(
        sourceKind: String,
        sourceProposalID: String?,
        reminder: PendingUpdateReminderContext?,
        giftSignal: PendingUpdateGiftSignalContext?,
        valueStruct: ProfileValueStruct?,
        classification: PendingUpdateClassificationContext? = nil
    ) {
        self.sourceKind = sourceKind
        self.sourceProposalID = sourceProposalID
        self.reminder = reminder
        self.giftSignal = giftSignal
        self.valueStruct = valueStruct
        self.classification = classification
    }

    enum CodingKeys: String, CodingKey {
        case sourceKind = "source_kind"
        case sourceProposalID = "source_proposal_id"
        case reminder
        case giftSignal = "gift_signal"
        case valueStruct = "value_struct"
        case classification
    }
}

public struct PendingUpdateReminderContext: Codable, Equatable, Sendable {
    public let title: String
    public let targetPersonID: String?
    public let targetDisplayName: String?
    public let candidatePersonIDs: [String]
    public let dueAt: String?
    public let dueLabel: String
    public let dateParseReason: String?
    public let scheduleSubtype: String?
    public let scheduleExecutionState: String?
    public let timeRole: String?
    public let timeExpressionKind: String?
    public let timePrecision: String?
    public let rawTimeExpression: String?
    public let referenceDate: String?
    public let referenceDatetime: String?
    public let timezone: String?
    public let startAt: String?
    public let endAt: String?
    public let deadlineRelation: String?
    public let remindAt: String?
    public let commitmentLevel: String?
    public let notificationPolicy: PendingUpdateNotificationPolicy?
    public let needsSlotConfirmation: Bool
    public let confirmationBlockers: [PendingUpdateConfirmationBlocker]
    public let confirmationReasons: [String]
    public let requiresUserApproval: Bool
    public let reasonSummary: String?
    public let confusionGuard: [String]
    public let actor: String?
    public let action: String?
    public let targetPerson: String?
    public let location: String?
    public let resolvedWindow: [String: String]?
    public let resolvedTime: [String: String]?
    public let recurrenceRule: [String: String]?
    public let mutationMatch: [String: String]?
    public let contextualGuard: [String: String]?

    public init(
        title: String,
        targetPersonID: String?,
        targetDisplayName: String?,
        candidatePersonIDs: [String],
        dueAt: String?,
        dueLabel: String,
        dateParseReason: String?,
        scheduleSubtype: String? = nil,
        scheduleExecutionState: String? = nil,
        timeRole: String? = nil,
        timeExpressionKind: String? = nil,
        timePrecision: String? = nil,
        rawTimeExpression: String? = nil,
        referenceDate: String? = nil,
        referenceDatetime: String? = nil,
        timezone: String? = nil,
        startAt: String? = nil,
        endAt: String? = nil,
        deadlineRelation: String? = nil,
        remindAt: String? = nil,
        commitmentLevel: String? = nil,
        notificationPolicy: PendingUpdateNotificationPolicy? = nil,
        needsSlotConfirmation: Bool = false,
        confirmationBlockers: [PendingUpdateConfirmationBlocker] = [],
        confirmationReasons: [String] = [],
        requiresUserApproval: Bool = true,
        reasonSummary: String? = nil,
        confusionGuard: [String] = [],
        actor: String? = nil,
        action: String? = nil,
        targetPerson: String? = nil,
        location: String? = nil,
        resolvedWindow: [String: String]? = nil,
        resolvedTime: [String: String]? = nil,
        recurrenceRule: [String: String]? = nil,
        mutationMatch: [String: String]? = nil,
        contextualGuard: [String: String]? = nil
    ) {
        self.title = title
        self.targetPersonID = targetPersonID
        self.targetDisplayName = targetDisplayName
        self.candidatePersonIDs = candidatePersonIDs
        self.dueAt = dueAt
        self.dueLabel = dueLabel
        self.dateParseReason = dateParseReason
        self.scheduleSubtype = scheduleSubtype
        self.scheduleExecutionState = scheduleExecutionState
        self.timeRole = timeRole
        self.timeExpressionKind = timeExpressionKind
        self.timePrecision = timePrecision
        self.rawTimeExpression = rawTimeExpression
        self.referenceDate = referenceDate
        self.referenceDatetime = referenceDatetime
        self.timezone = timezone
        self.startAt = startAt
        self.endAt = endAt
        self.deadlineRelation = deadlineRelation
        self.remindAt = remindAt
        self.commitmentLevel = commitmentLevel
        self.notificationPolicy = notificationPolicy
        self.needsSlotConfirmation = needsSlotConfirmation
        self.confirmationBlockers = confirmationBlockers
        self.confirmationReasons = confirmationReasons.isEmpty ? confirmationBlockers.map(\.code) : confirmationReasons
        self.requiresUserApproval = requiresUserApproval
        self.reasonSummary = reasonSummary
        self.confusionGuard = confusionGuard
        self.actor = actor
        self.action = action
        self.targetPerson = targetPerson
        self.location = location
        self.resolvedWindow = resolvedWindow
        self.resolvedTime = resolvedTime
        self.recurrenceRule = recurrenceRule
        self.mutationMatch = mutationMatch
        self.contextualGuard = contextualGuard
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        targetPersonID = try container.decodeIfPresent(String.self, forKey: .targetPersonID)
        targetDisplayName = try container.decodeIfPresent(String.self, forKey: .targetDisplayName)
        candidatePersonIDs = try container.decode([String].self, forKey: .candidatePersonIDs)
        dueAt = try container.decodeIfPresent(String.self, forKey: .dueAt)
        dueLabel = try container.decode(String.self, forKey: .dueLabel)
        dateParseReason = try container.decodeIfPresent(String.self, forKey: .dateParseReason)
        scheduleSubtype = try container.decodeIfPresent(String.self, forKey: .scheduleSubtype)
        scheduleExecutionState = try container.decodeIfPresent(String.self, forKey: .scheduleExecutionState)
        timeRole = try container.decodeIfPresent(String.self, forKey: .timeRole)
        timeExpressionKind = try container.decodeIfPresent(String.self, forKey: .timeExpressionKind)
        timePrecision = try container.decodeIfPresent(String.self, forKey: .timePrecision)
        rawTimeExpression = try container.decodeIfPresent(String.self, forKey: .rawTimeExpression)
        referenceDate = try container.decodeIfPresent(String.self, forKey: .referenceDate)
        referenceDatetime = try container.decodeIfPresent(String.self, forKey: .referenceDatetime)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        startAt = try container.decodeIfPresent(String.self, forKey: .startAt)
        endAt = try container.decodeIfPresent(String.self, forKey: .endAt)
        deadlineRelation = try container.decodeIfPresent(String.self, forKey: .deadlineRelation)
        remindAt = try container.decodeIfPresent(String.self, forKey: .remindAt)
        commitmentLevel = try container.decodeIfPresent(String.self, forKey: .commitmentLevel)
        notificationPolicy = try container.decodeIfPresent(PendingUpdateNotificationPolicy.self, forKey: .notificationPolicy)
        needsSlotConfirmation = try container.decodeIfPresent(Bool.self, forKey: .needsSlotConfirmation) ?? false
        confirmationBlockers = try container.decodeIfPresent([PendingUpdateConfirmationBlocker].self, forKey: .confirmationBlockers) ?? []
        confirmationReasons = try container.decodeIfPresent([String].self, forKey: .confirmationReasons) ?? confirmationBlockers.map(\.code)
        requiresUserApproval = try container.decodeIfPresent(Bool.self, forKey: .requiresUserApproval) ?? true
        reasonSummary = try container.decodeIfPresent(String.self, forKey: .reasonSummary)
        confusionGuard = try container.decodeIfPresent([String].self, forKey: .confusionGuard) ?? []
        actor = try container.decodeIfPresent(String.self, forKey: .actor)
        action = try container.decodeIfPresent(String.self, forKey: .action)
        targetPerson = try container.decodeIfPresent(String.self, forKey: .targetPerson)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        resolvedWindow = try container.decodeIfPresent([String: String].self, forKey: .resolvedWindow)
        resolvedTime = try container.decodeIfPresent([String: String].self, forKey: .resolvedTime)
        recurrenceRule = try container.decodeIfPresent([String: String].self, forKey: .recurrenceRule)
        mutationMatch = try container.decodeIfPresent([String: String].self, forKey: .mutationMatch)
        contextualGuard = try container.decodeIfPresent([String: String].self, forKey: .contextualGuard)
    }

    enum CodingKeys: String, CodingKey {
        case title
        case targetPersonID = "target_person_id"
        case targetDisplayName = "target_display_name"
        case candidatePersonIDs = "candidate_person_ids"
        case dueAt = "due_at"
        case dueLabel = "due_label"
        case dateParseReason = "date_parse_reason"
        case scheduleSubtype = "schedule_subtype"
        case scheduleExecutionState = "schedule_execution_state"
        case timeRole = "time_role"
        case timeExpressionKind = "time_expression_kind"
        case timePrecision = "time_precision"
        case rawTimeExpression = "raw_time_expression"
        case referenceDate = "reference_date"
        case referenceDatetime = "reference_datetime"
        case timezone
        case startAt = "start_at"
        case endAt = "end_at"
        case deadlineRelation = "deadline_relation"
        case remindAt = "remind_at"
        case commitmentLevel = "commitment_level"
        case notificationPolicy = "notification_policy"
        case needsSlotConfirmation = "needs_slot_confirmation"
        case confirmationBlockers = "confirmation_blockers"
        case confirmationReasons = "confirmation_reasons"
        case requiresUserApproval = "requires_user_approval"
        case reasonSummary = "reason_summary"
        case confusionGuard = "confusion_guard"
        case actor
        case action
        case targetPerson = "target_person"
        case location
        case resolvedWindow = "resolved_window"
        case resolvedTime = "resolved_time"
        case recurrenceRule = "recurrence_rule"
        case mutationMatch = "mutation_match"
        case contextualGuard = "contextual_guard"
    }
}

public struct PendingUpdateGiftSignalContext: Codable, Equatable, Sendable {
    public let targetPersonID: String?
    public let targetDisplayName: String?
    public let candidatePersonIDs: [String]
    public let signalSummary: String
    public let occasion: String?
    public let budgetHint: String?
    public let riskTags: [GiftSocialRisk]
    public let risk: String
    public let confirmationQuestion: String

    public init(
        targetPersonID: String?,
        targetDisplayName: String?,
        candidatePersonIDs: [String],
        signalSummary: String,
        occasion: String?,
        budgetHint: String?,
        riskTags: [GiftSocialRisk],
        risk: String,
        confirmationQuestion: String
    ) {
        self.targetPersonID = targetPersonID
        self.targetDisplayName = targetDisplayName
        self.candidatePersonIDs = candidatePersonIDs
        self.signalSummary = signalSummary
        self.occasion = occasion
        self.budgetHint = budgetHint
        self.riskTags = riskTags
        self.risk = risk
        self.confirmationQuestion = confirmationQuestion
    }

    enum CodingKeys: String, CodingKey {
        case targetPersonID = "target_person_id"
        case targetDisplayName = "target_display_name"
        case candidatePersonIDs = "candidate_person_ids"
        case signalSummary = "signal_summary"
        case occasion
        case budgetHint = "budget_hint"
        case riskTags = "risk_tags"
        case risk
        case confirmationQuestion = "confirmation_question"
    }
}

public struct PendingUpdateReviewExplanation: Codable, Equatable, Sendable {
    public let targetMatchReason: String?
    public let categoryReason: String?
    public let dateParseReason: String?
    public let riskReason: String?
    public let confidenceReason: String?

    public init(
        targetMatchReason: String?,
        categoryReason: String?,
        dateParseReason: String?,
        riskReason: String?,
        confidenceReason: String?
    ) {
        self.targetMatchReason = targetMatchReason
        self.categoryReason = categoryReason
        self.dateParseReason = dateParseReason
        self.riskReason = riskReason
        self.confidenceReason = confidenceReason
    }

    enum CodingKeys: String, CodingKey {
        case targetMatchReason = "target_match_reason"
        case categoryReason = "category_reason"
        case dateParseReason = "date_parse_reason"
        case riskReason = "risk_reason"
        case confidenceReason = "confidence_reason"
    }
}

public struct PendingUpdateFreshness: Codable, Equatable, Sendable {
    public let effectiveStatus: String
    public let lastObserved: String?
    public let stalenessReason: String?
    public let supersedesMemoryID: String?

    public init(
        effectiveStatus: String,
        lastObserved: String?,
        stalenessReason: String?,
        supersedesMemoryID: String?
    ) {
        self.effectiveStatus = effectiveStatus
        self.lastObserved = lastObserved
        self.stalenessReason = stalenessReason
        self.supersedesMemoryID = supersedesMemoryID
    }

    public static func current(lastObserved: String? = memoriaDateOnlyString()) -> PendingUpdateFreshness {
        PendingUpdateFreshness(
            effectiveStatus: "current",
            lastObserved: lastObserved,
            stalenessReason: nil,
            supersedesMemoryID: nil
        )
    }

    enum CodingKeys: String, CodingKey {
        case effectiveStatus = "effective_status"
        case lastObserved = "last_observed"
        case stalenessReason = "staleness_reason"
        case supersedesMemoryID = "supersedes_memory_id"
    }
}

public struct PendingUpdateApprovalResult: Codable, Equatable, Sendable {
    public var approvedAt: String?
    public var memoryAtomID: String?
    public var derivedReminderID: String?
    public var derivedGiftIdeaID: String?
    public var profilePatchPreimage: ProfilePatchPreimage?
    public var profilePatchExpectedValue: String?

    public init(
        approvedAt: String? = nil,
        memoryAtomID: String? = nil,
        derivedReminderID: String? = nil,
        derivedGiftIdeaID: String? = nil,
        profilePatchPreimage: ProfilePatchPreimage? = nil,
        profilePatchExpectedValue: String? = nil
    ) {
        self.approvedAt = approvedAt
        self.memoryAtomID = memoryAtomID
        self.derivedReminderID = derivedReminderID
        self.derivedGiftIdeaID = derivedGiftIdeaID
        self.profilePatchPreimage = profilePatchPreimage
        self.profilePatchExpectedValue = profilePatchExpectedValue
    }

    enum CodingKeys: String, CodingKey {
        case approvedAt = "approved_at"
        case memoryAtomID = "memory_atom_id"
        case derivedReminderID = "derived_reminder_id"
        case derivedGiftIdeaID = "derived_gift_idea_id"
        case profilePatchPreimage = "profile_patch_preimage"
        case profilePatchExpectedValue = "profile_patch_expected_value"
    }
}

public struct ProfilePatchPreimage: Codable, Equatable, Sendable {
    public let personID: String
    public let category: PersonProfileCategory
    public let oldValue: String

    public init(personID: String, category: PersonProfileCategory, oldValue: String) {
        self.personID = personID
        self.category = category
        self.oldValue = oldValue
    }

    enum CodingKeys: String, CodingKey {
        case personID = "person_id"
        case category
        case oldValue = "old_value"
    }
}

public struct PendingUpdateUndo: Codable, Equatable, Sendable {
    public var state: String
    public var preimage: [String: String]?
    public var result: [String: String]?
    public var createdCorrectionPendingUpdateID: String?

    public init(
        state: String,
        preimage: [String: String]? = nil,
        result: [String: String]? = nil,
        createdCorrectionPendingUpdateID: String? = nil
    ) {
        self.state = state
        self.preimage = preimage
        self.result = result
        self.createdCorrectionPendingUpdateID = createdCorrectionPendingUpdateID
    }

    enum CodingKeys: String, CodingKey {
        case state
        case preimage
        case result
        case createdCorrectionPendingUpdateID = "created_correction_pending_update_id"
    }
}

public enum PendingUpdatePayloadEnvelopeValidator {
    private static let envelopeKeys: Set<String> = [
        "payload_schema_version",
        "payload_contract_name",
        "proposal_kind",
        "proposal",
        "structured_context",
        "review_explanation",
        "freshness",
        "approval_result",
        "undo"
    ]

    public static func validate(data: Data, expectedProposalKind: PendingProposalType) throws {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            throw AIContractError.invalidJSON
        }
        for key in dictionary.keys where !envelopeKeys.contains(key) {
            throw AIContractError.unknownKey("$.payload.\(key)")
        }
        guard dictionary["payload_schema_version"] as? String == "1.1" else {
            throw AIContractError.invalidContract("pending_update_payload missing schema version")
        }
        guard dictionary["payload_contract_name"] as? String == "pending_update_payload" else {
            throw AIContractError.invalidContract("pending_update_payload missing contract name")
        }
        guard dictionary["proposal_kind"] as? String == expectedProposalKind.rawValue else {
            throw AIContractError.invalidSchemaValue("proposal_kind")
        }
        guard let proposal = dictionary["proposal"] as? [String: Any] else {
            throw AIContractError.invalidSchemaValue("proposal")
        }
        if expectedProposalKind == .memoryAtom {
            guard proposal["proposal_type"] as? String == PendingProposalType.memoryAtom.rawValue else {
                throw AIContractError.invalidSchemaValue("proposal.proposal_type")
            }
        } else if let proposalType = proposal["proposal_type"] as? String,
                  proposalType != expectedProposalKind.rawValue {
            throw AIContractError.invalidSchemaValue("proposal.proposal_type")
        }
    }
}

public enum AIContractError: LocalizedError, Equatable {
    case invalidJSON
    case missingSourceQuote
    case invalidProfilePatch
    case invalidContract(String)
    case unknownKey(String)
    case invalidConfidence
    case invalidSchemaValue(String)
    case unsupportedProposalType(String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            "AI returned invalid JSON."
        case .missingSourceQuote:
            "AI proposal is missing a source quote."
        case .invalidProfilePatch:
            "AI profile patch is missing a target person or proposed value."
        case .invalidContract(let contract):
            "Unsupported AI contract: \(contract)."
        case .unknownKey(let key):
            "AI output contains an unsupported key: \(key)."
        case .invalidConfidence:
            "AI confidence must be between 0 and 1."
        case .invalidSchemaValue(let value):
            "AI output contains an unsupported schema value: \(value)."
        case .unsupportedProposalType(let type):
            "Unsupported proposal type: \(type)."
        }
    }
}

private extension KeyedDecodingContainer where K == ExtractMemoryResponse.CodingKeys {
    func decodeFlexibleReminderProposals(forKey key: K) throws -> [ReminderProposal] {
        if let proposals = try? decode([ReminderProposal].self, forKey: key) {
            return proposals
        }
        if let legacy = try? decode([String].self, forKey: key) {
            return legacy.enumerated().map { ReminderProposal.legacy($0.element, index: $0.offset) }
        }
        return []
    }

    func decodeFlexibleGiftSignalProposals(forKey key: K) throws -> [GiftSignalProposal] {
        if let proposals = try? decode([GiftSignalProposal].self, forKey: key) {
            return proposals
        }
        if let legacy = try? decode([String].self, forKey: key) {
            return legacy.enumerated().map { GiftSignalProposal.legacy($0.element, index: $0.offset) }
        }
        return []
    }
}
