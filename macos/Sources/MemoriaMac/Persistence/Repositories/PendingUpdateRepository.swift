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
        proposal: MemoryAtomProposal,
        envelope: PendingUpdatePayloadEnvelope<MemoryAtomProposal>? = nil
    ) throws -> PendingUpdate {
        guard !proposal.sourceQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIContractError.missingSourceQuote
        }

        let timestamp = nowString()
        let effectiveEnvelope = envelope ?? proposal.boundaryReviewEnvelopeIfNeeded()
        let payloadData = try effectiveEnvelope.map { try encoder.encode($0) } ?? encoder.encode(proposal)
        let payload = try String(data: payloadData, encoding: .utf8).requireValue("Could not encode proposal")
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
        proposal: PersonProfilePatchProposal,
        envelope: PendingUpdatePayloadEnvelope<PersonProfilePatchProposal>? = nil
    ) throws -> PendingUpdate {
        try AIContractValidator().validateProfilePatch(proposal)

        let timestamp = nowString()
        let payloadData = try envelope.map { try encoder.encode($0) } ?? encoder.encode(proposal)
        let payload = try String(data: payloadData, encoding: .utf8).requireValue("Could not encode proposal")
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
        content: String,
        memoryType: MemoryAtomType? = nil,
        targetPersonID: String? = nil,
        targetDisplayName: String? = nil,
        reminderDueAt: String? = nil,
        reminderDueLabel: String? = nil,
        giftBudgetHint: String? = nil,
        giftOccasion: String? = nil,
        giftRisk: String? = nil,
        giftConfirmationQuestion: String? = nil,
        giftRiskTags: [GiftSocialRisk]? = nil
    ) throws -> PendingUpdate {
        guard let update = try fetch(id: id) else {
            throw PendingUpdateError.notFound
        }
        guard update.status == .pending || update.status == .edited else {
            throw PendingUpdateError.notReviewable
        }
        var proposal = try update.memoryAtomProposalForReview()
        proposal.title = title
        proposal.summary = summary
        proposal.content = content
        if let memoryType {
            proposal.memoryType = memoryType
        }
        let normalizedTargetName = targetDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedTargetName.isEmpty {
            proposal.relatedPeople = [
                RelatedPersonProposal(
                    displayName: normalizedTargetName,
                    matchedPersonID: targetPersonID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    matchConfidence: targetPersonID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? 0.92 : 0.68,
                    relationType: "about"
                )
            ]
        }
        let payload = try editedMemoryAtomPayload(for: update, proposal: proposal)
        let finalPayload = try editedStructuredPayloadIfNeeded(
            update: update,
            basePayload: payload,
            proposal: proposal,
            targetPersonID: targetPersonID,
            targetDisplayName: targetDisplayName,
            reminderDueAt: reminderDueAt,
            reminderDueLabel: reminderDueLabel,
            giftBudgetHint: giftBudgetHint,
            giftOccasion: giftOccasion,
            giftRisk: giftRisk,
            giftConfirmationQuestion: giftConfirmationQuestion,
            giftRiskTags: giftRiskTags
        )
        try database.execute(
            """
            UPDATE pending_updates
            SET payload_json = ?, confidence = ?, status = 'edited'
            WHERE id = ?
            """,
            [finalPayload, String(proposal.confidence), id]
        )
        return try fetch(id: id).requireValue("Edited pending update not found")
    }

    @discardableResult
    public func editPersonProfilePatch(
        id: String,
        targetPersonID: String?,
        targetDisplayName: String,
        profileCategory: PersonProfileCategory,
        proposedValue: String,
        valueStruct: ProfileValueStruct?
    ) throws -> PendingUpdate {
        guard let update = try fetch(id: id) else {
            throw PendingUpdateError.notFound
        }
        guard update.status == .pending || update.status == .edited else {
            throw PendingUpdateError.notReviewable
        }
        let oldPatch = try update.profilePatchProposalForReview()
        let patch = PersonProfilePatchProposal(
            targetPersonID: targetPersonID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            targetDisplayName: targetDisplayName,
            profileCategory: profileCategory,
            proposedValue: proposedValue,
            valueStruct: valueStruct ?? oldPatch.valueStruct,
            sourceQuote: oldPatch.sourceQuote,
            confidence: oldPatch.confidence,
            sensitivity: oldPatch.sensitivity,
            isAIInferred: oldPatch.isAIInferred,
            mergeStrategy: oldPatch.mergeStrategy,
            classification: oldPatch.classification
        )
        try AIContractValidator().validateProfilePatch(patch)
        let payload = try editedProfilePatchPayload(for: update, patch: patch)
        try database.execute(
            """
            UPDATE pending_updates
            SET payload_json = ?, confidence = ?, status = 'edited'
            WHERE id = ?
            """,
            [payload, String(patch.confidence), id]
        )
        return try fetch(id: id).requireValue("Edited profile patch not found")
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
            let proposal = try update.memoryAtomProposalForReview()
            guard !proposal.sourceQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIContractError.missingSourceQuote
            }
            try validateStructuredScheduleCanBeApproved(update)

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
                update: update,
                memoryID: memoryID
            )

            let approvedPayload = try memoryAtomPayloadAfterApproval(
                update: update,
                memoryID: memoryID,
                proposal: proposal,
                approvedAt: timestamp
            )
            try database.execute(
                "UPDATE pending_updates SET payload_json = ?, status = 'approved', decided_at = ? WHERE id = ?",
                [approvedPayload, timestamp, id]
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
        let patch = try update.profilePatchProposalForReview()
        try AIContractValidator().validateProfilePatch(patch)
        let preimage = try profilePatchPreimage(for: patch)
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
        let approvedPayload = try profilePatchPayloadAfterApproval(
            update: update,
            patch: patch,
            memoryID: memoryID,
            approvedAt: timestamp,
            preimage: preimage,
            expectedValue: person.categoryNote(patch.profileCategory)
        )
        try database.execute(
            "UPDATE pending_updates SET payload_json = ?, status = 'approved', decided_at = ? WHERE id = ?",
            [approvedPayload, timestamp, update.id]
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

    public func reject(id: String, reason: String? = nil) throws {
        try database.execute(
            "UPDATE pending_updates SET status = 'rejected', decided_at = ?, error_message = ? WHERE id = ?",
            [nowString(), reason?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty, id]
        )
    }

    @discardableResult
    public func undoApproval(id: String) throws -> PendingUpdate {
        guard let update = try fetch(id: id) else {
            throw PendingUpdateError.notFound
        }
        guard update.status == .approved else {
            throw PendingUpdateError.notReviewable
        }
        switch update.proposalType {
        case .memoryAtom:
            return try undoMemoryAtomApproval(update)
        case .personProfilePatch:
            return try undoProfilePatchApproval(update)
        }
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

    private func editedMemoryAtomPayload(for update: PendingUpdate, proposal: MemoryAtomProposal) throws -> String {
        let data = Data(update.payloadJSON.utf8)
        if var envelope = try? decoder.decode(PendingUpdatePayloadEnvelope<MemoryAtomProposal>.self, from: data) {
            try PendingUpdatePayloadEnvelopeValidator.validate(data: data, expectedProposalKind: .memoryAtom)
            envelope.proposal = proposal
            return try String(data: encoder.encode(envelope), encoding: .utf8).requireValue("Could not encode edited proposal")
        }
        return try String(data: encoder.encode(proposal), encoding: .utf8).requireValue("Could not encode edited proposal")
    }

    private func editedStructuredPayloadIfNeeded(
        update: PendingUpdate,
        basePayload: String,
        proposal: MemoryAtomProposal,
        targetPersonID: String?,
        targetDisplayName: String?,
        reminderDueAt: String?,
        reminderDueLabel: String?,
        giftBudgetHint: String?,
        giftOccasion: String?,
        giftRisk: String?,
        giftConfirmationQuestion: String?,
        giftRiskTags: [GiftSocialRisk]?
    ) throws -> String {
        let data = Data(basePayload.utf8)
        guard var envelope = try? decoder.decode(PendingUpdatePayloadEnvelope<MemoryAtomProposal>.self, from: data) else {
            return basePayload
        }
        var context = envelope.structuredContext
        let normalizedTargetName = targetDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        if let reminder = context?.reminder {
            let confirmedReminderAt = reminderDueAt?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            let hasConfirmedReminderTime = confirmedReminderAt.flatMap { timeOnly(from: $0) } != nil &&
                !["contextual_guard", "cancel_existing", "reschedule_existing", "update_existing"].contains(reminder.scheduleSubtype ?? "")
            let editedNotificationPolicy = hasConfirmedReminderTime
                ? PendingUpdateNotificationPolicy(
                    deliveryMode: "reminder",
                    policySource: "user_confirmed",
                    triggerAtOrNull: confirmedReminderAt,
                    offsetOrNull: nil,
                    nextTriggerAtOrNull: nil,
                    timezone: reminder.timezone ?? "Asia/Shanghai",
                    requiresConfirmation: false,
                    defaultAllowed: false
                )
                : reminder.notificationPolicy
            let candidateReminder = PendingUpdateReminderContext(
                title: proposal.title,
                targetPersonID: targetPersonID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? reminder.targetPersonID,
                targetDisplayName: normalizedTargetName ?? reminder.targetDisplayName,
                candidatePersonIDs: reminder.candidatePersonIDs,
                dueAt: reminder.scheduleSubtype == "deadline" ? reminder.dueAt : (confirmedReminderAt ?? reminder.dueAt),
                dueLabel: reminderDueLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? reminder.dueLabel,
                dateParseReason: confirmedReminderAt == nil ? reminder.dateParseReason : "用户在整理台中确认了具体提醒时间。",
                scheduleSubtype: reminder.scheduleSubtype,
                scheduleExecutionState: hasConfirmedReminderTime ? "executable_reminder" : reminder.scheduleExecutionState,
                timeRole: hasConfirmedReminderTime ? "reminder_trigger" : reminder.timeRole,
                timeExpressionKind: hasConfirmedReminderTime ? "exact_datetime" : reminder.timeExpressionKind,
                timePrecision: hasConfirmedReminderTime ? "exact_minute" : reminder.timePrecision,
                rawTimeExpression: reminder.rawTimeExpression,
                referenceDate: reminder.referenceDate,
                referenceDatetime: reminder.referenceDatetime,
                timezone: reminder.timezone,
                startAt: reminder.startAt,
                endAt: reminder.endAt,
                deadlineRelation: reminder.deadlineRelation,
                remindAt: confirmedReminderAt ?? reminder.remindAt,
                commitmentLevel: reminder.commitmentLevel,
                notificationPolicy: editedNotificationPolicy,
                needsSlotConfirmation: hasConfirmedReminderTime ? false : reminder.needsSlotConfirmation,
                confirmationBlockers: hasConfirmedReminderTime ? [] : reminder.confirmationBlockers,
                confirmationReasons: hasConfirmedReminderTime ? [] : reminder.confirmationReasons,
                requiresUserApproval: reminder.requiresUserApproval,
                reasonSummary: hasConfirmedReminderTime ? "用户已在整理台补齐明确提醒时间和提醒策略。" : reminder.reasonSummary,
                confusionGuard: reminder.confusionGuard,
                actor: reminder.actor,
                action: reminder.action,
                targetPerson: reminder.targetPerson,
                location: reminder.location,
                resolvedWindow: reminder.resolvedWindow,
                resolvedTime: hasConfirmedReminderTime ? [
                    "remind_at": confirmedReminderAt ?? "",
                    "timezone": reminder.timezone ?? "Asia/Shanghai",
                    "source": "user_confirmed"
                ] : reminder.resolvedTime,
                recurrenceRule: reminder.recurrenceRule,
                mutationMatch: reminder.mutationMatch,
                contextualGuard: reminder.contextualGuard
            )
            let finalReminder: PendingUpdateReminderContext
            if hasConfirmedReminderTime, (try? validateExecutableReminderContext(candidateReminder)) == nil {
                finalReminder = PendingUpdateReminderContext(
                    title: candidateReminder.title,
                    targetPersonID: candidateReminder.targetPersonID,
                    targetDisplayName: candidateReminder.targetDisplayName,
                    candidatePersonIDs: candidateReminder.candidatePersonIDs,
                    dueAt: candidateReminder.dueAt,
                    dueLabel: candidateReminder.dueLabel,
                    dateParseReason: "用户补充的提醒时间仍缺少可执行日程所需字段。",
                    scheduleSubtype: reminder.scheduleSubtype,
                    scheduleExecutionState: reminder.scheduleExecutionState,
                    timeRole: reminder.timeRole,
                    timeExpressionKind: reminder.timeExpressionKind,
                    timePrecision: reminder.timePrecision,
                    rawTimeExpression: reminder.rawTimeExpression,
                    referenceDate: reminder.referenceDate,
                    referenceDatetime: reminder.referenceDatetime,
                    timezone: reminder.timezone,
                    startAt: reminder.startAt,
                    endAt: reminder.endAt,
                    deadlineRelation: reminder.deadlineRelation,
                    remindAt: candidateReminder.remindAt,
                    commitmentLevel: reminder.commitmentLevel,
                    notificationPolicy: reminder.notificationPolicy,
                    needsSlotConfirmation: true,
                    confirmationBlockers: reminder.confirmationBlockers.isEmpty
                        ? [
                            PendingUpdateConfirmationBlocker(
                                code: "classification_ambiguity",
                                field: "structured_schedule",
                                requiredFor: "executable_reminder",
                                observedValue: confirmedReminderAt,
                                question: "这条安排还缺少事件时间、截止日期或有效未来提醒策略。"
                            )
                        ]
                        : reminder.confirmationBlockers,
                    confirmationReasons: reminder.confirmationReasons.isEmpty ? ["classification_ambiguity"] : reminder.confirmationReasons,
                    requiresUserApproval: reminder.requiresUserApproval,
                    reasonSummary: reminder.reasonSummary,
                    confusionGuard: reminder.confusionGuard,
                    actor: reminder.actor,
                    action: reminder.action,
                    targetPerson: reminder.targetPerson,
                    location: reminder.location,
                    resolvedWindow: reminder.resolvedWindow,
                    resolvedTime: candidateReminder.resolvedTime,
                    recurrenceRule: reminder.recurrenceRule,
                    mutationMatch: reminder.mutationMatch,
                    contextualGuard: reminder.contextualGuard
                )
            } else {
                finalReminder = candidateReminder
            }
            context = PendingUpdateStructuredReviewContext(
                sourceKind: context?.sourceKind ?? "reminder_proposal",
                sourceProposalID: context?.sourceProposalID,
                reminder: finalReminder,
                giftSignal: context?.giftSignal,
                valueStruct: context?.valueStruct,
                classification: editedClassificationContext(
                    context?.classification,
                    reminder: finalReminder,
                    confirmedReminderAt: confirmedReminderAt
                )
            )
        }
        if let giftSignal = context?.giftSignal {
            context = PendingUpdateStructuredReviewContext(
                sourceKind: context?.sourceKind ?? "gift_signal_proposal",
                sourceProposalID: context?.sourceProposalID,
                reminder: context?.reminder,
                giftSignal: PendingUpdateGiftSignalContext(
                    targetPersonID: targetPersonID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? giftSignal.targetPersonID,
                    targetDisplayName: normalizedTargetName ?? giftSignal.targetDisplayName,
                    candidatePersonIDs: giftSignal.candidatePersonIDs,
                    signalSummary: proposal.summary,
                    occasion: giftOccasion?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? giftSignal.occasion,
                    budgetHint: giftBudgetHint?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? giftSignal.budgetHint,
                    riskTags: giftRiskTags ?? giftSignal.riskTags,
                    risk: giftRisk?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? giftSignal.risk,
                    confirmationQuestion: giftConfirmationQuestion?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? giftSignal.confirmationQuestion
                ),
                valueStruct: context?.valueStruct,
                classification: context?.classification
            )
        }
        envelope.proposal = proposal
        envelope.structuredContext = context
        return try String(data: encoder.encode(envelope), encoding: .utf8).requireValue("Could not encode edited structured proposal")
    }

    private func editedClassificationContext(
        _ classification: PendingUpdateClassificationContext?,
        reminder: PendingUpdateReminderContext,
        confirmedReminderAt: String?
    ) -> PendingUpdateClassificationContext? {
        guard let classification,
              reminder.scheduleExecutionState == "executable_reminder",
              reminder.needsSlotConfirmation == false,
              reminder.confirmationBlockers.isEmpty else {
            return classification
        }
        return PendingUpdateClassificationContext(
            propositionUnits: classification.propositionUnits,
            semanticPrimaryUnitID: classification.semanticPrimaryUnitID,
            workflowPrimaryUnitID: classification.workflowPrimaryUnitID,
            secondaryUnitIDs: classification.secondaryUnitIDs,
            semanticPrimary: classification.semanticPrimary,
            workflowPrimary: classification.workflowPrimary,
            secondaryWorkflows: classification.secondaryWorkflows,
            storageTargets: classification.storageTargets,
            retentionPolicy: classification.retentionPolicy,
            illocutionaryForce: classification.illocutionaryForce,
            domainFrame: classification.domainFrame,
            operation: classification.operation,
            opportunityType: classification.opportunityType,
            assetValue: classification.assetValue,
            sensitivityDomain: classification.sensitivityDomain,
            severity: classification.severity,
            privacyDisplayRisk: classification.privacyDisplayRisk,
            visibilityPreference: classification.visibilityPreference,
            requiresDiscreetReview: classification.requiresDiscreetReview,
            ambiguousSlots: [],
            candidateInterpretations: classification.candidateInterpretations,
            blockedDecision: nil,
            confirmationQuestion: nil,
            reasonSummary: confirmedReminderAt.map { "用户已补齐提醒时间 \($0)，该日程现在可在批准后创建本地提醒。" } ?? classification.reasonSummary,
            confusionGuard: classification.confusionGuard,
            opportunityConsent: classification.opportunityConsent,
            relationshipStage: classification.relationshipStage,
            priorityScoreAudit: classification.priorityScoreAudit,
            opportunityLifecycle: classification.opportunityLifecycle,
            networkPath: classification.networkPath,
            giveFirstOffer: classification.giveFirstOffer
        )
    }

    private func editedProfilePatchPayload(for update: PendingUpdate, patch: PersonProfilePatchProposal) throws -> String {
        let data = Data(update.payloadJSON.utf8)
        if var envelope = try? decoder.decode(PendingUpdatePayloadEnvelope<PersonProfilePatchProposal>.self, from: data) {
            try PendingUpdatePayloadEnvelopeValidator.validate(data: data, expectedProposalKind: .personProfilePatch)
            envelope.proposal = patch
            envelope.structuredContext = PendingUpdateStructuredReviewContext(
                sourceKind: envelope.structuredContext?.sourceKind ?? "person_profile_patch",
                sourceProposalID: envelope.structuredContext?.sourceProposalID,
                reminder: nil,
                giftSignal: nil,
                valueStruct: patch.valueStruct,
                classification: envelope.structuredContext?.classification
            )
            return try String(data: encoder.encode(envelope), encoding: .utf8).requireValue("Could not encode edited profile patch")
        }
        return try String(data: encoder.encode(patch), encoding: .utf8).requireValue("Could not encode edited profile patch")
    }

    private func memoryAtomPayloadAfterApproval(
        update: PendingUpdate,
        memoryID: String,
        proposal: MemoryAtomProposal,
        approvedAt: String
    ) throws -> String {
        let data = Data(update.payloadJSON.utf8)
        guard var envelope = try? decoder.decode(PendingUpdatePayloadEnvelope<MemoryAtomProposal>.self, from: data) else {
            return update.payloadJSON
        }
        try PendingUpdatePayloadEnvelopeValidator.validate(data: data, expectedProposalKind: .memoryAtom)
        envelope.proposal = proposal
        envelope.approvalResult = PendingUpdateApprovalResult(
            approvedAt: approvedAt,
            memoryAtomID: memoryID,
            derivedReminderID: approvedPayloadShouldCreateReminder(update: update, proposal: proposal) ? "reminder-\(memoryID)" : nil,
            derivedGiftIdeaID: nil,
            profilePatchPreimage: nil,
            profilePatchExpectedValue: nil
        )
        envelope.undo = PendingUpdateUndo(
            state: "available",
            preimage: ["memory_atom_id": memoryID],
            result: nil,
            createdCorrectionPendingUpdateID: nil
        )
        return try String(data: encoder.encode(envelope), encoding: .utf8).requireValue("Could not encode approved proposal")
    }

    private func approvedPayloadShouldCreateReminder(update: PendingUpdate, proposal: MemoryAtomProposal) -> Bool {
        if let reminder = update.structuredReviewContext?.reminder {
            return reminder.scheduleExecutionState == "executable_reminder" &&
                !reminder.needsSlotConfirmation &&
                reminder.confirmationBlockers.isEmpty
        }
        return proposal.memoryType == .reminderSource
    }

    private func profilePatchPayloadAfterApproval(
        update: PendingUpdate,
        patch: PersonProfilePatchProposal,
        memoryID: String,
        approvedAt: String,
        preimage: ProfilePatchPreimage?,
        expectedValue: String
    ) throws -> String {
        let data = Data(update.payloadJSON.utf8)
        guard var envelope = try? decoder.decode(PendingUpdatePayloadEnvelope<PersonProfilePatchProposal>.self, from: data) else {
            return update.payloadJSON
        }
        try PendingUpdatePayloadEnvelopeValidator.validate(data: data, expectedProposalKind: .personProfilePatch)
        envelope.proposal = patch
        envelope.approvalResult = PendingUpdateApprovalResult(
            approvedAt: approvedAt,
            memoryAtomID: memoryID,
            derivedReminderID: nil,
            derivedGiftIdeaID: nil,
            profilePatchPreimage: preimage,
            profilePatchExpectedValue: expectedValue
        )
        envelope.undo = PendingUpdateUndo(
            state: preimage == nil ? "not_available" : "available",
            preimage: preimage.map {
                [
                    "person_id": $0.personID,
                    "category": $0.category.rawValue,
                    "old_value": $0.oldValue,
                    "expected_value": expectedValue
                ]
            },
            result: nil,
            createdCorrectionPendingUpdateID: nil
        )
        return try String(data: encoder.encode(envelope), encoding: .utf8).requireValue("Could not encode approved patch")
    }

    private func profilePatchPreimage(for patch: PersonProfilePatchProposal) throws -> ProfilePatchPreimage? {
        guard let personID = patch.targetPersonID else { return nil }
        let person = try database.loadSnapshot().people.first { $0.id == personID }
        return ProfilePatchPreimage(
            personID: personID,
            category: patch.profileCategory,
            oldValue: person?.categoryNote(patch.profileCategory) ?? ""
        )
    }

    private func undoMemoryAtomApproval(_ update: PendingUpdate) throws -> PendingUpdate {
        let data = Data(update.payloadJSON.utf8)
        var envelope = try decoder.decode(PendingUpdatePayloadEnvelope<MemoryAtomProposal>.self, from: data)
        guard envelope.undo?.state == "available", let result = envelope.approvalResult, let memoryID = result.memoryAtomID else {
            throw PendingUpdateError.undoNotAvailable
        }
        if let reminderID = result.derivedReminderID {
            try database.deleteReminder(id: reminderID)
        }
        let status: MemoryAtomStatus = envelope.proposal.memoryType == .giftSignal ? .archived : .disputed
        try database.updateMemoryAtomStatus(id: memoryID, status: status)
        envelope.undo = PendingUpdateUndo(
            state: "applied",
            preimage: envelope.undo?.preimage,
            result: [
                "applied_at": nowString(),
                "memory_atom_id": memoryID,
                "memory_status": status.rawValue,
                "raw_entry_preserved": update.sourceEntryID == nil ? "unknown" : "true"
            ],
            createdCorrectionPendingUpdateID: nil
        )
        let payload = try String(data: encoder.encode(envelope), encoding: .utf8).requireValue("Could not encode undo payload")
        try database.execute("UPDATE pending_updates SET payload_json = ? WHERE id = ?", [payload, update.id])
        return try fetch(id: update.id).requireValue("Undo update not found")
    }

    private func undoProfilePatchApproval(_ update: PendingUpdate) throws -> PendingUpdate {
        let data = Data(update.payloadJSON.utf8)
        var envelope = try decoder.decode(PendingUpdatePayloadEnvelope<PersonProfilePatchProposal>.self, from: data)
        guard envelope.undo?.state == "available",
              let result = envelope.approvalResult,
              let preimage = result.profilePatchPreimage,
              let expectedValue = result.profilePatchExpectedValue else {
            throw PendingUpdateError.undoNotAvailable
        }

        let currentPerson = try database.loadSnapshot().people.first { $0.id == preimage.personID }
        let currentValue = currentPerson?.categoryNote(preimage.category) ?? ""
        if currentValue == expectedValue {
            try database.replaceProfileCategoryNote(
                personID: preimage.personID,
                category: preimage.category,
                value: preimage.oldValue
            )
            if let memoryID = result.memoryAtomID {
                try database.updateMemoryAtomStatus(id: memoryID, status: .disputed)
            }
            envelope.undo = PendingUpdateUndo(
                state: "applied",
                preimage: envelope.undo?.preimage,
                result: [
                    "applied_at": nowString(),
                    "person_id": preimage.personID,
                    "category": preimage.category.rawValue,
                    "memory_atom_id": result.memoryAtomID ?? "",
                    "memory_status": MemoryAtomStatus.disputed.rawValue,
                    "raw_entry_preserved": update.sourceEntryID == nil ? "unknown" : "true"
                ],
                createdCorrectionPendingUpdateID: nil
            )
        } else {
            let correction = try createBlockedUndoCorrection(preimage: preimage, update: update)
            envelope.undo = PendingUpdateUndo(
                state: "blocked",
                preimage: envelope.undo?.preimage,
                result: ["blocked_at": nowString(), "reason": "profile_value_changed_after_approval"],
                createdCorrectionPendingUpdateID: correction.id
            )
        }
        let payload = try String(data: encoder.encode(envelope), encoding: .utf8).requireValue("Could not encode undo payload")
        try database.execute("UPDATE pending_updates SET payload_json = ? WHERE id = ?", [payload, update.id])
        return try fetch(id: update.id).requireValue("Undo update not found")
    }

    private func createBlockedUndoCorrection(preimage: ProfilePatchPreimage, update: PendingUpdate) throws -> PendingUpdate {
        let name = try database.scalarString("SELECT display_name FROM people WHERE id = ?", [preimage.personID]) ?? preimage.personID
        let patch = PersonProfilePatchProposal(
            targetPersonID: preimage.personID,
            targetDisplayName: name,
            profileCategory: preimage.category,
            proposedValue: preimage.oldValue,
            sourceQuote: "撤销被阻止：批准后此档案字段已被手动修改，需要重新确认。",
            confidence: 1,
            sensitivity: .normal,
            isAIInferred: false
        )
        return try createPersonProfilePatchProposal(
            sourceEntryID: update.sourceEntryID,
            proposal: patch,
            envelope: patch.pendingUpdateEnvelope()
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
        update: PendingUpdate,
        memoryID: String
    ) throws {
        guard proposal.memoryType == .reminderSource || (proposal.memoryType == .event && proposal.hasScheduleSignals) else {
            return
        }

        if let reminderContext = update.structuredReviewContext?.reminder {
            guard (try? validateExecutableReminderContext(reminderContext)) != nil else {
                return
            }

            let reminder = TransferReminder(
                id: "reminder-\(memoryID)",
                title: proposal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Memoria reminder" : proposal.title,
                personName: reminderContext.targetDisplayName ?? proposal.relatedPeople.first?.displayName ?? "Memoria",
                dueLabel: reminderContext.dueLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "已确认提醒" : reminderContext.dueLabel,
                dueDate: dateOnly(from: reminderContext.remindAt ?? reminderContext.dueAt ?? reminderContext.startAt),
                timeLabel: timeOnly(from: reminderContext.remindAt ?? reminderContext.dueAt ?? reminderContext.startAt) ?? "",
                context: proposal.summary,
                location: ""
            )
            try database.upsertReminder(reminder)
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

    private func validateStructuredScheduleCanBeApproved(_ update: PendingUpdate) throws {
        guard let reminder = update.structuredReviewContext?.reminder else {
            return
        }
        if reminder.needsSlotConfirmation || !reminder.confirmationBlockers.isEmpty {
            throw PendingUpdateError.needsSlotConfirmation
        }
        switch reminder.scheduleExecutionState {
        case nil:
            return
        case "executable_reminder":
            try validateExecutableReminderContext(reminder)
            return
        case "executable_schedule_item":
            guard let policy = reminder.notificationPolicy,
                  ["calendar_only", "no_notification"].contains(policy.deliveryMode),
                  policy.policySource == "user_explicit",
                  reminder.startAt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw PendingUpdateError.needsSlotConfirmation
            }
            return
        case "anchored_contextual_guard":
            guard reminder.contextualGuard?["anchor_status"] == "anchored",
                  reminder.contextualGuard?["anchor_event_id_or_null"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw PendingUpdateError.needsSlotConfirmation
            }
            return
        default:
            throw PendingUpdateError.needsSlotConfirmation
        }
    }

    private func validateExecutableReminderContext(_ reminder: PendingUpdateReminderContext) throws {
        guard reminder.scheduleExecutionState == "executable_reminder",
              reminder.needsSlotConfirmation == false,
              reminder.confirmationBlockers.isEmpty,
              reminder.timeRole != "ambiguous",
              let policy = reminder.notificationPolicy,
              policy.deliveryMode == "reminder",
              ["user_explicit", "user_preference", "user_confirmed"].contains(policy.policySource),
              policy.requiresConfirmation == false else {
            throw PendingUpdateError.needsSlotConfirmation
        }

        if reminder.scheduleSubtype != "recurring",
           policy.nextTriggerAtOrNull?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty != nil {
            throw PendingUpdateError.needsSlotConfirmation
        }
        let trigger = policy.triggerAtOrNull?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ??
            (reminder.scheduleSubtype == "recurring" ? policy.nextTriggerAtOrNull?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil)
        guard let trigger else {
            throw PendingUpdateError.needsSlotConfirmation
        }
        if let reference = reminder.referenceDatetime,
           !timestampIsFuture(trigger, reference: reference) {
            throw PendingUpdateError.needsSlotConfirmation
        }
        if let remindAt = reminder.remindAt?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
           remindAt != trigger {
            throw PendingUpdateError.needsSlotConfirmation
        }

        switch reminder.scheduleSubtype {
        case "event":
            guard reminder.startAt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  reminder.remindAt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw PendingUpdateError.needsSlotConfirmation
            }
        case "deadline":
            guard reminder.dueAt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  reminder.deadlineRelation?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  reminder.remindAt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw PendingUpdateError.needsSlotConfirmation
            }
        case "recurring":
            guard let rule = reminder.recurrenceRule,
                  rule["frequency"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  rule["interval"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  rule["anchor_date"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  rule["timezone"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  (rule["by_weekday"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
                   rule["day_of_month"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false),
                  (rule["remind_time_or_null"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
                   rule["next_trigger_at_or_null"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) else {
                throw PendingUpdateError.needsSlotConfirmation
            }
        case "contextual_guard", "cancel_existing", "reschedule_existing", "update_existing":
            throw PendingUpdateError.needsSlotConfirmation
        default:
            guard reminder.remindAt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw PendingUpdateError.needsSlotConfirmation
            }
        }
    }

    private func dateOnly(from timestamp: String?) -> String? {
        guard let timestamp, timestamp.count >= 10 else { return nil }
        return String(timestamp.prefix(10))
    }

    private func timeOnly(from timestamp: String?) -> String? {
        guard let timestamp else { return nil }
        if let match = firstRegexCapture(in: timestamp, pattern: #"T(\d{1,2}:\d{2})"#) {
            return match
        }
        if let match = firstRegexMatch(in: timestamp, pattern: #"\b\d{1,2}:\d{2}\b"#) {
            return match
        }
        return nil
    }

    private func timestampIsFuture(_ timestamp: String, reference: String) -> Bool {
        guard let timestampDate = parseFlexibleTimestamp(timestamp),
              let referenceDate = parseFlexibleTimestamp(reference) else {
            return false
        }
        return timestampDate > referenceDate
    }

    private func parseFlexibleTimestamp(_ value: String) -> Date? {
        if let parsed = parseMemoriaTimestamp(value) {
            return parsed
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
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
        for dayPart in ["早上", "上午", "中午", "下午", "晚上", "今晚"] where normalized.contains(dayPart) {
            return dayPart
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
    case undoNotAvailable
    case needsSlotConfirmation

    public var errorDescription: String? {
        switch self {
        case .notFound:
            "Pending update not found."
        case .notReviewable:
            "Pending update has already been decided."
        case .undoNotAvailable:
            "This approval cannot be safely undone."
        case .needsSlotConfirmation:
            "This schedule proposal still needs required time, notification, target, or anchor details before approval."
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

private extension MemoryAtomProposal {
    func boundaryReviewEnvelopeIfNeeded() -> PendingUpdatePayloadEnvelope<MemoryAtomProposal>? {
        if memoryType != .reminderSource, let classification {
            return PendingUpdatePayloadEnvelope(
                proposalKind: .memoryAtom,
                proposal: self,
                structuredContext: PendingUpdateStructuredReviewContext(
                    sourceKind: "memory_atom_classification",
                    sourceProposalID: nil,
                    reminder: nil,
                    giftSignal: nil,
                    valueStruct: nil,
                    classification: classification
                ),
                reviewExplanation: PendingUpdateReviewExplanation(
                    targetMatchReason: relatedPeople.first.map { "原文提到 \($0.displayName)。" } ?? "原文没有明确目标人物。",
                    categoryReason: "这条建议保留了 v1.1 分类边界：语义主命题、工作流主卡和写入目标分开审核。",
                    dateParseReason: nil,
                    riskReason: sensitivity == .normal ? "未发现额外敏感风险。" : "这条包含私密或敏感信息，列表默认遮罩。",
                    confidenceReason: isAIInferred ? "包含 AI 推断，确认前不会保存成事实。" : "来源是用户原文。"
                ),
                freshness: .current(),
                approvalResult: nil,
                undo: nil
            )
        }
        guard memoryType == .reminderSource else { return nil }

        let projection = ScheduleBoundaryProjection(text: sourceQuote, title: title)
        let classification = projection.classificationContext()
        let reminderContext = PendingUpdateReminderContext(
            title: title,
            targetPersonID: relatedPeople.first?.matchedPersonID,
            targetDisplayName: relatedPeople.first?.displayName,
            candidatePersonIDs: relatedPeople.compactMap(\.matchedPersonID),
            dueAt: projection.dueAt,
            dueLabel: projection.dueLabel,
            dateParseReason: projection.reasonSummary,
            scheduleSubtype: projection.scheduleSubtype,
            scheduleExecutionState: projection.scheduleExecutionState,
            timeRole: projection.timeRole,
            timeExpressionKind: projection.timeExpressionKind,
            timePrecision: projection.timePrecision,
            rawTimeExpression: projection.rawTimeExpression,
            referenceDate: projection.referenceDate,
            referenceDatetime: projection.referenceDatetime,
            timezone: projection.timezone,
            startAt: projection.startAt,
            endAt: nil,
            deadlineRelation: projection.deadlineRelation,
            remindAt: projection.remindAt,
            commitmentLevel: projection.commitmentLevel,
            notificationPolicy: projection.notificationPolicy,
            needsSlotConfirmation: projection.needsSlotConfirmation,
            confirmationBlockers: projection.confirmationBlockers,
            confirmationReasons: projection.confirmationReasons,
            requiresUserApproval: true,
            reasonSummary: projection.reasonSummary,
            confusionGuard: projection.confusionGuard,
            actor: projection.actor,
            action: projection.action,
            targetPerson: projection.targetPerson,
            location: nil,
            resolvedWindow: projection.resolvedWindow,
            resolvedTime: projection.resolvedTime,
            recurrenceRule: projection.recurrenceRule,
            mutationMatch: projection.mutationMatch,
            contextualGuard: projection.contextualGuard
        )

        return PendingUpdatePayloadEnvelope(
            proposalKind: .memoryAtom,
            proposal: self,
            structuredContext: PendingUpdateStructuredReviewContext(
                sourceKind: "memory_atom_schedule_projection",
                sourceProposalID: nil,
                reminder: reminderContext,
                giftSignal: nil,
                valueStruct: nil,
                classification: classification
            ),
            reviewExplanation: PendingUpdateReviewExplanation(
                targetMatchReason: relatedPeople.first.map { "原文提到 \($0.displayName)。" } ?? "原文没有明确目标人物。",
                categoryReason: "这句话包含用户动作、未来/待确认时间或日程修改语义，因此进入行程安排；批准前不会直接写入本地提醒。",
                dateParseReason: projection.reasonSummary,
                riskReason: "普通行程默认 sensitivity=normal；没有用户明确私密展示偏好时不标记为私密。",
                confidenceReason: isAIInferred ? "包含 AI 推断，确认前不会保存成事实。" : "来源是用户原文。"
            ),
            freshness: .current(),
            approvalResult: nil,
            undo: nil
        )
    }
}

private struct ScheduleBoundaryProjection {
    let text: String
    let title: String
    let referenceDate: String
    let referenceDatetime: String
    let timezone = "Asia/Shanghai"

    init(text: String, title: String) {
        self.text = text
        self.title = title
        self.referenceDate = memoriaDateOnlyString()
        self.referenceDatetime = memoriaTimestamp()
    }

    private struct TimestampCandidate {
        let raw: String
        let dateOnly: String
        let timeLabel: String
        let timestamp: String
    }

    var hasEventVerb: Bool {
        containsAny(["约饭", "约个饭", "吃饭", "见面", "开会", "会议", "喝咖啡", "讲座"], in: text)
    }

    var noNotificationRequest: Bool {
        containsAny(["不用提醒", "别提醒", "不要提醒", "不需要提醒"], in: text)
    }

    private var absoluteDateTimeCandidates: [TimestampCandidate] {
        regexCaptureGroups(in: text, pattern: #"(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]?\s*([01]?\d|2[0-3]):([0-5]\d)"#).compactMap { match in
            guard match.count >= 5,
                  let month = Int(match[1]),
                  let day = Int(match[2]),
                  let hour = Int(match[3]) else {
                return nil
            }
            let minute = match[4]
            let date = monthDayDateOnly(month: month, day: day)
            let time = String(format: "%02d:%@", hour, minute)
            return TimestampCandidate(raw: match[0], dateOnly: date, timeLabel: time, timestamp: timestamp(dateOnly: date, timeLabel: time))
        }
    }

    private var relativeDateTimeCandidates: [TimestampCandidate] {
        regexCaptureGroups(in: text, pattern: #"(昨天|今天|明天|后天|周[一二三四五六日天]|星期[一二三四五六日天])\s*([01]?\d|2[0-3]):([0-5]\d)"#).compactMap { match in
            guard match.count >= 4,
                  let hour = Int(match[2]),
                  let date = dateOnly(forRelativeExpression: match[1]) else {
                return nil
            }
            let time = String(format: "%02d:%@", hour, match[3])
            return TimestampCandidate(raw: match[0], dateOnly: date, timeLabel: time, timestamp: timestamp(dateOnly: date, timeLabel: time))
        }
    }

    private var dateTimeCandidates: [TimestampCandidate] {
        absoluteDateTimeCandidates + relativeDateTimeCandidates
    }

    var timeLabels: [String] {
        regexCaptureGroups(in: text, pattern: #"\b([01]?\d|2[0-3]):([0-5]\d)\b"#).compactMap { match in
            guard match.count >= 3, let hour = Int(match[1]) else { return nil }
            return String(format: "%02d:%@", hour, match[2])
        }
    }

    var deadlineDateOnly: String? {
        if let match = regexCaptureGroups(in: text, pattern: #"(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]?\s*(?:前|之前|截止)"#).first,
           match.count >= 3,
           let month = Int(match[1]),
           let day = Int(match[2]) {
            return monthDayDateOnly(month: month, day: day)
        }
        if text.contains("周五前") || text.contains("星期五前") {
            return dateOnlyStringForNextWeekday(6)
        }
        return nil
    }

    var eventStartAt: String? {
        guard scheduleSubtype == "event" else { return nil }
        if conflatedEventReminderTime {
            return nil
        }
        return dateTimeCandidates.first?.timestamp
    }

    var reminderTriggerAt: String? {
        if scheduleSubtype == "recurring" {
            return recurringNextTriggerAt
        }
        if scheduleSubtype == "deadline" {
            if dateTimeCandidates.count >= 2 {
                return dateTimeCandidates[1].timestamp
            }
            if explicitReminderRequest {
                return dateTimeCandidates.first?.timestamp
            }
            return nil
        }
        if hasEventVerb, explicitReminderRequest {
            guard !conflatedEventReminderTime else { return nil }
            if dateTimeCandidates.count >= 2 {
                return dateTimeCandidates[1].timestamp
            }
            if let eventStartAt,
               let eventDate = dateOnly(fromTimestamp: eventStartAt),
               timeLabels.count >= 2 {
                return timestamp(dateOnly: eventDate, timeLabel: timeLabels[1])
            }
            return nil
        }
        guard explicitReminderRequest else { return nil }
        return dateTimeCandidates.first?.timestamp ?? resolvedTimestamp
    }

    var recurringNextTriggerAt: String? {
        guard scheduleSubtype == "recurring",
              let remindTime = recurringRemindTime,
              let weekday = inferredWeekday else {
            return nil
        }
        return timestamp(dateOnly: dateOnlyStringForNextWeekday(weekday), timeLabel: remindTime)
    }

    var recurringRemindTime: String? {
        scheduleSubtype == "recurring" ? timeLabels.first : nil
    }

    var conflatedEventReminderTime: Bool {
        hasEventVerb &&
            explicitReminderRequest &&
            dateTimeCandidates.count == 1 &&
            timeLabels.count <= 1
    }

    var reminderTriggerIsPast: Bool {
        guard let trigger = reminderTriggerAt,
              let triggerDate = parseFlexibleTimestamp(trigger),
              let referenceDate = parseFlexibleTimestamp(referenceDatetime) else {
            return false
        }
        return triggerDate <= referenceDate
    }

    var scheduleSubtype: String {
        if containsAny(["取消"], in: text) { return "cancel_existing" }
        if containsAny(["改到", "改成", "换到", "延期"], in: text) { return "reschedule_existing" }
        if noNotificationRequest, !hasEventVerb { return "update_existing" }
        if containsAny(["每周", "每月", "每天", "每次"], in: text) { return "recurring" }
        if containsAny(["别提", "别说", "不要提"], in: text), containsAny(["见", "见面", "下次"], in: text) { return "contextual_guard" }
        if containsAny(["前", "截止", "deadline", "due"], in: text), !containsAny(["见面前", "见 May 前", "见May前"], in: text) { return "deadline" }
        if hasEventVerb { return "event" }
        if containsAny(["问", "确认", "跟进", "祝", "发消息", "忘"], in: text) { return "follow_up" }
        return "task"
    }

    var scheduleExecutionState: String {
        switch scheduleSubtype {
        case "cancel_existing", "reschedule_existing", "update_existing":
            return "existing_item_mutation"
        case "contextual_guard":
            return "contextual_guard_candidate"
        case "recurring":
            if recurringNextTriggerAt != nil, !reminderTriggerIsPast {
                return "executable_reminder"
            }
            return "draft_schedule_candidate"
        case "deadline":
            if reminderTriggerAt != nil, !reminderTriggerIsPast {
                return "executable_reminder"
            }
            return "draft_schedule_candidate"
        case "event":
            if noNotificationRequest, eventStartAt != nil {
                return "executable_schedule_item"
            }
            if explicitReminderRequest, eventStartAt != nil, reminderTriggerAt != nil, !reminderTriggerIsPast {
                return "executable_reminder"
            }
            return "draft_schedule_candidate"
        default:
            if explicitReminderRequest, reminderTriggerAt != nil, !reminderTriggerIsPast {
                return "executable_reminder"
            }
            return "draft_schedule_candidate"
        }
    }

    var rawTimeExpression: String? {
        if let raw = dateTimeCandidates.first?.raw {
            return raw
        }
        if let relativeDateTime = firstRegexMatch(in: text, pattern: #"(今天|明天|后天|周[一二三四五六日天]|星期[一二三四五六日天])\s*([01]?\d|2[0-3]):[0-5]\d"#) {
            return relativeDateTime
        }
        if let bareTime = timeLabel, containsAny(["今天", "明天", "后天", "周", "星期"], in: text) {
            if text.contains("明天") { return "明天 \(bareTime)" }
            if text.contains("今天") { return "今天 \(bareTime)" }
            if text.contains("后天") { return "后天 \(bareTime)" }
            return bareTime
        }
        for token in ["下午", "今晚", "明早", "明晚", "明天", "下周三", "下周", "周五", "周三"] where text.contains(token) {
            return token
        }
        return firstRegexMatch(in: text, pattern: #"\d{1,2}\s*月\s*\d{1,2}\s*[日号]?(?:\s*\d{1,2}:\d{2})?"#)
    }

    var dueLabel: String {
        rawTimeExpression ?? "未定日期"
    }

    var dueAt: String? {
        if scheduleSubtype == "deadline" {
            return deadlineDateOnly
        }
        return reminderTriggerAt ?? eventStartAt ?? resolvedTimestamp
    }

    var explicitReminderRequest: Bool {
        containsAny(["提醒我", "提醒一下", "提醒"], in: text) &&
            !containsAny(["不用提醒", "别提醒", "不要提醒"], in: text)
    }

    var dateOnly: String? {
        if let date = dateTimeCandidates.first?.dateOnly {
            return date
        }
        if text.contains("昨天") { return memoriaDateOnlyString(daysFromNow: -1) }
        if text.contains("今天") { return memoriaDateOnlyString(daysFromNow: 0) }
        if text.contains("明天") { return memoriaDateOnlyString(daysFromNow: 1) }
        if text.contains("后天") { return memoriaDateOnlyString(daysFromNow: 2) }
        if let weekday = inferredWeekday {
            return dateOnlyStringForNextWeekday(weekday)
        }
        if let date = firstRegexMatch(in: text, pattern: #"\d{4}-\d{2}-\d{2}"#) {
            return date
        }
        return nil
    }

    var timeLabel: String? {
        if let time = dateTimeCandidates.first?.timeLabel {
            return time
        }
        if let time = firstRegexMatch(in: text, pattern: #"\b([01]?\d|2[0-3]):[0-5]\d\b"#) {
            return time.count == 4 ? "0\(time)" : time
        }
        if let hour = firstRegexCapture(in: text, pattern: #"(\d{1,2})\s*(点|时)"#),
           let hourInt = Int(hour),
           (0...23).contains(hourInt) {
            return String(format: "%02d:00", hourInt)
        }
        return nil
    }

    var resolvedTimestamp: String? {
        guard let dateOnly, let timeLabel else { return nil }
        return "\(dateOnly)T\(timeLabel):00+08:00"
    }

    var actor: String {
        "user"
    }

    var action: String {
        if containsAny(["取消"], in: text) { return "cancel" }
        if containsAny(["改到", "改成", "换到", "延期"], in: text) { return "reschedule" }
        if containsAny(["不用提醒", "别提醒", "不要提醒"], in: text) { return "disable_reminder" }
        if containsAny(["问"], in: text) { return "ask" }
        if containsAny(["发"], in: text) { return "send" }
        if containsAny(["祝"], in: text) { return "congratulate" }
        if containsAny(["约饭", "约个饭", "吃饭"], in: text) { return "meal" }
        if containsAny(["开会", "会议"], in: text) { return "meeting" }
        return scheduleSubtype
    }

    var targetPerson: String? {
        for name in ["Jason", "May", "Alex", "Chris"] where text.localizedCaseInsensitiveContains(name) {
            return name
        }
        return nil
    }

    var resolvedWindow: [String: String]? {
        guard let rawTimeExpression else { return nil }
        if let eventStartAt {
            var window = [
                "start_at": eventStartAt,
                "precision": "exact_minute",
                "requires_confirmation": scheduleExecutionState == "executable_schedule_item" ? "false" : "true"
            ]
            if let reminderTriggerAt {
                window["remind_at"] = reminderTriggerAt
                window["requires_confirmation"] = "false"
            }
            return window
        }
        if let reminderTriggerAt {
            return [
                "remind_at": reminderTriggerAt,
                "precision": "exact_minute",
                "requires_confirmation": scheduleExecutionState == "executable_reminder" ? "false" : "true"
            ]
        }
        if rawTimeExpression == "下午" {
            return [
                "start_after": "\(referenceDate)T12:00:00+08:00",
                "end_before": "\(referenceDate)T18:00:00+08:00",
                "requires_confirmation": "true"
            ]
        }
        if ["今晚", "明早", "明晚"].contains(rawTimeExpression) {
            return [
                "raw_time_expression": rawTimeExpression,
                "requires_confirmation": "true"
            ]
        }
        return nil
    }

    var resolvedTime: [String: String]? {
        var result: [String: String] = [:]
        if let eventStartAt {
            result["start_at"] = eventStartAt
        }
        if let deadlineDateOnly {
            result["due_date"] = deadlineDateOnly
            result["due_precision"] = "date_only"
        }
        if let reminderTriggerAt {
            result["remind_at"] = reminderTriggerAt
        }
        guard !result.isEmpty else { return nil }
        result["timezone"] = timezone
        result["source"] = explicitReminderRequest || recurringRemindTime != nil || noNotificationRequest ? "user_explicit" : "parsed_event_time"
        return result
    }

    var recurrenceRule: [String: String]? {
        guard scheduleSubtype == "recurring" else { return nil }
        var rule = [
            "frequency": text.contains("每月") ? "monthly" : "weekly",
            "interval": "1",
            "timezone": timezone,
            "anchor_date": referenceDate,
            "end_condition_or_null": "",
            "skip_or_exception_policy": "ask",
            "business_day_policy": "",
            "calendar_system": "Gregorian",
            "timezone_dst_policy": ""
        ]
        if let weekday = inferredWeekdayName {
            rule["by_weekday"] = weekday
        }
        if let recurringRemindTime {
            rule["remind_time_or_null"] = recurringRemindTime
            rule["needs_remind_time"] = "false"
        } else {
            rule["remind_time_or_null"] = ""
            rule["needs_remind_time"] = "true"
        }
        if let recurringNextTriggerAt {
            rule["next_trigger_at_or_null"] = recurringNextTriggerAt
        } else {
            rule["next_trigger_at_or_null"] = ""
        }
        return rule
    }

    var mutationMatch: [String: String]? {
        guard ["cancel_existing", "reschedule_existing", "update_existing"].contains(scheduleSubtype) else { return nil }
        return [
            "match_status": "ambiguous",
            "can_approve_without_more_input": "false",
            "operation_allowed": "false",
            "match_score": "0"
        ]
    }

    var contextualGuard: [String: String]? {
        guard scheduleSubtype == "contextual_guard" else { return nil }
        return [
            "anchor_status": "unmatched",
            "anchor_event_id_or_null": "",
            "anchor_match_score": "0",
            "standalone_blocked_reason": "anchor_event_missing",
            "guard_condition": "before_meeting"
        ]
    }

    var startAt: String? {
        eventStartAt
    }

    var remindAt: String? {
        reminderTriggerAt
    }

    var deadlineRelation: String? {
        guard scheduleSubtype == "deadline" else { return nil }
        if containsAny(["前", "之前"], in: text) { return "before_or_on" }
        if containsAny(["截止"], in: text) { return "by_end_of_day" }
        return "unknown"
    }

    var timeRole: String {
        switch scheduleSubtype {
        case "deadline":
            return "deadline_due"
        case "recurring":
            return "recurrence_trigger"
        case "contextual_guard":
            return "anchor_event"
        case "cancel_existing", "reschedule_existing", "update_existing":
            return "ambiguous"
        default:
            if conflatedEventReminderTime {
                return "ambiguous"
            }
            if reminderTriggerAt != nil {
                return "reminder_trigger"
            }
            if eventStartAt != nil {
                return "event_start"
            }
            return containsAny(["提醒"], in: text) ? "reminder_trigger" : "event_start"
        }
    }

    var timeExpressionKind: String {
        if scheduleSubtype == "recurring" {
            return "recurring_rule"
        }
        if eventStartAt != nil || reminderTriggerAt != nil {
            return "exact_datetime"
        }
        if scheduleSubtype == "deadline", deadlineDateOnly != nil {
            return "absolute_date"
        }
        guard let rawTimeExpression else { return "missing_time" }
        if containsAny(["下午", "今晚", "明早", "明晚"], in: rawTimeExpression) {
            return "fuzzy_window"
        }
        if containsAny(["下周"], in: rawTimeExpression) {
            return "relative_window"
        }
        if containsAny(["今天", "明天", "周"], in: rawTimeExpression) {
            return "relative_date"
        }
        if rawTimeExpression.range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) != nil {
            return "exact_datetime"
        }
        return "absolute_date"
    }

    var timePrecision: String {
        switch timeExpressionKind {
        case "exact_datetime":
            return "exact_minute"
        case "recurring_rule":
            return recurringRemindTime == nil ? "date_only" : "exact_minute"
        case "fuzzy_window":
            return "half_day_window"
        case "relative_date", "absolute_date":
            return "date_only"
        case "relative_window":
            return "relative_window"
        default:
            return "unresolved"
        }
    }

    var commitmentLevel: String {
        if containsAny(["如果", "有空"], in: text) { return "conditional" }
        if containsAny(["可能", "要不"], in: text) { return "suggested" }
        if containsAny(["上周", "昨天"], in: text) { return "past" }
        if containsAny(["不想", "不太想"], in: text) { return "negative" }
        if containsAny(["打算", "想", "准备"], in: text) { return "intended" }
        return "committed"
    }

    var notificationPolicy: PendingUpdateNotificationPolicy {
        if scheduleExecutionState == "executable_reminder",
           let trigger = reminderTriggerAt {
            return PendingUpdateNotificationPolicy(
                deliveryMode: "reminder",
                policySource: "user_explicit",
                triggerAtOrNull: scheduleSubtype == "recurring" ? nil : trigger,
                offsetOrNull: nil,
                nextTriggerAtOrNull: scheduleSubtype == "recurring" ? trigger : nil,
                timezone: timezone,
                requiresConfirmation: false,
                defaultAllowed: false
            )
        }
        if scheduleExecutionState == "executable_schedule_item", noNotificationRequest {
            return PendingUpdateNotificationPolicy(
                deliveryMode: "no_notification",
                policySource: "user_explicit",
                triggerAtOrNull: nil,
                offsetOrNull: nil,
                nextTriggerAtOrNull: nil,
                timezone: timezone,
                requiresConfirmation: false,
                defaultAllowed: false
            )
        }
        return PendingUpdateNotificationPolicy.unspecified(timezone: timezone)
    }

    var needsSlotConfirmation: Bool {
        !confirmationBlockers.isEmpty
    }

    var confirmationReasons: [String] {
        confirmationBlockers.map(\.code)
    }

    var confirmationBlockers: [PendingUpdateConfirmationBlocker] {
        switch scheduleSubtype {
        case "cancel_existing":
            return [
                blocker("mutation_match_ambiguous", field: "mutation_match", requiredFor: "existing_item_mutation", question: "你要取消哪一项？"),
                blocker("cancel_scope_missing", field: "cancel_scope", requiredFor: "cancel_existing", question: "这次只取消单次，还是整个重复事项？")
            ]
        case "reschedule_existing":
            return [
                blocker("mutation_match_ambiguous", field: "mutation_match", requiredFor: "existing_item_mutation", question: "你要改期哪一项？"),
                blocker("time_slot", field: "new_time", requiredFor: "reschedule_existing", question: "新时间具体是几点？"),
                blocker("notification_policy_missing", field: "notification_policy", requiredFor: "executable_reminder", question: "改期后还需要提醒吗？")
            ]
        case "update_existing":
            return [
                blocker("target_item", field: "target_item", requiredFor: "update_existing", question: "你要修改哪一个提醒？")
            ]
        case "contextual_guard":
            return [
                blocker("anchor_event_missing", field: "anchor_event", requiredFor: "anchored_contextual_guard", question: "这条边界要挂在哪一次见面前？")
            ]
        case "recurring":
            if scheduleExecutionState == "executable_reminder" {
                return []
            }
            return [
                blocker("recurrence_policy", field: "recurrence_rule", requiredFor: "executable_reminder", question: "重复提醒的具体触发时间是什么？"),
                blocker("notification_policy_missing", field: "notification_policy", requiredFor: "executable_reminder", question: "你希望我什么时候提醒你？")
            ]
        case "deadline":
            if scheduleExecutionState == "executable_reminder" {
                return []
            }
            if reminderTriggerIsPast {
                return [
                    blocker("past_trigger", field: "remind_at", requiredFor: "executable_reminder", question: "这个提醒时间已经过去了，要改成什么时候？")
                ]
            }
            return [
                blocker("date_only_due_without_reminder", field: "due_at", requiredFor: "executable_reminder", question: "截止前你希望什么时候提醒？"),
                blocker("deadline_relation_unknown", field: "deadline_relation", requiredFor: "deadline", question: "这个截止是当天前、当天结束前，还是其他边界？")
            ]
        default:
            guard scheduleExecutionState != "executable_reminder",
                  scheduleExecutionState != "executable_schedule_item" else {
                return []
            }
            var blockers: [PendingUpdateConfirmationBlocker] = []
            if reminderTriggerIsPast {
                blockers.append(blocker("past_trigger", field: "remind_at", requiredFor: "executable_reminder", question: "这个提醒时间已经过去了，要改成什么时候？"))
                return blockers
            }
            if conflatedEventReminderTime {
                blockers.append(blocker("time_slot", field: "raw_time_expression", requiredFor: "executable_reminder", question: "15:00 是会议开始时间，还是提醒你的时间？"))
                blockers.append(blocker("notification_policy_missing", field: "notification_policy", requiredFor: "executable_reminder", question: "如果 15:00 是会议开始时间，你希望什么时候提醒？"))
                return blockers
            }
            if timePrecision != "exact_minute" {
                blockers.append(blocker("time_slot", field: "raw_time_expression", requiredFor: "executable_reminder", question: "这条安排具体是什么时间？"))
            }
            blockers.append(blocker("notification_policy_missing", field: "notification_policy", requiredFor: "executable_reminder", question: "你希望我什么时候提醒你？"))
            return blockers
        }
    }

    var reasonSummary: String {
        "已按语义边界归为 \(scheduleSubtype)：保留原文时间「\(dueLabel)」，当前为 \(scheduleExecutionState)，必须先处理 \(confirmationReasons.joined(separator: ", ")) 后才可能变成可执行提醒。"
    }

    var confusionGuard: [String] {
        var guards = ["schedule_vs_reflection"]
        if containsAny(["尴尬", "担心", "怕"], in: text) {
            guards.append("emotion_as_context_not_reflection")
        }
        return guards
    }

    func classificationContext() -> PendingUpdateClassificationContext {
        if text.contains("面试"), containsAny(["问", "提醒我", "祝"], in: text) {
            return PendingUpdateClassificationContext(
                propositionUnits: [
                    ClassificationPropositionUnit(
                        unitID: "u1",
                        sourceSpan: "Jason 最近准备面试",
                        propositionalContent: "Jason is preparing for an interview",
                        attitudeHolder: "user",
                        intentionalMode: "belief/assertion",
                        directionOfFit: "mind_to_world",
                        evidentiality: "direct_observation",
                        confidenceBasis: "user states a friend current state",
                        domainObject: "person_fact",
                        candidateWorkflow: "person_fact/current_state",
                        candidateStorageTargets: ["person_fact"],
                        proposalKind: "write_candidate"
                    ),
                    ClassificationPropositionUnit(
                        unitID: "u2",
                        sourceSpan: text,
                        propositionalContent: "the user intends a follow-up action",
                        attitudeHolder: "user",
                        intentionalMode: "intention",
                        directionOfFit: "world_to_mind",
                        evidentiality: "direct_observation",
                        confidenceBasis: "user states a future action",
                        domainObject: "schedule",
                        candidateWorkflow: "reminder_source/follow_up",
                        candidateStorageTargets: ["reminder_source"],
                        proposalKind: "workflow_candidate"
                    )
                ],
                semanticPrimaryUnitID: "u1",
                workflowPrimaryUnitID: "u2",
                secondaryUnitIDs: ["u1"],
                semanticPrimary: "u1:friend current state",
                workflowPrimary: "reminder_source/follow_up",
                secondaryWorkflows: ["person_fact/current_state"],
                storageTargets: ["reminder_source", "person_fact"],
                retentionPolicy: "write_candidate",
                illocutionaryForce: "planning_declaration",
                domainFrame: "schedule",
                operation: "create",
                ambiguousSlots: ["raw_time_expression", "notification_policy"],
                candidateInterpretations: [
                    ClassificationCandidateInterpretation(workflowPrimary: "reminder_source/follow_up", reason: "用户表达了后续跟进行动。")
                ],
                blockedDecision: "cannot_create_executable_reminder_until_time_and_notification_policy_confirmed",
                confirmationQuestion: "你希望什么时候提醒你跟进？",
                reasonSummary: "朋友状态是语义主命题，用户跟进行动是整理台主卡。",
                confusionGuard: ["friend_state_with_user_follow_up"]
            )
        }

        let secondaryUnits: [ClassificationPropositionUnit]
        let secondaryIDs: [String]
        if containsAny(["尴尬", "焦虑", "紧张"], in: text) {
            secondaryUnits = [
                ClassificationPropositionUnit(
                    unitID: "u2",
                    sourceSpan: "有点情绪上下文",
                    propositionalContent: "the user reports a short-lived feeling attached to the plan",
                    attitudeHolder: "user",
                    intentionalMode: "self_interpretation",
                    directionOfFit: "self_interpretation",
                    evidentiality: "direct_observation",
                    confidenceBasis: "emotion is incidental to the schedule statement",
                    domainObject: "episodic_self_state",
                    candidateWorkflow: nil,
                    candidateStorageTargets: [],
                    proposalKind: "context_only"
                )
            ]
            secondaryIDs = ["u2"]
        } else {
            secondaryUnits = []
            secondaryIDs = []
        }

        return PendingUpdateClassificationContext(
            propositionUnits: [
                ClassificationPropositionUnit(
                    unitID: "u1",
                    sourceSpan: text,
                    propositionalContent: "the user has a schedule-like action or mutation to review",
                    attitudeHolder: "user",
                    intentionalMode: commitmentLevel == "negative" ? "preference" : "intention",
                    directionOfFit: "world_to_mind",
                    evidentiality: "direct_observation",
                    confidenceBasis: "the source is the user's own record",
                    domainObject: "schedule",
                    candidateWorkflow: "reminder_source/\(scheduleSubtype)",
                    candidateStorageTargets: ["reminder_source"],
                    proposalKind: "workflow_candidate"
                )
            ] + secondaryUnits,
            semanticPrimaryUnitID: "u1",
            workflowPrimaryUnitID: "u1",
            secondaryUnitIDs: secondaryIDs,
            semanticPrimary: "u1:schedule candidate",
            workflowPrimary: "reminder_source/\(scheduleSubtype)",
            secondaryWorkflows: [],
            storageTargets: ["reminder_source"],
            retentionPolicy: "write_candidate",
            illocutionaryForce: "planning_declaration",
            domainFrame: "schedule",
            operation: classificationOperation,
            ambiguousSlots: confirmationReasons,
            candidateInterpretations: [
                ClassificationCandidateInterpretation(workflowPrimary: "reminder_source/\(scheduleSubtype)", reason: "原文包含用户动作、时间或提醒/修改语义。")
            ],
            blockedDecision: needsSlotConfirmation ? "cannot_create_executable_reminder_until_required_slots_confirmed" : nil,
            confirmationQuestion: confirmationBlockers.first?.question,
            reasonSummary: reasonSummary,
            confusionGuard: confusionGuard
        )
    }

    var classificationOperation: String {
        switch scheduleSubtype {
        case "cancel_existing":
            return "cancel_existing"
        case "reschedule_existing":
            return "reschedule_existing"
        case "update_existing":
            return "update_existing"
        case "contextual_guard":
            return "ask_confirmation"
        default:
            return "create"
        }
    }

    private func blocker(
        _ code: String,
        field: String,
        requiredFor: String,
        question: String
    ) -> PendingUpdateConfirmationBlocker {
        PendingUpdateConfirmationBlocker(
            code: code,
            field: field,
            requiredFor: requiredFor,
            observedValue: dueLabel == "未定日期" ? nil : dueLabel,
            question: question
        )
    }

    private func containsAny(_ needles: [String], in text: String) -> Bool {
        needles.contains { text.localizedCaseInsensitiveContains($0) }
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

    private func regexCaptureGroups(in text: String, pattern: String) -> [[String]] {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        return regex.matches(in: text, range: nsRange).map { match in
            (0..<match.numberOfRanges).map { index in
                guard let range = Range(match.range(at: index), in: text) else {
                    return ""
                }
                return String(text[range])
            }
        }
    }

    private func monthDayDateOnly(month: Int, day: Int) -> String {
        let year = Int(referenceDate.prefix(4)) ?? Calendar.current.component(.year, from: Date())
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func dateOnly(forRelativeExpression expression: String) -> String? {
        switch expression {
        case "昨天":
            return memoriaDateOnlyString(daysFromNow: -1)
        case "今天":
            return memoriaDateOnlyString(daysFromNow: 0)
        case "明天":
            return memoriaDateOnlyString(daysFromNow: 1)
        case "后天":
            return memoriaDateOnlyString(daysFromNow: 2)
        default:
            guard let weekday = weekdayNumber(for: expression) else { return nil }
            return dateOnlyStringForNextWeekday(weekday)
        }
    }

    private func timestamp(dateOnly: String, timeLabel: String) -> String {
        "\(dateOnly)T\(timeLabel):00+08:00"
    }

    private func dateOnly(fromTimestamp timestamp: String) -> String? {
        guard timestamp.count >= 10 else { return nil }
        return String(timestamp.prefix(10))
    }

    private func parseFlexibleTimestamp(_ value: String) -> Date? {
        if let parsed = parseMemoriaTimestamp(value) {
            return parsed
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private var inferredWeekdayName: String? {
        guard let weekday = inferredWeekday else { return nil }
        switch weekday {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
        default: return nil
        }
    }

    private var inferredWeekday: Int? {
        weekdayNumber(for: text)
    }

    private func weekdayNumber(for value: String) -> Int? {
        let pairs: [(String, Int)] = [
            ("周日", 1), ("星期日", 1), ("周天", 1), ("星期天", 1),
            ("周一", 2), ("星期一", 2),
            ("周二", 3), ("星期二", 3),
            ("周三", 4), ("星期三", 4),
            ("周四", 5), ("星期四", 5),
            ("周五", 6), ("星期五", 6),
            ("周六", 7), ("星期六", 7)
        ]
        return pairs.first { value.contains($0.0) }?.1
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

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
