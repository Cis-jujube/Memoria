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
        try checkConnectionTestRequestIsMinimalJSONPing()
        try await checkLocalFallbackKeepsPersonPreferenceAsFriendFact()
        try await checkLocalFallbackCreatesFriendProfilePatches()
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
        } catch AIContractError.invalidJSON {
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

        store.confirm(update)
        try expect(store.sidebarSelection == SidebarSelection.section(.schedule), "approving a schedule item should open schedule")
        try expect(store.reminders.contains { $0.title.contains("考试") || $0.context.contains("考试") }, "approved schedule item should create a reminder")
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
        try expect(store.pendingUpdates.count == pendingCount + 1, "fallback capture should create a reviewable pending update")
        try expect(store.statusMessage.contains("本地") || store.statusMessage.localizedCaseInsensitiveContains("local"), "fallback capture should explain local draft fallback")
        let created = try require(store.pendingUpdates.first, "fallback pending update missing")
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

    private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw CheckError.failed(message)
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
