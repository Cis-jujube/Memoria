import Foundation
import MemoriaCore

private let checker = ProtocolChecker()
try await checker.run()
print("Memoria protocol checks passed")

private struct ProtocolChecker {
    func run() async throws {
        try checkMigrationAppliesSchemaV2Tables()
        try checkRawEntryRepositoryCreatesAndFetchesRawEntry()
        try checkAIParserAcceptsValidExtractMemoryResponseAndRejectsInvalidJSON()
        try checkAIParserRejectsStrictKeyAndConfidenceFailures()
        try checkAIParserAcceptsV11StructuredProposalsAndRejectsBadV11()
        try checkStructuredPendingUpdateEnvelopeDisplaysEditsAndApproves()
        try checkReviewUIFixtureCoversExecutableScenarios()
        try checkConnectionTestRequestIsMinimalJSONPing()
        try await checkLocalFallbackKeepsPersonPreferenceAsFriendFact()
        try await checkLocalFallbackCreatesFriendProfilePatches()
        try await checkLocalFallbackRoutesSocialPlansToSchedule()
        try await checkClassificationBoundaryEdgeCases()
        try checkPendingUpdateApprovalCreatesMemoryAtomAndLinksThemeAndPerson()
        try checkProfilePatchApprovalMergesIntoFriendDossier()
        try checkInvalidProfilePatchProposalsAreRejected()
        try checkApprovalCreatesSourceBackedRelationshipEdgeProposal()
        try checkPendingUpdateApprovalIsStatusGuarded()
        try checkMemorySearchFiltersByTypePersonThemeAndSensitivity()
        try checkPeopleGroupsCanBeChangedAndQueried()
        try await checkPeopleCanBelongToMultipleGroups()
        try await checkDashboardStoreCanAddEditAndDeletePeople()
        try checkAgendaActionsPrioritizeTodayReminders()
        try checkPendingUpdatesRouteToThreeReviewCategoriesAndApproveOnce()
        try await checkCaptureModeSelectsTheReviewDeskCategory()
        try await checkQuickCaptureProgressAndDuplicateSubmissionGuard()
        try await checkCaptureRemoteFailureKeepsLocalFallbackDraft()
        try await checkFriendDossierCaptureDeduplicatesProfileFactSuggestions()
        try await checkScheduleCaptureModeForcesScheduleReviewAndReminderCreation()
        try checkCaptureViewNoLongerShowsShortcutChips()
        try checkReminderDueDatePersistsAndLegacyRemindersLoad()
        try checkPeopleProfilesExposeEducationWorkAndRelationshipNetwork()
        try checkRelationshipEdgesArePersistedAndMutable()
        try await checkDashboardStoreCanEditAndDeleteRelationshipEdges()
        try checkRelationshipTagsResolveByManualPriorityAIAndLegacyLabel()
        try checkDefaultSelfIndexThemesAreSeeded()
        try checkClosenessUsesManualLevelAndAISignals()
        try checkGiftRecommendationsExposeScoresAndRisk()
        try checkGiftRecommendationWorkflowGeneratesScoredDirections()
        try checkReminderNotificationPlannerBuildsTodayPlans()
        try checkPeoplePresentationCollapsesInCompactWindows()
        try await checkSidebarRestoresCaptureAndReviewDeskEntrypoints()
        try await checkCaptureFallsBackToReviewableDraftWhenAIJSONFails()
        try checkAgendaAssistantPlansWithoutMutatingCalendar()
        try checkMemoryAutoOrganizerSuggestsCategories()
        try await checkSelfIndexTagsFilterTimelinePosts()
        try await checkSelfIndexManualTagsAndPlazaPostsAreMutable()
        try await checkSelfIndexAllTagSelectionAndRefreshPruneStaleFilters()
        try checkAIPromptIncludesWorkflowToolContextAndCoreTags()
        try await checkLocalFallbackUsesKnownCoreThemesForSelfSearch()
        try await checkDeveloperLogsExposeDiagnosticsAndAuditEvents()
        try await checkDashboardStoreAssistantsDoNotMutatePersistedData()
        try await checkProfileFactSearchRoutesToPeopleNotSelfReflection()
        try await checkBulkFriendCSVPreviewAndConfirmCreatesPeopleAndPatchReviews()
        try await checkTransferBundlePreviewAndMergeKeepsExistingData()
        try checkRelationshipMapLayoutScalesInNarrowWindows()
        try checkRelationshipVisualToneClassification()
        try checkMemoryCategoriesIncludeReflectionsRelationshipsAndGifts()
        try checkChineseFirstCopyExistsForCoreNavigation()
        try checkPersonProfileCategoriesBackAISchema()
    }

    private func checkMigrationAppliesSchemaV2Tables() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = try LocalSQLiteStore(filename: "test.sqlite3", directory: tempDirectory, seedDemoData: false)

        let tables = try store.tableNames()

        try expect(tables.contains("raw_entries"), "raw_entries table missing")
        try expect(tables.contains("memory_atoms"), "memory_atoms table missing")
        try expect(tables.contains("pending_updates"), "pending_updates table missing")
        try expect(tables.contains("themes"), "themes table missing")
        try expect(tables.contains("memory_person_links"), "memory_person_links table missing")
        try expect(tables.contains("memory_theme_links"), "memory_theme_links table missing")
        try expect(tables.contains("ai_runs"), "ai_runs table missing")
    }

    private func checkRawEntryRepositoryCreatesAndFetchesRawEntry() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = try LocalSQLiteStore(filename: "test.sqlite3", directory: tempDirectory, seedDemoData: false)
        let repository = RawEntryRepository(database: store)

        let entry = try repository.create(inputType: .text, rawText: "我好像总是怕麻烦 Alex，所以很多事情没说。")
        let fetched = try repository.fetch(id: entry.id)

        try expect(fetched?.id == entry.id, "raw entry id mismatch")
        try expect(fetched?.inputType == .text, "raw entry input type mismatch")
        try expect(fetched?.rawText == "我好像总是怕麻烦 Alex，所以很多事情没说。", "raw entry text mismatch")
    }

    private func checkAIParserAcceptsValidExtractMemoryResponseAndRejectsInvalidJSON() throws {
        let valid = try fixtureData("extract_memory_valid_response")
        let invalid = try fixtureData("extract_memory_invalid_response")

        let parsed = try AIJSONParser().parseExtractMemoryResponse(data: valid)

        try expect(parsed.memoryProposals.count == 1, "valid response should include one proposal")
        try expect(parsed.memoryProposals[0].sourceQuote == "我好像总是怕麻烦 Alex，所以很多事情没说。", "source quote mismatch")

        do {
            _ = try AIJSONParser().parseExtractMemoryResponse(data: invalid)
            throw CheckError.failed("invalid response was accepted")
        } catch is AIContractError {
        }
    }

    private func checkAIParserRejectsStrictKeyAndConfidenceFailures() throws {
        let parser = AIJSONParser()
        try expectAIContractFailure("extract_memory_extra_top_level_key", parser: parser)
        try expectAIContractFailure("extract_memory_extra_nested_key", parser: parser)
        try expectAIContractFailure("extract_memory_confidence_out_of_range", parser: parser)
    }

    private func checkAIParserAcceptsV11StructuredProposalsAndRejectsBadV11() throws {
        let parser = AIJSONParser()
        let parsed = try parser.parseExtractMemoryResponse(data: fixtureData("extract_memory_v11_structured_schedule_gift"))

        try expect(parsed.schemaVersion == "1.1", "v1.1 response should preserve schema version")
        try expect(parsed.contractName == "extract_memory", "v1.1 response should preserve contract name")
        try expect(parsed.reminderProposals.count == 1, "v1.1 response should parse structured reminder")
        try expect(parsed.reminderProposals[0].dueAt == nil, "relative reminder date should remain unconfirmed")
        try expect(parsed.reminderProposals[0].scheduleSubtype == "follow_up", "structured reminder should preserve schedule subtype")
        try expect(parsed.reminderProposals[0].scheduleExecutionState == "draft_schedule_candidate", "relative reminder should stay a draft candidate")
        try expect(parsed.reminderProposals[0].needsSlotConfirmation, "missing notification policy should require slot confirmation")
        try expect(parsed.reminderProposals[0].confirmationReasons == ["notification_policy_missing"], "confirmation reasons should derive from blockers")
        try expect(parsed.reminderProposals[0].requiresUserApproval, "all reminder proposals must require user approval")
        try expect(parsed.reminderProposals[0].classification?.workflowPrimary == "reminder_source/follow_up", "classification context should preserve workflow primary")
        try expect(parsed.giftSignalProposals.count == 1, "v1.1 response should parse structured gift signal")
        try expect(parsed.giftSignalProposals[0].riskTags == [.preferenceUncertain, .surpriseSensitive], "gift risk tags should parse as enum values")
        try expect(parsed.personFactProposals.first?.valueStruct?.kind == "dislike", "profile value_struct should parse")
        try expect(parsed.personFactProposals.first?.classification?.workflowPrimary == "person_fact/dietary_allergy", "profile fact classification should preserve workflow primary")
        try expect(parsed.giftSignalProposals.first?.classification?.workflowPrimary == "gift_signal/touchpoint", "gift signal classification should preserve workflow primary")

        let legacyReminderJSON = """
        {"entry_summary":"legacy reminder","memory_proposals":[],"person_fact_proposals":[],"reminder_proposals":["明天提醒我问 Jason"],"gift_signal_proposals":["May 喜欢拍立得"],"conflicts":[],"follow_up_questions":[]}
        """
        let legacy = try parser.parseExtractMemoryResponse(content: legacyReminderJSON)
        try expect(legacy.reminderProposals.first?.legacyText == "明天提醒我问 Jason", "legacy reminder string should remain readable")
        try expect(legacy.giftSignalProposals.first?.legacyText == "May 喜欢拍立得", "legacy gift string should remain readable")

        for fixture in [
            "extract_memory_v11_unknown_version",
            "extract_memory_v11_bad_reminder_unknown_key",
            "extract_memory_v11_bad_gift_risk_tag",
            "extract_memory_v11_bad_value_struct_anniversary",
            "extract_memory_v11_bad_candidate_person_ids",
            "extract_memory_v11_bad_legacy_string_arrays",
            "extract_memory_v11_bad_time_role",
            "extract_memory_v11_bad_deadline_missing_due",
            "extract_memory_v11_bad_recurring_incomplete"
        ] {
            try expectAIContractFailure(fixture, parser: parser)
        }
    }

    private func checkStructuredPendingUpdateEnvelopeDisplaysEditsAndApproves() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = try LocalSQLiteStore(filename: "test.sqlite3", directory: tempDirectory, seedDemoData: true)
        let rawEntries = RawEntryRepository(database: store)
        let pendingUpdates = PendingUpdateRepository(database: store)
        let parsed = try AIJSONParser().parseExtractMemoryResponse(data: fixtureData("extract_memory_v11_structured_schedule_gift"))

        let profileEntry = try rawEntries.create(inputType: .text, rawText: "May 不喜欢香菜，但不是过敏。")
        let patch = try require(parsed.personFactProposals.first, "structured profile patch fixture missing")
        let profileUpdate = try pendingUpdates.createPersonProfilePatchProposal(
            sourceEntryID: profileEntry.id,
            proposal: patch,
            envelope: patch.pendingUpdateEnvelope()
        )
        try expect(profileUpdate.structuredReviewContext?.valueStruct?.kind == "dislike", "profile value_struct should be reviewable from envelope")
        let editedProfileUpdate = try pendingUpdates.editPersonProfilePatch(
            id: profileUpdate.id,
            targetPersonID: "demo-may",
            targetDisplayName: "May",
            profileCategory: .dietaryAllergy,
            proposedValue: "不喜欢香菜，但不是过敏。",
            valueStruct: patch.valueStruct
        )
        try expect(editedProfileUpdate.structuredReviewContext?.valueStruct?.item == "香菜", "editing profile patch should preserve value_struct")
        let profileTraceMemory = try pendingUpdates.approve(id: profileUpdate.id)
        let mayAfterProfileApproval = try require(try store.loadSnapshot().people.first { $0.id == "demo-may" }, "May missing after profile approval")
        try expect(mayAfterProfileApproval.categoryNote(.dietaryAllergy).contains("香菜"), "approved profile patch should update May")
        let undoneProfileUpdate = try pendingUpdates.undoApproval(id: profileUpdate.id)
        try expect(undoneProfileUpdate.undoState == "applied", "profile patch undo should update envelope state")
        let mayAfterUndo = try require(try store.loadSnapshot().people.first { $0.id == "demo-may" }, "May missing after profile undo")
        try expect(!mayAfterUndo.categoryNote(.dietaryAllergy).contains("香菜"), "profile patch undo should restore old category note")
        let profileTraceAfterUndo = try require(MemoryRepository(database: store).fetch(id: profileTraceMemory.id), "profile undo should preserve trace memory")
        try expect(profileTraceAfterUndo.status == .disputed, "profile undo should mark trace memory disputed instead of deleting it")

        let reminderEntry = try rawEntries.create(inputType: .text, rawText: "下周三提醒我问 Jason 内推材料")
        let reminder = try require(parsed.reminderProposals.first, "structured reminder fixture missing")
        let reminderUpdate = try pendingUpdates.createMemoryAtomProposal(
            sourceEntryID: reminderEntry.id,
            proposal: reminder.memoryAtomProposal(),
            envelope: reminder.pendingUpdateEnvelope()
        )

        try expect(reminderUpdate.proposal?.memoryType == .reminderSource, "structured reminder should project to reminder_source")
        try expect(reminderUpdate.structuredReviewContext?.reminder?.dueLabel == "下周三", "structured reminder context should be reviewable")
        try expect(reminderUpdate.structuredReviewContext?.reminder?.scheduleSubtype == "follow_up", "structured reminder context should retain subtype")
        try expect(reminderUpdate.structuredReviewContext?.reminder?.confirmationReasons == ["notification_policy_missing"], "structured reminder context should retain blocker reasons")
        try expect(reminderUpdate.structuredReviewContext?.classification?.workflowPrimary == "reminder_source/follow_up", "pending envelope should retain classification context")

        let edited = try pendingUpdates.edit(
            id: reminderUpdate.id,
            title: "问 Jason 内推材料（确认）",
            summary: "下周三提醒用户问 Jason 内推材料。",
            content: "下周三提醒用户问 Jason 内推材料。"
        )
        try expect(edited.structuredReviewContext?.reminder != nil, "editing an envelope should preserve structured context")
        try expect(edited.structuredReviewContext?.classification?.workflowPrimary == "reminder_source/follow_up", "editing should preserve classification context")

        do {
            _ = try pendingUpdates.approve(id: reminderUpdate.id)
            throw CheckError.failed("blocked structured reminder should not approve without slot confirmation")
        } catch PendingUpdateError.needsSlotConfirmation {
        }
        let remindersAfterBlockedStructuredReminder = try store.loadSnapshot().reminders
        try expect(remindersAfterBlockedStructuredReminder.allSatisfy { !$0.title.contains("Jason") || !$0.title.contains("内推") }, "blocked structured reminder must not create a derived reminder")

        let giftEntry = try rawEntries.create(inputType: .text, rawText: "May 想试拍立得相纸和小型香水")
        let giftCountBefore = try store.loadSnapshot().gifts.count
        let gift = try require(parsed.giftSignalProposals.first, "structured gift fixture missing")
        let giftUpdate = try pendingUpdates.createMemoryAtomProposal(
            sourceEntryID: giftEntry.id,
            proposal: gift.memoryAtomProposal(),
            envelope: gift.pendingUpdateEnvelope()
        )
        try expect(giftUpdate.reviewCategory == .friendDossier, "gift signal should route to friend dossier review")
        try expect(giftUpdate.structuredReviewContext?.classification?.workflowPrimary == "gift_signal/touchpoint", "gift pending envelope should retain classification context")
        let giftMemory = try pendingUpdates.approve(id: giftUpdate.id)
        let giftCountAfter = try store.loadSnapshot().gifts.count
        try expect(giftMemory.type == .giftSignal, "structured gift should approve as gift_signal memory")
        try expect(giftCountAfter == giftCountBefore, "approving a gift signal must not create final gift ideas directly")
    }

    private func checkReviewUIFixtureCoversExecutableScenarios() throws {
        let data = try fixtureData("review_ui_pending_updates")
        let object = try JSONSerialization.jsonObject(with: data)
        let dictionary = try castDictionary(object, "review UI fixture")
        let pendingUpdates = try castArray(dictionary["pending_updates"], "pending_updates")
        let scenarios = Set(pendingUpdates.compactMap { ($0 as? [String: Any])?["scenario"] as? String })
        for required in [
            "friend_fact",
            "schedule_unclear_date",
            "gift_signal_high_risk",
            "schema_failure",
            "candidate_people",
            "sensitive_self_reflection"
        ] {
            try expect(scenarios.contains(required), "review UI fixture missing \(required)")
        }
        for update in pendingUpdates {
            let entry = try castDictionary(update, "pending update fixture")
            try expect(entry["id"] as? String != nil, "fixture update needs stable id")
            try expect(entry["proposal_type"] as? String != nil, "fixture update needs proposal type")
            try expect(entry["payload_schema_version"] as? String == "1.1", "fixture update should model v1.1 envelope")
            try expect(entry["payload_contract_name"] as? String == "pending_update_payload", "fixture update should model pending payload contract")
            try expect((entry["expected_labels"] as? [String])?.isEmpty == false, "fixture update needs expected labels")
        }
    }

    private func checkConnectionTestRequestIsMinimalJSONPing() throws {
        let request = makeConnectionTestRequest(settings: NativeSettings(model: .flash))
        let data = try JSONEncoder().encode(request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CheckError.failed("connection test request was not JSON")
        }

        try expect(json["model"] as? String == "deepseek-v4-flash", "connection test uses the wrong model")
        try expect(json["max_tokens"] as? Int == 64, "connection test should stay small")
        let responseFormat = try castDictionary(json["response_format"], "response_format")
        try expect(responseFormat["type"] as? String == "json_object", "connection test should request json_object")
        let messages = try castArray(json["messages"], "messages")
        let messageText = messages
            .compactMap { $0 as? [String: Any] }
            .compactMap { $0["content"] as? String }
            .joined(separator: "\n")
        try expect(messageText.contains(#""ok":true"#), "connection test should use a simple ok=true ping")
        try expect(!messageText.contains("memory_proposals"), "connection test must not use extraction schema")
    }

    private func checkLocalFallbackKeepsPersonPreferenceAsFriendFact() async throws {
        let rawEntry = RawEntry(
            id: "raw-food-preference",
            inputType: .text,
            rawText: "我记得 Alex Chen 他喜欢吃薯片。",
            sourceFileID: nil,
            createdAt: memoriaTimestamp(),
            updatedAt: memoriaTimestamp()
        )

        let response = try await AIWorkflowService().extractMemory(
            rawEntry: rawEntry,
            knownPeople: DashboardSnapshot.demo.people,
            knownThemes: [],
            apiKey: nil,
            settings: NativeSettings(language: .zhCN)
        )
        let proposal = try require(response.memoryProposals.first, "local fallback proposal missing")

        try expect(proposal.memoryType == .personFact, "friend food preference should be a person fact, not reflection")
        try expect(proposal.title.contains("Alex") && proposal.title.contains("薯片"), "fallback title should describe the explicit friend fact")
        try expect(!proposal.title.contains("害怕麻烦"), "fallback title leaked unrelated reflection copy")
        try expect(proposal.relatedPeople.first?.matchedPersonID == "demo-alex", "fallback should link the matched person")
        try expect(proposal.sourceQuote == rawEntry.rawText, "fallback should preserve the original source quote")
    }

    private func checkLocalFallbackCreatesFriendProfilePatches() async throws {
        let rawEntry = RawEntry(
            id: "raw-alex-food-profile",
            inputType: .text,
            rawText: "我记得 Alex Chen 喜欢吃火锅，不吃香菜。",
            sourceFileID: nil,
            createdAt: memoriaTimestamp(),
            updatedAt: memoriaTimestamp()
        )

        let response = try await AIWorkflowService().extractMemory(
            rawEntry: rawEntry,
            knownPeople: DashboardSnapshot.demo.people,
            knownThemes: [],
            apiKey: nil,
            settings: NativeSettings(language: .zhCN)
        )

        try expect(!response.memoryProposals.contains { $0.memoryType == .personalReflection }, "explicit friend food facts must not become personal reflections")
        try expect(response.personFactProposals.contains { $0.targetPersonID == "demo-alex" && $0.profileCategory == .foodPreference && $0.proposedValue.contains("火锅") }, "fallback should create a food preference profile patch")
        try expect(response.personFactProposals.contains { $0.targetPersonID == "demo-alex" && $0.profileCategory == .dietaryAllergy && $0.proposedValue.contains("香菜") }, "fallback should create a dietary/allergy profile patch")
    }

    private func checkLocalFallbackRoutesSocialPlansToSchedule() async throws {
        let text = "我要和 Jason 下午约个饭。"
        let workflow = AIWorkflowService()
        let route = workflow.routeInput(text: text)

        try expect(route.primaryType == MemoryAtomType.reminderSource.rawValue, "social plans with a time should route as schedule, not reflection")
        try expect(route.requiresReminderGeneration, "social plans should request reminder generation")
        let reflectionRoute = workflow.routeInput(text: "今天准备考试时，我发现自己有点焦虑。")
        try expect(reflectionRoute.primaryType == "context_only", "one-off exam anxiety should remain context-only unless the user asks to save it")
        try expect(!reflectionRoute.requiresExtraction, "context-only episodic state should not create a review card by default")

        let rawEntry = RawEntry(
            id: "raw-local-social-plan",
            inputType: .text,
            rawText: text,
            sourceFileID: nil,
            createdAt: memoriaTimestamp(),
            updatedAt: memoriaTimestamp()
        )
        let response = try await workflow.extractMemory(
            rawEntry: rawEntry,
            knownPeople: DashboardSnapshot.demo.people,
            knownThemes: DashboardSnapshot.demo.themes,
            apiKey: nil,
            settings: NativeSettings(language: .zhCN)
        )
        let proposal = try require(response.memoryProposals.first, "local schedule fallback proposal missing")

        try expect(proposal.memoryType == .reminderSource, "social plan should become a reminder source")
        try expect(proposal.sensitivity == .normal, "plain schedule facts must not be marked private")
        try expect(proposal.relatedPeople.first?.matchedPersonID == "demo-jason", "schedule fallback should link Jason")
        try expect(proposal.themes.contains { $0.name == "提醒事项" }, "schedule fallback should use reminder themes")
        try expect(!response.memoryProposals.contains { $0.memoryType == .personalReflection }, "social plan must not create self-reflection cards")

        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = try LocalSQLiteStore(filename: "local-social-plan.sqlite3", directory: tempDirectory, seedDemoData: true)
        let rawEntries = RawEntryRepository(database: store)
        let pendingUpdates = PendingUpdateRepository(database: store)
        let storedEntry = try rawEntries.create(inputType: .text, rawText: text)
        let update = try pendingUpdates.createMemoryAtomProposal(sourceEntryID: storedEntry.id, proposal: proposal)

        try expect(update.reviewCategory == .schedule, "social plan pending update should route to schedule review")
        let scheduleContext = try require(update.structuredReviewContext?.reminder, "schedule fallback should create structured reminder context")
        try expect(scheduleContext.scheduleSubtype == "event", "social plan should be an event candidate")
        try expect(scheduleContext.scheduleExecutionState == "draft_schedule_candidate", "afternoon social plan should not be executable without confirmation")
        try expect(scheduleContext.timeExpressionKind == "fuzzy_window", "afternoon should be preserved as a fuzzy window")
        try expect(scheduleContext.timePrecision == "half_day_window", "afternoon should keep half-day precision")
        try expect(scheduleContext.needsSlotConfirmation, "afternoon social plan should need slot confirmation")
        try expect(scheduleContext.confirmationReasons.contains("time_slot"), "afternoon social plan should ask for a concrete slot")
        try expect(scheduleContext.confirmationReasons.contains("notification_policy_missing"), "non-explicit reminder should ask for notification policy")
        try expect(scheduleContext.requiresUserApproval, "schedule proposals must still require user approval")
        try expect(update.structuredReviewContext?.classification?.workflowPrimary == "reminder_source/event", "schedule fallback should preserve workflow primary")
        try expect(update.proposal?.sensitivity == .normal, "ordinary social plan should stay normal sensitivity")
        do {
            _ = try pendingUpdates.approve(id: update.id)
            throw CheckError.failed("draft social plan should not approve or create a reminder without slot confirmation")
        } catch PendingUpdateError.needsSlotConfirmation {
        }
        let remindersAfterBlockedSocialPlan = try store.loadSnapshot().reminders
        try expect(remindersAfterBlockedSocialPlan.allSatisfy { !$0.title.contains("约饭") }, "blocked social plan must not create a reminder")
    }

    private func checkClassificationBoundaryEdgeCases() async throws {
        let workflow = AIWorkflowService()

        func extract(_ text: String) async throws -> ExtractMemoryResponse {
            let rawEntry = RawEntry(
                id: "raw-\(abs(text.hashValue))",
                inputType: .text,
                rawText: text,
                sourceFileID: nil,
                createdAt: memoriaTimestamp(),
                updatedAt: memoriaTimestamp()
            )
            return try await workflow.extractMemory(
                rawEntry: rawEntry,
                knownPeople: DashboardSnapshot.demo.people,
                knownThemes: DashboardSnapshot.demo.themes,
                apiKey: nil,
                settings: NativeSettings(language: .zhCN)
            )
        }

        let oneOffAnxiety = try await extract("今天准备考试时，我发现自己有点焦虑。")
        try expect(oneOffAnxiety.memoryProposals.isEmpty, "one-off exam anxiety should not create a durable self-reflection card by default")
        try expect(oneOffAnxiety.followUpQuestions.contains { $0.contains("长期保存") || $0.contains("自我反思") }, "context-only state should offer an explicit save path")

        let savedAnxiety = try await extract("今天准备考试时，我发现自己有点焦虑，想记一下这个状态。")
        try expect(savedAnxiety.memoryProposals.first?.memoryType == .personalReflection, "explicit save intent should create a self-reflection candidate")

        let awkwardPlan = try await extract("我想下午和 Jason 吃饭但有点尴尬。")
        try expect(awkwardPlan.memoryProposals.first?.memoryType == .reminderSource, "social plan with incidental awkwardness should stay a schedule candidate")
        try expect(awkwardPlan.memoryProposals.first?.sensitivity == .normal, "incidental awkwardness in a normal plan should not become sensitive")
        try expect(!awkwardPlan.memoryProposals.contains { $0.memoryType == .personalReflection }, "incidental awkwardness should not create a self-reflection card")

        let friendEventOnly = try await extract("Jason 下周面试。")
        try expect(friendEventOnly.memoryProposals.first?.memoryType == .personFact, "friend event without user action should be a friend fact")
        try expect(!friendEventOnly.memoryProposals.contains { $0.memoryType == .reminderSource }, "friend event without user action should not become a reminder")
        try expect(friendEventOnly.personFactProposals.contains { $0.profileCategory == .currentState }, "friend interview state should update current_state")

        let friendWithFollowUp = try await extract("Jason 最近准备面试，我明天问问他。")
        try expect(friendWithFollowUp.memoryProposals.first?.memoryType == .reminderSource, "friend state plus user follow-up should make follow-up the primary workflow")
        try expect(friendWithFollowUp.personFactProposals.contains { $0.profileCategory == .currentState }, "friend follow-up should preserve the friend state as a secondary profile fact")

        let fearMotivation = try await extract("我怕 Jason 忘了材料。")
        try expect(fearMotivation.memoryProposals.first?.memoryType == .reminderSource, "fear about Jason forgetting material should be follow-up motivation, not reflection")

        let foodFact = try await extract("Alex 喜欢薯片，不吃香菜。")
        try expect(foodFact.memoryProposals.first?.memoryType == .personFact, "explicit food preference should be a person fact")
        try expect(foodFact.personFactProposals.contains { $0.profileCategory == .foodPreference }, "food preference should create a food profile patch")
        try expect(foodFact.personFactProposals.contains { $0.profileCategory == .dietaryAllergy }, "dietary avoidance should create a dietary profile patch")

        let relationshipMemory = try await extract("May 和 Alex 最近一起做项目。")
        try expect(relationshipMemory.memoryProposals.first?.memoryType == .relationshipMemory, "two-person collaboration should be relationship memory")

        let giftTouchpoint = try await extract("May 说想试拍立得。")
        try expect(giftTouchpoint.memoryProposals.first?.memoryType == .giftSignal, "friend wish touchpoint should be a gift signal")

        let resourceFact = try await extract("Jason 认识一个投资人。")
        try expect(resourceFact.memoryProposals.first?.memoryType == .personFact, "resource fact without user ask should stay a person fact")
        try expect(resourceFact.memoryProposals.first?.classification?.workflowPrimary == "person_fact/resources", "resource fact should not become an opportunity workflow by itself")
        try expect(resourceFact.memoryProposals.first?.classification?.opportunityType == "none", "resource fact alone should not create a relationship opportunity")
        try expect(resourceFact.personFactProposals.contains { $0.profileCategory == .friendNetwork }, "resource fact should create a friend_network profile patch")
        try expect(!resourceFact.memoryProposals.contains { $0.memoryType == .reminderSource }, "resource fact should not create a reminder")

        let referralRequest = try await extract("Jason 认识一个投资人，我想问他能不能介绍。")
        try expect(referralRequest.memoryProposals.first?.memoryType == .relationshipMemory, "explicit referral ask should be a relationship opportunity review candidate")
        try expect(referralRequest.memoryProposals.first?.classification?.workflowPrimary == "relationship_opportunity/referral_request", "referral ask should use relationship_opportunity workflow")
        try expect(referralRequest.memoryProposals.first?.classification?.storageTargets.contains("relationship_memory") == true, "relationship opportunity should write only approved facts/memory, not a new storage type")
        try expect(referralRequest.memoryProposals.first?.classification?.blockedDecision?.contains("consent") == true, "referral request should stay gated by consent and give-first framing")
        try expect(referralRequest.memoryProposals.first?.classification?.opportunityConsent?["requires_consent"] == "true", "referral request should carry consent metadata")
        try expect(referralRequest.memoryProposals.first?.classification?.giveFirstOffer?["required"] == "true", "referral request should require give-first framing")
        try expect(referralRequest.memoryProposals.first?.classification?.relationshipStage?["confidence"] != nil, "referral request should carry relationship stage confidence")
        try expect(referralRequest.memoryProposals.first?.classification?.priorityScoreAudit?["cap"] == "give_first_and_consent_missing", "referral request should cap priority when consent/give-first are missing")
        try expect(referralRequest.memoryProposals.first?.classification?.opportunityLifecycle?["state"] == "blocked_confirmation", "referral request should start blocked")
        try expect(!referralRequest.memoryProposals.contains { $0.memoryType == .reminderSource }, "referral request should not bypass schedule protocol")

        let introRequest = try await extract("May 让我把她介绍给 Alex。")
        try expect(introRequest.memoryProposals.first?.memoryType == .relationshipMemory, "intro request should be a relationship opportunity review candidate")
        try expect(introRequest.memoryProposals.first?.classification?.workflowPrimary == "relationship_opportunity/intro", "intro request should preserve intro workflow")
        try expect(introRequest.memoryProposals.first?.classification?.blockedDecision?.contains("consent") == true, "single-party consent should not be enough for intro")
        try expect(introRequest.memoryProposals.first?.classification?.opportunityConsent?["ask_target_first"] == "true", "intro request should require target consent")
        try expect(introRequest.memoryProposals.first?.classification?.networkPath?["status"] == "partial", "intro request should carry partial network path")

        let giftAction = try await extract("我想给 May 买生日礼物。")
        try expect(giftAction.memoryProposals.first?.memoryType == .giftSignal, "explicit gift action should still store as gift signal after approval")
        try expect(giftAction.memoryProposals.first?.classification?.workflowPrimary == "relationship_opportunity/gift", "gift buying intent should be a gated relationship opportunity workflow")
        try expect(giftAction.memoryProposals.first?.classification?.storageTargets == ["gift_signal"], "gift opportunity should not introduce a relationship_opportunity storage target")
        try expect(giftAction.memoryProposals.first?.classification?.priorityScoreAudit?["cap"] == "gift_preference_uncertain", "gift opportunity should carry a risk-aware priority audit")
        try expect(giftAction.memoryProposals.first?.classification?.opportunityLifecycle?["state"] == "blocked_confirmation", "gift opportunity should start blocked until preference/timing confirmation")

        let friendDesire = try await extract("May 想暑假旅行。")
        try expect(friendDesire.memoryProposals.first?.memoryType == .personFact, "friend desire owner should not become user's schedule")
        try expect(friendDesire.personFactProposals.contains { $0.profileCategory == .travelPreference }, "friend travel desire should be a travel preference profile fact")

        let boundary = try await extract("我不太想再和 Chris 单独吃饭。")
        try expect(boundary.memoryProposals.first?.memoryType == .personalReflection, "negative relationship boundary should be self/relationship reflection, not schedule")
        try expect(!boundary.memoryProposals.contains { $0.memoryType == .reminderSource }, "negative relationship boundary should not create a new schedule")

        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = try LocalSQLiteStore(filename: "boundary-context.sqlite3", directory: tempDirectory, seedDemoData: true)
        let rawEntries = RawEntryRepository(database: store)
        let pendingUpdates = PendingUpdateRepository(database: store)
        let followUpEntry = try rawEntries.create(inputType: .text, rawText: "Jason 最近准备面试，我明天问问他。")
        let followUpUpdate = try pendingUpdates.createMemoryAtomProposal(
            sourceEntryID: followUpEntry.id,
            proposal: try require(friendWithFollowUp.memoryProposals.first, "follow-up proposal missing")
        )
        let classification = try require(followUpUpdate.structuredReviewContext?.classification, "follow-up classification context missing")
        try expect(classification.semanticPrimaryUnitID == "u1", "friend state should be semantic primary")
        try expect(classification.workflowPrimaryUnitID == "u2", "user follow-up should be workflow primary")
        try expect(classification.secondaryWorkflows.contains("person_fact/current_state"), "friend state should remain a secondary workflow")
        let reminder = try require(followUpUpdate.structuredReviewContext?.reminder, "follow-up reminder context missing")
        try expect(reminder.scheduleSubtype == "follow_up", "friend follow-up should preserve follow_up subtype")
        try expect(reminder.scheduleExecutionState == "draft_schedule_candidate", "date-only follow-up should remain draft candidate")
        try expect(reminder.confirmationReasons.contains("notification_policy_missing"), "follow-up should require notification policy before execution")

        let mutationEntry = try rawEntries.create(inputType: .text, rawText: "取消今晚和 Jason 的饭。")
        let mutationResponse = try await extract(mutationEntry.rawText)
        let mutationUpdate = try pendingUpdates.createMemoryAtomProposal(
            sourceEntryID: mutationEntry.id,
            proposal: try require(mutationResponse.memoryProposals.first, "mutation proposal missing")
        )
        let mutationContext = try require(mutationUpdate.structuredReviewContext?.reminder, "mutation context missing")
        try expect(mutationContext.scheduleSubtype == "cancel_existing", "cancel input should use cancel_existing subtype")
        try expect(mutationContext.scheduleExecutionState == "existing_item_mutation", "cancel input should be an existing item mutation")
        try expect(mutationContext.mutationMatch?["match_status"] == "ambiguous", "cancel mutation must not execute without a unique match")
        do {
            _ = try pendingUpdates.approve(id: mutationUpdate.id)
            throw CheckError.failed("ambiguous mutation should not approve")
        } catch PendingUpdateError.needsSlotConfirmation {
        }

        let guardEntry = try rawEntries.create(inputType: .text, rawText: "下次见 May 别提她前任。")
        let guardResponse = try await extract(guardEntry.rawText)
        let guardUpdate = try pendingUpdates.createMemoryAtomProposal(
            sourceEntryID: guardEntry.id,
            proposal: try require(guardResponse.memoryProposals.first, "contextual guard proposal missing")
        )
        let guardContext = try require(guardUpdate.structuredReviewContext?.reminder, "contextual guard context missing")
        try expect(guardContext.scheduleSubtype == "contextual_guard", "guard input should use contextual_guard subtype")
        try expect(guardContext.contextualGuard?["anchor_status"] == "unmatched", "unanchored guard should not be standalone executable")
        do {
            _ = try pendingUpdates.approve(id: guardUpdate.id)
            throw CheckError.failed("unanchored contextual guard should not approve")
        } catch PendingUpdateError.needsSlotConfirmation {
        }

        let recurringEntry = try rawEntries.create(inputType: .text, rawText: "每周五问 May 论文进度。")
        let recurringResponse = try await extract(recurringEntry.rawText)
        let recurringUpdate = try pendingUpdates.createMemoryAtomProposal(
            sourceEntryID: recurringEntry.id,
            proposal: try require(recurringResponse.memoryProposals.first, "recurring proposal missing")
        )
        let recurringContext = try require(recurringUpdate.structuredReviewContext?.reminder, "recurring context missing")
        try expect(recurringContext.scheduleSubtype == "recurring", "recurring input should preserve recurring subtype")
        try expect(recurringContext.recurrenceRule?["needs_remind_time"] == "true", "recurring candidate should require a remind time")
        do {
            _ = try pendingUpdates.approve(id: recurringUpdate.id)
            throw CheckError.failed("recurring candidate without trigger time should not approve")
        } catch PendingUpdateError.needsSlotConfirmation {
        }

        let tomorrowDate = memoriaDateOnlyString(daysFromNow: 1)
        let tomorrowReminderAt = "\(tomorrowDate)T14:30:00+08:00"
        let tomorrowMismatchReminderAt = "\(tomorrowDate)T14:45:00+08:00"
        let splitEventEntry = try rawEntries.create(inputType: .text, rawText: "明天 15:00 和 Jason 开会，14:30 提醒我。")
        let splitEventResponse = try await extract(splitEventEntry.rawText)
        let splitEventUpdate = try pendingUpdates.createMemoryAtomProposal(
            sourceEntryID: splitEventEntry.id,
            proposal: try require(splitEventResponse.memoryProposals.first, "split event proposal missing")
        )
        let splitEventContext = try require(splitEventUpdate.structuredReviewContext?.reminder, "split event context missing")
        try expect(splitEventContext.scheduleSubtype == "event", "split event should be an event")
        try expect(splitEventContext.scheduleExecutionState == "executable_reminder", "explicit event start and reminder trigger should be executable after approval")
        try expect(splitEventContext.startAt?.contains("\(tomorrowDate)T15:00") == true, "event start should stay separate from reminder trigger")
        try expect(splitEventContext.remindAt == tomorrowReminderAt, "reminder trigger should use the explicit reminder time")
        try expect(splitEventContext.notificationPolicy?.deliveryMode == "reminder", "executable reminder must use reminder delivery")
        try expect(splitEventContext.notificationPolicy?.policySource == "user_explicit", "explicit reminder must keep user_explicit policy source")
        try expect(!splitEventContext.needsSlotConfirmation, "split event should not need slot confirmation")
        let splitEventMemory = try pendingUpdates.approve(id: splitEventUpdate.id)
        let splitReminder = try require(try store.loadSnapshot().reminders.first { $0.id == "reminder-\(splitEventMemory.id)" }, "split event approval should create a local reminder")
        try expect(splitReminder.timeLabel == "14:30", "local reminder should use remind_at, not event start")

        let ambiguousEntry = try rawEntries.create(inputType: .text, rawText: "明天 15:00 提醒我和 Jason 开会。")
        let ambiguousResponse = try await extract(ambiguousEntry.rawText)
        let ambiguousUpdate = try pendingUpdates.createMemoryAtomProposal(
            sourceEntryID: ambiguousEntry.id,
            proposal: try require(ambiguousResponse.memoryProposals.first, "ambiguous event proposal missing")
        )
        let ambiguousContext = try require(ambiguousUpdate.structuredReviewContext?.reminder, "ambiguous event context missing")
        try expect(ambiguousContext.scheduleExecutionState == "draft_schedule_candidate", "conflated event/reminder time must remain a draft")
        try expect(ambiguousContext.timeRole == "ambiguous", "single explicit time with event and reminder wording should be ambiguous")
        try expect(ambiguousContext.confirmationReasons.contains("time_slot"), "ambiguous event should ask which time role was intended")
        do {
            _ = try pendingUpdates.approve(id: ambiguousUpdate.id)
            throw CheckError.failed("ambiguous event/reminder time should not approve")
        } catch PendingUpdateError.needsSlotConfirmation {
        }

        let eventWithoutReminderEntry = try rawEntries.create(inputType: .text, rawText: "明天 15:00 和 Jason 开会。")
        let eventWithoutReminderResponse = try await extract(eventWithoutReminderEntry.rawText)
        let eventWithoutReminderUpdate = try pendingUpdates.createMemoryAtomProposal(
            sourceEntryID: eventWithoutReminderEntry.id,
            proposal: try require(eventWithoutReminderResponse.memoryProposals.first, "event without reminder proposal missing")
        )
        let eventWithoutReminderContext = try require(eventWithoutReminderUpdate.structuredReviewContext?.reminder, "event without reminder context missing")
        try expect(eventWithoutReminderContext.scheduleExecutionState == "draft_schedule_candidate", "event start alone is not a reminder trigger")
        try expect(eventWithoutReminderContext.timeRole == "event_start", "event without reminder should classify the time as event_start")
        try expect(eventWithoutReminderContext.startAt?.contains("\(tomorrowDate)T15:00") == true, "event start should be retained")
        try expect(eventWithoutReminderContext.remindAt == nil, "event start should not be copied to remind_at")
        try expect(eventWithoutReminderContext.confirmationReasons.contains("notification_policy_missing"), "event without reminder policy should be blocked")
        do {
            _ = try pendingUpdates.approve(id: eventWithoutReminderUpdate.id)
            throw CheckError.failed("event without reminder policy should not approve")
        } catch PendingUpdateError.needsSlotConfirmation {
        }
        let editedEventWithoutReminder = try pendingUpdates.edit(
            id: eventWithoutReminderUpdate.id,
            title: eventWithoutReminderUpdate.title,
            summary: eventWithoutReminderUpdate.summary,
            content: eventWithoutReminderUpdate.proposal?.content ?? eventWithoutReminderUpdate.summary,
            reminderDueAt: tomorrowReminderAt,
            reminderDueLabel: "明天 14:30"
        )
        let editedReminderContext = try require(editedEventWithoutReminder.structuredReviewContext?.reminder, "edited reminder context missing")
        try expect(editedReminderContext.scheduleExecutionState == "executable_reminder", "editing an explicit reminder time should unblock the schedule")
        try expect(editedReminderContext.remindAt == tomorrowReminderAt, "edited reminder should store the confirmed remind_at")
        try expect(editedReminderContext.confirmationBlockers.isEmpty, "edited reminder should clear blockers")
        let editedReminderMemory = try pendingUpdates.approve(id: editedEventWithoutReminder.id)
        let editedLocalReminder = try require(try store.loadSnapshot().reminders.first { $0.id == "reminder-\(editedReminderMemory.id)" }, "edited reminder approval should create a local reminder")
        try expect(editedLocalReminder.timeLabel == "14:30", "edited local reminder should use confirmed reminder time")

        let pastEditedEntry = try rawEntries.create(inputType: .text, rawText: "明天 15:00 和 Jason 开会。")
        let pastEditedResponse = try await extract(pastEditedEntry.rawText)
        let pastEditedUpdate = try pendingUpdates.createMemoryAtomProposal(
            sourceEntryID: pastEditedEntry.id,
            proposal: try require(pastEditedResponse.memoryProposals.first, "past edited proposal missing")
        )
        let pastEdited = try pendingUpdates.edit(
            id: pastEditedUpdate.id,
            title: pastEditedUpdate.title,
            summary: pastEditedUpdate.summary,
            content: pastEditedUpdate.proposal?.content ?? pastEditedUpdate.summary,
            reminderDueAt: "2020-01-01T14:30:00+08:00",
            reminderDueLabel: "2020-01-01 14:30"
        )
        let pastEditedContext = try require(pastEdited.structuredReviewContext?.reminder, "past edited context missing")
        try expect(pastEditedContext.scheduleExecutionState != "executable_reminder", "editing a past trigger must not unblock a schedule")
        try expect(!pastEditedContext.confirmationBlockers.isEmpty, "past edited trigger should keep blockers")
        do {
            _ = try pendingUpdates.approve(id: pastEdited.id)
            throw CheckError.failed("past edited trigger should not approve")
        } catch PendingUpdateError.needsSlotConfirmation {
        }

        func malformedUpdate(
            from base: PendingUpdate,
            mutate: (PendingUpdateReminderContext) -> PendingUpdateReminderContext
        ) throws -> PendingUpdate {
            let envelope = try JSONDecoder().decode(PendingUpdatePayloadEnvelope<MemoryAtomProposal>.self, from: Data(base.payloadJSON.utf8))
            let reminder = try require(envelope.structuredContext?.reminder, "base reminder missing")
            var mutableEnvelope = envelope
            mutableEnvelope.structuredContext = PendingUpdateStructuredReviewContext(
                sourceKind: envelope.structuredContext?.sourceKind ?? "test_malformed_schedule",
                sourceProposalID: envelope.structuredContext?.sourceProposalID,
                reminder: mutate(reminder),
                giftSignal: envelope.structuredContext?.giftSignal,
                valueStruct: envelope.structuredContext?.valueStruct,
                classification: envelope.structuredContext?.classification
            )
            return try pendingUpdates.createMemoryAtomProposal(
                sourceEntryID: base.sourceEntryID,
                proposal: mutableEnvelope.proposal,
                envelope: mutableEnvelope
            )
        }

        let malformedMissingStart = try malformedUpdate(from: splitEventUpdate) { reminder in
            PendingUpdateReminderContext(
                title: reminder.title,
                targetPersonID: reminder.targetPersonID,
                targetDisplayName: reminder.targetDisplayName,
                candidatePersonIDs: reminder.candidatePersonIDs,
                dueAt: reminder.dueAt,
                dueLabel: reminder.dueLabel,
                dateParseReason: reminder.dateParseReason,
                scheduleSubtype: "event",
                scheduleExecutionState: "executable_reminder",
                timeRole: "reminder_trigger",
                timeExpressionKind: "exact_datetime",
                timePrecision: "exact_minute",
                rawTimeExpression: reminder.rawTimeExpression,
                referenceDate: reminder.referenceDate,
                referenceDatetime: reminder.referenceDatetime,
                timezone: reminder.timezone,
                startAt: nil,
                endAt: reminder.endAt,
                deadlineRelation: reminder.deadlineRelation,
                remindAt: reminder.remindAt,
                commitmentLevel: reminder.commitmentLevel,
                notificationPolicy: reminder.notificationPolicy,
                needsSlotConfirmation: false,
                confirmationBlockers: [],
                confirmationReasons: [],
                requiresUserApproval: true,
                reasonSummary: reminder.reasonSummary,
                confusionGuard: reminder.confusionGuard,
                actor: reminder.actor,
                action: reminder.action,
                targetPerson: reminder.targetPerson,
                location: reminder.location,
                resolvedWindow: reminder.resolvedWindow,
                resolvedTime: reminder.resolvedTime,
                recurrenceRule: reminder.recurrenceRule,
                mutationMatch: reminder.mutationMatch,
                contextualGuard: reminder.contextualGuard
            )
        }
        do {
            _ = try pendingUpdates.approve(id: malformedMissingStart.id)
            throw CheckError.failed("executable event without start_at should not approve")
        } catch PendingUpdateError.needsSlotConfirmation {
        }

        let malformedPolicyMismatch = try malformedUpdate(from: splitEventUpdate) { reminder in
            PendingUpdateReminderContext(
                title: reminder.title,
                targetPersonID: reminder.targetPersonID,
                targetDisplayName: reminder.targetDisplayName,
                candidatePersonIDs: reminder.candidatePersonIDs,
                dueAt: reminder.dueAt,
                dueLabel: reminder.dueLabel,
                dateParseReason: reminder.dateParseReason,
                scheduleSubtype: reminder.scheduleSubtype,
                scheduleExecutionState: "executable_reminder",
                timeRole: "reminder_trigger",
                timeExpressionKind: "exact_datetime",
                timePrecision: "exact_minute",
                rawTimeExpression: reminder.rawTimeExpression,
                referenceDate: reminder.referenceDate,
                referenceDatetime: reminder.referenceDatetime,
                timezone: reminder.timezone,
                startAt: reminder.startAt,
                endAt: reminder.endAt,
                deadlineRelation: reminder.deadlineRelation,
                remindAt: tomorrowMismatchReminderAt,
                commitmentLevel: reminder.commitmentLevel,
                notificationPolicy: reminder.notificationPolicy,
                needsSlotConfirmation: false,
                confirmationBlockers: [],
                confirmationReasons: [],
                requiresUserApproval: true,
                reasonSummary: reminder.reasonSummary,
                confusionGuard: reminder.confusionGuard,
                actor: reminder.actor,
                action: reminder.action,
                targetPerson: reminder.targetPerson,
                location: reminder.location,
                resolvedWindow: reminder.resolvedWindow,
                resolvedTime: reminder.resolvedTime,
                recurrenceRule: reminder.recurrenceRule,
                mutationMatch: reminder.mutationMatch,
                contextualGuard: reminder.contextualGuard
            )
        }
        do {
            _ = try pendingUpdates.approve(id: malformedPolicyMismatch.id)
            throw CheckError.failed("policy/remind mismatch should not approve")
        } catch PendingUpdateError.needsSlotConfirmation {
        }

        let malformedNextTriggerBypass = try malformedUpdate(from: splitEventUpdate) { reminder in
            PendingUpdateReminderContext(
                title: reminder.title,
                targetPersonID: reminder.targetPersonID,
                targetDisplayName: reminder.targetDisplayName,
                candidatePersonIDs: reminder.candidatePersonIDs,
                dueAt: reminder.dueAt,
                dueLabel: reminder.dueLabel,
                dateParseReason: reminder.dateParseReason,
                scheduleSubtype: reminder.scheduleSubtype,
                scheduleExecutionState: "executable_reminder",
                timeRole: "reminder_trigger",
                timeExpressionKind: "exact_datetime",
                timePrecision: "exact_minute",
                rawTimeExpression: reminder.rawTimeExpression,
                referenceDate: reminder.referenceDate,
                referenceDatetime: reminder.referenceDatetime,
                timezone: reminder.timezone,
                startAt: reminder.startAt,
                endAt: reminder.endAt,
                deadlineRelation: reminder.deadlineRelation,
                remindAt: tomorrowMismatchReminderAt,
                commitmentLevel: reminder.commitmentLevel,
                notificationPolicy: PendingUpdateNotificationPolicy(
                    deliveryMode: "reminder",
                    policySource: "user_explicit",
                    triggerAtOrNull: nil,
                    offsetOrNull: nil,
                    nextTriggerAtOrNull: tomorrowReminderAt,
                    timezone: "Asia/Shanghai",
                    requiresConfirmation: false,
                    defaultAllowed: false
                ),
                needsSlotConfirmation: false,
                confirmationBlockers: [],
                confirmationReasons: [],
                requiresUserApproval: true,
                reasonSummary: reminder.reasonSummary,
                confusionGuard: reminder.confusionGuard,
                actor: reminder.actor,
                action: reminder.action,
                targetPerson: reminder.targetPerson,
                location: reminder.location,
                resolvedWindow: reminder.resolvedWindow,
                resolvedTime: reminder.resolvedTime,
                recurrenceRule: reminder.recurrenceRule,
                mutationMatch: reminder.mutationMatch,
                contextualGuard: reminder.contextualGuard
            )
        }
        do {
            _ = try pendingUpdates.approve(id: malformedNextTriggerBypass.id)
            throw CheckError.failed("non-recurring next_trigger/remind mismatch should not approve")
        } catch PendingUpdateError.needsSlotConfirmation {
        }

        let nextThursday = dateOnlyStringForNextWeekday(5)
        let nextFriday = dateOnlyStringForNextWeekday(6)
        let deadlineEntry = try rawEntries.create(inputType: .text, rawText: "周五前提交 Alex 材料，周四 18:00 提醒我。")
        let deadlineResponse = try await extract(deadlineEntry.rawText)
        let deadlineUpdate = try pendingUpdates.createMemoryAtomProposal(
            sourceEntryID: deadlineEntry.id,
            proposal: try require(deadlineResponse.memoryProposals.first, "deadline proposal missing")
        )
        let deadlineContext = try require(deadlineUpdate.structuredReviewContext?.reminder, "deadline context missing")
        try expect(deadlineContext.scheduleSubtype == "deadline", "deadline wording should use deadline subtype")
        try expect(deadlineContext.scheduleExecutionState == "executable_reminder", "deadline with explicit remind_at should be executable after approval")
        try expect(deadlineContext.dueAt == nextFriday, "deadline due date should stay separate from remind_at")
        try expect(deadlineContext.deadlineRelation == "before_or_on", "deadline relation should preserve 前 semantics")
        try expect(deadlineContext.remindAt == "\(nextThursday)T18:00:00+08:00", "deadline reminder should use explicit remind_at")
        _ = try pendingUpdates.approve(id: deadlineUpdate.id)

        let executableRecurringEntry = try rawEntries.create(inputType: .text, rawText: "每周五 10:00 问 May 论文进度。")
        let executableRecurringResponse = try await extract(executableRecurringEntry.rawText)
        let executableRecurringUpdate = try pendingUpdates.createMemoryAtomProposal(
            sourceEntryID: executableRecurringEntry.id,
            proposal: try require(executableRecurringResponse.memoryProposals.first, "executable recurring proposal missing")
        )
        let executableRecurringContext = try require(executableRecurringUpdate.structuredReviewContext?.reminder, "executable recurring context missing")
        try expect(executableRecurringContext.scheduleSubtype == "recurring", "weekly exact time should stay recurring")
        try expect(executableRecurringContext.scheduleExecutionState == "executable_reminder", "recurring with exact remind time should be executable after approval")
        try expect(executableRecurringContext.recurrenceRule?["frequency"] == "weekly", "recurring rule should include frequency")
        try expect(executableRecurringContext.recurrenceRule?["remind_time_or_null"] == "10:00", "recurring rule should include explicit remind time")
        try expect(executableRecurringContext.recurrenceRule?["next_trigger_at_or_null"]?.contains("T10:00") == true, "recurring rule should include next trigger")
        _ = try pendingUpdates.approve(id: executableRecurringUpdate.id)

        let pastTriggerEntry = try rawEntries.create(inputType: .text, rawText: "昨天 20:00 提醒我问 Jason 材料。")
        let pastTriggerResponse = try await extract(pastTriggerEntry.rawText)
        let pastTriggerUpdate = try pendingUpdates.createMemoryAtomProposal(
            sourceEntryID: pastTriggerEntry.id,
            proposal: try require(pastTriggerResponse.memoryProposals.first, "past trigger proposal missing")
        )
        let pastTriggerContext = try require(pastTriggerUpdate.structuredReviewContext?.reminder, "past trigger context missing")
        try expect(pastTriggerContext.scheduleExecutionState == "draft_schedule_candidate", "past trigger must not be executable")
        try expect(pastTriggerContext.confirmationReasons.contains("past_trigger"), "past trigger should be a blocker")
        do {
            _ = try pendingUpdates.approve(id: pastTriggerUpdate.id)
            throw CheckError.failed("past trigger should not approve")
        } catch PendingUpdateError.needsSlotConfirmation {
        }
    }


    private func checkPendingUpdateApprovalCreatesMemoryAtomAndLinksThemeAndPerson() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = try LocalSQLiteStore(filename: "test.sqlite3", directory: tempDirectory, seedDemoData: true)
        let rawEntries = RawEntryRepository(database: store)
        let pendingUpdates = PendingUpdateRepository(database: store)
        let memories = MemoryRepository(database: store)

        let entry = try rawEntries.create(inputType: .text, rawText: "我好像总是怕麻烦 Alex，所以很多事情没说。")
        let parsed = try AIJSONParser().parseExtractMemoryResponse(data: fixtureData("extract_memory_valid_response"))
        let update = try pendingUpdates.createMemoryAtomProposal(sourceEntryID: entry.id, proposal: parsed.memoryProposals[0])

        let atom = try pendingUpdates.approve(id: update.id)
        let fetched = try memories.fetch(id: atom.id)

        try expect(fetched?.sourceEntryID == entry.id, "memory source entry mismatch")
        try expect(fetched?.title == "我在人际关系里害怕麻烦别人", "memory title mismatch")
        try expect(fetched?.sourceQuote == "我好像总是怕麻烦 Alex，所以很多事情没说。", "memory source quote mismatch")
        let linkedThemes = try memories.linkedThemeNames(memoryID: atom.id)
        let linkedPeople = try memories.linkedPersonIDs(memoryID: atom.id)
        let approvedStatus = try pendingUpdates.fetch(id: update.id)?.status
        try expect(linkedThemes == ["自我表达", "关系边界"], "theme links mismatch")
        try expect(linkedPeople == ["demo-alex"], "person links mismatch")
        try expect(approvedStatus == .approved, "pending update was not approved")

        let alex = try require(try store.loadSnapshot().people.first { $0.id == "demo-alex" }, "Alex missing before profile edit")
        try store.upsertPerson(copyPerson(alex, favoriteFoods: "薯片、火锅"))
        let linkedPeopleAfterProfileEdit = try memories.linkedPersonIDs(memoryID: atom.id)
        try expect(linkedPeopleAfterProfileEdit == ["demo-alex"], "manual profile edit should preserve existing memory person links")
        let reflectionEdges = try store.loadSnapshot().relationshipEdges.filter { $0.sourceMemoryID == atom.id }
        try expect(reflectionEdges.isEmpty, "private reflection should not create relationship edges without explicit edge proposals")
    }

    private func checkProfilePatchApprovalMergesIntoFriendDossier() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = try LocalSQLiteStore(filename: "profile-patch.sqlite3", directory: tempDirectory, seedDemoData: true)
        let rawEntries = RawEntryRepository(database: store)
        let pendingUpdates = PendingUpdateRepository(database: store)
        let entry = try rawEntries.create(inputType: .text, rawText: "我记得 Alex Chen 不吃香菜。")

        let patch = PersonProfilePatchProposal(
            targetPersonID: "demo-alex",
            targetDisplayName: "Alex Chen",
            profileCategory: .dietaryAllergy,
            proposedValue: "不吃香菜。",
            sourceQuote: entry.rawText,
            confidence: 0.91,
            sensitivity: .normal,
            isAIInferred: false
        )
        let update = try pendingUpdates.createPersonProfilePatchProposal(sourceEntryID: entry.id, proposal: patch)

        try expect(update.reviewCategory == .friendDossier, "profile patches should route to friend dossier review")
        let traceMemory = try pendingUpdates.approve(id: update.id)
        let alex = try require(try store.loadSnapshot().people.first { $0.id == "demo-alex" }, "Alex missing after profile patch approval")

        try expect(alex.categoryNote(.dietaryAllergy).contains("不吃香菜"), "approved profile patch should merge into category notes")
        try expect(traceMemory.type == .personFact, "approved profile patch should create a person_fact trace memory")
        try expect(traceMemory.sensitivity == .normal, "friend food facts must not be stored as private self reflections")
    }

    private func checkInvalidProfilePatchProposalsAreRejected() throws {
        let parser = AIJSONParser()
        let invalidCategoryJSON = """
        {"entry_summary":"bad","memory_proposals":[],"person_fact_proposals":[{"target_person_id":"demo-alex","target_display_name":"Alex Chen","profile_category":"not_a_category","proposed_value":"x","source_quote":"Alex likes x","confidence":0.5,"sensitivity":"normal","is_ai_inferred":false,"merge_strategy":"append_unique"}],"reminder_proposals":[],"gift_signal_proposals":[],"conflicts":[],"follow_up_questions":[]}
        """
        do {
            _ = try parser.parseExtractMemoryResponse(content: invalidCategoryJSON)
            throw CheckError.failed("invalid profile category should be rejected")
        } catch is AIContractError {
        }

        let emptySourcePatch = PersonProfilePatchProposal(
            targetPersonID: "demo-alex",
            targetDisplayName: "Alex Chen",
            profileCategory: .foodPreference,
            proposedValue: "喜欢火锅。",
            sourceQuote: "",
            confidence: 0.8,
            sensitivity: .normal,
            isAIInferred: false
        )
        do {
            try AIContractValidator().validateProfilePatch(emptySourcePatch)
            throw CheckError.failed("empty source quote should be rejected")
        } catch AIContractError.missingSourceQuote {
        }

        let missingTargetPatch = PersonProfilePatchProposal(
            targetPersonID: nil,
            targetDisplayName: "",
            profileCategory: .foodPreference,
            proposedValue: "喜欢火锅。",
            sourceQuote: "喜欢火锅",
            confidence: 0.8,
            sensitivity: .normal,
            isAIInferred: false
        )
        do {
            try AIContractValidator().validateProfilePatch(missingTargetPatch)
            throw CheckError.failed("missing target person should be rejected")
        } catch AIContractError.invalidProfilePatch {
        }
    }

    private func checkApprovalCreatesSourceBackedRelationshipEdgeProposal() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = try LocalSQLiteStore(filename: "test.sqlite3", directory: tempDirectory, seedDemoData: true)
        let rawEntries = RawEntryRepository(database: store)
        let pendingUpdates = PendingUpdateRepository(database: store)

        let sourceQuote = "May 说 Alex 最近经常问她 class project 的材料。"
        let entry = try rawEntries.create(inputType: .text, rawText: sourceQuote)
        let proposal = MemoryAtomProposal(
            proposalType: .memoryAtom,
            memoryType: .relationshipMemory,
            title: "May 和 Alex 的项目弱连接",
            summary: "May 与 Alex 最近因为 class project 交流变多。",
            content: "这条关系记忆用于解释 May 与 Alex 的项目弱连接。",
            sourceQuote: sourceQuote,
            confidence: 0.87,
            sensitivity: .normal,
            isAIInferred: false,
            relatedPeople: [
                RelatedPersonProposal(
                    displayName: "May Zhang",
                    matchedPersonID: "demo-may",
                    matchConfidence: 0.91,
                    relationType: "about"
                ),
                RelatedPersonProposal(
                    displayName: "Alex Chen",
                    matchedPersonID: "demo-alex",
                    matchConfidence: 0.88,
                    relationType: "mentioned"
                )
            ],
            themes: [
                ThemeProposal(name: "课程项目", confidence: 0.83)
            ],
            relationshipEdgeProposals: [
                RelationshipEdgeProposal(
                    sourcePersonID: "demo-may",
                    sourceDisplayName: "May Zhang",
                    targetPersonID: "demo-alex",
                    targetDisplayName: "Alex Chen",
                    label: "课程项目弱连接",
                    strength: 0.58,
                    relationKind: "project",
                    tags: ["项目伙伴", "弱连接"],
                    aiPrimaryTag: "项目伙伴",
                    confidence: 0.82,
                    sourceQuote: sourceQuote
                )
            ],
            followUpQuestions: [],
            suggestedActions: []
        )
        let update = try pendingUpdates.createMemoryAtomProposal(sourceEntryID: entry.id, proposal: proposal)

        let memory = try pendingUpdates.approve(id: update.id)
        let edges = try store.loadSnapshot().relationshipEdges.filter { $0.sourceMemoryID == memory.id }
        let edge = try require(edges.first, "source-backed relationship edge missing")

        try expect(edge.sourceID == "demo-may", "relationship edge source id mismatch")
        try expect(edge.targetID == "demo-alex", "relationship edge target id mismatch")
        try expect(edge.label == "课程项目弱连接", "relationship edge label mismatch")
        try expect(edge.tags == ["项目伙伴", "弱连接"], "relationship edge tags should persist")
        let priorities = try store.loadSnapshot().relationshipTagPriorities
        try expect(edge.displayTag(priorities: priorities) == "项目伙伴", "relationship edge should display AI primary tag metadata through priorities")
        try expect(edge.relationKind == "project", "relationship edge kind mismatch")
        try expect(edge.isAIInferred, "relationship edge should be marked AI inferred")
        try expect(edge.confidence == 0.82, "relationship edge confidence mismatch")
    }

    private func checkMemorySearchFiltersByTypePersonThemeAndSensitivity() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = try LocalSQLiteStore(filename: "test.sqlite3", directory: tempDirectory, seedDemoData: true)
        let rawEntries = RawEntryRepository(database: store)
        let pendingUpdates = PendingUpdateRepository(database: store)
        let memories = MemoryRepository(database: store)

        let entry = try rawEntries.create(inputType: .text, rawText: "我好像总是怕麻烦 Alex，所以很多事情没说。")
        let proposal = try AIJSONParser().parseExtractMemoryResponse(data: fixtureData("extract_memory_valid_response")).memoryProposals[0]
        let update = try pendingUpdates.createMemoryAtomProposal(sourceEntryID: entry.id, proposal: proposal)
        _ = try pendingUpdates.approve(id: update.id)

        let includedPrivateCount = try memories.search(query: "麻烦", type: .personalReflection, personID: "demo-alex", themeName: "自我表达", includeSensitive: true).count
        let wrongTypeCount = try memories.search(query: "麻烦", type: .giftSignal, personID: "demo-alex", themeName: "自我表达", includeSensitive: true).count
        let hiddenPrivateCount = try memories.search(query: "麻烦", type: .personalReflection, personID: "demo-alex", themeName: "自我表达", includeSensitive: false).count
        try expect(includedPrivateCount == 1, "search should find private memory when included")
        try expect(wrongTypeCount == 0, "search type filter failed")
        try expect(hiddenPrivateCount == 0, "search should hide private memory by default")
    }

    private func checkPeopleGroupsCanBeChangedAndQueried() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = try LocalSQLiteStore(filename: "test.sqlite3", directory: tempDirectory, seedDemoData: true)

        try store.updatePersonGroup(personID: "demo-alex", group: .internship)
        let snapshot = try store.loadSnapshot()
        let alex = try require(snapshot.people.first { $0.id == "demo-alex" }, "Alex missing after group update")

        try expect(alex.groupLabel == .internship, "person group update did not persist")
    }

    @MainActor
    private func checkPeopleCanBelongToMultipleGroups() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let database = try LocalSQLiteStore(filename: "test.sqlite3", directory: tempDirectory, seedDemoData: true)

        try database.updatePersonGroups(personID: "demo-alex", groups: [.classmates, .internship])
        let snapshot = try database.loadSnapshot()
        let alex = try require(snapshot.people.first { $0.id == "demo-alex" }, "Alex missing after multi-group update")

        try expect(alex.groupLabels == [.classmates, .internship], "person should persist ordered multi-group membership")
        try expect(alex.groupLabel == .classmates, "primary group should remain the first multi-group value")

        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: "test.sqlite3",
            seedDemoData: false
        )
        store.navigate(to: .internship)
        try expect(store.visiblePeople.contains { $0.id == "demo-alex" }, "group filter should include people with secondary group membership")
        try expect(store.count(for: .classmates) >= 1 && store.count(for: .internship) >= 1, "group counts should include multi-group memberships")
    }

    @MainActor
    private func checkDashboardStoreCanAddEditAndDeletePeople() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: "people-crud.sqlite3",
            seedDemoData: false
        )
        let alex = FriendPerson(
            id: "manual-alex",
            displayName: "Alex Chen",
            nickname: "Alex",
            englishName: "Alex Chen",
            relationLabel: "朋友",
            groupLabel: .classmates,
            location: "New York",
            birthday: "",
            dietaryRestrictions: "",
            favoriteFoods: "薯片",
            dislikedThings: "",
            zodiacSign: "",
            mbti: "",
            interests: "电影",
            books: "",
            sports: "",
            profileTags: "手动添加",
            lastSignal: "喜欢吃薯片",
            initials: "AC",
            manualClosenessLevel: 3,
            categoryNotes: [.foodPreference: "喜欢吃薯片。"]
        )

        store.addPerson(alex)
        try expect(store.people.contains { $0.id == "manual-alex" }, "store should add a manually created friend")
        try expect(store.selectedPersonID == "manual-alex", "newly added friend should be selected")

        let editedAlex = FriendPerson(
            id: alex.id,
            displayName: alex.displayName,
            nickname: alex.nickname,
            englishName: alex.englishName,
            relationLabel: alex.relationLabel,
            groupLabel: alex.groupLabel,
            groupLabels: alex.groupLabels,
            location: alex.location,
            birthday: alex.birthday,
            dietaryRestrictions: alex.dietaryRestrictions,
            favoriteFoods: "薯片、可乐",
            dislikedThings: alex.dislikedThings,
            zodiacSign: alex.zodiacSign,
            mbti: alex.mbti,
            interests: alex.interests,
            books: alex.books,
            sports: alex.sports,
            profileTags: alex.profileTags,
            lastSignal: "修正：喜欢吃薯片，也喝可乐",
            initials: alex.initials,
            manualClosenessLevel: 4,
            categoryNotes: [.foodPreference: "修正：喜欢吃薯片，也喝可乐。"]
        )

        store.savePerson(editedAlex)
        let afterEdit = try require(store.people.first { $0.id == "manual-alex" }, "edited friend missing")
        try expect(afterEdit.favoriteFoods == "薯片、可乐", "manual profile edit should persist favorite foods")
        try expect(afterEdit.manualClosenessLevel == 4, "manual profile edit should persist closeness level")
        try expect(afterEdit.categoryNote(.foodPreference).contains("可乐"), "manual profile edit should persist category notes")

        store.deletePerson(afterEdit)
        try expect(!store.people.contains { $0.id == "manual-alex" }, "store should delete a manually created friend")
        try expect(store.selectedPersonID == nil, "selection should clear when the last friend is deleted")
    }

    private func checkAgendaActionsPrioritizeTodayReminders() throws {
        let snapshot = DashboardSnapshot.demo
        let todayItems = snapshot.reminders.filter(\.isToday)

        try expect(!todayItems.isEmpty, "demo agenda should include a today reminder")
        try expect(todayItems.first?.timeLabel.isEmpty == false, "today reminder should expose a time label")
        try expect(todayItems.first?.context.isEmpty == false, "today reminder should expose actionable context")
    }

    private func checkPendingUpdatesRouteToThreeReviewCategoriesAndApproveOnce() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = try LocalSQLiteStore(filename: "test.sqlite3", directory: tempDirectory, seedDemoData: false)
        let rawEntries = RawEntryRepository(database: store)
        let pendingUpdates = PendingUpdateRepository(database: store)

        let reflectionEntry = try rawEntries.create(inputType: .text, rawText: "我今天突然意识到自己很怕麻烦别人。")
        let friendEntry = try rawEntries.create(inputType: .text, rawText: "Alex 最近很喜欢讨论微积分复习。")
        let scheduleEntry = try rawEntries.create(inputType: .text, rawText: "明天 20:00 提醒我问 Alex 期中复习。")

        let reflection = try pendingUpdates.createMemoryAtomProposal(
            sourceEntryID: reflectionEntry.id,
            proposal: protocolProposal(type: .personalReflection, title: "怕麻烦别人", sourceQuote: reflectionEntry.rawText)
        )
        let friend = try pendingUpdates.createMemoryAtomProposal(
            sourceEntryID: friendEntry.id,
            proposal: protocolProposal(type: .personFact, title: "Alex 复习状态", sourceQuote: friendEntry.rawText)
        )
        let schedule = try pendingUpdates.createMemoryAtomProposal(
            sourceEntryID: scheduleEntry.id,
            proposal: protocolProposal(type: .reminderSource, title: "问 Alex 期中复习", sourceQuote: scheduleEntry.rawText)
        )

        try expect(reflection.reviewCategory == .selfSearch, "reflection should route to self search review")
        try expect(friend.reviewCategory == .friendDossier, "person fact should route to friend dossier review")
        try expect(schedule.reviewCategory == .schedule, "reminder source should route to schedule review")

        let approvedMemory = try pendingUpdates.approve(id: schedule.id)
        let approvedStatus = try pendingUpdates.fetch(id: schedule.id)?.status
        try expect(approvedStatus == .approved, "approved schedule update should be decided once")

        let snapshot = try store.loadSnapshot()
        let createdReminder = try require(snapshot.reminders.first { $0.id == "reminder-\(approvedMemory.id)" }, "approved reminder source should create a local reminder")
        try expect(createdReminder.dueDate != nil, "approved reminder should infer a concrete date when possible")
        try expect(createdReminder.timeLabel == "20:00", "approved reminder should infer time label")

        do {
            _ = try pendingUpdates.approve(id: schedule.id)
            throw CheckError.failed("approved update was approved a second time")
        } catch PendingUpdateError.notReviewable {
        }
    }

    @MainActor
    private func checkCaptureModeSelectsTheReviewDeskCategory() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: "capture-mode-routing.sqlite3",
            seedDemoData: true,
            apiKeyReader: { nil }
        )

        store.selectedCaptureMode = .schedule
        await store.captureForReview("明天提醒我给 May 发消息，问她陶艺课准备得怎么样。")
        try expect(store.sidebarSelection == SidebarSelection.section(.aiReview), "capture should still land on the review desk")
        try expect(store.selectedReviewCategory == .schedule, "schedule mode should open the schedule review desk")
        try expect(store.pendingUpdates.contains { $0.reviewCategory == .schedule }, "schedule mode should create schedule review items")

        store.selectedCaptureMode = .friendDossier
        await store.captureForReview("我记得 Alex Chen 喜欢吃火锅，不吃香菜。")
        try expect(store.selectedReviewCategory == .friendDossier, "friend mode should open the friend dossier review desk")
        try expect(store.pendingUpdates.contains { $0.reviewCategory == .friendDossier }, "friend mode should create friend dossier review items")

        store.selectedCaptureMode = .selfSearch
        await store.captureForReview("我最近发现自己总是怕麻烦别人，所以很多需求没有说出口。")
        try expect(store.selectedReviewCategory == .selfSearch, "self-search mode should open the self-search review desk")
        try expect(store.pendingUpdates.contains { $0.reviewCategory == .selfSearch }, "self-search mode should create self-search review items")
    }

    @MainActor
    private func checkQuickCaptureProgressAndDuplicateSubmissionGuard() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let workflow = AIWorkflowService(
            remoteExtractMemory: { rawEntry, _, _, _, _ in
                try await Task.sleep(nanoseconds: 150_000_000)
                return try AIJSONParser().parseExtractMemoryResponse(content: """
                {"entry_summary":"Jason 喜欢吃三文鱼。","memory_proposals":[{"proposal_type":"memory_atom","memory_type":"person_fact","title":"Jason Wu - Food Preference","summary":"喜欢吃三文鱼","content":"Jason 喜欢吃三文鱼。","source_quote":"Jason Wu 喜欢吃三文鱼。","confidence":0.88,"sensitivity":"normal","is_ai_inferred":false,"related_people":[{"display_name":"Jason Wu","matched_person_id":"demo-jason","match_confidence":0.91,"relation_type":"about"}],"themes":[{"name":"Food Preference","confidence":0.88}],"follow_up_questions":[],"suggested_actions":[]}],"person_fact_proposals":[],"reminder_proposals":[],"gift_signal_proposals":[],"conflicts":[],"follow_up_questions":[]}
                """)
            }
        )
        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: "quick-capture-progress.sqlite3",
            seedDemoData: true,
            aiWorkflow: workflow,
            apiKeyReader: { "test-key" }
        )

        let initialPendingCount = store.pendingUpdates.count
        store.selectedCaptureMode = .friendDossier
        store.quickCaptureText = "Jason Wu 喜欢吃三文鱼。"
        store.quickCapture()
        store.quickCaptureText = "Jason Wu 喜欢吃三文鱼。"
        store.quickCapture()

        try expect(store.isCapturing, "quick capture should expose running state immediately")
        try expect(store.captureProgress.phase != .idle, "quick capture should leave idle progress while running")
        try await Task.sleep(nanoseconds: 260_000_000)

        try expect(!store.isCapturing, "quick capture should clear running state after delivery")
        try expect(store.captureProgress.phase == .delivered, "quick capture should finish in delivered phase")
        try expect(store.captureProgress.progress == 1, "delivered capture progress should be complete")
        try expect(store.selectedReviewCategory == .friendDossier, "quick capture should stay in the clicked mode review partition")
        let createdUpdates = store.pendingUpdates.filter { $0.sourceEntryID != nil }
        try expect(store.pendingUpdates.count == initialPendingCount + 1, "double quick capture should only create one pending update")
        try expect(createdUpdates.filter { $0.summary.contains("三文鱼") }.count == 1, "double quick capture created duplicate salmon suggestions")
    }

    @MainActor
    private func checkCaptureRemoteFailureKeepsLocalFallbackDraft() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let workflow = AIWorkflowService(
            remoteExtractMemory: { _, _, _, _, _ in
                throw LocalAIError.networkUnavailable
            }
        )
        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: "capture-remote-failure-fallback.sqlite3",
            seedDemoData: true,
            aiWorkflow: workflow,
            apiKeyReader: { "test-key" }
        )

        await store.captureForReview("明天提醒我准备考试。", mode: .schedule)

        try expect(store.captureProgress.phase == .failed, "remote extraction errors should finish in failed progress state")
        let fallbackUpdates = store.pendingUpdates.filter { $0.sourceEntryID != nil && ($0.summary.contains("考试") || $0.evidence.contains("考试")) }
        try expect(!fallbackUpdates.isEmpty, "remote extraction errors should keep a local fallback review draft")
        try expect(fallbackUpdates.allSatisfy { $0.reviewCategory == .schedule }, "fallback draft should keep the clicked capture mode")
    }

    @MainActor
    private func checkFriendDossierCaptureDeduplicatesProfileFactSuggestions() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: "friend-dossier-dedupe.sqlite3",
            seedDemoData: true,
            apiKeyReader: { nil }
        )

        await store.captureForReview("Jason Wu 喜欢吃三文鱼。", mode: .friendDossier)

        let salmonUpdates = store.pendingUpdates.filter {
            $0.reviewCategory == .friendDossier &&
            $0.title.contains("Jason") &&
            ($0.summary.contains("三文鱼") || $0.evidence.contains("三文鱼"))
        }
        try expect(salmonUpdates.count == 1, "friend dossier capture should not create duplicate food preference cards")
        try expect(salmonUpdates.first?.profilePatchProposal?.profileCategory == .foodPreference, "food preference should be represented by the profile patch card")
    }

    @MainActor
    private func checkScheduleCaptureModeForcesScheduleReviewAndReminderCreation() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let filename = "schedule-mode-routing.sqlite3"
        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: filename,
            seedDemoData: true,
            apiKeyReader: { nil }
        )

        await store.captureForReview("明天提醒我准备考试，还要安排和 May 约见。", mode: .schedule)

        let scheduleUpdates = store.pendingUpdates.filter { $0.evidence.contains("考试") || $0.summary.contains("考试") }
        try expect(!scheduleUpdates.isEmpty, "schedule capture should create a reviewable schedule item")
        try expect(scheduleUpdates.allSatisfy { $0.reviewCategory == .schedule }, "schedule capture should not route exam/meeting notes to self search")
        let update = try require(scheduleUpdates.first, "schedule update missing")
        try expect(update.proposal?.memoryType == .reminderSource || update.proposal?.hasScheduleSignals == true, "schedule capture should use a reminder-capable memory type")

        let reminderCountBefore = store.reminders.count
        store.confirm(update)
        try expect(store.reminders.count == reminderCountBefore, "blocked schedule item should not create a reminder")
        try expect(
            store.statusMessage.localizedCaseInsensitiveContains("slot") ||
                store.statusMessage.localizedCaseInsensitiveContains("required") ||
                store.statusMessage.contains("必要信息"),
            "blocked schedule approval should explain missing details"
        )
    }

    private func checkCaptureViewNoLongerShowsShortcutChips() throws {
        let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appending(path: "Sources/MemoriaMac/Views/CaptureMemoryActionsViews.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        for removedChip in ["感悟", "朋友近况", "灵感", "考试/约见", "随便说说"] {
            try expect(!source.contains("\"\(removedChip)\""), "capture view should not include shortcut chip \(removedChip)")
        }
        try expect(!source.contains("private var chips"), "capture view should remove the shortcut chip source")
    }

    private func checkReminderDueDatePersistsAndLegacyRemindersLoad() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = try LocalSQLiteStore(filename: "test.sqlite3", directory: tempDirectory, seedDemoData: false)

        try store.upsertReminder(
            TransferReminder(
                id: "dated-reminder",
                title: "准备面试",
                personName: "May Zhang",
                dueLabel: "2026-06-14",
                dueDate: "2026-06-14",
                timeLabel: "09:30",
                context: "准备问题清单",
                location: "线上"
            )
        )
        try store.upsertReminder(
            TransferReminder(
                id: "legacy-reminder",
                title: "找时间约饭",
                personName: "Alex Chen",
                dueLabel: "本周有空",
                dueDate: nil,
                timeLabel: "",
                context: "旧文本时间提醒",
                location: ""
            )
        )

        let reminders = try store.loadSnapshot().reminders
        let dated = try require(reminders.first { $0.id == "dated-reminder" }, "dated reminder should load")
        let legacy = try require(reminders.first { $0.id == "legacy-reminder" }, "legacy reminder should load")

        try expect(dated.dueDate == "2026-06-14", "new reminder should persist due_date")
        try expect(dated.hasConcreteDueDate, "new reminder should expose concrete due date")
        try expect(legacy.dueDate == nil, "legacy reminder should keep nil due_date")
        try expect(!legacy.hasConcreteDueDate, "legacy reminder should remain text-time only")
    }

    private func checkPeopleProfilesExposeEducationWorkAndRelationshipNetwork() throws {
        let snapshot = DashboardSnapshot.demo
        let alex = try require(snapshot.people.first { $0.id == "demo-alex" }, "Alex missing")
        let alexEdges = snapshot.relationshipEdges.filter { $0.involves(personID: alex.id) }

        try expect(alex.school == "NYU", "school should be available on person profile")
        try expect(alex.major == "Mathematics", "major should be available on person profile")
        try expect(alex.company == "Campus Research Lab", "company/research affiliation should be available")
        try expect(!alex.researchExperience.isEmpty, "research experience should be available")
        try expect(!alex.internshipExperience.isEmpty, "internship experience should be available")
        try expect(!alex.familyNotes.isEmpty, "family notes should be available")
        try expect(!alexEdges.isEmpty, "person-specific relationship graph should have edges")
    }

    private func checkRelationshipEdgesArePersistedAndMutable() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = try LocalSQLiteStore(filename: "test.sqlite3", directory: tempDirectory, seedDemoData: true)
        let tables = try store.tableNames()

        try expect(tables.contains("relationship_edges"), "relationship_edges table missing")
        try store.upsertRelationshipEdge(
            RelationshipEdge(
                id: "edge-check",
                sourceID: "demo-may",
                sourceName: "May Zhang",
                targetID: "external-roommate",
                targetName: "大学室友",
                label: "关系很好",
                strength: 0.82,
                relationKind: "close_friend"
            )
        )
        let snapshot = try store.loadSnapshot()
        let edge = try require(snapshot.relationshipEdges.first { $0.id == "edge-check" }, "persisted relationship edge missing")

        try expect(edge.involves(personID: "demo-may"), "relationship edge should be queryable for a person")
        try expect(edge.targetName == "大学室友", "relationship edge target name mismatch")
        try expect(edge.relationKind == "close_friend", "relationship edge relation kind mismatch")
    }

    @MainActor
    private func checkDashboardStoreCanEditAndDeleteRelationshipEdges() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: "relationship-edge-edit.sqlite3",
            seedDemoData: true
        )
        let may = try require(store.people.first { $0.id == "demo-may" }, "May missing for relationship edit check")
        let existingIDs = Set(store.relationshipEdges.map(\.id))

        store.addRelationship(for: may, targetName: "大学室友", label: "室友", relationKind: "close_friend")
        let edge = try require(
            store.relationshipEdges.first { !existingIDs.contains($0.id) && $0.sourceID == may.id },
            "manual relationship edge should be created"
        )

        store.updateRelationshipEdge(
            edge,
            targetName: "研究搭子",
            label: "项目伙伴",
            relationKind: "project",
            strength: 0.64,
            tags: ["弱连接", "项目伙伴"],
            manualPrimaryTag: "项目伙伴"
        )
        let updated = try require(store.relationshipEdges.first { $0.id == edge.id }, "updated relationship edge missing")

        try expect(updated.targetName == "研究搭子", "relationship edge target should be editable")
        try expect(updated.label == "项目伙伴", "relationship edge label should be editable")
        try expect(updated.relationKind == "project", "relationship edge kind should be editable")
        try expect(updated.tags == ["弱连接", "项目伙伴"], "relationship edge tags should be editable")
        try expect(updated.displayTag(priorities: store.relationshipTagPriorities) == "项目伙伴", "manual display tag should be editable")

        store.deleteRelationshipEdge(updated)
        try expect(!store.relationshipEdges.contains { $0.id == edge.id }, "relationship edge should be deletable")
    }

    private func checkRelationshipTagsResolveByManualPriorityAIAndLegacyLabel() throws {
        let priorities = [
            RelationshipTagPriority(tag: "室友", rank: 20),
            RelationshipTagPriority(tag: "弱连接", rank: 200)
        ]
        let priorityEdge = RelationshipEdge(
            id: "edge-priority",
            sourceName: "Me",
            targetName: "Alex",
            label: "旧标签",
            strength: 0.5,
            tags: ["弱连接", "室友"],
            aiPrimaryTag: "AI主标签"
        )
        let manualEdge = RelationshipEdge(
            id: "edge-manual",
            sourceName: "Me",
            targetName: "May",
            label: "旧标签",
            strength: 0.5,
            tags: ["弱连接"],
            aiPrimaryTag: "AI主标签",
            manualPrimaryTag: "手动主标签"
        )
        let aiEdge = RelationshipEdge(
            id: "edge-ai",
            sourceName: "Me",
            targetName: "Nina",
            label: "旧标签",
            strength: 0.5,
            aiPrimaryTag: "AI主标签"
        )
        let legacyEdge = RelationshipEdge(
            id: "edge-legacy",
            sourceName: "Me",
            targetName: "Jason",
            label: "旧标签",
            strength: 0.5
        )

        try expect(priorityEdge.displayTag(priorities: priorities) == "室友", "priority tag should outrank weaker tags")
        try expect(manualEdge.displayTag(priorities: priorities) == "手动主标签", "manual primary tag should win")
        try expect(aiEdge.displayTag(priorities: priorities) == "AI主标签", "AI primary tag should be used when no tags exist")
        try expect(legacyEdge.displayTag(priorities: priorities) == "旧标签", "legacy label should remain fallback")
    }

    private func checkDefaultSelfIndexThemesAreSeeded() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = try LocalSQLiteStore(filename: "test.sqlite3", directory: tempDirectory, seedDemoData: false)
        let snapshot = try store.loadSnapshot()
        let themeNames = Set(snapshot.themes.map(\.name))

        try expect(snapshot.themes.count == 12, "empty stores should seed 12 default self index themes")
        try expect(themeNames.contains("自我认知"), "default themes should include self awareness")
        try expect(themeNames.contains("生活审美"), "default themes should include life aesthetics")
        try expect(snapshot.relationshipTagPriorities.contains { $0.tag == "室友" }, "default relationship tag priorities should be seeded")
    }

    private func checkClosenessUsesManualLevelAndAISignals() throws {
        let snapshot = DashboardSnapshot.demo
        let may = try require(snapshot.people.first { $0.id == "demo-may" }, "May missing")

        try expect((1...6).contains(may.manualClosenessLevel), "manual closeness level should use 1...6")
        try expect(may.manualClosenessTitle(for: .zhCN) == "非常亲近", "manual closeness title should be localized")
        try expect(may.closenessSignalsList.contains { $0.contains("最近互动频率") }, "AI closeness signals should include recent interaction frequency")
        try expect(may.closenessSignalsList.contains { $0.contains("需要关心") }, "AI closeness signals should include care-needed event")
    }

    private func checkGiftRecommendationsExposeScoresAndRisk() throws {
        let snapshot = DashboardSnapshot.demo
        let mayGifts = snapshot.gifts.filter { $0.personName == "May Zhang" }

        try expect(mayGifts.count >= 3, "May should have at least three gift recommendation directions")
        try expect(mayGifts.contains { $0.title.contains("陶艺") }, "gift recommendations should include ceramics direction")
        try expect(mayGifts.contains { $0.title.contains("冰岛") }, "gift recommendations should include Iceland travel direction")
        try expect(mayGifts.allSatisfy { (0...100).contains($0.matchScore) }, "gift match score should be 0...100")
        try expect(mayGifts.allSatisfy { (0...100).contains($0.surpriseScore) }, "gift surprise score should be 0...100")
        try expect(mayGifts.allSatisfy { !$0.riskLevel.isEmpty && !$0.practicality.isEmpty && !$0.emotionalValue.isEmpty }, "gift recommendations should expose risk, practicality, and emotional value")
    }

    private func checkGiftRecommendationWorkflowGeneratesScoredDirections() throws {
        let may = try require(DashboardSnapshot.demo.people.first { $0.id == "demo-may" }, "May missing")
        let gifts = GiftRecommendationWorkflow().recommendations(
            for: may,
            prompt: "给小雨推荐生日礼物，预算 300 到 500 元，不要太普通，最好有一点心意。"
        )

        try expect(gifts.count >= 3, "gift workflow should generate at least three directions")
        try expect(gifts.allSatisfy { $0.personName == may.displayName }, "gift workflow should target the selected person")
        try expect(gifts.contains { $0.title.contains("陶艺") }, "gift workflow should use current interest signals")
        try expect(gifts.contains { $0.title.contains("冰岛") }, "gift workflow should use travel signals")
        try expect(gifts.allSatisfy { (0...100).contains($0.matchScore) && (0...100).contains($0.surpriseScore) }, "gift workflow scores should be bounded")
        try expect(gifts.allSatisfy { !$0.risk.isEmpty && !$0.confirmationQuestion.isEmpty }, "gift workflow should include risk and confirmation question")
    }

    private func checkReminderNotificationPlannerBuildsTodayPlans() throws {
        let plans = ReminderNotificationPlanner().plans(for: DashboardSnapshot.demo.reminders)

        try expect(!plans.isEmpty, "notification planner should build plans for today's reminders")
        try expect(plans.allSatisfy { $0.identifier.hasPrefix("memoria.reminder.") }, "notification identifiers should be stable")
        try expect(plans.first?.title.contains("May") == true || plans.first?.body.contains("May") == true, "notification plan should include reminder context")
    }

    private func checkPeoplePresentationCollapsesInCompactWindows() throws {
        try expect(PeoplePresentationPolicy.mode(forAvailableWidth: 980) == .focusedProfile, "people page should collapse directory in compact windows")
        try expect(PeoplePresentationPolicy.mode(forAvailableWidth: 1360) == .directoryAndProfile, "people page should show directory when width allows")
    }

    @MainActor
    private func checkSidebarRestoresCaptureAndReviewDeskEntrypoints() throws {
        let groups = memoriaSidebarNavigationGroups(for: .zhCN)
        let workflow = try require(groups.first { $0.title == "工作流" }, "sidebar should expose a workflow section")

        try expect(workflow.sections == [.capture, .aiReview], "workflow section should contain Capture then Review Desk")
        try expect(workflow.sections.map { $0.title(for: .zhCN) } == ["记录", "整理台"], "workflow entries should use Chinese capture/review copy")

        let modeGroup = try require(groups.first { $0.title == "三种模式" }, "sidebar should expose the three mode section")
        try expect(modeGroup.sections == [.selfSearch, .friendDossier, .schedule], "three mode section should contain self, friend, and schedule")

        let store = DashboardStore(snapshot: .demo)
        store.selectedReviewCategory = .schedule
        store.openReviewDesk()
        try expect(store.sidebarSelection == SidebarSelection.section(.aiReview), "opening review desk should navigate to review desk")
        try expect(store.selectedReviewCategory == nil, "opening review desk from sidebar should show overview")

        store.openReviewDesk(category: .friendDossier)
        try expect(store.sidebarSelection == SidebarSelection.section(.aiReview), "opening a review category should stay on review desk")
        try expect(store.selectedReviewCategory == .friendDossier, "opening a review category should preserve the selected partition")
    }

    @MainActor
    private func checkCaptureFallsBackToReviewableDraftWhenAIJSONFails() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let workflow = AIWorkflowService(
            remoteExtractMemory: { _, _, _, _, _ in
                throw AIContractError.invalidJSON
            }
        )
        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: "capture-fallback.sqlite3",
            seedDemoData: true,
            aiWorkflow: workflow,
            apiKeyReader: { "saved-key-that-returns-invalid-json" }
        )
        let pendingCount = store.pendingUpdates.count

        await store.captureForReview("May 今天说她最近压力很大，提醒我这周末关心一下。")

        try expect(store.sidebarSelection == SidebarSelection.section(.aiReview), "capture should land in AI Review")
        try expect(store.pendingUpdates.count > pendingCount, "fallback capture should create reviewable pending updates")
        try expect(store.statusMessage.contains("本地") || store.statusMessage.localizedCaseInsensitiveContains("local"), "fallback capture should explain local draft fallback")
        let created = try require(store.pendingUpdates.first { $0.summary.contains("May") || $0.evidence.contains("压力") }, "fallback pending update missing")
        try expect(created.summary.contains("May") || created.summary.contains("压力"), "fallback pending update should preserve user text")
    }

    private func checkAgendaAssistantPlansWithoutMutatingCalendar() throws {
        let inputReminders = DashboardSnapshot.demo.reminders
        let plan = AgendaAssistantWorkflow().plan(
            prompt: "今天约了人，帮我安排日历和行程，不要让我忘记。",
            reminders: inputReminders,
            pendingUpdates: DashboardSnapshot.demo.pendingUpdates,
            gifts: DashboardSnapshot.demo.gifts,
            language: .zhCN
        )

        try expect(!plan.items.isEmpty, "agenda assistant should produce plan items")
        try expect(plan.items.allSatisfy(\.requiresApproval), "agenda assistant should be suggestion-only")
        try expect(plan.items.contains { $0.kind == .calendarBlock }, "agenda assistant should suggest calendar blocks")
        try expect(plan.items.contains { $0.kind == .preparation }, "agenda assistant should suggest preparation work")
        try expect(inputReminders == DashboardSnapshot.demo.reminders, "agenda assistant must not mutate source reminders")
    }

    private func checkMemoryAutoOrganizerSuggestsCategories() throws {
        let suggestions = MemoryAutoOrganizer().suggestions(
            for: DashboardSnapshot.demo.memoryAtoms,
            language: .zhCN
        )

        try expect(!suggestions.isEmpty, "memory auto organizer should produce suggestions")
        try expect(suggestions.contains { $0.targetType == .personalReflection }, "organizer should suggest reflection grouping")
        try expect(suggestions.contains { $0.targetType == .giftSignal }, "organizer should suggest gift signal grouping")
        try expect(suggestions.allSatisfy { !$0.requiresApproval }, "organizer should run automatically and leave editing to the user")
    }

    @MainActor
    private func checkSelfIndexTagsFilterTimelinePosts() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let filename = "self-index-tags.sqlite3"
        let database = try LocalSQLiteStore(filename: filename, directory: tempDirectory, seedDemoData: true)
        let rawEntries = RawEntryRepository(database: database)
        let pendingUpdates = PendingUpdateRepository(database: database)
        let proposal = try AIJSONParser().parseExtractMemoryResponse(data: fixtureData("extract_memory_valid_response")).memoryProposals[0]
        let entry = try rawEntries.create(inputType: .text, rawText: proposal.sourceQuote)
        let update = try pendingUpdates.createMemoryAtomProposal(sourceEntryID: entry.id, proposal: proposal)
        let memory = try pendingUpdates.approve(id: update.id)

        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: filename,
            seedDemoData: false
        )

        store.selectedSelfIndexThemeName = "自我表达"
        try expect(store.selfIndexTimelineMemories.contains { $0.id == memory.id }, "self-index tag should reveal linked posts")
        store.selectedSelfIndexThemeName = "不存在的标签"
        try expect(!store.selfIndexTimelineMemories.contains { $0.id == memory.id }, "unmatched self-index tag should hide posts")
        store.selectedSelfIndexThemeName = nil
        try expect(store.selfIndexTimelineMemories.contains { $0.id == memory.id }, "clearing the tag should restore the timeline plaza")
    }

    @MainActor
    private func checkSelfIndexManualTagsAndPlazaPostsAreMutable() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: "self-index-edit.sqlite3",
            seedDemoData: false
        )

        store.addSelfIndexTheme(name: "手动主题", description: "初始说明")
        let theme = try require(store.themes.first { $0.name == "手动主题" }, "manual self-index tag should be created")
        try expect(store.selectedSelfIndexThemeName == "手动主题", "new self-index tag should be selected")

        store.updateSelfIndexTheme(theme, name: "手动主题更新", description: "更新说明")
        try expect(store.themes.contains { $0.name == "手动主题更新" && $0.description == "更新说明" }, "manual self-index tag should be editable")

        store.addSelfIndexMemory(
            title: "第一条自我广场",
            summary: "先记录一个版本",
            content: "正文内容",
            type: .personalReflection,
            sensitivity: .private,
            themeNames: ["手动主题更新"]
        )
        let memory = try require(store.memoryAtoms.first { $0.title == "第一条自我广场" }, "manual self-index plaza post should be created")
        try expect(store.themeNames(for: memory) == ["手动主题更新"], "manual self-index plaza post should link selected tags")

        store.selectedSelfIndexThemeName = "手动主题更新"
        try expect(store.selfIndexTimelineMemories.contains { $0.id == memory.id }, "manual tag should filter to the new plaza post")

        store.updateSelfIndexMemory(
            memory,
            title: "第二条自我广场",
            summary: "改过的摘要",
            content: "改过的正文",
            type: .idea,
            sensitivity: .normal,
            themeNames: ["生活审美"]
        )
        let updated = try require(store.memoryAtoms.first { $0.id == memory.id }, "updated self-index plaza post should exist")
        try expect(updated.title == "第二条自我广场", "self-index plaza post title should be editable")
        try expect(updated.type == .idea, "self-index plaza post type should be editable")
        try expect(updated.sensitivity == .normal, "self-index plaza post sensitivity should be editable")
        try expect(store.themeNames(for: updated) == ["生活审美"], "self-index plaza post tags should be editable")

        store.selectedSelfIndexThemeName = "手动主题更新"
        try expect(!store.selfIndexTimelineMemories.contains { $0.id == memory.id }, "old tag should no longer reveal retagged post")
        store.selectedSelfIndexThemeName = "生活审美"
        try expect(store.selfIndexTimelineMemories.contains { $0.id == memory.id }, "new tag should reveal retagged post")

        store.deleteSelfIndexMemory(updated)
        try expect(!store.memoryAtoms.contains { $0.id == memory.id }, "self-index plaza post should be deletable")

        let updatedTheme = try require(store.themes.first { $0.name == "手动主题更新" }, "updated manual tag missing before delete")
        store.deleteSelfIndexTheme(updatedTheme)
        try expect(!store.themes.contains { $0.id == updatedTheme.id }, "manual self-index tag should be deletable")
    }

    @MainActor
    private func checkSelfIndexAllTagSelectionAndRefreshPruneStaleFilters() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: "self-index-selection.sqlite3",
            seedDemoData: false
        )

        store.addSelfIndexTheme(name: "研究复盘", description: "读论文、实验和研究方向")
        store.selectSelfIndexTheme(named: "研究复盘")
        try expect(store.selectedSelfIndexThemeName == "研究复盘", "explicit tag selection should choose the requested core tag")

        store.selectAllSelfIndexThemes()
        try expect(store.selectedSelfIndexThemeName == nil, "all self plaza tag should clear the selected core tag")

        store.selectSelfIndexTheme(named: "不存在的标签")
        try expect(store.selectedSelfIndexThemeName == "不存在的标签", "stale selection setup should hold an unmatched tag before refresh")
        store.autoOrganizeMemories()
        try expect(store.selectedSelfIndexThemeName == nil, "refresh should prune stale self-index tag filters")
    }

    private func checkAIPromptIncludesWorkflowToolContextAndCoreTags() throws {
        let rawEntry = RawEntry(
            id: "entry-tool-context",
            inputType: .text,
            rawText: "今天读论文的时候发现自己更喜欢有明确问题意识的研究。",
            sourceFileID: nil,
            createdAt: memoriaTimestamp(),
            updatedAt: memoriaTimestamp()
        )
        let theme = Theme(
            id: "theme-research",
            name: "研究复盘",
            description: "读论文、实验和研究方向",
            createdAt: memoriaTimestamp(),
            updatedAt: memoriaTimestamp()
        )

        let messages = PromptBuilder().extractMemoryPrompt(rawEntry: rawEntry, knownPeople: [], knownThemes: [theme])
        let systemPrompt = try require(messages.first?.content, "extract memory system prompt missing")
        let userPrompt = try require(messages.last?.content, "extract memory user prompt missing")

        try expect(systemPrompt.contains("workflow") && systemPrompt.contains("tool"), "AI prompt should describe a workflow/tool contract")
        try expect(systemPrompt.contains("约饭") && systemPrompt.contains("行程"), "AI prompt should route social plans as schedule facts")
        try expect(userPrompt.contains(#""known_core_tags""#), "AI user prompt should include structured core tags")
        try expect(userPrompt.contains("研究复盘"), "AI prompt should include user-created core tag names")
        try expect(userPrompt.contains("读论文、实验和研究方向"), "AI prompt should include user-created core tag descriptions")
        try expect(userPrompt.contains(#""available_tools""#), "AI user prompt should include available tool definitions")
        try expect(userPrompt.contains("web_search"), "AI tool context should advertise web search as an explicit tool boundary")
    }

    private func checkLocalFallbackUsesKnownCoreThemesForSelfSearch() async throws {
        let rawEntry = RawEntry(
            id: "entry-known-theme",
            inputType: .text,
            rawText: "今天课程项目复盘时，我发现自己适合先写实验记录再做展示。",
            sourceFileID: nil,
            createdAt: memoriaTimestamp(),
            updatedAt: memoriaTimestamp()
        )
        let knownThemes = [
            Theme(
                id: "theme-academic-growth",
                name: "学业成长",
                description: "课程、学习策略、考试和知识成长",
                createdAt: memoriaTimestamp(),
                updatedAt: memoriaTimestamp()
            )
        ]

        let response = try await AIWorkflowService().extractMemory(
            rawEntry: rawEntry,
            knownPeople: [],
            knownThemes: knownThemes,
            apiKey: nil,
            settings: NativeSettings()
        )

        try expect(response.memoryProposals.first?.themes.contains { $0.name == "学业成长" } == true, "local fallback should reuse matching known core tags")
    }

    @MainActor
    private func checkDeveloperLogsExposeDiagnosticsAndAuditEvents() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: "developer-logs.sqlite3",
            seedDemoData: true,
            apiKeyReader: { nil }
        )

        store.refreshDeveloperLogs()
        try expect(store.developerLogSnapshot.databaseMetrics.contains { $0.label == "raw_entries" }, "developer logs should include database table metrics")
        try expect(store.developerLogSnapshot.runtimeEntries.contains { $0.title == "App state" }, "developer logs should include runtime app state")

        await store.captureForReview("Jason Wu 喜欢吃三文鱼。", mode: .friendDossier)
        let update = try require(
            store.pendingUpdates.first { $0.reviewCategory == .friendDossier && ($0.summary.contains("三文鱼") || $0.evidence.contains("三文鱼")) },
            "developer log setup missing salmon update"
        )
        store.confirm(update)
        store.refreshDeveloperLogs()

        try expect(store.developerLogSnapshot.recentEntries.contains { $0.title == "person_profile_patch_approved" }, "developer logs should surface recent audit events")
        try expect(!store.developerLogSnapshot.searchableText.localizedCaseInsensitiveContains("api_key"), "developer logs should not expose API key fields")
    }

    @MainActor
    private func checkDashboardStoreAssistantsDoNotMutatePersistedData() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let filename = "store-boundary.sqlite3"

        let before = try loadSnapshot(filename: filename, directory: tempDirectory, seedDemoData: true)
        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: filename,
            seedDemoData: true
        )
        let originalReminders = store.reminders
        let originalMemoryAtoms = store.memoryAtoms
        let originalPendingUpdates = store.pendingUpdates

        store.generateAgendaAssistantPlan()
        let afterAgendaPlan = try loadSnapshot(filename: filename, directory: tempDirectory, seedDemoData: false)

        try expect(!store.agendaAssistantPlan.items.isEmpty, "store agenda assistant should create suggestions")
        try expect(store.agendaAssistantPlan.items.allSatisfy(\.requiresApproval), "store agenda suggestions should require approval")
        try expect(store.reminders == originalReminders, "agenda assistant must not mutate in-memory reminders")
        try expect(store.memoryAtoms == originalMemoryAtoms, "agenda assistant must not mutate in-memory memories")
        try expect(store.pendingUpdates == originalPendingUpdates, "agenda assistant must not mutate pending review items")
        try expect(afterAgendaPlan.reminders == before.reminders, "agenda assistant must not persist reminder changes")
        try expect(afterAgendaPlan.memoryAtoms == before.memoryAtoms, "agenda assistant must not persist memory changes")
        try expect(afterAgendaPlan.pendingUpdates == before.pendingUpdates, "agenda assistant must not persist pending-update changes")

        store.autoOrganizeMemories()
        let afterOrganizer = try loadSnapshot(filename: filename, directory: tempDirectory, seedDemoData: false)

        try expect(!store.memoryOrganizationSuggestions.isEmpty, "store memory organizer should create suggestions")
        try expect(store.memoryOrganizationSuggestions.allSatisfy { !$0.requiresApproval }, "store organization suggestions should be automatic editable summaries")
        try expect(store.reminders == originalReminders, "memory organizer must not mutate in-memory reminders")
        try expect(store.memoryAtoms == originalMemoryAtoms, "memory organizer must not mutate in-memory memories")
        try expect(store.pendingUpdates == originalPendingUpdates, "memory organizer must not mutate pending review items")
        try expect(afterOrganizer.reminders == before.reminders, "memory organizer must not persist reminder changes")
        try expect(afterOrganizer.memoryAtoms == before.memoryAtoms, "memory organizer must not persist memory changes")
        try expect(afterOrganizer.pendingUpdates == before.pendingUpdates, "memory organizer must not persist pending-update changes")
    }

    @MainActor
    private func checkProfileFactSearchRoutesToPeopleNotSelfReflection() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: "profile-search.sqlite3",
            seedDemoData: true,
            apiKeyReader: { nil }
        )

        await store.captureForReview("我记得 Alex Chen 喜欢吃火锅，不吃香菜。")
        let allergyUpdate = try require(
            store.pendingUpdates.first { $0.profilePatchProposal?.profileCategory == .dietaryAllergy },
            "dietary profile patch should be waiting for review"
        )
        store.confirm(allergyUpdate)
        store.searchQuery = "香菜"

        try expect(store.searchResults.contains { $0.id == "person-demo-alex" }, "profile search should find Alex through category notes")
        try expect(!store.searchResults.contains { $0.source.contains("自我") && $0.excerpt.contains("香菜") }, "friend profile facts should not appear as self-reflection search results")
    }

    @MainActor
    private func checkBulkFriendCSVPreviewAndConfirmCreatesPeopleAndPatchReviews() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: "bulk-friends.sqlite3",
            seedDemoData: true
        )
        let originalPeopleCount = store.people.count
        let originalPendingCount = store.pendingUpdates.count
        let alexBefore = try require(store.people.first { $0.id == "demo-alex" }, "Alex should exist before CSV import")
        let alexOriginalFood = alexBefore.categoryNote(.foodPreference)
        let csv = """
        display_name,nickname,relation_label,group,contact,birthday,food_preference,dietary_allergy,interests,notes
        Alex Chen,Alex,Roommate,Classmates,,Nov 3,火锅,不吃香菜,数学,
        Riley Sun,Riley,Project friend,Classmates,wechat:riley,Jan 8,咖啡,,设计工具,课程项目伙伴
        """

        store.previewBulkFriendImport(text: csv, filename: "friends.csv")
        let preview = try require(store.importPreview, "CSV import preview should be created")

        try expect(preview.peopleToCreate == 1, "CSV preview should count Riley as a new person")
        try expect(preview.peopleToUpdate == 1, "CSV preview should count Alex as an existing person update")
        try expect(preview.profilePatchesToReview >= 4, "CSV preview should count profile patches needing review")
        try expect(store.people.count == originalPeopleCount, "CSV preview must not mutate people")
        try expect(store.pendingUpdates.count == originalPendingCount, "CSV preview must not create pending updates")

        store.confirmImportPreview()

        let alexAfter = try require(store.people.first { $0.id == "demo-alex" }, "Alex should remain after CSV import")
        try expect(store.people.count == originalPeopleCount + 1, "CSV confirm should create one new friend")
        try expect(store.people.contains { $0.displayName == "Riley Sun" }, "CSV confirm should create Riley")
        try expect(alexAfter.categoryNote(.foodPreference) == alexOriginalFood, "CSV confirm should not directly mutate existing profile facts")
        try expect(store.pendingUpdates.count > originalPendingCount, "CSV confirm should create reviewable profile patches")
        try expect(store.pendingUpdates.contains { $0.profilePatchProposal?.targetPersonID == "demo-alex" && $0.profilePatchProposal?.profileCategory == .foodPreference }, "CSV confirm should create an Alex food preference patch")
    }

    private func checkMemoryCategoriesIncludeReflectionsRelationshipsAndGifts() throws {
        let snapshot = DashboardSnapshot.demo
        let categories = Dictionary(grouping: snapshot.memoryAtoms, by: \.type)

        try expect(categories[.personalReflection]?.isEmpty == false, "memory demo should include reflection category")
        try expect(categories[.relationshipMemory]?.isEmpty == false, "memory demo should include relationship category")
        try expect(categories[.giftSignal]?.isEmpty == false, "memory demo should include gift category")
    }

    @MainActor
    private func checkTransferBundlePreviewAndMergeKeepsExistingData() async throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let filename = "transfer-target.sqlite3"
        let store = DashboardStore(
            databaseDirectory: tempDirectory,
            databaseFilename: filename,
            seedDemoData: true
        )
        let originalPeopleCount = store.people.count
        let originalAlex = try require(store.people.first { $0.id == "demo-alex" }, "Alex should exist before transfer import")
        let importedPerson = FriendPerson(
            id: "import-riley",
            displayName: "Riley Sun",
            relationLabel: "Project friend",
            groupLabel: .classmates,
            location: "NYU",
            birthday: "Jan 8",
            dietaryRestrictions: "",
            favoriteFoods: "咖啡",
            dislikedThings: "",
            zodiacSign: "",
            mbti: "",
            interests: "设计工具",
            books: "",
            sports: "",
            profileTags: "项目伙伴",
            lastSignal: "一起整理课程项目",
            initials: "RS"
        )
        let importedEdge = RelationshipEdge(
            id: "import-edge-alex-riley",
            sourceID: originalAlex.id,
            sourceName: originalAlex.displayName,
            targetID: importedPerson.id,
            targetName: importedPerson.displayName,
            label: "课程项目伙伴",
            strength: 0.64,
            relationKind: "project",
            confidence: 0.8,
            isAIInferred: true,
            tags: ["项目伙伴"],
            aiPrimaryTag: "项目伙伴"
        )
        let bundle = MemoriaTransferBundle(
            people: [TransferPerson(person: importedPerson)],
            memoryAtoms: [],
            themes: [TransferTheme(theme: Theme(id: "theme-import", name: "迁移测试", description: "导入预览测试", createdAt: memoriaTimestamp(), updatedAt: memoriaTimestamp()))],
            memoryPersonLinks: [],
            memoryThemeLinks: [],
            relationshipEdges: [TransferRelationshipEdge(edge: importedEdge)],
            relationshipTagPriorities: [],
            reminders: [],
            gifts: [],
            files: []
        )
        let url = tempDirectory.appending(path: "memoria-transfer-test.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(bundle).write(to: url, options: [.atomic])

        store.previewImportBundle(from: url)
        let preview = try require(store.importPreview, "transfer import preview should be created")

        try expect(preview.peopleToCreate == 1, "preview should count imported person as new")
        try expect(preview.relationshipEdgesToCreate == 1, "preview should count imported relationship edge as new")
        try expect(store.people.count == originalPeopleCount, "preview must not mutate people")

        store.confirmImportPreview()

        try expect(store.importPreview == nil, "preview should clear after confirmed import")
        try expect(store.people.count == originalPeopleCount + 1, "confirmed import should add one person")
        try expect(store.people.contains { $0.id == originalAlex.id }, "confirmed import must not delete existing people")
        try expect(store.relationshipEdges.contains { $0.id == importedEdge.id && $0.displayTag(priorities: store.relationshipTagPriorities) == "项目伙伴" }, "confirmed import should merge relationship edge tags")
    }

    private func checkRelationshipMapLayoutScalesInNarrowWindows() throws {
        let narrow = RelationshipMapLayoutPolicy.metrics(width: 420, height: 260)
        let wide = RelationshipMapLayoutPolicy.metrics(width: 1100, height: 640)

        try expect(narrow.scale < wide.scale, "relationship map should scale down in narrow windows")
        try expect(narrow.centerNodeSize < wide.centerNodeSize, "center node should shrink in narrow windows")
        try expect(narrow.secondHopRadius < 130, "narrow map should keep second-hop radius inside canvas short side")
        try expect(!narrow.showsSecondaryEdgeLabels, "narrow map should hide secondary edge labels")
        try expect(wide.showsSecondaryEdgeLabels, "wide map can show secondary edge labels")
    }

    private func checkRelationshipVisualToneClassification() throws {
        let normal = RelationshipEdge(
            id: "tone-normal",
            sourceName: "A",
            targetName: "B",
            label: "项目伙伴",
            strength: 0.48,
            relationKind: "project",
            tags: ["同学"]
        )
        let intimate = RelationshipEdge(
            id: "tone-intimate",
            sourceName: "A",
            targetName: "C",
            label: "核心朋友",
            strength: 0.86,
            relationKind: "friend",
            tags: ["好朋友"]
        )
        let unfriendly = RelationshipEdge(
            id: "tone-unfriendly",
            sourceName: "A",
            targetName: "D",
            label: "有冲突",
            strength: 0.91,
            relationKind: "conflict",
            tags: ["边界风险"]
        )

        try expect(normal.visualTone == .normal, "ordinary relationship edges should use the normal visual tone")
        try expect(intimate.visualTone == .intimate, "close relationship edges should use the intimate visual tone")
        try expect(unfriendly.visualTone == .unfriendly, "unfriendly relationship labels should override high strength")
        try expect(RelationshipVisualTone.normal.title(for: .zhCN) == "普通", "relationship tone should expose Chinese labels")
        try expect(RelationshipVisualTone.unfriendly.title(for: .en) == "Unfriendly", "relationship tone should expose English labels")
    }

    private func checkChineseFirstCopyExistsForCoreNavigation() throws {
        try expect(AppSection.capture.title(for: .zhCN) == "记录", "capture section should have Chinese copy")
        try expect(AppSection.aiReview.title(for: .zhCN) == "整理台", "review desk section should have Chinese copy")
        try expect(AppSection.ask.title(for: .zhCN) == "对话检索", "ask section should have Chinese copy")
        try expect(AppSection.selfSearch.title(for: .zhCN) == "自我检索", "self search section should have Chinese copy")
        try expect(AppSection.memory.title(for: .zhCN) == "自我检索", "legacy memory section should map to self search copy")
        try expect(AppSection.friendDossier.title(for: .zhCN) == "朋友档案管理", "friend dossier section should have Chinese copy")
        try expect(AppSection.schedule.title(for: .zhCN) == "行程安排", "schedule section should have Chinese copy")
        try expect(GroupFilter.internship.title(for: .zhCN) == "实习/职业", "group filter should have Chinese copy")
        try expect(MemoryAtomType.personalReflection.displayName(for: .zhCN) == "自我想法", "memory type should have Chinese copy")
    }

    private func checkPendingUpdateApprovalIsStatusGuarded() throws {
        let tempDirectory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        let store = try LocalSQLiteStore(filename: "test.sqlite3", directory: tempDirectory, seedDemoData: true)
        let rawEntries = RawEntryRepository(database: store)
        let pendingUpdates = PendingUpdateRepository(database: store)
        let memories = MemoryRepository(database: store)

        let entry = try rawEntries.create(inputType: .text, rawText: "我好像总是怕麻烦 Alex，所以很多事情没说。")
        let proposal = try AIJSONParser().parseExtractMemoryResponse(data: fixtureData("extract_memory_valid_response")).memoryProposals[0]
        let update = try pendingUpdates.createMemoryAtomProposal(sourceEntryID: entry.id, proposal: proposal)
        _ = try pendingUpdates.approve(id: update.id)

        do {
            _ = try pendingUpdates.approve(id: update.id)
            throw CheckError.failed("approved update was approved twice")
        } catch PendingUpdateError.notReviewable {
        }

        do {
            _ = try pendingUpdates.edit(id: update.id, title: "Edited after approval", summary: "Invalid", content: "Invalid")
            throw CheckError.failed("approved update was edited after approval")
        } catch PendingUpdateError.notReviewable {
        }

        let memoriesAfterSecondApprovalAttempt = try memories.search(query: "麻烦", includeSensitive: true)
        let sourceMatchedMemories = memoriesAfterSecondApprovalAttempt.filter { $0.sourceEntryID == entry.id }
        try expect(sourceMatchedMemories.count == 1, "double approval created duplicate memory")
    }

    private func checkPersonProfileCategoriesBackAISchema() throws {
        let categories = PersonProfileCategory.allCases
        let may = try require(DashboardSnapshot.demo.people.first { $0.id == "demo-may" }, "May missing")
        let prompt = PromptBuilder().extractMemoryPrompt(
            rawEntry: RawEntry(
                id: "raw-check",
                inputType: .text,
                rawText: "小雨 8 月要去冰岛，最近也在学陶艺。",
                sourceFileID: nil,
                createdAt: memoriaTimestamp(),
                updatedAt: memoriaTimestamp()
            ),
            knownPeople: DashboardSnapshot.demo.people,
            knownThemes: []
        )
        let promptText = prompt.map { $0.content }.joined(separator: "\n")

        try expect(categories.count == 25, "profile category schema should include the requested 25 categories")
        try expect(categories.contains(.aiInference), "profile category schema should include explicit AI inference category")
        try expect(may.categoryNote(.communicationPreference).contains("文字"), "person profile should store category notes")
        try expect(promptText.contains(PersonProfileCategory.aiInference.rawValue), "AI extraction prompt should include profile category keys")
        try expect(promptText.contains("必须标记为推断"), "AI extraction prompt should warn about inferred facts")
    }

    private func fixtureData(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw CheckError.failed("missing fixture \(name).json")
        }
        return try Data(contentsOf: url)
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "MemoriaMacChecks-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func loadSnapshot(filename: String, directory: URL, seedDemoData: Bool) throws -> DashboardSnapshot {
        let store = try LocalSQLiteStore(filename: filename, directory: directory, seedDemoData: seedDemoData)
        return try store.loadSnapshot()
    }

    private func protocolProposal(
        type: MemoryAtomType,
        title: String,
        sourceQuote: String
    ) -> MemoryAtomProposal {
        MemoryAtomProposal(
            proposalType: .memoryAtom,
            memoryType: type,
            title: title,
            summary: sourceQuote,
            content: sourceQuote,
            sourceQuote: sourceQuote,
            confidence: 0.82,
            sensitivity: .normal,
            isAIInferred: true,
            relatedPeople: [],
            themes: [],
            followUpQuestions: [],
            suggestedActions: []
        )
    }

    private func copyPerson(_ person: FriendPerson, favoriteFoods: String? = nil) -> FriendPerson {
        FriendPerson(
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
            favoriteFoods: favoriteFoods ?? person.favoriteFoods,
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
            categoryNotes: person.categoryNotes
        )
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

    private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw CheckError.failed(message)
        }
    }

    private func expectAIContractFailure(_ fixture: String, parser: AIJSONParser) throws {
        do {
            _ = try parser.parseExtractMemoryResponse(data: fixtureData(fixture))
            throw CheckError.failed("\(fixture).json should fail AI contract validation")
        } catch is AIContractError {
        }
    }

    private func require<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else {
            throw CheckError.failed(message)
        }
        return value
    }

    private func castDictionary(_ value: Any?, _ name: String) throws -> [String: Any] {
        guard let dictionary = value as? [String: Any] else {
            throw CheckError.failed("\(name) was not an object")
        }
        return dictionary
    }

    private func castArray(_ value: Any?, _ name: String) throws -> [Any] {
        guard let array = value as? [Any] else {
            throw CheckError.failed("\(name) was not an array")
        }
        return array
    }
}

private enum CheckError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            message
        }
    }
}
