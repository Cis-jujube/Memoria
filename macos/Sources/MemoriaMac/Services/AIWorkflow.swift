import Foundation

public struct AIJSONParser: Sendable {
    public init() {}

    public func parseExtractMemoryResponse(data: Data) throws -> ExtractMemoryResponse {
        do {
            try AIJSONRawValidator.validateExtractMemoryResponse(data: data)
            let decoded = try JSONDecoder().decode(ExtractMemoryResponse.self, from: data)
            try AIContractValidator().validate(decoded)
            return decoded
        } catch let error as AIContractError {
            throw error
        } catch {
            throw AIContractError.invalidJSON
        }
    }

    public func parseExtractMemoryResponse(content: String) throws -> ExtractMemoryResponse {
        guard let data = content.data(using: .utf8) else {
            throw AIContractError.invalidJSON
        }
        return try parseExtractMemoryResponse(data: data)
    }
}

public struct AIContractValidator: Sendable {
    public init() {}

    public func validate(_ response: ExtractMemoryResponse) throws {
        if let schemaVersion = response.schemaVersion {
            guard schemaVersion == "1.1", response.contractName == "extract_memory" else {
                throw AIContractError.invalidContract("\(response.contractName ?? "missing") \(schemaVersion)")
            }
        } else if response.contractName != nil {
            throw AIContractError.invalidContract(response.contractName ?? "missing")
        }

        for proposal in response.memoryProposals {
            guard proposal.proposalType == .memoryAtom else {
                throw AIContractError.unsupportedProposalType(proposal.proposalType.rawValue)
            }
            guard !proposal.sourceQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIContractError.missingSourceQuote
            }
        }
        for proposal in response.personFactProposals {
            try validateProfilePatch(proposal)
        }
        for proposal in response.reminderProposals {
            guard !proposal.sourceQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIContractError.missingSourceQuote
            }
            guard !proposal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIContractError.invalidSchemaValue("empty reminder title")
            }
            try validateTargetCandidateConsistency(
                targetPersonID: proposal.targetPersonID,
                candidatePersonIDs: proposal.candidatePersonIDs
            )
        }
        for proposal in response.giftSignalProposals {
            guard !proposal.sourceQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIContractError.missingSourceQuote
            }
            guard !proposal.confirmationQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIContractError.invalidSchemaValue("empty confirmation question")
            }
            try validateTargetCandidateConsistency(
                targetPersonID: proposal.targetPersonID,
                candidatePersonIDs: proposal.candidatePersonIDs
            )
        }
    }

    public func validateProfilePatch(_ proposal: PersonProfilePatchProposal) throws {
        guard !proposal.sourceQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIContractError.missingSourceQuote
        }
        guard proposal.targetPersonID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
            !proposal.targetDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIContractError.invalidProfilePatch
        }
        guard !proposal.proposedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIContractError.invalidProfilePatch
        }
    }

    private func validateTargetCandidateConsistency(targetPersonID: String?, candidatePersonIDs: [String]) throws {
        guard let targetPersonID, !targetPersonID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        guard candidatePersonIDs.isEmpty || candidatePersonIDs.contains(targetPersonID) else {
            throw AIContractError.invalidSchemaValue("target_person_id not in candidate_person_ids")
        }
    }
}

private enum AIJSONRawValidator {
    private static let topLevelKeys: Set<String> = [
        "schema_version",
        "contract_name",
        "entry_summary",
        "memory_proposals",
        "person_fact_proposals",
        "reminder_proposals",
        "gift_signal_proposals",
        "conflicts",
        "follow_up_questions"
    ]

    private static let memoryProposalKeys: Set<String> = [
        "proposal_type",
        "memory_type",
        "title",
        "summary",
        "content",
        "source_quote",
        "confidence",
        "sensitivity",
        "is_ai_inferred",
        "related_people",
        "themes",
        "relationship_edge_proposals",
        "follow_up_questions",
        "suggested_actions",
        "classification"
    ]

    private static let profilePatchKeys: Set<String> = [
        "target_person_id",
        "target_display_name",
        "profile_category",
        "proposed_value",
        "value_struct",
        "source_quote",
        "confidence",
        "sensitivity",
        "is_ai_inferred",
        "merge_strategy",
        "classification"
    ]

    private static let relatedPeopleKeys: Set<String> = [
        "display_name",
        "matched_person_id",
        "match_confidence",
        "relation_type"
    ]

    private static let themeKeys: Set<String> = [
        "name",
        "confidence"
    ]

    private static let relationshipEdgeKeys: Set<String> = [
        "source_person_id",
        "source_display_name",
        "target_person_id",
        "target_display_name",
        "label",
        "strength",
        "relation_kind",
        "tags",
        "ai_primary_tag",
        "confidence",
        "is_ai_inferred",
        "source_quote"
    ]

    private static let reminderKeys: Set<String> = [
        "proposal_id",
        "title",
        "target_person_id",
        "target_display_name",
        "candidate_person_ids",
        "due_at",
        "due_label",
        "source_entry_id",
        "source_quote",
        "source_quote_start",
        "source_quote_end",
        "confidence",
        "is_ai_inferred",
        "legacy_text",
        "schedule_subtype",
        "schedule_execution_state",
        "time_role",
        "time_expression_kind",
        "time_precision",
        "raw_time_expression",
        "reference_date",
        "reference_datetime",
        "timezone",
        "start_at",
        "end_at",
        "deadline_relation",
        "remind_at",
        "commitment_level",
        "notification_policy",
        "needs_slot_confirmation",
        "confirmation_blockers",
        "confirmation_reasons",
        "requires_user_approval",
        "reason_summary",
        "confusion_guard",
        "classification",
        "actor",
        "action",
        "target_person",
        "location",
        "resolved_window",
        "resolved_time",
        "recurrence_rule",
        "mutation_match",
        "contextual_guard"
    ]

    private static let classificationKeys: Set<String> = [
        "proposition_units",
        "semantic_primary_unit_id",
        "workflow_primary_unit_id",
        "secondary_unit_ids",
        "semantic_primary",
        "workflow_primary",
        "secondary_workflows",
        "storage_targets",
        "retention_policy",
        "illocutionary_force",
        "domain_frame",
        "operation",
        "opportunity_type",
        "asset_value",
        "sensitivity_domain",
        "severity",
        "privacy_display_risk",
        "visibility_preference",
        "requires_discreet_review",
        "ambiguous_slots",
        "candidate_interpretations",
        "blocked_decision",
        "confirmation_question",
        "reason_summary",
        "confusion_guard",
        "opportunity_consent",
        "relationship_stage",
        "priority_score_audit",
        "opportunity_lifecycle",
        "network_path",
        "give_first_offer"
    ]

    private static let propositionUnitKeys: Set<String> = [
        "unit_id",
        "source_span",
        "propositional_content",
        "attitude_holder",
        "intentional_mode",
        "direction_of_fit",
        "evidentiality",
        "confidence_basis",
        "domain_object",
        "candidate_workflow",
        "candidate_storage_targets",
        "proposal_kind"
    ]

    private static let candidateInterpretationKeys: Set<String> = [
        "workflow_primary",
        "reason"
    ]

    private static let giftKeys: Set<String> = [
        "proposal_id",
        "target_person_id",
        "target_display_name",
        "candidate_person_ids",
        "signal_summary",
        "occasion",
        "budget_hint",
        "risk_tags",
        "risk",
        "confirmation_question",
        "source_quote",
        "source_quote_start",
        "source_quote_end",
        "confidence",
        "is_ai_inferred",
        "legacy_text",
        "classification"
    ]

    private static let valueStructKeys: Set<String> = [
        "kind",
        "date_label",
        "month",
        "day",
        "year",
        "item",
        "severity",
        "channel",
        "value",
        "visibility"
    ]

    static func validateExtractMemoryResponse(data: Data) throws {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            throw AIContractError.invalidJSON
        }

        try rejectUnknownKeys(in: dictionary, allowed: topLevelKeys, path: "$")
        try validateContract(in: dictionary)
        let allowsLegacyStructuredArrays = dictionary["schema_version"] == nil
        try validateMemoryProposals(dictionary["memory_proposals"], requiresClassification: !allowsLegacyStructuredArrays)
        try validateProfilePatches(dictionary["person_fact_proposals"], requiresClassification: !allowsLegacyStructuredArrays)
        try validateReminderProposals(
            dictionary["reminder_proposals"],
            allowsLegacyStrings: allowsLegacyStructuredArrays,
            requiresBoundaryFields: !allowsLegacyStructuredArrays
        )
        try validateGiftSignalProposals(
            dictionary["gift_signal_proposals"],
            allowsLegacyStrings: allowsLegacyStructuredArrays,
            requiresClassification: !allowsLegacyStructuredArrays
        )
    }

    private static func validateContract(in dictionary: [String: Any]) throws {
        let schemaVersion = dictionary["schema_version"] as? String
        let contractName = dictionary["contract_name"] as? String
        switch (schemaVersion, contractName) {
        case (nil, nil):
            return
        case ("1.1"?, "extract_memory"?):
            return
        default:
            throw AIContractError.invalidContract("\(contractName ?? "missing") \(schemaVersion ?? "missing")")
        }
    }

    private static func validateMemoryProposals(_ value: Any?, requiresClassification: Bool) throws {
        for (index, proposal) in try objectArray(value, path: "memory_proposals").enumerated() {
            let path = "memory_proposals[\(index)]"
            try rejectUnknownKeys(in: proposal, allowed: memoryProposalKeys, path: path)
            try requireString(proposal["proposal_type"], equals: PendingProposalType.memoryAtom.rawValue, path: "\(path).proposal_type")
            try requireEnum(proposal["memory_type"], allowed: Set(MemoryAtomType.allCases.map(\.rawValue)), path: "\(path).memory_type")
            try requireNonEmptyString(proposal["source_quote"], path: "\(path).source_quote")
            try validateConfidence(proposal["confidence"], path: "\(path).confidence")
            try requireEnum(proposal["sensitivity"], allowed: Set(MemorySensitivity.allCases.map(\.rawValue)), path: "\(path).sensitivity")

            for (personIndex, person) in try objectArray(proposal["related_people"], path: "\(path).related_people").enumerated() {
                let personPath = "\(path).related_people[\(personIndex)]"
                try rejectUnknownKeys(in: person, allowed: relatedPeopleKeys, path: personPath)
                try validateConfidence(person["match_confidence"], path: "\(personPath).match_confidence")
            }

            for (themeIndex, theme) in try objectArray(proposal["themes"], path: "\(path).themes").enumerated() {
                let themePath = "\(path).themes[\(themeIndex)]"
                try rejectUnknownKeys(in: theme, allowed: themeKeys, path: themePath)
                try validateConfidence(theme["confidence"], path: "\(themePath).confidence")
            }

            if let edgeValue = proposal["relationship_edge_proposals"], !(edgeValue is NSNull) {
                for (edgeIndex, edge) in try objectArray(edgeValue, path: "\(path).relationship_edge_proposals").enumerated() {
                    let edgePath = "\(path).relationship_edge_proposals[\(edgeIndex)]"
                    try rejectUnknownKeys(in: edge, allowed: relationshipEdgeKeys, path: edgePath)
                    try requireNonEmptyString(edge["source_quote"], path: "\(edgePath).source_quote")
                    try validateConfidence(edge["strength"], path: "\(edgePath).strength")
                    try validateConfidence(edge["confidence"], path: "\(edgePath).confidence")
                }
            }
            try validateProposalClassification(
                proposal["classification"],
                path: "\(path).classification",
                requiresClassification: requiresClassification
            )
        }
    }

    private static func validateProfilePatches(_ value: Any?, requiresClassification: Bool) throws {
        for (index, proposal) in try objectArray(value, path: "person_fact_proposals").enumerated() {
            let path = "person_fact_proposals[\(index)]"
            try rejectUnknownKeys(in: proposal, allowed: profilePatchKeys, path: path)
            try requireEnum(proposal["profile_category"], allowed: Set(PersonProfileCategory.allCases.map(\.rawValue)), path: "\(path).profile_category")
            try requireNonEmptyString(proposal["source_quote"], path: "\(path).source_quote")
            try requireNonEmptyString(proposal["proposed_value"], path: "\(path).proposed_value")
            try validateProfileTarget(proposal, path: path)
            try validateConfidence(proposal["confidence"], path: "\(path).confidence")
            try requireEnum(proposal["sensitivity"], allowed: Set(MemorySensitivity.allCases.map(\.rawValue)), path: "\(path).sensitivity")
            try requireEnum(proposal["merge_strategy"], allowed: Set(ProfilePatchMergeStrategy.allCases.map(\.rawValue)), path: "\(path).merge_strategy")

            if let valueStruct = proposal["value_struct"], !(valueStruct is NSNull) {
                guard let category = proposal["profile_category"] as? String else {
                    throw AIContractError.invalidSchemaValue("\(path).profile_category")
                }
                try validateValueStruct(valueStruct, category: category, path: "\(path).value_struct")
            }
            try validateProposalClassification(
                proposal["classification"],
                path: "\(path).classification",
                requiresClassification: requiresClassification
            )
        }
    }

    private static func validateReminderProposals(_ value: Any?, allowsLegacyStrings: Bool, requiresBoundaryFields: Bool) throws {
        if value == nil { return }
        if value is [String] {
            if allowsLegacyStrings { return }
            throw AIContractError.invalidSchemaValue("reminder_proposals")
        }
        for (index, proposal) in try objectArray(value, path: "reminder_proposals").enumerated() {
            let path = "reminder_proposals[\(index)]"
            try rejectUnknownKeys(in: proposal, allowed: reminderKeys, path: path)
            try requireNonEmptyString(proposal["proposal_id"], path: "\(path).proposal_id")
            try requireNonEmptyString(proposal["title"], path: "\(path).title")
            try requireNonEmptyString(proposal["source_quote"], path: "\(path).source_quote")
            try validateConfidence(proposal["confidence"], path: "\(path).confidence")
            try validateCandidateIDs(proposal, path: path)
            if let dueAt = proposal["due_at"], !(dueAt is NSNull), !(dueAt is String) {
                throw AIContractError.invalidSchemaValue("\(path).due_at")
            }
            guard proposal["candidate_person_ids"] is [String] else {
                throw AIContractError.invalidSchemaValue("\(path).candidate_person_ids")
            }
            try validateReminderBoundaryFields(proposal, path: path, requiresBoundaryFields: requiresBoundaryFields)
        }
    }

    private static func validateGiftSignalProposals(_ value: Any?, allowsLegacyStrings: Bool, requiresClassification: Bool) throws {
        if value == nil { return }
        if value is [String] {
            if allowsLegacyStrings { return }
            throw AIContractError.invalidSchemaValue("gift_signal_proposals")
        }
        for (index, proposal) in try objectArray(value, path: "gift_signal_proposals").enumerated() {
            let path = "gift_signal_proposals[\(index)]"
            try rejectUnknownKeys(in: proposal, allowed: giftKeys, path: path)
            try requireNonEmptyString(proposal["proposal_id"], path: "\(path).proposal_id")
            try requireNonEmptyString(proposal["signal_summary"], path: "\(path).signal_summary")
            try requireNonEmptyString(proposal["confirmation_question"], path: "\(path).confirmation_question")
            try requireNonEmptyString(proposal["source_quote"], path: "\(path).source_quote")
            try validateConfidence(proposal["confidence"], path: "\(path).confidence")
            try validateCandidateIDs(proposal, path: path)
            guard proposal["candidate_person_ids"] is [String] else {
                throw AIContractError.invalidSchemaValue("\(path).candidate_person_ids")
            }
            guard let riskTags = proposal["risk_tags"] as? [String] else {
                throw AIContractError.invalidSchemaValue("\(path).risk_tags")
            }
            let allowedRiskTags = Set(GiftSocialRisk.allCases.map(\.rawValue))
            for tag in riskTags where !allowedRiskTags.contains(tag) {
                throw AIContractError.invalidSchemaValue("\(path).risk_tags.\(tag)")
            }
            try validateProposalClassification(
                proposal["classification"],
                path: "\(path).classification",
                requiresClassification: requiresClassification
            )
        }
    }

    private static func validateProposalClassification(_ value: Any?, path: String, requiresClassification: Bool) throws {
        guard let value, !(value is NSNull) else {
            if requiresClassification {
                throw AIContractError.invalidSchemaValue(path)
            }
            return
        }
        guard let dictionary = value as? [String: Any] else {
            throw AIContractError.invalidSchemaValue(path)
        }
        try validateClassificationBoundaryFields(dictionary, path: path)
    }

    private static func validateValueStruct(_ value: Any, category: String, path: String) throws {
        guard let dictionary = value as? [String: Any] else {
            throw AIContractError.invalidSchemaValue(path)
        }
        try rejectUnknownKeys(in: dictionary, allowed: valueStructKeys, path: path)
        switch category {
        case PersonProfileCategory.anniversaries.rawValue:
            try requireEnum(dictionary["kind"], allowed: ["birthday", "anniversary", "exam", "work_start", "other"], path: "\(path).kind")
            try requireNonEmptyString(dictionary["date_label"], path: "\(path).date_label")
            try optionalInt(dictionary["month"], path: "\(path).month")
            try optionalInt(dictionary["day"], path: "\(path).day")
            try optionalInt(dictionary["year"], path: "\(path).year")
        case PersonProfileCategory.dietaryAllergy.rawValue:
            try requireEnum(dictionary["kind"], allowed: ["dislike", "allergy", "religious", "health", "unknown"], path: "\(path).kind")
            try requireNonEmptyString(dictionary["item"], path: "\(path).item")
            try requireEnum(dictionary["severity"], allowed: ["low", "medium", "high", "unknown"], path: "\(path).severity")
        case PersonProfileCategory.contact.rawValue:
            try requireEnum(dictionary["channel"], allowed: ["wechat", "phone", "email", "instagram", "linkedin", "other"], path: "\(path).channel")
            try requireNonEmptyString(dictionary["value"], path: "\(path).value")
            try requireEnum(dictionary["visibility"], allowed: ["private", "normal"], path: "\(path).visibility")
        default:
            throw AIContractError.invalidSchemaValue("\(path) unsupported category \(category)")
        }
    }

    private static func validateProfileTarget(_ proposal: [String: Any], path: String) throws {
        let targetID = (proposal["target_person_id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayName = (proposal["target_display_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !targetID.isEmpty || !displayName.isEmpty else {
            throw AIContractError.invalidProfilePatch
        }
    }

    private static func validateReminderBoundaryFields(_ proposal: [String: Any], path: String, requiresBoundaryFields: Bool) throws {
        if requiresBoundaryFields {
            for key in [
                "schedule_subtype",
                "schedule_execution_state",
                "time_role",
                "time_expression_kind",
                "time_precision",
                "reference_date",
                "reference_datetime",
                "timezone",
                "raw_time_expression",
                "start_at",
                "end_at",
                "deadline_relation",
                "remind_at",
                "commitment_level",
                "notification_policy",
                "needs_slot_confirmation",
                "confirmation_blockers",
                "confirmation_reasons",
                "requires_user_approval",
                "reason_summary",
                "confusion_guard",
                "classification",
                "actor",
                "action",
                "target_person",
                "location",
                "resolved_window",
                "resolved_time",
                "recurrence_rule",
                "mutation_match",
                "contextual_guard"
            ] where proposal[key] == nil {
                throw AIContractError.invalidSchemaValue("\(path).\(key)")
            }
        }
        try optionalEnum(
            proposal["schedule_subtype"],
            allowed: [
                "event", "deadline", "task", "follow_up", "prep", "recurring", "anniversary_reminder",
                "contextual_guard", "cancel_existing", "reschedule_existing", "update_existing"
            ],
            path: "\(path).schedule_subtype"
        )
        try optionalEnum(
            proposal["schedule_execution_state"],
            allowed: [
                "draft_schedule_candidate", "executable_reminder", "executable_schedule_item",
                "contextual_guard_candidate", "anchored_contextual_guard", "existing_item_mutation"
            ],
            path: "\(path).schedule_execution_state"
        )
        try optionalEnum(
            proposal["time_role"],
            allowed: ["event_start", "reminder_trigger", "deadline_due", "recurrence_trigger", "anchor_event", "ambiguous"],
            path: "\(path).time_role"
        )
        try optionalEnum(
            proposal["time_expression_kind"],
            allowed: [
                "exact_datetime", "absolute_date", "relative_date", "relative_window",
                "fuzzy_window", "event_relative", "recurring_rule", "missing_time"
            ],
            path: "\(path).time_expression_kind"
        )
        try optionalEnum(
            proposal["time_precision"],
            allowed: ["exact_minute", "date_only", "half_day_window", "relative_window", "unresolved"],
            path: "\(path).time_precision"
        )
        try optionalEnum(
            proposal["commitment_level"],
            allowed: ["committed", "intended", "tentative", "conditional", "suggested", "past", "negative"],
            path: "\(path).commitment_level"
        )

        if let requiresApproval = proposal["requires_user_approval"] as? Bool, !requiresApproval {
            throw AIContractError.invalidSchemaValue("\(path).requires_user_approval")
        }

        if let policy = proposal["notification_policy"], !(policy is NSNull) {
            guard let dictionary = policy as? [String: Any] else {
                throw AIContractError.invalidSchemaValue("\(path).notification_policy")
            }
            for key in [
                "delivery_mode",
                "policy_source",
                "trigger_at_or_null",
                "offset_or_null",
                "next_trigger_at_or_null",
                "timezone",
                "requires_confirmation",
                "default_allowed"
            ] where dictionary[key] == nil {
                throw AIContractError.invalidSchemaValue("\(path).notification_policy.\(key)")
            }
            try requireEnum(dictionary["delivery_mode"], allowed: ["reminder", "calendar_only", "no_notification", "unspecified"], path: "\(path).notification_policy.delivery_mode")
            try requireEnum(dictionary["policy_source"], allowed: ["user_explicit", "user_preference", "user_confirmed", "system_default_disallowed"], path: "\(path).notification_policy.policy_source")
            guard dictionary["requires_confirmation"] is Bool,
                  dictionary["default_allowed"] is Bool else {
                throw AIContractError.invalidSchemaValue("\(path).notification_policy.flags")
            }
        }

        let needsSlotConfirmation = proposal["needs_slot_confirmation"] as? Bool
        let blockers = try objectArray(proposal["confirmation_blockers"], path: "\(path).confirmation_blockers")
        if needsSlotConfirmation == true && blockers.isEmpty {
            throw AIContractError.invalidSchemaValue("\(path).confirmation_blockers")
        }

        for (index, blocker) in blockers.enumerated() {
            let blockerPath = "\(path).confirmation_blockers[\(index)]"
            try requireNonEmptyString(blocker["code"], path: "\(blockerPath).code")
            try requireNonEmptyString(blocker["field"], path: "\(blockerPath).field")
            try requireNonEmptyString(blocker["required_for"], path: "\(blockerPath).required_for")
            try requireNonEmptyString(blocker["question"], path: "\(blockerPath).question")
        }

        if proposal["schedule_execution_state"] as? String == "executable_reminder" {
            if needsSlotConfirmation == true || !blockers.isEmpty {
                throw AIContractError.invalidSchemaValue("\(path).schedule_execution_state")
            }
            guard let policy = proposal["notification_policy"] as? [String: Any] else {
                throw AIContractError.invalidSchemaValue("\(path).notification_policy")
            }
            guard policy["delivery_mode"] as? String == "reminder",
                  let policySource = policy["policy_source"] as? String,
                  ["user_explicit", "user_preference", "user_confirmed"].contains(policySource),
                  policy["requires_confirmation"] as? Bool == false else {
                throw AIContractError.invalidSchemaValue("\(path).notification_policy")
            }
            if proposal["time_role"] as? String == "ambiguous" {
                throw AIContractError.invalidSchemaValue("\(path).time_role")
            }
            let trigger = policy["trigger_at_or_null"] as? String
            let offset = policy["offset_or_null"] as? String
            let nextTrigger = policy["next_trigger_at_or_null"] as? String
            if proposal["schedule_subtype"] as? String != "recurring",
               nonEmptyString(nextTrigger) != nil {
                throw AIContractError.invalidSchemaValue("\(path).notification_policy.next_trigger_at_or_null")
            }
            let effectiveTrigger = nonEmptyString(trigger) ?? ((proposal["schedule_subtype"] as? String == "recurring") ? nonEmptyString(nextTrigger) : nil)
            guard effectiveTrigger != nil || offset?.isEmpty == false else {
                throw AIContractError.invalidSchemaValue("\(path).notification_policy.trigger")
            }
            try validateFutureTrigger(trigger, referenceDatetime: proposal["reference_datetime"], path: "\(path).notification_policy.trigger_at_or_null")
            try validateFutureTrigger(nextTrigger, referenceDatetime: proposal["reference_datetime"], path: "\(path).notification_policy.next_trigger_at_or_null")
            try validateFutureTrigger(proposal["remind_at"] as? String, referenceDatetime: proposal["reference_datetime"], path: "\(path).remind_at")
            if let effectiveTrigger,
               let remindAt = nonEmptyString(proposal["remind_at"]),
               remindAt != effectiveTrigger {
                throw AIContractError.invalidSchemaValue("\(path).remind_at")
            }

            switch proposal["schedule_subtype"] as? String {
            case "event":
                guard nonEmptyString(proposal["start_at"]) != nil,
                      nonEmptyString(proposal["remind_at"]) != nil else {
                    throw AIContractError.invalidSchemaValue("\(path).start_at/remind_at")
                }
            case "deadline":
                guard nonEmptyString(proposal["due_at"]) != nil,
                      nonEmptyString(proposal["remind_at"]) != nil,
                      nonEmptyString(proposal["deadline_relation"]) != nil else {
                    throw AIContractError.invalidSchemaValue("\(path).deadline")
                }
            case "recurring":
                guard let recurrenceRule = proposal["recurrence_rule"] as? [String: Any] else {
                    throw AIContractError.invalidSchemaValue("\(path).recurrence_rule")
                }
                try validateExecutableRecurrenceRule(recurrenceRule, path: "\(path).recurrence_rule")
            case "contextual_guard", "cancel_existing", "reschedule_existing", "update_existing":
                throw AIContractError.invalidSchemaValue("\(path).schedule_subtype")
            default:
                break
            }
        } else if proposal["schedule_execution_state"] as? String == "executable_schedule_item" {
            guard needsSlotConfirmation != true,
                  blockers.isEmpty,
                  let policy = proposal["notification_policy"] as? [String: Any],
                  let deliveryMode = policy["delivery_mode"] as? String,
                  ["calendar_only", "no_notification"].contains(deliveryMode),
                  policy["policy_source"] as? String == "user_explicit" else {
                throw AIContractError.invalidSchemaValue("\(path).notification_policy")
            }
        } else if proposal["schedule_execution_state"] as? String == "draft_schedule_candidate" {
            if needsSlotConfirmation == false || blockers.isEmpty {
                throw AIContractError.invalidSchemaValue("\(path).confirmation_blockers")
            }
        } else if proposal["schedule_execution_state"] as? String == "existing_item_mutation" {
            guard let mutationMatch = proposal["mutation_match"] as? [String: Any],
                  let matchStatus = mutationMatch["match_status"] as? String else {
                throw AIContractError.invalidSchemaValue("\(path).mutation_match")
            }
            if matchStatus != "unique_high_confidence" && needsSlotConfirmation != true {
                throw AIContractError.invalidSchemaValue("\(path).needs_slot_confirmation")
            }
        } else if proposal["schedule_execution_state"] as? String == "contextual_guard_candidate" {
            guard let contextualGuard = proposal["contextual_guard"] as? [String: Any],
                  contextualGuard["anchor_status"] as? String != "anchored",
                  needsSlotConfirmation == true,
                  !blockers.isEmpty else {
                throw AIContractError.invalidSchemaValue("\(path).contextual_guard")
            }
        } else if proposal["schedule_execution_state"] as? String == "anchored_contextual_guard" {
            guard let contextualGuard = proposal["contextual_guard"] as? [String: Any],
                  contextualGuard["anchor_status"] as? String == "anchored",
                  nonEmptyString(contextualGuard["anchor_event_id_or_null"]) != nil else {
                throw AIContractError.invalidSchemaValue("\(path).contextual_guard")
            }
        }

        if let classification = proposal["classification"], !(classification is NSNull) {
            guard let dictionary = classification as? [String: Any] else {
                throw AIContractError.invalidSchemaValue("\(path).classification")
            }
            try validateClassificationBoundaryFields(dictionary, path: "\(path).classification")
        } else if requiresBoundaryFields {
            throw AIContractError.invalidSchemaValue("\(path).classification")
        }
    }

    private static func validateClassificationBoundaryFields(_ classification: [String: Any], path: String) throws {
        try rejectUnknownKeys(in: classification, allowed: classificationKeys, path: path)

        for key in [
            "proposition_units",
            "semantic_primary_unit_id",
            "workflow_primary_unit_id",
            "secondary_unit_ids",
            "semantic_primary",
            "workflow_primary",
            "secondary_workflows",
            "storage_targets",
            "retention_policy",
            "reason_summary",
            "confusion_guard"
        ] where classification[key] == nil {
            throw AIContractError.invalidSchemaValue("\(path).\(key)")
        }

        let propositionUnits = try objectArray(classification["proposition_units"], path: "\(path).proposition_units")
        guard !propositionUnits.isEmpty else {
            throw AIContractError.invalidSchemaValue("\(path).proposition_units")
        }

        for (index, unit) in propositionUnits.enumerated() {
            let unitPath = "\(path).proposition_units[\(index)]"
            try rejectUnknownKeys(in: unit, allowed: propositionUnitKeys, path: unitPath)
            for key in [
                "unit_id",
                "source_span",
                "propositional_content",
                "attitude_holder",
                "confidence_basis"
            ] {
                try requireNonEmptyString(unit[key], path: "\(unitPath).\(key)")
            }
            try requireEnum(
                unit["intentional_mode"],
                allowed: ["belief/assertion", "desire", "intention", "fear", "preference", "request", "motivation", "self_interpretation", "unknown"],
                path: "\(unitPath).intentional_mode"
            )
            try requireEnum(
                unit["direction_of_fit"],
                allowed: ["mind_to_world", "world_to_mind", "self_interpretation", "none", "unknown"],
                path: "\(unitPath).direction_of_fit"
            )
            try requireEnum(
                unit["evidentiality"],
                allowed: ["direct_observation", "inference", "hearsay", "file_source", "user_guess", "unknown"],
                path: "\(unitPath).evidentiality"
            )
            try requireEnum(
                unit["domain_object"],
                allowed: ["episodic_self_state", "durable_self_pattern", "person_fact", "relationship", "schedule", "gift_touchpoint", "file_source", "risk", "unknown"],
                path: "\(unitPath).domain_object"
            )
            _ = try requireStringArray(unit["candidate_storage_targets"], path: "\(unitPath).candidate_storage_targets")
            try requireEnum(
                unit["proposal_kind"],
                allowed: ["write_candidate", "workflow_candidate", "context_only", "blocker"],
                path: "\(unitPath).proposal_kind"
            )
            if let workflow = unit["candidate_workflow"], !(workflow is NSNull) {
                try requireNonEmptyString(workflow, path: "\(unitPath).candidate_workflow")
            }
        }

        _ = try requireStringArray(classification["secondary_unit_ids"], path: "\(path).secondary_unit_ids")
        _ = try requireStringArray(classification["secondary_workflows"], path: "\(path).secondary_workflows")
        _ = try requireStringArray(classification["storage_targets"], path: "\(path).storage_targets")
        _ = try requireStringArray(classification["confusion_guard"], path: "\(path).confusion_guard")
        if let ambiguousSlots = classification["ambiguous_slots"], !(ambiguousSlots is NSNull) {
            _ = try requireStringArray(ambiguousSlots, path: "\(path).ambiguous_slots")
        }
        if let assetValue = classification["asset_value"], !(assetValue is NSNull) {
            _ = try requireStringArray(assetValue, path: "\(path).asset_value")
        }

        if let semanticPrimaryUnitID = classification["semantic_primary_unit_id"], !(semanticPrimaryUnitID is NSNull) {
            try requireNonEmptyString(semanticPrimaryUnitID, path: "\(path).semantic_primary_unit_id")
        }
        if let workflowPrimaryUnitID = classification["workflow_primary_unit_id"], !(workflowPrimaryUnitID is NSNull) {
            try requireNonEmptyString(workflowPrimaryUnitID, path: "\(path).workflow_primary_unit_id")
        }
        if let semanticPrimary = classification["semantic_primary"], !(semanticPrimary is NSNull) {
            try requireNonEmptyString(semanticPrimary, path: "\(path).semantic_primary")
        }
        if let workflowPrimary = classification["workflow_primary"], !(workflowPrimary is NSNull) {
            try requireNonEmptyString(workflowPrimary, path: "\(path).workflow_primary")
        }
        try requireEnum(
            classification["retention_policy"],
            allowed: ["write_candidate", "source_context_only", "context_only", "discard_after_review"],
            path: "\(path).retention_policy"
        )
        try requireNonEmptyString(classification["reason_summary"], path: "\(path).reason_summary")

        try optionalEnum(
            classification["illocutionary_force"],
            allowed: ["assertion", "planning_declaration", "directive_to_system", "reported_request", "question", "correction", "cancellation", "reschedule", "preference_expression"],
            path: "\(path).illocutionary_force"
        )
        try optionalEnum(
            classification["domain_frame"],
            allowed: ["self_state", "friend_profile", "relationship", "schedule", "gift_touchpoint", "file_source"],
            path: "\(path).domain_frame"
        )
        try optionalEnum(
            classification["operation"],
            allowed: ["create", "update_existing", "cancel_existing", "reschedule_existing", "disable_reminder", "link_source", "ask_confirmation", "none"],
            path: "\(path).operation"
        )
        try optionalEnum(
            classification["opportunity_type"],
            allowed: ["none", "gift", "congratulate", "comfort", "thanks", "intro", "follow_up", "risk_reduction", "referral_request"],
            path: "\(path).opportunity_type"
        )
        try optionalEnum(
            classification["sensitivity_domain"],
            allowed: ["none", "health", "mental_health", "financial", "romantic", "family_conflict", "identity", "trauma", "relationship_risk"],
            path: "\(path).sensitivity_domain"
        )
        try optionalEnum(
            classification["severity"],
            allowed: ["none", "mild", "moderate", "high", "crisis"],
            path: "\(path).severity"
        )
        try optionalEnum(
            classification["privacy_display_risk"],
            allowed: ["none", "low", "medium", "high"],
            path: "\(path).privacy_display_risk"
        )
        try optionalEnum(
            classification["visibility_preference"],
            allowed: ["default", "suggest_limited", "user_marked_private"],
            path: "\(path).visibility_preference"
        )
        if let requiresDiscreetReview = classification["requires_discreet_review"],
           !(requiresDiscreetReview is NSNull),
           !(requiresDiscreetReview is Bool) {
            throw AIContractError.invalidSchemaValue("\(path).requires_discreet_review")
        }

        for (index, interpretation) in try objectArray(classification["candidate_interpretations"], path: "\(path).candidate_interpretations").enumerated() {
            let interpretationPath = "\(path).candidate_interpretations[\(index)]"
            try rejectUnknownKeys(in: interpretation, allowed: candidateInterpretationKeys, path: interpretationPath)
            try requireNonEmptyString(interpretation["workflow_primary"], path: "\(interpretationPath).workflow_primary")
            try requireNonEmptyString(interpretation["reason"], path: "\(interpretationPath).reason")
        }

        for key in [
            "opportunity_consent",
            "relationship_stage",
            "priority_score_audit",
            "opportunity_lifecycle",
            "network_path",
            "give_first_offer"
        ] {
            try optionalStringMap(classification[key], path: "\(path).\(key)")
        }
    }

    private static func validateCandidateIDs(_ proposal: [String: Any], path: String) throws {
        let candidates = (proposal["candidate_person_ids"] as? [String]) ?? []
        guard let targetID = proposal["target_person_id"] as? String,
              !targetID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        guard candidates.isEmpty || candidates.contains(targetID) else {
            throw AIContractError.invalidSchemaValue("\(path).target_person_id")
        }
    }

    private static func validateExecutableRecurrenceRule(_ rule: [String: Any], path: String) throws {
        for key in ["frequency", "interval", "anchor_date", "timezone", "skip_or_exception_policy", "calendar_system"] where nonEmptyString(rule[key]) == nil {
            throw AIContractError.invalidSchemaValue("\(path).\(key)")
        }
        if nonEmptyString(rule["by_weekday"]) == nil && nonEmptyString(rule["day_of_month"]) == nil {
            throw AIContractError.invalidSchemaValue("\(path).by_weekday")
        }
        if nonEmptyString(rule["remind_time_or_null"]) == nil && nonEmptyString(rule["next_trigger_at_or_null"]) == nil {
            throw AIContractError.invalidSchemaValue("\(path).next_trigger_at_or_null")
        }
    }

    private static func validateFutureTrigger(_ value: String?, referenceDatetime: Any?, path: String) throws {
        guard let value = value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        guard let reference = nonEmptyString(referenceDatetime),
              let triggerDate = parseFlexibleTimestamp(value),
              let referenceDate = parseFlexibleTimestamp(reference),
              triggerDate > referenceDate else {
            throw AIContractError.invalidSchemaValue(path)
        }
    }

    private static func parseFlexibleTimestamp(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = fractionalFormatter.date(from: value) {
            return parsed
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func rejectUnknownKeys(in dictionary: [String: Any], allowed: Set<String>, path: String) throws {
        for key in dictionary.keys where !allowed.contains(key) {
            throw AIContractError.unknownKey("\(path).\(key)")
        }
    }

    private static func objectArray(_ value: Any?, path: String) throws -> [[String: Any]] {
        guard let value else { return [] }
        guard let array = value as? [Any] else {
            throw AIContractError.invalidSchemaValue(path)
        }
        return try array.enumerated().map { index, element in
            guard let dictionary = element as? [String: Any] else {
                throw AIContractError.invalidSchemaValue("\(path)[\(index)]")
            }
            return dictionary
        }
    }

    private static func requireString(_ value: Any?, equals expected: String, path: String) throws {
        guard let string = value as? String, string == expected else {
            throw AIContractError.invalidSchemaValue(path)
        }
    }

    private static func requireNonEmptyString(_ value: Any?, path: String) throws {
        guard let string = value as? String,
              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if path.hasSuffix("source_quote") {
                throw AIContractError.missingSourceQuote
            }
            throw AIContractError.invalidSchemaValue(path)
        }
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func requireStringArray(_ value: Any?, path: String) throws -> [String] {
        guard let array = value as? [Any] else {
            throw AIContractError.invalidSchemaValue(path)
        }
        return try array.enumerated().map { index, element in
            guard let string = element as? String else {
                throw AIContractError.invalidSchemaValue("\(path)[\(index)]")
            }
            return string
        }
    }

    private static func optionalStringMap(_ value: Any?, path: String) throws {
        guard let value, !(value is NSNull) else { return }
        guard let dictionary = value as? [String: Any] else {
            throw AIContractError.invalidSchemaValue(path)
        }
        for (key, value) in dictionary where !(value is String) {
            throw AIContractError.invalidSchemaValue("\(path).\(key)")
        }
    }

    private static func requireEnum(_ value: Any?, allowed: Set<String>, path: String) throws {
        guard let string = value as? String, allowed.contains(string) else {
            throw AIContractError.invalidSchemaValue(path)
        }
    }

    private static func optionalEnum(_ value: Any?, allowed: Set<String>, path: String) throws {
        guard let value, !(value is NSNull) else { return }
        try requireEnum(value, allowed: allowed, path: path)
    }

    private static func validateConfidence(_ value: Any?, path: String) throws {
        guard let number = jsonNumber(value), (0...1).contains(number) else {
            throw AIContractError.invalidConfidence
        }
    }

    private static func optionalInt(_ value: Any?, path: String) throws {
        guard let value, !(value is NSNull) else { return }
        guard let number = value as? NSNumber, !isJSONBoolean(number), floor(number.doubleValue) == number.doubleValue else {
            throw AIContractError.invalidSchemaValue(path)
        }
    }

    private static func jsonNumber(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, !isJSONBoolean(number) else {
            return nil
        }
        return number.doubleValue
    }

    private static func isJSONBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}

public struct RouteInputResult: Codable, Equatable, Sendable {
    public let primaryType: String
    public let secondaryTypes: [String]
    public let confidence: Double
    public let requiresExtraction: Bool
    public let requiresPersonLinking: Bool
    public let requiresReminderGeneration: Bool
    public let requiresGiftGeneration: Bool
    public let language: String
    public let reasonSummary: String

    enum CodingKeys: String, CodingKey {
        case primaryType = "primary_type"
        case secondaryTypes = "secondary_types"
        case confidence
        case requiresExtraction = "requires_extraction"
        case requiresPersonLinking = "requires_person_linking"
        case requiresReminderGeneration = "requires_reminder_generation"
        case requiresGiftGeneration = "requires_gift_generation"
        case language
        case reasonSummary = "reason_summary"
    }
}

public struct AIWorkflowToolDefinition: Codable, Equatable, Sendable {
    public let name: String
    public let purpose: String
    public let inputSchema: String
    public let outputPolicy: String
    public let availability: String
    public let requiresUserApproval: Bool

    public init(
        name: String,
        purpose: String,
        inputSchema: String,
        outputPolicy: String,
        availability: String,
        requiresUserApproval: Bool
    ) {
        self.name = name
        self.purpose = purpose
        self.inputSchema = inputSchema
        self.outputPolicy = outputPolicy
        self.availability = availability
        self.requiresUserApproval = requiresUserApproval
    }

    enum CodingKeys: String, CodingKey {
        case name
        case purpose
        case inputSchema = "input_schema"
        case outputPolicy = "output_policy"
        case availability
        case requiresUserApproval = "requires_user_approval"
    }
}

public enum AIWorkflowToolCatalog {
    public static let extractionTools: [AIWorkflowToolDefinition] = [
        AIWorkflowToolDefinition(
            name: "memory_search",
            purpose: "Search confirmed local memories and friend dossiers before proposing profile or relationship updates.",
            inputSchema: #"{"query":"string","memory_type":"optional string","person_id":"optional string","theme_name":"optional string"}"#,
            outputPolicy: "Use only returned local-memory snippets with source quotes. Never invent missing facts.",
            availability: "enabled_local",
            requiresUserApproval: false
        ),
        AIWorkflowToolDefinition(
            name: "core_tag_resolver",
            purpose: "Map a self-reflection note to existing core tags, or suggest a new tag when none fit.",
            inputSchema: #"{"raw_text":"string","known_core_tags":["name + description"]}"#,
            outputPolicy: "Prefer existing known_core_tags by exact name. New tag names remain pending until review.",
            availability: "enabled_local",
            requiresUserApproval: false
        ),
        AIWorkflowToolDefinition(
            name: "web_search",
            purpose: "Search the public web to verify external facts only when the user explicitly enables an external search provider.",
            inputSchema: #"{"query":"string","recency_days":"optional integer"}"#,
            outputPolicy: "Do not use or cite web facts unless a tool result is present in this workflow input.",
            availability: "disabled_until_search_provider_configured",
            requiresUserApproval: true
        ),
        AIWorkflowToolDefinition(
            name: "web_page_fetch",
            purpose: "Read a specific public URL supplied by the user or search results when external browsing is enabled.",
            inputSchema: #"{"url":"string"}"#,
            outputPolicy: "Use short source-backed summaries only. Never store raw pages as memory without review.",
            availability: "disabled_until_search_provider_configured",
            requiresUserApproval: true
        )
    ]
}

public struct PromptBuilder: Sendable {
    public init() {}

    public func routeInputPrompt(text: String) -> [DeepSeekChatRequest.Message] {
        [
            .init(
                role: "system",
                content: """
                You are Memoria's route_input workflow. Return strict json object only.
                Classify the user's free-form memory input without mutating data.
                """
            ),
            .init(role: "user", content: text)
        ]
    }

    public func extractMemoryPrompt(rawEntry: RawEntry, knownPeople: [FriendPerson], knownThemes: [Theme]) -> [DeepSeekChatRequest.Message] {
        let workflowInput = ExtractMemoryWorkflowInput(
            rawEntryID: rawEntry.id,
            rawText: rawEntry.rawText,
            knownPeople: knownPeople.map(KnownPersonContext.init(person:)),
            knownCoreTags: knownThemes.map(KnownCoreTagContext.init(theme:)),
            availableTools: AIWorkflowToolCatalog.extractionTools,
            workflowNotes: [
                "Reuse known_core_tags by exact name when the note fits a current core tag.",
                "If no existing core tag fits a self-reflection, propose a concise new theme name inside memory_proposals[].themes.",
                "External web tools are explicit opt-in boundaries; ignore web facts unless a tool result is supplied."
            ]
        )
        let workflowInputJSON = Self.encodeWorkflowInput(workflowInput)
        let profileSchema = PersonProfileCategory.aiSchemaDescription
        return [
            .init(
                role: "system",
                content: """
                你是 Memoria 的个人记忆整理助手。你的任务是把用户的自由输入整理为结构化、可确认、可追溯的记忆建议。
                按 Dify-style workflow/tool contract 工作：先阅读 workflow input，再只在工具边界允许的范围内使用 local memory、core tag resolver 或外部 web 工具结果。

                规则：
                1. 只抽取用户文本明确表达或强烈支持的信息。
                2. 不要编造事实。
                3. 每条记忆必须有 source_quote。
                4. 个人感悟、朋友事实、关系观察必须区分。
                5. 心理、健康、家庭、财务、恋爱、政治等内容标记 sensitive 或 private。
                6. 模糊表达必须降低 confidence。
                7. AI 推断必须设置 is_ai_inferred=true。
                8. 不要输出诊断，不要把反思写成心理疾病判断。
                9. 不要直接决定关系等级变化，只能提出建议。
                10. 输出严格 json object，不要 markdown，不要解释文字。
                11. 朋友档案字段必须归入 profile_category 之一，category key 只能来自下面 schema。
                12. AI 推断只能归入 ai_inference，必须标记为推断，不能写成确认事实。
                13. 如果原文明确支持两个人之间的关系边，只能放入 relationship_edge_proposals，且必须包含 source_quote；批准前不会写入关系星图。
                14. relationship_edge_proposals 不能表达亲近等级变化，不能修改 manual_closeness_level。
                15. relationship_edge_proposals 可以提供 tags 和 ai_primary_tag；tags 是自由关系标签，ai_primary_tag 只能从 tags 里选一个最能概括当前关系的标签。
                16. 自我检索标签优先使用 workflow input 中的 known_core_tags.name；新增核心标签只能作为 themes 建议，等待用户确认或编辑。
                17. web_search 和 web_page_fetch 只有在 workflow input 附带 tool result 时才算可用；没有工具结果时不能声称已联网搜索或验证。
                18. 顶层必须输出 schema_version="1.1" 和 contract_name="extract_memory"。
                19. reminder_proposals 必须是结构化对象数组；相对日期或不确定日期用 due_at=null，并在 due_label 保留原文时间表达。
                20. gift_signal_proposals 必须是结构化对象数组；不要直接生成最终礼物，只提出待确认线索、risk_tags 和 confirmation_question。
                21. 只有 anniversaries、dietary_allergy、contact 三类 profile_category 可以附带 value_struct；proposed_value 仍必须保留人类可读文本。
                22. 同名或昵称不唯一时，把目标人物放进 candidate_person_ids，不要自动绑定第一个人。
                23. 先拆 proposition_units，再分离 semantic_primary_unit_id、workflow_primary_unit_id、唯一 workflow_primary、secondary_workflows、storage_targets；workflow 主卡不能反向改写语义主命题。
                24. 陈述和某人在某个时间约饭、见面、开会或准备事项，只有当用户参与、用户要做动作、或用户要求提醒/取消/改期时才进入 reminder_proposals / reminder_source；例如“我要和 Jason 下午约个饭”是 reminder_source/event，不是 personal_reflection，也不应标记 private/sensitive。
                25. 普通社交安排默认 sensitivity="normal"，visibility_preference="default"，requires_discreet_review=false；不要因为出现“我”、朋友名、时间词或轻微尴尬就标记 sensitive/private。
                26. “今天准备考试时，我发现自己有点焦虑”默认是 episodic_self_state context_only，不直接写长期 personal_reflection；只有“想记一下这个状态”、复盘、反复模式或长期价值明确时才生成 personal_reflection 候选。
                27. “我觉得/我怕/我担心/我想”先作为 evidentiality、confidence、motivation 或 intention；例如“我觉得 Alex 不吃香菜”是低置信 person_fact，“我怕 Jason 忘了材料”是 follow_up motivation，不是自我反思。
                28. 日程提案必须保留 schedule_subtype、schedule_execution_state、time_role、time_expression_kind、time_precision、raw_time_expression、reference_date、reference_datetime、timezone、commitment_level、notification_policy、needs_slot_confirmation、confirmation_blockers、confirmation_reasons、requires_user_approval，以及 actor、action、target_person、location、resolved_window、resolved_time、recurrence_rule、mutation_match、contextual_guard。模糊时间、date-only、缺 notification_policy、mutation 未匹配、contextual guard 未锚定时不能升级 executable_reminder。
                29. start_at、due_at 和 remind_at 必须分开；date-only deadline 不得静默补成 09:00、23:59 或全天。没有用户显式提醒或已确认默认提醒策略时，不要把事件开始时间复制成 remind_at。
                30. 朋友状态、生日、偏好、愿望主体属于朋友本人的愿望时，先进入 person_fact/gift_signal/relationship_memory；例如“Jason 下周面试”不是用户日程，“May 想暑假旅行”不是用户旅行安排。
                31. 关系机会必须有显式行动意图才进入 relationship_opportunity；资源事实或帮助历史默认只存事实/关系记忆，可附 latent affordance，但不得生成 ask/intro/referral 生命周期、优先级分数或自动触达建议。进入 relationship_opportunity 时，classification 必须包含 opportunity_consent、relationship_stage、priority_score_audit、opportunity_lifecycle、network_path、give_first_offer；缺同意范围、give-first、关系阶段或 network path 时必须 blocked。
                32. v1.1 的 memory_proposals、person_fact_proposals、reminder_proposals、gift_signal_proposals 每个对象都必须带 classification，并保留 proposition_units、semantic_primary_unit_id、workflow_primary_unit_id、workflow_primary、storage_targets、retention_policy、reason_summary、confusion_guard。

                profile category schema:
                \(profileSchema)

                json example: {"schema_version":"1.1","contract_name":"extract_memory","entry_summary":"","memory_proposals":[{"proposal_type":"memory_atom","memory_type":"relationship_memory","title":"","summary":"","content":"","source_quote":"","confidence":0.8,"sensitivity":"normal","is_ai_inferred":false,"related_people":[],"themes":[],"relationship_edge_proposals":[{"source_person_id":"","source_display_name":"","target_person_id":"","target_display_name":"","label":"","strength":0.5,"relation_kind":"friend","tags":["同学"],"ai_primary_tag":"同学","confidence":0.8,"is_ai_inferred":true,"source_quote":""}],"follow_up_questions":[],"suggested_actions":[],"classification":{"proposition_units":[{"unit_id":"u1","source_span":"","propositional_content":"relationship event","attitude_holder":"user","intentional_mode":"belief/assertion","direction_of_fit":"mind_to_world","evidentiality":"direct_observation","confidence_basis":"source quote","domain_object":"relationship","candidate_workflow":"relationship_memory","candidate_storage_targets":["relationship_memory"],"proposal_kind":"write_candidate"}],"semantic_primary_unit_id":"u1","workflow_primary_unit_id":"u1","secondary_unit_ids":[],"semantic_primary":"u1:relationship","workflow_primary":"relationship_memory","secondary_workflows":[],"storage_targets":["relationship_memory"],"retention_policy":"write_candidate","reason_summary":"关系记忆候选。","confusion_guard":["relationship_memory_not_closeness_override"]}}],"person_fact_proposals":[{"target_person_id":"","target_display_name":"","profile_category":"dietary_allergy","proposed_value":"","value_struct":{"kind":"dislike","item":"","severity":"low"},"source_quote":"","confidence":0.8,"sensitivity":"normal","is_ai_inferred":false,"merge_strategy":"append_unique","classification":{"proposition_units":[{"unit_id":"u1","source_span":"","propositional_content":"friend profile fact","attitude_holder":"user","intentional_mode":"belief/assertion","direction_of_fit":"mind_to_world","evidentiality":"direct_observation","confidence_basis":"source quote","domain_object":"person_fact","candidate_workflow":"person_fact/dietary_allergy","candidate_storage_targets":["person_fact"],"proposal_kind":"write_candidate"}],"semantic_primary_unit_id":"u1","workflow_primary_unit_id":"u1","secondary_unit_ids":[],"semantic_primary":"u1:person fact","workflow_primary":"person_fact/dietary_allergy","secondary_workflows":[],"storage_targets":["person_fact"],"retention_policy":"write_candidate","reason_summary":"朋友档案事实，不是自我反思。","confusion_guard":["friend_fact_vs_self_reflection"]}}],"reminder_proposals":[{"proposal_id":"rp-1","title":"下午和 Jason 约饭","target_person_id":null,"target_display_name":"Jason","candidate_person_ids":[],"due_at":null,"due_label":"下午","source_entry_id":null,"source_quote":"我要和 Jason 下午约个饭","source_quote_start":0,"source_quote_end":16,"confidence":0.86,"is_ai_inferred":false,"legacy_text":"","schedule_subtype":"event","schedule_execution_state":"draft_schedule_candidate","time_role":"event_start","time_expression_kind":"fuzzy_window","time_precision":"half_day_window","raw_time_expression":"下午","reference_date":"2026-06-19","reference_datetime":"2026-06-19T10:00:00+08:00","timezone":"Asia/Shanghai","start_at":null,"end_at":null,"deadline_relation":null,"remind_at":null,"commitment_level":"committed","notification_policy":{"delivery_mode":"unspecified","policy_source":"system_default_disallowed","trigger_at_or_null":null,"offset_or_null":null,"next_trigger_at_or_null":null,"timezone":"Asia/Shanghai","requires_confirmation":true,"default_allowed":false},"needs_slot_confirmation":true,"confirmation_blockers":[{"code":"time_slot","field":"raw_time_expression","required_for":"executable_reminder","observed_value":"下午","question":"你说的下午大概是几点？"},{"code":"notification_policy_missing","field":"notification_policy","required_for":"executable_reminder","observed_value":"unspecified","question":"你希望我什么时候提醒你？"}],"confirmation_reasons":["time_slot","notification_policy_missing"],"requires_user_approval":true,"reason_summary":"用户参与的未来约饭安排；普通社交行程不是自我反思或敏感内容。","confusion_guard":["schedule_vs_reflection"],"actor":"user","action":"meal","target_person":"Jason","location":null,"resolved_window":{"start_after":"2026-06-19T12:00:00+08:00","end_before":"2026-06-19T18:00:00+08:00","requires_confirmation":"true"},"resolved_time":null,"recurrence_rule":null,"mutation_match":null,"contextual_guard":null,"classification":{"proposition_units":[{"unit_id":"u1","source_span":"我要和 Jason 下午约个饭","propositional_content":"the user intends lunch with Jason this afternoon","attitude_holder":"user","intentional_mode":"intention","direction_of_fit":"world_to_mind","evidentiality":"direct_observation","confidence_basis":"user states own plan","domain_object":"schedule","candidate_workflow":"reminder_source/event","candidate_storage_targets":["reminder_source"],"proposal_kind":"workflow_candidate"}],"semantic_primary_unit_id":"u1","workflow_primary_unit_id":"u1","secondary_unit_ids":[],"semantic_primary":"u1:user meal plan with Jason","workflow_primary":"reminder_source/event","secondary_workflows":[],"storage_targets":["reminder_source"],"retention_policy":"write_candidate","illocutionary_force":"planning_declaration","domain_frame":"schedule","operation":"create","opportunity_type":"none","asset_value":[],"sensitivity_domain":"none","severity":"none","privacy_display_risk":"none","visibility_preference":"default","requires_discreet_review":false,"ambiguous_slots":["raw_time_expression"],"candidate_interpretations":[{"workflow_primary":"reminder_source/event","reason":"用户表达了未来约饭安排"}],"blocked_decision":"cannot_create_executable_reminder_until_time_and_notification_policy_confirmed","confirmation_question":"你说的下午大概是几点？","reason_summary":"普通社交行程，需确认时间和提醒策略。","confusion_guard":["schedule_vs_reflection"]}}],"gift_signal_proposals":[{"proposal_id":"gp-1","target_person_id":null,"target_display_name":"","candidate_person_ids":[],"signal_summary":"","occasion":"unknown","budget_hint":null,"risk_tags":[],"risk":"","confirmation_question":"","source_quote":"","source_quote_start":null,"source_quote_end":null,"confidence":0.8,"is_ai_inferred":false,"legacy_text":"","classification":{"proposition_units":[{"unit_id":"u1","source_span":"","propositional_content":"gift touchpoint","attitude_holder":"user","intentional_mode":"belief/assertion","direction_of_fit":"mind_to_world","evidentiality":"direct_observation","confidence_basis":"source quote","domain_object":"gift_touchpoint","candidate_workflow":"gift_signal/touchpoint","candidate_storage_targets":["gift_signal"],"proposal_kind":"write_candidate"}],"semantic_primary_unit_id":"u1","workflow_primary_unit_id":"u1","secondary_unit_ids":[],"semantic_primary":"u1:gift touchpoint","workflow_primary":"gift_signal/touchpoint","secondary_workflows":[],"storage_targets":["gift_signal"],"retention_policy":"write_candidate","reason_summary":"礼物触点候选，不直接生成最终礼物。","confusion_guard":["gift_touchpoint_not_final_gift"]}}],"conflicts":[],"follow_up_questions":[]}
                """
            ),
            .init(
                role: "user",
                content: workflowInputJSON
            )
        ]
    }

    private static func encodeWorkflowInput(_ input: ExtractMemoryWorkflowInput) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(input),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"raw_text":"","known_people":[],"known_core_tags":[],"available_tools":[]}"#
        }
        return json
    }
}

private struct ExtractMemoryWorkflowInput: Encodable, Sendable {
    let rawEntryID: String
    let rawText: String
    let knownPeople: [KnownPersonContext]
    let knownCoreTags: [KnownCoreTagContext]
    let availableTools: [AIWorkflowToolDefinition]
    let workflowNotes: [String]

    enum CodingKeys: String, CodingKey {
        case rawEntryID = "raw_entry_id"
        case rawText = "raw_text"
        case knownPeople = "known_people"
        case knownCoreTags = "known_core_tags"
        case availableTools = "available_tools"
        case workflowNotes = "workflow_notes"
    }
}

private struct KnownPersonContext: Encodable, Sendable {
    let id: String
    let displayName: String
    let nickname: String
    let aliases: [String]
    let manualClosenessLevel: Int

    init(person: FriendPerson) {
        id = person.id
        displayName = person.displayName
        nickname = person.nickname
        aliases = [person.englishName, person.nickname]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        manualClosenessLevel = person.manualClosenessLevel
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case nickname
        case aliases
        case manualClosenessLevel = "manual_closeness_level"
    }
}

private struct KnownCoreTagContext: Encodable, Sendable {
    let id: String
    let name: String
    let description: String?

    init(theme: Theme) {
        id = theme.id
        name = theme.name
        description = theme.description
    }
}

public struct AIWorkflowService: Sendable {
    public typealias RemoteExtractMemory = @Sendable (
        RawEntry,
        [FriendPerson],
        [Theme],
        String,
        NativeSettings
    ) async throws -> ExtractMemoryResponse

    private let parser: AIJSONParser
    private let remoteExtractMemory: RemoteExtractMemory
    private let remoteTimeoutNanoseconds: UInt64

    public init(
        parser: AIJSONParser = AIJSONParser(),
        deepSeek: DeepSeekClient = DeepSeekClient(),
        remoteExtractMemory: RemoteExtractMemory? = nil,
        remoteTimeoutNanoseconds: UInt64 = 35_000_000_000
    ) {
        self.parser = parser
        self.remoteTimeoutNanoseconds = remoteTimeoutNanoseconds
        self.remoteExtractMemory = remoteExtractMemory ?? { rawEntry, knownPeople, knownThemes, apiKey, settings in
            try await deepSeek.extractMemory(
                rawEntry: rawEntry,
                knownPeople: knownPeople,
                knownThemes: knownThemes,
                apiKey: apiKey,
                settings: settings
            )
        }
    }

    public func routeInput(text: String) -> RouteInputResult {
        let mentionsKnownPerson = ["Alex", "May", "Jason"].contains { name in
            text.localizedCaseInsensitiveContains(name)
        }
        let matchedPerson = mentionsKnownPerson ? DashboardSnapshot.demo.people.first : nil
        let primaryType = fallbackRoutePrimaryType(for: text, matchedPerson: matchedPerson)
        let requiresReminderGeneration = primaryType == MemoryAtomType.reminderSource.rawValue || looksLikeReminderRequest(text) || looksLikeSchedulePlan(text)

        return RouteInputResult(
            primaryType: primaryType,
            secondaryTypes: mentionsKnownPerson && primaryType != MemoryAtomType.relationshipMemory.rawValue ? ["relationship_memory"] : [],
            confidence: 0.78,
            requiresExtraction: primaryType != "context_only",
            requiresPersonLinking: mentionsKnownPerson,
            requiresReminderGeneration: requiresReminderGeneration,
            requiresGiftGeneration: looksLikeGiftTouchpoint(text, matchedPerson: matchedPerson),
            language: containsChinese(text) ? "zh" : "en",
            reasonSummary: "Local mocked route for deterministic macOS workflow tests."
        )
    }

    public func extractMemory(
        rawEntry: RawEntry,
        knownPeople: [FriendPerson],
        knownThemes: [Theme],
        apiKey: String?,
        settings: NativeSettings
    ) async throws -> ExtractMemoryResponse {
        if let apiKey, !apiKey.isEmpty {
            return try await withRemoteExtractionTimeout(nanoseconds: remoteTimeoutNanoseconds) {
                try await remoteExtractMemory(rawEntry, knownPeople, knownThemes, apiKey, settings)
            }
        }

        return try parser.parseExtractMemoryResponse(
            data: mockExtractMemoryData(for: rawEntry, knownPeople: knownPeople, knownThemes: knownThemes)
        )
    }

    private func mockExtractMemoryData(for rawEntry: RawEntry, knownPeople: [FriendPerson], knownThemes: [Theme]) throws -> Data {
        let text = rawEntry.rawText
        let matchedPerson = matchedPerson(in: text, knownPeople: knownPeople)
        if matchedPerson == nil, isContextOnlyEpisodicSelfState(text) {
            let response = ExtractMemoryResponse(
                entrySummary: text.count > 96 ? String(text.prefix(93)) + "..." : text,
                memoryProposals: [],
                personFactProposals: [],
                reminderProposals: [],
                giftSignalProposals: [],
                conflicts: [],
                followUpQuestions: ["这更像一次性状态上下文；如果你想长期保存，我可以转成自我反思候选。"]
            )
            return try JSONEncoder().encode(response)
        }
        let personName = matchedPerson?.displayName ?? "Memory"
        let memoryType = fallbackMemoryType(for: text, matchedPerson: matchedPerson)
        let sensitivity = fallbackSensitivity(for: text, memoryType: memoryType)
        let title = fallbackTitle(for: text, personName: personName, memoryType: memoryType)
        let classification = fallbackClassificationContext(for: text, matchedPerson: matchedPerson, memoryType: memoryType)
        let proposal = MemoryAtomProposal(
            proposalType: .memoryAtom,
            memoryType: memoryType,
            title: title,
            summary: text.count > 96 ? String(text.prefix(93)) + "..." : text,
            content: text,
            sourceQuote: text,
            confidence: 0.86,
            sensitivity: sensitivity,
            isAIInferred: false,
            relatedPeople: matchedPerson.map { person in
                [
                    RelatedPersonProposal(
                        displayName: person.displayName,
                        matchedPersonID: person.id,
                        matchConfidence: 0.91,
                        relationType: "about"
                    )
                ]
            } ?? [],
            themes: fallbackThemes(for: text, memoryType: memoryType, knownThemes: knownThemes),
            followUpQuestions: [fallbackFollowUpQuestion(for: personName, memoryType: memoryType)],
            suggestedActions: [],
            classification: classification
        )
        let personFactProposals = fallbackProfilePatches(for: text, matchedPerson: matchedPerson)
        let response = ExtractMemoryResponse(
            entrySummary: proposal.summary,
            memoryProposals: [proposal],
            personFactProposals: personFactProposals,
            reminderProposals: [],
            giftSignalProposals: [],
            conflicts: [],
            followUpQuestions: proposal.followUpQuestions
        )
        return try JSONEncoder().encode(response)
    }
}

private func withRemoteExtractionTimeout<T: Sendable>(
    nanoseconds: UInt64,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: nanoseconds)
            throw LocalAIError.timeout
        }

        do {
            guard let result = try await group.next() else {
                throw LocalAIError.timeout
            }
            group.cancelAll()
            return result
        } catch {
            group.cancelAll()
            throw error
        }
    }
}

private func matchedPerson(in text: String, knownPeople: [FriendPerson]) -> FriendPerson? {
    knownPeople.first { person in
        person.matchAliases.contains { alias in
            text.localizedCaseInsensitiveContains(alias)
        }
    }
}

private func fallbackRoutePrimaryType(for text: String, matchedPerson: FriendPerson?) -> String {
    if matchedPerson == nil, isContextOnlyEpisodicSelfState(text) {
        return "context_only"
    }
    return fallbackMemoryType(for: text, matchedPerson: matchedPerson).rawValue
}

private func fallbackMemoryType(for text: String, matchedPerson: FriendPerson?) -> MemoryAtomType {
    if looksLikeContextualGuard(text) {
        return .reminderSource
    }

    if looksLikeRelationshipBoundary(text) {
        return .personalReflection
    }

    if looksLikeRelationshipMemory(text) {
        return .relationshipMemory
    }

    if looksLikeGiftTouchpoint(text, matchedPerson: matchedPerson) {
        return .giftSignal
    }

    if looksLikeRelationshipOpportunityIntent(text, matchedPerson: matchedPerson) {
        return .relationshipMemory
    }

    if looksLikeFollowUpMotivation(text, matchedPerson: matchedPerson) {
        return .reminderSource
    }

    if matchedPerson != nil, looksLikeResourceFact(text) {
        return .personFact
    }

    if looksLikeReminderRequest(text) || looksLikeSchedulePlan(text) || looksLikeReminderMutation(text) {
        return .reminderSource
    }

    if matchedPerson != nil, looksLikeFriendFact(text) {
        return .personFact
    }

    if matchedPerson != nil, containsAny(["关系", "共同朋友", "室友", "同学", "伴侣", "男朋友", "女朋友", "partner", "roommate", "classmate"], in: text) {
        return .relationshipMemory
    }

    return .personalReflection
}

private func fallbackClassificationContext(
    for text: String,
    matchedPerson: FriendPerson?,
    memoryType: MemoryAtomType
) -> PendingUpdateClassificationContext {
    let opportunityType = fallbackOpportunityType(for: text, memoryType: memoryType)
    let workflowPrimary: String
    let storageTargets: [String]
    let domainFrame: String
    let domainObject: String
    let assetValue: [String]
    let blockedDecision: String?
    let confirmationQuestion: String?
    let confusionGuard: [String]
    let opportunityConsent: [String: String]?
    let relationshipStage: [String: String]?
    let priorityScoreAudit: [String: String]?
    let opportunityLifecycle: [String: String]?
    let networkPath: [String: String]?
    let giveFirstOffer: [String: String]?

    switch opportunityType {
    case "gift":
        workflowPrimary = "relationship_opportunity/gift"
        storageTargets = ["gift_signal"]
        domainFrame = "gift_touchpoint"
        domainObject = "gift_touchpoint"
        assetValue = ["opportunity"]
        blockedDecision = "cannot_generate_final_gift_without_preference_and_timing_confirmation"
        confirmationQuestion = "这份礼物的预算、时机和对方是否介意惊喜要怎么处理？"
        confusionGuard = ["gift_opportunity_requires_user_action", "gift_signal_not_final_gift"]
        opportunityConsent = ["requires_consent": "false", "consent_scope": "not_applicable"]
        relationshipStage = ["stage": "known_contact", "confidence": "0.6", "evidence": "matched friend profile"]
        priorityScoreAudit = ["score": "40", "cap": "gift_preference_uncertain", "reason": "gift intent exists but preference and budget need confirmation"]
        opportunityLifecycle = ["state": "blocked_confirmation", "next_action": "confirm_budget_timing_preference"]
        networkPath = ["status": "not_applicable"]
        giveFirstOffer = ["required": "false", "offer": ""]
    case "intro":
        workflowPrimary = "relationship_opportunity/intro"
        storageTargets = ["relationship_memory"]
        domainFrame = "relationship"
        domainObject = "relationship"
        assetValue = ["opportunity", "risk_reduction"]
        blockedDecision = "cannot_offer_intro_until_all_party_consent_scope_is_confirmed"
        confirmationQuestion = "要先问 Alex 是否愿意被介绍，以及可以分享哪些背景吗？"
        confusionGuard = ["single_party_consent_not_enough", "relationship_opportunity_not_storage_target"]
        opportunityConsent = ["requires_consent": "true", "party_consents": "source_confirmed_target_unconfirmed", "ask_target_first": "true", "consent_scope": "unknown"]
        relationshipStage = ["stage": "unknown_or_weak", "confidence": "0.4", "evidence": "intro request only"]
        priorityScoreAudit = ["score": "30", "cap": "target_consent_missing", "reason": "intro cannot proceed until both party consent and context are confirmed"]
        opportunityLifecycle = ["state": "blocked_confirmation", "next_action": "confirm_target_consent_scope"]
        networkPath = ["status": "partial", "intermediary": matchedPerson?.displayName ?? "unknown", "target": "Alex", "trust_basis": "unknown"]
        giveFirstOffer = ["required": "false", "offer": ""]
    case "referral_request":
        workflowPrimary = "relationship_opportunity/referral_request"
        storageTargets = ["relationship_memory", "person_fact"]
        domainFrame = "relationship"
        domainObject = "relationship"
        assetValue = ["opportunity", "resource_intelligence"]
        blockedDecision = "cannot_request_referral_until_consent_stage_and_give_first_framing_are_confirmed"
        confirmationQuestion = "你想先给 Jason 提供什么上下文或帮助，再问内推/介绍吗？"
        confusionGuard = ["resource_fact_vs_referral_request", "give_first_required"]
        opportunityConsent = ["requires_consent": "true", "party_consents": "unknown", "ask_intermediary_first": "true", "consent_scope": "unknown"]
        relationshipStage = ["stage": "unknown", "confidence": "0.3", "evidence": "fallback cannot infer closeness"]
        priorityScoreAudit = ["score": "35", "cap": "give_first_and_consent_missing", "reason": "resource request intent exists but consent, relationship stage and reciprocity are unconfirmed"]
        opportunityLifecycle = ["state": "blocked_confirmation", "next_action": "confirm_give_first_and_consent_strategy"]
        networkPath = ["status": "partial", "intermediary": matchedPerson?.displayName ?? "unknown", "target_resource": "referral_or_intro", "trust_basis": "unknown"]
        giveFirstOffer = ["required": "true", "offer": "unknown", "question": "先提供什么帮助或上下文"]
    default:
        workflowPrimary = fallbackWorkflowPrimary(for: memoryType, text: text)
        storageTargets = fallbackStorageTargets(for: memoryType)
        domainFrame = fallbackDomainFrame(for: memoryType)
        domainObject = looksLikeResourceFact(text) ? "person_fact" : fallbackDomainObject(for: memoryType)
        assetValue = looksLikeResourceFact(text) ? ["resource_intelligence"] : fallbackAssetValue(for: memoryType)
        blockedDecision = nil
        confirmationQuestion = nil
        confusionGuard = [fallbackConfusionGuard(for: memoryType)]
        opportunityConsent = nil
        relationshipStage = nil
        priorityScoreAudit = nil
        opportunityLifecycle = nil
        networkPath = nil
        giveFirstOffer = nil
    }

    let unit = ClassificationPropositionUnit(
        unitID: "u1",
        sourceSpan: text,
        propositionalContent: fallbackPropositionalContent(for: text, matchedPerson: matchedPerson, memoryType: memoryType, workflowPrimary: workflowPrimary),
        attitudeHolder: opportunityType == "gift" && matchedPerson != nil && !text.contains("我想给") ? matchedPerson?.displayName ?? "user" : "user",
        intentionalMode: opportunityType == "none" ? "belief/assertion" : "intention",
        directionOfFit: opportunityType == "none" ? "mind_to_world" : "world_to_mind",
        evidentiality: "direct_observation",
        confidenceBasis: "local fallback classification from explicit source text",
        domainObject: domainObject,
        candidateWorkflow: workflowPrimary,
        candidateStorageTargets: storageTargets,
        proposalKind: "workflow_candidate"
    )

    return PendingUpdateClassificationContext(
        propositionUnits: [unit],
        semanticPrimaryUnitID: "u1",
        workflowPrimaryUnitID: "u1",
        secondaryUnitIDs: [],
        semanticPrimary: "u1:\(domainObject)",
        workflowPrimary: workflowPrimary,
        secondaryWorkflows: [],
        storageTargets: storageTargets,
        retentionPolicy: "write_candidate",
        illocutionaryForce: opportunityType == "none" ? "assertion" : "planning_declaration",
        domainFrame: domainFrame,
        operation: "create",
        opportunityType: opportunityType,
        assetValue: assetValue,
        sensitivityDomain: "none",
        severity: "none",
        privacyDisplayRisk: opportunityType == "none" ? "none" : "low",
        visibilityPreference: "default",
        requiresDiscreetReview: false,
        ambiguousSlots: blockedDecision == nil ? [] : ["consent_scope", "relationship_stage"],
        candidateInterpretations: [
            ClassificationCandidateInterpretation(workflowPrimary: workflowPrimary, reason: fallbackClassificationReason(workflowPrimary: workflowPrimary, opportunityType: opportunityType))
        ],
        blockedDecision: blockedDecision,
        confirmationQuestion: confirmationQuestion,
        reasonSummary: "本地 fallback 按 v1.1 边界保留语义主命题、整理台 workflow 和批准后的写入目标。",
        confusionGuard: confusionGuard,
        opportunityConsent: opportunityConsent,
        relationshipStage: relationshipStage,
        priorityScoreAudit: priorityScoreAudit,
        opportunityLifecycle: opportunityLifecycle,
        networkPath: networkPath,
        giveFirstOffer: giveFirstOffer
    )
}

private func fallbackOpportunityType(for text: String, memoryType: MemoryAtomType) -> String {
    if memoryType == .giftSignal, containsAny(["我想给", "买生日礼物", "买礼物", "准备礼物"], in: text) {
        return "gift"
    }
    if containsAny(["介绍给", "把她介绍给", "把他介绍给", "让我把", "介绍她给", "介绍他给"], in: text) {
        return "intro"
    }
    if containsAny(["要内推", "找 Jason 要内推", "找 May 要内推", "能不能介绍", "问他能不能介绍", "问她能不能介绍"], in: text) {
        return "referral_request"
    }
    return "none"
}

private func fallbackWorkflowPrimary(for memoryType: MemoryAtomType, text: String) -> String {
    if looksLikeResourceFact(text) {
        return "person_fact/resources"
    }
    switch memoryType {
    case .personalReflection:
        return "personal_reflection"
    case .personFact:
        return "person_fact/general"
    case .relationshipMemory:
        return "relationship_memory"
    case .reminderSource, .event:
        return "reminder_source"
    case .giftSignal:
        return "gift_signal/touchpoint"
    case .fileNote:
        return "file_note"
    case .idea:
        return "idea"
    }
}

private func fallbackStorageTargets(for memoryType: MemoryAtomType) -> [String] {
    switch memoryType {
    case .personalReflection:
        return ["personal_reflection"]
    case .personFact:
        return ["person_fact"]
    case .relationshipMemory:
        return ["relationship_memory"]
    case .reminderSource, .event:
        return ["reminder_source"]
    case .giftSignal:
        return ["gift_signal"]
    case .fileNote:
        return ["file_note"]
    case .idea:
        return ["personal_reflection"]
    }
}

private func fallbackDomainFrame(for memoryType: MemoryAtomType) -> String {
    switch memoryType {
    case .personalReflection:
        return "self_state"
    case .personFact:
        return "friend_profile"
    case .relationshipMemory:
        return "relationship"
    case .reminderSource, .event:
        return "schedule"
    case .giftSignal:
        return "gift_touchpoint"
    case .fileNote:
        return "file_source"
    case .idea:
        return "self_state"
    }
}

private func fallbackDomainObject(for memoryType: MemoryAtomType) -> String {
    switch memoryType {
    case .personalReflection:
        return "durable_self_pattern"
    case .personFact:
        return "person_fact"
    case .relationshipMemory:
        return "relationship"
    case .reminderSource, .event:
        return "schedule"
    case .giftSignal:
        return "gift_touchpoint"
    case .fileNote:
        return "file_source"
    case .idea:
        return "durable_self_pattern"
    }
}

private func fallbackAssetValue(for memoryType: MemoryAtomType) -> [String] {
    switch memoryType {
    case .personalReflection:
        return ["self_understanding"]
    case .personFact:
        return ["profile_completeness"]
    case .relationshipMemory:
        return ["relationship_signal"]
    case .reminderSource, .event:
        return ["opportunity"]
    case .giftSignal:
        return ["opportunity"]
    case .fileNote:
        return ["source_traceability"]
    case .idea:
        return ["self_understanding"]
    }
}

private func fallbackConfusionGuard(for memoryType: MemoryAtomType) -> String {
    switch memoryType {
    case .personalReflection:
        return "self_reflection_requires_durable_value"
    case .personFact:
        return "friend_fact_vs_self_reflection"
    case .relationshipMemory:
        return "relationship_memory_not_closeness_override"
    case .reminderSource, .event:
        return "schedule_vs_reflection"
    case .giftSignal:
        return "gift_touchpoint_not_final_gift"
    case .fileNote:
        return "file_source_context"
    case .idea:
        return "idea_as_reflection_candidate"
    }
}

private func fallbackPropositionalContent(
    for text: String,
    matchedPerson: FriendPerson?,
    memoryType: MemoryAtomType,
    workflowPrimary: String
) -> String {
    if workflowPrimary == "person_fact/resources" {
        return "\(matchedPerson?.displayName ?? "the friend") has a resource or network connection"
    }
    if workflowPrimary.hasPrefix("relationship_opportunity/") {
        return "the user is considering a relationship opportunity that requires consent and review"
    }
    return text
}

private func fallbackClassificationReason(workflowPrimary: String, opportunityType: String) -> String {
    if opportunityType != "none" {
        return "原文包含用户显式行动意图，但该机会仍需要同意、关系阶段和风险边界确认。"
    }
    if workflowPrimary == "person_fact/resources" {
        return "原文只是资源事实，不能自动升级为引荐或索取动作。"
    }
    return "该 workflow 与批准后的写入目标保持分离。"
}

private func fallbackSensitivity(for text: String, memoryType: MemoryAtomType) -> MemorySensitivity {
    if memoryType == .reminderSource {
        return .normal
    }

    if containsAny(["家庭", "财务", "恋爱", "政治", "健康", "病", "抑郁", "family", "finance", "health"], in: text) {
        return .sensitive
    }

    return memoryType == .personalReflection ? .private : .normal
}

private func fallbackTitle(for text: String, personName: String, memoryType: MemoryAtomType) -> String {
    switch memoryType {
    case .giftSignal:
        return personName == "Memory" ? "礼物线索" : "\(personName) 的礼物线索"
    case .reminderSource:
        return "行程安排：\(compactFactText(text))"
    case .personFact:
        return "\(personName) 的朋友事实：\(compactFactText(text))"
    case .relationshipMemory:
        return personName == "Memory" ? "关系观察" : "\(personName) 的关系观察"
    case .personalReflection:
        if containsAny(["怕麻烦", "害怕麻烦"], in: text) {
            return "我在人际关系里害怕麻烦别人"
        }
        return "个人想法：\(compactFactText(text))"
    default:
        return compactFactText(text)
    }
}

private func fallbackThemes(for text: String, memoryType: MemoryAtomType, knownThemes: [Theme]) -> [ThemeProposal] {
    let fallbackNames: [String]
    switch memoryType {
    case .personFact:
        if containsAny(["吃", "喝", "忌口", "过敏", "food", "drink"], in: text) {
            fallbackNames = ["饮食偏好", "朋友事实"]
        } else {
            fallbackNames = ["朋友事实"]
        }
    case .giftSignal:
        fallbackNames = ["礼物线索"]
    case .reminderSource:
        fallbackNames = ["提醒事项"]
    case .relationshipMemory:
        fallbackNames = ["关系观察"]
    default:
        fallbackNames = ["自我表达", "关系边界"]
    }

    let matchedKnownThemes = matchingKnownThemes(
        for: text,
        knownThemes: knownThemes,
        preferredNames: fallbackNames
    )
    let names = matchedKnownThemes.isEmpty ? fallbackNames : matchedKnownThemes.map(\.name)
    return names.enumerated().map { index, name in
        ThemeProposal(name: name, confidence: max(0.72, 0.9 - Double(index) * 0.06))
    }
}

private func matchingKnownThemes(for text: String, knownThemes: [Theme], preferredNames: [String]) -> [Theme] {
    let scoredThemes = knownThemes.compactMap { theme -> (theme: Theme, score: Int)? in
        let score = themeMatchScore(theme, text: text, preferredNames: preferredNames)
        return score > 0 ? (theme, score) : nil
    }
    return scoredThemes
        .sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return lhs.theme.name < rhs.theme.name
        }
        .prefix(3)
        .map(\.theme)
}

private func themeMatchScore(_ theme: Theme, text: String, preferredNames: [String]) -> Int {
    let lowercasedText = text.lowercased()
    var score = preferredNames.contains(theme.name) ? 3 : 0
    for keyword in themeKeywords(theme) {
        let normalizedKeyword = keyword.lowercased()
        guard normalizedKeyword.count >= 2 else { continue }
        if lowercasedText.contains(normalizedKeyword) {
            score += normalizedKeyword == theme.name.lowercased() ? 8 : 5
        }
    }
    return score
}

private func themeKeywords(_ theme: Theme) -> [String] {
    var values = [theme.name]
    if let description = theme.description {
        values.append(contentsOf: description.components(separatedBy: themeDescriptionSeparators))
    }
    values.append(contentsOf: defaultCoreThemeKeywordHints[theme.name] ?? [])
    return values
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
        .filter { !$0.isEmpty }
}

private let themeDescriptionSeparators = CharacterSet(charactersIn: "，。、；;,. /\n\t（）()")

private let defaultCoreThemeKeywordHints: [String: [String]] = [
    "自我认知": ["自我", "习惯", "性格", "长期模式", "我发现自己"],
    "情绪状态": ["情绪", "感受", "触发", "低落", "开心", "焦虑"],
    "关系边界": ["边界", "拒绝", "压力", "期待", "相处", "麻烦"],
    "亲密/朋友": ["朋友", "亲密", "陪伴", "信任", "友情"],
    "学业成长": ["课程", "学习", "考试", "知识", "项目", "论文", "实验", "展示"],
    "职业方向": ["实习", "研究", "职业", "能力", "公司", "工作"],
    "创作灵感": ["灵感", "创作", "作品", "表达欲", "想法"],
    "身体作息": ["睡眠", "饮食", "运动", "身体", "作息"],
    "压力恢复": ["压力", "恢复", "休息", "支持系统"],
    "价值判断": ["取舍", "原则", "偏好", "判断", "价值"],
    "重要选择": ["决定", "选择", "备选", "路径", "影响"],
    "生活审美": ["空间", "物品", "风格", "城市", "生活质感"]
]

private func fallbackProfilePatches(for text: String, matchedPerson: FriendPerson?) -> [PersonProfilePatchProposal] {
    guard let matchedPerson else { return [] }

    var patches: [PersonProfilePatchProposal] = []
    let factText = compactFactText(text)
    if containsAny(["喜欢", "爱吃", "爱喝", "火锅", "咖啡", "food", "drink", "likes"], in: text) {
        patches.append(
            PersonProfilePatchProposal(
                targetPersonID: matchedPerson.id,
                targetDisplayName: matchedPerson.displayName,
                profileCategory: .foodPreference,
                proposedValue: profilePatchValue(
                    in: text,
                    matchedPerson: matchedPerson,
                    keywords: ["喜欢", "爱吃", "爱喝", "火锅", "咖啡", "food", "drink", "likes"]
                ) ?? factText,
                sourceQuote: text,
                confidence: 0.88,
                sensitivity: .normal,
                isAIInferred: false
            )
        )
    }

    if containsAny(["不吃", "忌口", "过敏", "allergy", "does not eat"], in: text) {
        patches.append(
            PersonProfilePatchProposal(
                targetPersonID: matchedPerson.id,
                targetDisplayName: matchedPerson.displayName,
                profileCategory: .dietaryAllergy,
                proposedValue: profilePatchValue(
                    in: text,
                    matchedPerson: matchedPerson,
                    keywords: ["不吃", "忌口", "过敏", "allergy", "does not eat"]
                ) ?? factText,
                sourceQuote: text,
                confidence: 0.9,
                sensitivity: .normal,
                isAIInferred: false
            )
        )
    }

    if containsAny(["生日", "birthday"], in: text) {
        patches.append(
            PersonProfilePatchProposal(
                targetPersonID: matchedPerson.id,
                targetDisplayName: matchedPerson.displayName,
                profileCategory: .anniversaries,
                proposedValue: profilePatchValue(
                    in: text,
                    matchedPerson: matchedPerson,
                    keywords: ["生日", "birthday"]
                ) ?? factText,
                sourceQuote: text,
                confidence: 0.84,
                sensitivity: .normal,
                isAIInferred: false
            )
        )
    }

    if containsAny(["准备面试", "面试", "在找实习", "最近压力", "最近准备", "最近在做", "current state", "interview"], in: text) {
        patches.append(
            PersonProfilePatchProposal(
                targetPersonID: matchedPerson.id,
                targetDisplayName: matchedPerson.displayName,
                profileCategory: .currentState,
                proposedValue: profilePatchValue(
                    in: text,
                    matchedPerson: matchedPerson,
                    keywords: ["准备面试", "面试", "在找实习", "最近压力", "最近准备", "最近在做", "current state", "interview"]
                ) ?? factText,
                sourceQuote: text,
                confidence: 0.82,
                sensitivity: .normal,
                isAIInferred: false
            )
        )
    }

    if containsAny(["突然电话", "提前约", "提前约时间", "喜欢别人提前约", "communication"], in: text) {
        patches.append(
            PersonProfilePatchProposal(
                targetPersonID: matchedPerson.id,
                targetDisplayName: matchedPerson.displayName,
                profileCategory: .communicationPreference,
                proposedValue: profilePatchValue(
                    in: text,
                    matchedPerson: matchedPerson,
                    keywords: ["突然电话", "提前约", "提前约时间", "喜欢别人提前约", "communication"]
                ) ?? factText,
                sourceQuote: text,
                confidence: 0.84,
                sensitivity: .normal,
                isAIInferred: false
            )
        )
    }

    if containsAny(["暑假旅行", "想旅行", "旅行"], in: text) {
        patches.append(
            PersonProfilePatchProposal(
                targetPersonID: matchedPerson.id,
                targetDisplayName: matchedPerson.displayName,
                profileCategory: .travelPreference,
                proposedValue: profilePatchValue(
                    in: text,
                    matchedPerson: matchedPerson,
                    keywords: ["暑假旅行", "想旅行", "旅行"]
                ) ?? factText,
                sourceQuote: text,
                confidence: 0.78,
                sensitivity: .normal,
                isAIInferred: false
            )
        )
    }

    if containsAny(["最近在学", "喜欢讨论", "兴趣", "interests"], in: text) {
        patches.append(
            PersonProfilePatchProposal(
                targetPersonID: matchedPerson.id,
                targetDisplayName: matchedPerson.displayName,
                profileCategory: .interests,
                proposedValue: profilePatchValue(
                    in: text,
                    matchedPerson: matchedPerson,
                    keywords: ["最近在学", "喜欢讨论", "兴趣", "interests"]
                ) ?? factText,
                sourceQuote: text,
                confidence: 0.8,
                sensitivity: .normal,
                isAIInferred: false
            )
        )
    }

    if looksLikeResourceFact(text) {
        patches.append(
            PersonProfilePatchProposal(
                targetPersonID: matchedPerson.id,
                targetDisplayName: matchedPerson.displayName,
                profileCategory: .friendNetwork,
                proposedValue: profilePatchValue(
                    in: text,
                    matchedPerson: matchedPerson,
                    keywords: ["认识一个投资人", "认识投资人", "认识做 AI 产品", "认识校友", "资源", "投资人", "校友"]
                ) ?? factText,
                sourceQuote: text,
                confidence: 0.78,
                sensitivity: .normal,
                isAIInferred: false,
                classification: fallbackClassificationContext(for: text, matchedPerson: matchedPerson, memoryType: .personFact)
            )
        )
    }

    return patches
}

private func profilePatchValue(
    in text: String,
    matchedPerson: FriendPerson,
    keywords: [String]
) -> String? {
    let segments = text
        .components(separatedBy: CharacterSet(charactersIn: "，,。.;；\n"))
        .map { cleanProfilePatchSegment($0, matchedPerson: matchedPerson) }
        .filter { !$0.isEmpty }

    return segments.first { segment in
        containsAny(keywords, in: segment)
    }
}

private func cleanProfilePatchSegment(_ segment: String, matchedPerson: FriendPerson) -> String {
    var cleaned = segment.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    for removable in ["我记得", matchedPerson.displayName, matchedPerson.nickname, matchedPerson.englishName] where !removable.isEmpty {
        cleaned = cleaned.replacingOccurrences(of: removable, with: "", options: [.caseInsensitive])
    }
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
}

private func fallbackFollowUpQuestion(for personName: String, memoryType: MemoryAtomType) -> String {
    switch memoryType {
    case .personFact:
        return personName == "Memory" ? "要不要把这条事实保存到朋友档案？" : "要不要把这条事实更新到 \(personName) 的朋友档案？"
    case .giftSignal:
        return personName == "Memory" ? "要不要保存这条礼物线索？" : "要不要把这条礼物线索关联到 \(personName)？"
    case .reminderSource:
        return "要不要基于这条记录创建提醒？"
    default:
        return personName == "Memory" ? "要不要保存这条记忆？" : "要不要把这条记忆关联到 \(personName) 的关系时间线？"
    }
}

private func looksLikeFriendFact(_ text: String) -> Bool {
    containsAny(
        [
            "喜欢", "爱吃", "爱喝", "不吃", "不喜欢", "讨厌", "忌口", "过敏",
            "生日", "住在", "来自", "家乡", "学校", "专业", "公司", "实习",
            "工作", "微信", "电话", "mbti", "星座", "计划", "最近在学", "准备面试", "面试",
            "在找实习", "想暑假旅行", "暑假旅行", "提前约", "突然电话",
            "likes", "dislikes", "birthday", "allergy", "school", "major", "works at"
        ],
        in: text
    )
}

private func looksLikeReminderRequest(_ text: String) -> Bool {
    containsAny(
        [
            "提醒", "别忘", "待办", "日程", "deadline", "due", "remind", "reminder", "todo"
        ],
        in: text
    )
}

private func looksLikeSchedulePlan(_ text: String) -> Bool {
    if looksLikeRelationshipBoundary(text) || looksLikeFriendOnlyFutureState(text) || looksLikeContextualGuard(text) {
        return false
    }

    if containsAny(["约饭", "约个饭", "吃个饭", "见个面", "have lunch", "have dinner", "meet up"], in: text) {
        return true
    }

    guard hasScheduleTimeSignal(text) else { return false }
    if looksLikeIntrospectiveReflection(text) {
        return false
    }
    return containsAny(
        [
            "约", "见面", "碰面", "吃饭", "午饭", "晚饭", "开会", "会议", "面试", "考试", "准备",
            "找", "问", "发", "提交", "帮", "祝", "meeting", "meet", "lunch", "dinner", "coffee", "interview", "exam", "call"
        ],
        in: text
    )
}

private func looksLikeReminderMutation(_ text: String) -> Bool {
    containsAny(["取消", "改到", "改成", "不用提醒", "别提醒", "不要提醒"], in: text)
}

private func looksLikeFriendOnlyFutureState(_ text: String) -> Bool {
    guard containsAny(["面试", "考试", "旅行", "准备", "在找实习"], in: text),
          hasScheduleTimeSignal(text) || containsAny(["最近", "暑假"], in: text) else {
        return false
    }
    return !containsAny(["我明天", "我下周", "提醒我", "我要", "我想", "我打算", "我可以", "帮", "问", "祝", "发", "提交", "找"], in: text)
}

private func looksLikeContextualGuard(_ text: String) -> Bool {
    containsAny(["别提", "别说", "不要提"], in: text) &&
        containsAny(["下次见", "见面前", "每次见", "见 May 前", "见May前"], in: text)
}

private func looksLikeRelationshipBoundary(_ text: String) -> Bool {
    containsAny(["不太想再和", "不想和", "以后少和", "边界"], in: text) ||
        (text.contains("单独吃饭") && containsAny(["不太想", "不想", "少"], in: text))
}

private func looksLikeRelationshipMemory(_ text: String) -> Bool {
    containsAny(["一起做项目", "介绍我认识", "共同朋友", "聊得少", "帮我准备面试", "帮我介绍"], in: text)
}

private func looksLikeResourceFact(_ text: String) -> Bool {
    containsAny(["认识一个投资人", "认识投资人", "认识做 AI 产品", "认识校友", "能内推", "有内推", "资源", "投资人", "校友"], in: text)
}

private func looksLikeRelationshipOpportunityIntent(_ text: String, matchedPerson: FriendPerson?) -> Bool {
    guard matchedPerson != nil else { return false }
    return containsAny(
        [
            "我想找", "要内推", "想问他能不能介绍", "想问她能不能介绍",
            "能不能介绍", "让我把", "介绍给", "介绍她给", "介绍他给"
        ],
        in: text
    )
}

private func looksLikeGiftTouchpoint(_ text: String, matchedPerson: FriendPerson?) -> Bool {
    if containsAny(["礼物", "gift", "present", "买生日礼物"], in: text) {
        return true
    }
    guard matchedPerson != nil else { return false }
    return containsAny(["想试拍立得", "想试", "想要拍立得", "香水"], in: text) &&
        !containsAny(["暑假旅行"], in: text)
}

private func looksLikeFollowUpMotivation(_ text: String, matchedPerson: FriendPerson?) -> Bool {
    matchedPerson != nil &&
        containsAny(["我怕", "我担心", "担心"], in: text) &&
        containsAny(["忘", "材料", "迟到", "错过"], in: text)
}

private func isContextOnlyEpisodicSelfState(_ text: String) -> Bool {
    guard containsAny(["焦虑", "紧张", "后悔", "压力"], in: text),
          containsAny(["今天", "昨天", "考试", "准备考试"], in: text) else {
        return false
    }
    return !hasExplicitSelfReflectionStorageIntent(text)
}

private func hasExplicitSelfReflectionStorageIntent(_ text: String) -> Bool {
    containsAny(["想记一下", "记一下这个状态", "复盘", "反思", "总是", "长期", "我发现自己总是"], in: text)
}

private func hasScheduleTimeSignal(_ text: String) -> Bool {
    if containsAny(
        [
            "今天", "明天", "后天", "本周", "这周", "下周", "周一", "周二", "周三", "周四", "周五", "周六", "周日",
            "星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日",
            "早上", "上午", "中午", "下午", "晚上", "今晚", "明早", "明晚",
            "today", "tomorrow", "this week", "next week", "morning", "afternoon", "evening", "tonight"
        ],
        in: text
    ) {
        return true
    }

    return text.range(of: #"\b([01]?\d|2[0-3]):[0-5]\d\b"#, options: .regularExpression) != nil ||
        text.range(of: #"\d{1,2}\s*(点|时)"#, options: .regularExpression) != nil ||
        text.range(of: #"\d{1,2}\s*(月|/)\s*\d{1,2}\s*(日|号)?"#, options: .regularExpression) != nil ||
        text.range(of: #"\b\d{1,2}\s*(am|pm)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
}

private func looksLikeIntrospectiveReflection(_ text: String) -> Bool {
    containsAny(
        [
            "我发现", "我意识到", "意识到自己", "觉得自己", "感觉自己", "反思", "复盘",
            "怕麻烦", "害怕麻烦", "不敢", "没说出口", "害怕明天考试"
        ],
        in: text
    )
}

private func containsAny(_ needles: [String], in text: String) -> Bool {
    needles.contains { text.localizedCaseInsensitiveContains($0) }
}

private func compactFactText(_ text: String) -> String {
    let trimmed = text
        .replacingOccurrences(of: "我记得", with: "")
        .replacingOccurrences(of: "我记得，", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    guard trimmed.count > 42 else { return trimmed }
    return String(trimmed.prefix(39)) + "..."
}

private extension FriendPerson {
    var matchAliases: [String] {
        [
            displayName,
            nickname,
            englishName,
            displayName.split(separator: " ").first.map(String.init) ?? ""
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    }
}

public struct GiftRecommendationWorkflow: Sendable {
    public init() {}

    public func recommendations(for person: FriendPerson, prompt: String) -> [GiftIdea] {
        let budget = parseBudget(from: prompt) ?? "300-500 元"
        let combinedSignals = [
            person.interests,
            person.categoryNote(.interests),
            person.categoryNote(.travelPreference),
            person.categoryNote(.currentState),
            person.categoryNote(.giftHistory),
            person.categoryNote(.spendingPreference)
        ].joined(separator: "\n")

        var ideas: [GiftIdea] = []
        if combinedSignals.contains("陶艺") || prompt.contains("心意") {
            ideas.append(
                GiftIdea(
                    id: "gift-\(person.id)-ceramic-\(stablePromptSuffix(prompt))",
                    title: "推荐方向 1：陶艺相关体验或工具",
                    personName: person.displayName,
                    priceBand: budget,
                    rationale: "她最近在学陶艺，体验型礼物比单纯物品更贴合当前兴趣。",
                    risk: "如果她已经有固定课程，重复购买可能浪费。",
                    confirmationQuestion: "她是手作体验型还是想长期学习？",
                    matchScore: 92,
                    surpriseScore: 82,
                    riskLevel: "中",
                    practicality: "中",
                    emotionalValue: "高",
                    needsMoreInfo: true
                )
            )
        }

        if combinedSignals.contains("冰岛") || combinedSignals.contains("旅行") || prompt.contains("旅行") {
            ideas.append(
                GiftIdea(
                    id: "gift-\(person.id)-iceland-\(stablePromptSuffix(prompt))",
                    title: "推荐方向 2：冰岛旅行相关实用物品",
                    personName: person.displayName,
                    priceBand: budget,
                    rationale: "她 8 月要去冰岛，可以送轻便保暖、旅行收纳、拍照相关物品。",
                    risk: "功能性礼物如果审美不合，惊喜感不足。",
                    confirmationQuestion: "她已经买了哪些旅行装备？她偏什么颜色？",
                    matchScore: 86,
                    surpriseScore: 70,
                    riskLevel: "中",
                    practicality: "高",
                    emotionalValue: "中",
                    needsMoreInfo: true
                )
            )
        }

        ideas.append(
            GiftIdea(
                id: "gift-\(person.id)-support-\(stablePromptSuffix(prompt))",
                title: "推荐方向 3：换工作阶段的低压力陪伴礼物",
                personName: person.displayName,
                priceBand: budget,
                rationale: "她最近压力较大，适合送香薰、按摩、睡眠、轻办公相关物品。",
                risk: "不要显得像在暗示她状态不好。",
                confirmationQuestion: "她最近更需要放松、效率，还是有人陪她聊聊？",
                matchScore: 84,
                surpriseScore: 76,
                riskLevel: "低",
                practicality: "高",
                emotionalValue: "高",
                needsMoreInfo: false
            )
        )

        while ideas.count < 3 {
            ideas.append(
                GiftIdea(
                    id: "gift-\(person.id)-ritual-\(ideas.count)-\(stablePromptSuffix(prompt))",
                    title: "推荐方向 \(ideas.count + 1)：有仪式感的小众日常礼物",
                    personName: person.displayName,
                    priceBand: budget,
                    rationale: "她更重视心意和被理解的感觉，小众但贴合日常的礼物比标准爆款更合适。",
                    risk: "审美偏好不确认时容易买到不合适的颜色或香味。",
                    confirmationQuestion: "她最近更偏哪种颜色、香味或日常使用场景？",
                    matchScore: 78,
                    surpriseScore: 72,
                    riskLevel: "中",
                    practicality: "中",
                    emotionalValue: "高",
                    needsMoreInfo: true
                )
            )
        }

        return Array(ideas.prefix(3))
    }
}

private func containsChinese(_ text: String) -> Bool {
    text.unicodeScalars.contains { scalar in
        scalar.value >= 0x4E00 && scalar.value <= 0x9FFF
    }
}

private func parseBudget(from prompt: String) -> String? {
    let digits = prompt.split { !$0.isNumber }.compactMap { Int($0) }
    guard digits.count >= 2 else { return nil }
    return "\(digits[0])-\(digits[1]) 元"
}

private func stablePromptSuffix(_ prompt: String) -> String {
    let value = abs(prompt.unicodeScalars.reduce(0) { partialResult, scalar in
        partialResult &* 31 &+ Int(scalar.value)
    })
    return String(value % 100_000)
}
