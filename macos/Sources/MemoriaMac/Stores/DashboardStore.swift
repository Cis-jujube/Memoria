import Combine
import Foundation

@MainActor
public final class DashboardStore: ObservableObject {
    @Published public var sidebarSelection: SidebarSelection? = .section(.home)
    @Published public var selectedPersonID: FriendPerson.ID?
    @Published public var selectedMemoryType: MemoryAtomType?
    @Published public var selectedCaptureMode: WorkspaceMode = .selfSearch
    @Published public var selectedReviewCategory: ReviewCategory?
    @Published public var selectedSelfIndexThemeName: String?
    @Published public var searchQuery = ""
    @Published public var quickCaptureText = ""
    @Published public var agendaAssistantPrompt = "今天约了人，帮我安排日历和行程，不要让我忘记。"
    @Published public private(set) var agendaAssistantPlan = AgendaAssistantPlan.empty
    @Published public private(set) var memoryOrganizationSuggestions: [MemoryOrganizationSuggestion] = []
    @Published public private(set) var captureProgress = CaptureProgressState.idle
    @Published public private(set) var developerLogSnapshot = DeveloperLogSnapshot.empty
    @Published public var settings = NativeSettings()
    @Published public var statusMessage = ""

    @Published public private(set) var people: [FriendPerson]
    @Published public private(set) var pendingUpdates: [PendingUpdate]
    @Published public private(set) var memoryAtoms: [MemoryAtom]
    @Published public private(set) var themes: [Theme]
    @Published public private(set) var reminders: [ReminderItem]
    @Published public private(set) var gifts: [GiftIdea]
    @Published public private(set) var files: [ImportedFile]
    @Published public private(set) var relationshipEdges: [RelationshipEdge]
    @Published public private(set) var relationshipTagPriorities: [RelationshipTagPriority]
    @Published public private(set) var importPreview: TransferImportPreview?
    @Published public private(set) var themeNamesByMemoryID: [String: [String]] = [:]

    private var database: LocalSQLiteStore?
    private let keyStore = SecureAPIKeyStore()
    private let deepSeek = DeepSeekClient()
    private let aiWorkflow: AIWorkflowService
    private let apiKeyReader: (() -> String?)?
    private let giftWorkflow = GiftRecommendationWorkflow()
    private let notificationPlanner = ReminderNotificationPlanner()
    private let agendaWorkflow = AgendaAssistantWorkflow()
    private let memoryOrganizer = MemoryAutoOrganizer()

    public init(
        snapshot: DashboardSnapshot = .demo,
        databaseDirectory: URL? = nil,
        databaseFilename: String = "memoria.sqlite3",
        seedDemoData: Bool = true,
        aiWorkflow: AIWorkflowService = AIWorkflowService(),
        apiKeyReader: (() -> String?)? = nil
    ) {
        self.aiWorkflow = aiWorkflow
        self.apiKeyReader = apiKeyReader
        do {
            let database = try LocalSQLiteStore(
                filename: databaseFilename,
                directory: databaseDirectory,
                seedDemoData: seedDemoData
            )
            self.database = database
            let loadedSnapshot = try database.loadSnapshot()
            var loadedSettings = try database.loadSettings()
            loadedSettings.hasAPIKey = keyStore.hasSavedKeyWithoutPrompt()
            settings = loadedSettings
            people = loadedSnapshot.people
            pendingUpdates = loadedSnapshot.pendingUpdates
            memoryAtoms = loadedSnapshot.memoryAtoms
            themes = loadedSnapshot.themes
            reminders = loadedSnapshot.reminders
            gifts = loadedSnapshot.gifts
            files = loadedSnapshot.files
            relationshipEdges = loadedSnapshot.relationshipEdges
            relationshipTagPriorities = loadedSnapshot.relationshipTagPriorities
            themeNamesByMemoryID = Self.loadThemeNamesByMemoryID(
                for: loadedSnapshot.memoryAtoms,
                database: database
            )
            selectedPersonID = loadedSnapshot.people.first?.id
            refreshDeveloperLogs()
            return
        } catch {
            database = nil
            statusMessage = "Local database failed: \(error.localizedDescription)"
        }

        people = snapshot.people
        pendingUpdates = snapshot.pendingUpdates
        memoryAtoms = snapshot.memoryAtoms
        themes = snapshot.themes
        reminders = snapshot.reminders
        gifts = snapshot.gifts
        files = snapshot.files
        relationshipEdges = snapshot.relationshipEdges
        relationshipTagPriorities = snapshot.relationshipTagPriorities
        themeNamesByMemoryID = [:]
        selectedPersonID = snapshot.people.first?.id
        refreshDeveloperLogs()
    }

    public var copy: NativeCopy {
        nativeCopy(for: settings.language)
    }

    public var isCapturing: Bool {
        captureProgress.phase.isRunning
    }

    public var currentSection: AppSection {
        switch sidebarSelection {
        case .section(let section):
            section
        case .group:
            .people
        case nil:
            .home
        }
    }

    public var selectedGroup: GroupFilter? {
        if case .group(let group) = sidebarSelection {
            return group
        }

        return nil
    }

    public var visiblePeople: [FriendPerson] {
        guard let selectedGroup else {
            return people
        }

        return people.filter { $0.belongs(to: selectedGroup) }
    }

    public var selectedPerson: FriendPerson? {
        if let selectedPersonID,
           let person = people.first(where: { $0.id == selectedPersonID }) {
            return person
        }

        return visiblePeople.first ?? people.first
    }

    public var relationshipHealth: [CountItem] {
        [
            CountItem(label: "Active people", count: people.count),
            CountItem(label: "AI updates", count: pendingUpdates.count),
            CountItem(label: "Memories", count: memoryAtoms.count),
            CountItem(label: "Reminders", count: reminders.count),
        ]
    }

    public var todayReminders: [ReminderItem] {
        sortedReminders(reminders.filter(\.isToday))
    }

    public var upcomingReminders: [ReminderItem] {
        sortedReminders(reminders.filter { !$0.isToday })
    }

    public var datedReminders: [ReminderItem] {
        sortedReminders(reminders.filter(\.hasConcreteDueDate))
    }

    public var unscheduledReminders: [ReminderItem] {
        sortedReminders(reminders.filter { !$0.hasConcreteDueDate })
    }

    public var visibleMemoryAtoms: [MemoryAtom] {
        selfIndexTimelineMemories
    }

    public var selfIndexTimelineMemories: [MemoryAtom] {
        guard let selectedMemoryType else {
            return filterBySelectedSelfIndexTheme(memoryAtoms.filter(\.isSelfSearchDefault))
        }
        return filterBySelectedSelfIndexTheme(memoryAtoms.filter { $0.type == selectedMemoryType })
    }

    public var selfIndexThemeSummaries: [SelfIndexThemeSummary] {
        themes.map { theme in
            SelfIndexThemeSummary(
                theme: theme,
                memoryCount: memoryAtoms.filter { memory in
                    memory.isSelfSearchDefault && (themeNamesByMemoryID[memory.id] ?? []).contains(theme.name)
                }.count
            )
        }
    }

    public var memoryTypeCounts: [CountItem] {
        MemoryAtomType.allCases.map { type in
            CountItem(
                label: type.displayName(for: settings.language),
                count: memoryAtoms.filter { $0.type == type }.count
            )
        }
    }

    public var groupCounts: [CountItem] {
        GroupFilter.allCases.map { group in
            CountItem(
                label: group.rawValue,
                count: people.filter { $0.belongs(to: group) }.count
            )
        }
    }

    public var reminderWindowCounts: [CountItem] {
        countBy(reminders.map { $0.dueDate ?? reminderWindow($0.dueLabel) })
    }

    public var fileStatusCounts: [CountItem] {
        countBy(files.map(\.status))
    }

    public var focusItems: [FocusItem] {
        var items: [FocusItem] = []

        if let firstUpdate = pendingUpdates.first {
            items.append(
                FocusItem(
                    id: "review-\(firstUpdate.id)",
                    label: "Review \(firstUpdate.personName)",
                    detail: firstUpdate.summary,
                    target: .section(.aiReview),
                    priority: .high
                )
            )
        }

        if let firstReminder = reminders.first {
            items.append(
                FocusItem(
                    id: "reminder-\(firstReminder.id)",
                    label: "Prepare \(firstReminder.personName)",
                    detail: "\(firstReminder.title) - \(firstReminder.dueLabel)",
                    target: .section(.schedule),
                    priority: .high
                )
            )
        }

        if let firstGift = gifts.first {
            items.append(
                FocusItem(
                    id: "gift-\(firstGift.id)",
                    label: "Gift idea for \(firstGift.personName)",
                    detail: "\(firstGift.title) - \(firstGift.priceBand)",
                    target: .section(.friendDossier),
                    priority: .medium
                )
            )
        }

        return items
    }

    public var askSuggestions: [String] {
        let firstVisibleMemory = memoryAtoms.first { $0.sensitivity == .normal }
        if resolvedLanguage(settings.language) == .zhCN {
            return [
                firstVisibleMemory.map { "这条记忆说明了什么：\($0.title)？" } ?? "我最近在人际关系里反复在想什么？",
                pendingUpdates.first.map { "\($0.personName) 的待确认内容有什么需要我看？" } ?? "哪些记忆还需要我确认？",
                "帮我搜索 May 的生日、礼物和旅行偏好",
                "Alex 最近有什么需要提醒或关心的事？"
            ]
        }
        return [
            firstVisibleMemory.map { "What does this memory say: \($0.title)?" } ?? "What have I been thinking about recently?",
            pendingUpdates.first.map { "What should I review for \($0.personName)?" } ?? "Which memories still need review?",
            "Which memories mention Alex?"
        ]
    }

    public var searchResults: [SearchResult] {
        let normalized = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !normalized.isEmpty else {
            return []
        }

        var results: [SearchResult] = []
        let isChinese = resolvedLanguage(settings.language) == .zhCN

        for update in pendingUpdates where update.personName.lowercased().contains(normalized) || update.summary.lowercased().contains(normalized) {
            results.append(
                SearchResult(
                    id: "update-\(update.id)",
                    title: update.personName,
                    excerpt: update.summary,
                    source: "\(isChinese ? "整理台" : "AI Inbox") - \(update.createdLabel)"
                )
            )
        }

        for memory in memoryAtoms where memory.sensitivity == .normal && (memory.title.lowercased().contains(normalized) || memory.summary.lowercased().contains(normalized) || memory.content.lowercased().contains(normalized) || (memory.sourceQuote ?? "").lowercased().contains(normalized)) {
            results.append(
                SearchResult(
                    id: "memory-\(memory.id)",
                    title: memory.title,
                    excerpt: memory.summary,
                    source: "\(isChinese ? "记忆" : "Memory") - \(memory.type.displayName(for: settings.language))"
                )
            )
        }

        for person in people where person.matches(query: normalized) {
            results.append(
                SearchResult(
                    id: "person-\(person.id)",
                    title: person.displayName,
                    excerpt: person.lastSignal,
                    source: "\(person.groupLabelsTitle(for: settings.language)) - \(person.location)"
                )
            )
        }

        for reminder in reminders where reminder.matches(query: normalized) {
            results.append(
                SearchResult(
                    id: "reminder-\(reminder.id)",
                    title: reminder.title,
                    excerpt: [reminder.personName, reminder.dueLabel, reminder.timeLabel, reminder.context].filter { !$0.isEmpty }.joined(separator: " · "),
                    source: isChinese ? "提醒事项" : "Reminder"
                )
            )
        }

        for gift in gifts where gift.matches(query: normalized) {
            results.append(
                SearchResult(
                    id: "gift-\(gift.id)",
                    title: gift.title,
                    excerpt: gift.rationale,
                    source: "\(isChinese ? "礼物推荐" : "Gift Ideas") - \(gift.personName)"
                )
            )
        }

        return results
    }

    public func navigate(to section: AppSection) {
        sidebarSelection = .section(section)
    }

    public func openReviewDesk(category: ReviewCategory? = nil) {
        selectedReviewCategory = category
        sidebarSelection = .section(.aiReview)
    }

    public func navigate(to group: GroupFilter) {
        sidebarSelection = .group(group)
        selectedPersonID = visiblePeople.first?.id
    }

    public func selectFirstPendingUpdate() {
        openReviewDesk()
    }

    public func confirm(_ update: PendingUpdate) {
        approve(update)
    }

    public func discard(_ update: PendingUpdate) {
        reject(update)
    }

    public func quickCapture() {
        let trimmed = quickCaptureText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty, !isCapturing else {
            return
        }

        let mode = selectedCaptureMode
        quickCaptureText = ""
        captureProgress = .saving(reviewCategory: mode.reviewCategory)
        selectedReviewCategory = mode.reviewCategory
        sidebarSelection = .section(.aiReview)
        Task { await captureForReview(trimmed, mode: mode) }
    }

    public func resetCaptureProgress() {
        guard !isCapturing else { return }
        captureProgress = .idle
    }

    public func refreshDeveloperLogs() {
        let runtimeEntries = makeRuntimeDeveloperLogEntries()
        guard let database else {
            developerLogSnapshot = DeveloperLogSnapshot(
                generatedAt: memoriaTimestamp(),
                databaseMetrics: [],
                runtimeEntries: runtimeEntries + [
                    DeveloperLogEntry(
                        id: "database-unavailable",
                        title: "Database unavailable",
                        detail: "The local SQLite store is not available in this store instance.",
                        createdAt: memoriaTimestamp(),
                        level: .warning
                    )
                ],
                recentEntries: []
            )
            return
        }

        do {
            developerLogSnapshot = try database.loadDeveloperLogSnapshot(runtimeEntries: runtimeEntries)
        } catch {
            developerLogSnapshot = DeveloperLogSnapshot(
                generatedAt: memoriaTimestamp(),
                databaseMetrics: [],
                runtimeEntries: runtimeEntries + [
                    DeveloperLogEntry(
                        id: "developer-log-refresh-error",
                        title: "Developer log refresh failed",
                        detail: developerLogRedactedText(error.localizedDescription),
                        createdAt: memoriaTimestamp(),
                        level: .error
                    )
                ],
                recentEntries: []
            )
        }
    }

    public func updateSettings(_ settings: NativeSettings) {
        self.settings = settings
        do {
            try database?.saveSettings(settings)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func saveAPIKey(_ apiKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try keyStore.save(trimmed)
            settings.hasAPIKey = true
            statusMessage = "DeepSeek key saved locally."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func removeAPIKey() {
        do {
            try keyStore.remove()
            settings.hasAPIKey = false
            statusMessage = "DeepSeek key removed."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func testConnection() {
        Task {
            guard let apiKey = keyStore.read() else {
                statusMessage = copy.missingKeyMessage
                return
            }
            let currentSettings = settings
            let client = deepSeek

            do {
                let result = try await client.testConnection(apiKey: apiKey, settings: currentSettings)
                statusMessage = result.statusMessage
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    public func exportLocalData() {
        do {
            let export = try makeTransferBundle()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(export)
            let documents = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let filename = "memoria-transfer-\(Int(Date().timeIntervalSince1970)).json"
            let url = documents.appending(path: filename)
            try data.write(to: url, options: [.atomic])
            statusMessage = resolvedLanguage(settings.language) == .zhCN
                ? "已导出完整本地迁移包，不包含 API key：\(url.path)"
                : "Exported complete local transfer bundle without API keys: \(url.path)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func previewImportBundle(from url: URL) {
        do {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let data = try Data(contentsOf: url)
            let bundle = try JSONDecoder().decode(MemoriaTransferBundle.self, from: data)
            guard bundle.schemaVersion == 1 else {
                statusMessage = resolvedLanguage(settings.language) == .zhCN
                    ? "暂不支持 schema_version \(bundle.schemaVersion) 的迁移包。"
                    : "Unsupported transfer bundle schema_version \(bundle.schemaVersion)."
                return
            }
            importPreview = makeImportPreview(filename: url.lastPathComponent, bundle: bundle)
            statusMessage = resolvedLanguage(settings.language) == .zhCN
                ? "已读取迁移包，请确认预览后再合并。"
                : "Transfer bundle loaded. Review the preview before merging."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func previewBulkFriendImport(text: String, filename: String = "friends.csv") {
        do {
            let parsed = try BulkFriendImportParser().parse(text: text, filename: filename, existingPeople: people)
            importPreview = makeImportPreview(
                filename: filename,
                bundle: parsed.bundle,
                profilePatchProposals: parsed.profilePatchProposals
            )
            statusMessage = resolvedLanguage(settings.language) == .zhCN
                ? "已生成朋友批量导入预览，请确认后再创建档案和待确认事实。"
                : "Bulk friend import preview is ready. Confirm before creating profiles and reviewable facts."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func confirmImportPreview() {
        guard let importPreview else { return }
        do {
            try database?.importTransferBundle(importPreview.bundle)
            if let database {
                let pending = PendingUpdateRepository(database: database)
                for proposal in importPreview.profilePatchProposals {
                    _ = try pending.createPersonProfilePatchProposal(sourceEntryID: nil, proposal: proposal)
                }
            }
            try reloadSnapshot()
            self.importPreview = nil
            selectedPersonID = visiblePeople.first?.id ?? people.first?.id
            statusMessage = resolvedLanguage(settings.language) == .zhCN
                ? "已合并迁移包；没有删除本机原有数据。"
                : "Transfer bundle merged without deleting existing local data."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func cancelImportPreview() {
        importPreview = nil
        statusMessage = resolvedLanguage(settings.language) == .zhCN
            ? "已取消导入预览。"
            : "Import preview cancelled."
    }

    public func deleteAllLocalData() {
        do {
            try database?.deleteAllData()
            try keyStore.remove()
            settings.hasAPIKey = false
            try reloadSnapshot()
            selectedPersonID = nil
            statusMessage = "Deleted local SQLite data and removed the DeepSeek key."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func edit(_ update: PendingUpdate, title: String, summary: String, content: String) {
        do {
            guard let database else { return }
            _ = try PendingUpdateRepository(database: database).edit(
                id: update.id,
                title: title,
                summary: summary,
                content: content
            )
            try reloadSnapshot()
            statusMessage = "Proposal edited. Review before approving."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func captureForReview(_ text: String, mode: WorkspaceMode? = nil) async {
        let captureMode = mode ?? selectedCaptureMode
        let reviewCategory = captureMode.reviewCategory
        do {
            guard let database else { return }
            captureProgress = .saving(reviewCategory: reviewCategory)
            selectedReviewCategory = reviewCategory
            sidebarSelection = .section(.aiReview)
            let rawEntries = RawEntryRepository(database: database)
            let pending = PendingUpdateRepository(database: database)
            let themes = ThemeRepository(database: database)

            let rawEntry = try rawEntries.create(inputType: .text, rawText: text)
            captureProgress = .thinking(reviewCategory: reviewCategory)
            let key = apiKeyReader.map { $0() } ?? keyStore.read()
            let knownPeople = people
            let currentSettings = settings
            let workflow = aiWorkflow
            let knownThemes = (try? themes.list()) ?? []
            let response: ExtractMemoryResponse
            let fallbackMessage: String?
            do {
                response = try await workflow.extractMemory(
                    rawEntry: rawEntry,
                    knownPeople: knownPeople,
                    knownThemes: knownThemes,
                    apiKey: key,
                    settings: currentSettings
                )
                fallbackMessage = nil
            } catch {
                response = try await workflow.extractMemory(
                    rawEntry: rawEntry,
                    knownPeople: knownPeople,
                    knownThemes: knownThemes,
                    apiKey: nil,
                    settings: currentSettings
                )
                fallbackMessage = error.localizedDescription
            }
            captureProgress = .organizing(reviewCategory: reviewCategory)
            let constrainedResponse = response.constrained(to: captureMode, rawEntry: rawEntry)
            for proposal in constrainedResponse.memoryProposals {
                _ = try pending.createMemoryAtomProposal(sourceEntryID: rawEntry.id, proposal: proposal)
            }
            for proposal in constrainedResponse.personFactProposals {
                _ = try pending.createPersonProfilePatchProposal(sourceEntryID: rawEntry.id, proposal: proposal)
            }

            if let fallbackMessage {
                statusMessage = resolvedLanguage(settings.language) == .zhCN
                    ? "真实 AI 返回不可用，已保存原文并生成本地待确认草稿。原因：\(fallbackMessage)"
                    : "Remote AI was unavailable. Saved the raw entry and created a local review draft. Reason: \(fallbackMessage)"
                captureProgress = .failed(reviewCategory: reviewCategory, message: statusMessage)
            } else if key == nil {
                statusMessage = resolvedLanguage(settings.language) == .zhCN
                    ? "已送到整理台 · \(reviewCategory.title(for: settings.language))。当前使用本地 AI 草稿；可在设置中添加 DeepSeek key。"
                    : "Sent to Review · \(reviewCategory.title(for: settings.language)). Created a local AI draft; add a DeepSeek key in Settings for real extraction."
                captureProgress = .delivered(reviewCategory: reviewCategory)
            } else {
                statusMessage = resolvedLanguage(settings.language) == .zhCN
                    ? "已送到整理台 · \(reviewCategory.title(for: settings.language))。"
                    : "Sent to Review · \(reviewCategory.title(for: settings.language))."
                captureProgress = .delivered(reviewCategory: reviewCategory)
            }

            try reloadSnapshot()
        } catch {
            statusMessage = error.localizedDescription
            captureProgress = .failed(reviewCategory: reviewCategory, message: error.localizedDescription)
        }
    }

    private func approve(_ update: PendingUpdate) {
        do {
            guard let database else { return }
            let destination = destinationSection(for: update.reviewCategory)
            _ = try PendingUpdateRepository(database: database).approve(id: update.id)
            try reloadSnapshot()
            sidebarSelection = .section(destination)
            statusMessage = "已批准入库。"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func reject(_ update: PendingUpdate) {
        do {
            guard let database else { return }
            try PendingUpdateRepository(database: database).reject(id: update.id)
            try reloadSnapshot()
            statusMessage = "Proposal rejected. Raw entry remains saved."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func reloadSnapshot() throws {
        guard let database else { return }
        let snapshot = try database.loadSnapshot()
        people = snapshot.people
        pendingUpdates = snapshot.pendingUpdates
        memoryAtoms = snapshot.memoryAtoms
        themes = snapshot.themes
        reminders = snapshot.reminders
        gifts = snapshot.gifts
        files = snapshot.files
        relationshipEdges = snapshot.relationshipEdges
        relationshipTagPriorities = snapshot.relationshipTagPriorities
        themeNamesByMemoryID = Self.loadThemeNamesByMemoryID(
            for: snapshot.memoryAtoms,
            database: database
        )
        pruneSelectedSelfIndexThemeIfNeeded()
    }

    public func memories(for person: FriendPerson) -> [MemoryAtom] {
        guard let database,
              let memories = try? MemoryRepository(database: database).memories(forPersonID: person.id) else {
            return memoryAtoms.filter { memory in
                memory.title.localizedCaseInsensitiveContains(person.displayName) ||
                    memory.summary.localizedCaseInsensitiveContains(person.displayName)
            }
        }
        return memories
    }

    public func themeNames(for memory: MemoryAtom) -> [String] {
        themeNamesByMemoryID[memory.id] ?? []
    }

    public func selectAllSelfIndexThemes() {
        selectedSelfIndexThemeName = nil
    }

    public func selectSelfIndexTheme(named name: String?) {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        selectedSelfIndexThemeName = trimmedName.isEmpty ? nil : trimmedName
    }

    public func addSelfIndexTheme(name: String, description: String?) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusMessage = resolvedLanguage(settings.language) == .zhCN ? "先填写标签名称。" : "Enter a tag name first."
            return
        }

        do {
            if let database {
                let theme = try database.upsertTheme(name: trimmedName, description: description)
                try reloadSnapshot()
                selectedSelfIndexThemeName = theme.name
            } else if !themes.contains(where: { $0.name == trimmedName }) {
                let now = memoriaTimestamp()
                themes.append(Theme(id: "theme-\(UUID().uuidString)", name: trimmedName, description: description, createdAt: now, updatedAt: now))
                selectedSelfIndexThemeName = trimmedName
            }
            statusMessage = resolvedLanguage(settings.language) == .zhCN ? "已新增标签 \(trimmedName)。" : "Added tag \(trimmedName)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func updateSelfIndexTheme(_ theme: Theme, name: String, description: String?) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusMessage = resolvedLanguage(settings.language) == .zhCN ? "标签名称不能为空。" : "Tag name cannot be empty."
            return
        }

        let updatedTheme = Theme(
            id: theme.id,
            name: trimmedName,
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: theme.createdAt,
            updatedAt: memoriaTimestamp()
        )

        do {
            if let database {
                try database.updateTheme(updatedTheme)
                try reloadSnapshot()
            } else if let index = themes.firstIndex(where: { $0.id == theme.id }) {
                themes[index] = updatedTheme
            }
            if selectedSelfIndexThemeName == theme.name {
                selectedSelfIndexThemeName = trimmedName
            }
            statusMessage = resolvedLanguage(settings.language) == .zhCN ? "已更新标签 \(trimmedName)。" : "Updated tag \(trimmedName)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func deleteSelfIndexTheme(_ theme: Theme) {
        do {
            if let database {
                try database.deleteTheme(id: theme.id)
                try reloadSnapshot()
            } else {
                themes.removeAll { $0.id == theme.id }
                themeNamesByMemoryID = themeNamesByMemoryID.mapValues { names in
                    names.filter { $0 != theme.name }
                }
            }
            if selectedSelfIndexThemeName == theme.name {
                selectedSelfIndexThemeName = nil
            }
            statusMessage = resolvedLanguage(settings.language) == .zhCN ? "已删除标签 \(theme.name)。" : "Deleted tag \(theme.name)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func addSelfIndexMemory(
        title: String,
        summary: String,
        content: String,
        type: MemoryAtomType,
        sensitivity: MemorySensitivity,
        themeNames: [String]
    ) {
        let now = memoriaTimestamp()
        let memory = MemoryAtom(
            id: "memory-\(UUID().uuidString)",
            sourceEntryID: nil,
            type: type,
            title: normalizedTitle(title, fallback: resolvedLanguage(settings.language) == .zhCN ? "新的自我记录" : "New self note"),
            summary: normalizedTitle(summary, fallback: content.trimmingCharacters(in: .whitespacesAndNewlines)),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceQuote: nil,
            confidence: 1,
            sensitivity: sensitivity,
            isAIInferred: false,
            status: .confirmed,
            eventTime: nil,
            validUntil: nil,
            createdAt: now,
            updatedAt: now
        )
        saveSelfIndexMemory(memory, themeNames: themeNames, successMessage: resolvedLanguage(settings.language) == .zhCN ? "已新增广场内容。" : "Added plaza item.")
    }

    public func updateSelfIndexMemory(
        _ memory: MemoryAtom,
        title: String,
        summary: String,
        content: String,
        type: MemoryAtomType,
        sensitivity: MemorySensitivity,
        themeNames: [String]
    ) {
        let updatedMemory = MemoryAtom(
            id: memory.id,
            sourceEntryID: memory.sourceEntryID,
            type: type,
            title: normalizedTitle(title, fallback: memory.title),
            summary: normalizedTitle(summary, fallback: memory.summary),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceQuote: memory.sourceQuote,
            confidence: memory.confidence,
            sensitivity: sensitivity,
            isAIInferred: memory.isAIInferred,
            status: memory.status,
            eventTime: memory.eventTime,
            validUntil: memory.validUntil,
            createdAt: memory.createdAt,
            updatedAt: memoriaTimestamp()
        )
        saveSelfIndexMemory(updatedMemory, themeNames: themeNames, successMessage: resolvedLanguage(settings.language) == .zhCN ? "已更新广场内容。" : "Updated plaza item.")
    }

    public func deleteSelfIndexMemory(_ memory: MemoryAtom) {
        do {
            if let database {
                try database.deleteMemoryAtom(id: memory.id)
                try reloadSnapshot()
            } else {
                memoryAtoms.removeAll { $0.id == memory.id }
                themeNamesByMemoryID[memory.id] = nil
            }
            statusMessage = resolvedLanguage(settings.language) == .zhCN ? "已删除广场内容。" : "Deleted plaza item."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func nextAction(for person: FriendPerson) -> String {
        if pendingUpdates.contains(where: { $0.personName == person.displayName }) {
            return "Review pending update"
        }

        if reminders.contains(where: { $0.personName == person.displayName }) {
            return "Prepare for reminder"
        }

        if gifts.contains(where: { $0.personName == person.displayName }) {
            return "Check gift idea"
        }

        return "Capture one fresh signal"
    }

    public func count(for group: GroupFilter) -> Int {
        people.filter { $0.belongs(to: group) }.count
    }

    public func move(_ person: FriendPerson, to group: GroupFilter) {
        setGroups(person, groups: [group])
    }

    public func setGroups(_ person: FriendPerson, groups: [GroupFilter]) {
        do {
            let normalized = groups.reduce(into: [GroupFilter]()) { result, group in
                guard !result.contains(group) else { return }
                result.append(group)
            }
            try database?.updatePersonGroups(personID: person.id, groups: normalized.isEmpty ? [person.groupLabel] : normalized)
            try reloadSnapshot()
            selectedPersonID = person.id
            statusMessage = resolvedLanguage(settings.language) == .zhCN
                ? "\(person.displayName) 的分组已更新。"
                : "Updated \(person.displayName)'s groups."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func toggleGroup(_ group: GroupFilter, for person: FriendPerson) {
        var groups = person.groupLabels
        if groups.contains(group), groups.count > 1 {
            groups.removeAll { $0 == group }
        } else if !groups.contains(group) {
            groups.append(group)
        }
        setGroups(person, groups: groups)
    }

    public func addPerson(_ person: FriendPerson) {
        savePerson(person, successMessage: resolvedLanguage(settings.language) == .zhCN ? "已添加 \(person.displayName)。" : "Added \(person.displayName).")
    }

    public func savePerson(_ person: FriendPerson) {
        savePerson(person, successMessage: resolvedLanguage(settings.language) == .zhCN ? "\(person.displayName) 的档案已更新。" : "Updated \(person.displayName)'s profile.")
    }

    public func deletePerson(_ person: FriendPerson) {
        do {
            if let database {
                try database.deletePerson(person)
                try reloadSnapshot()
            } else {
                people.removeAll { $0.id == person.id }
                relationshipEdges.removeAll { $0.involves(personID: person.id) }
                reminders.removeAll { $0.personName == person.displayName }
                gifts.removeAll { $0.personName == person.displayName }
            }
            selectedPersonID = visiblePeople.first?.id ?? people.first?.id
            statusMessage = resolvedLanguage(settings.language) == .zhCN ? "已删除 \(person.displayName)。" : "Deleted \(person.displayName)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func relationshipEdges(for person: FriendPerson) -> [RelationshipEdge] {
        relationshipEdges.filter { $0.involves(personID: person.id) }
    }

    public func gifts(for person: FriendPerson) -> [GiftIdea] {
        gifts.filter { $0.personName == person.displayName }
    }

    public func addRelationship(for person: FriendPerson, targetName: String, label: String, relationKind: String) {
        let trimmedTarget = targetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTarget.isEmpty else {
            statusMessage = resolvedLanguage(settings.language) == .zhCN ? "先填写对方名字。" : "Enter the other person's name first."
            return
        }

        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKind = relationKind.trimmingCharacters(in: .whitespacesAndNewlines)
        let edge = RelationshipEdge(
            id: "edge-\(UUID().uuidString)",
            sourceID: person.id,
            sourceName: person.displayName,
            targetID: "external-\(UUID().uuidString)",
            targetName: trimmedTarget,
            label: trimmedLabel.isEmpty ? (resolvedLanguage(settings.language) == .zhCN ? "关系很好" : "Close") : trimmedLabel,
            strength: 0.72,
            relationKind: trimmedKind.isEmpty ? "friend" : trimmedKind,
            tags: trimmedLabel.isEmpty ? [] : [trimmedLabel],
            manualPrimaryTag: trimmedLabel.isEmpty ? nil : trimmedLabel
        )

        do {
            try database?.upsertRelationshipEdge(edge)
            try reloadSnapshot()
            selectedPersonID = person.id
            statusMessage = resolvedLanguage(settings.language) == .zhCN ? "已加入 \(person.displayName) 的关系网。" : "Added relationship edge."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func updateRelationshipEdge(
        _ edge: RelationshipEdge,
        targetName: String,
        label: String,
        relationKind: String,
        strength: Double,
        tags: [String],
        manualPrimaryTag: String?
    ) {
        let trimmedTarget = targetName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKind = relationKind.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTarget.isEmpty, !trimmedLabel.isEmpty else {
            statusMessage = resolvedLanguage(settings.language) == .zhCN ? "关系对象和关系说明不能为空。" : "Target and relationship label cannot be empty."
            return
        }

        let updatedEdge = RelationshipEdge(
            id: edge.id,
            sourceID: edge.sourceID,
            sourceName: edge.sourceName,
            targetID: edge.targetID,
            targetName: trimmedTarget,
            label: trimmedLabel,
            strength: strength,
            relationKind: trimmedKind.isEmpty ? edge.relationKind : trimmedKind,
            sourceMemoryID: edge.sourceMemoryID,
            confidence: edge.confidence,
            isAIInferred: edge.isAIInferred,
            tags: tags,
            aiPrimaryTag: edge.aiPrimaryTag,
            manualPrimaryTag: manualPrimaryTag
        )

        do {
            if let database {
                try database.upsertRelationshipEdge(updatedEdge)
                try reloadSnapshot()
            } else if let index = relationshipEdges.firstIndex(where: { $0.id == edge.id }) {
                relationshipEdges[index] = updatedEdge
            }
            statusMessage = resolvedLanguage(settings.language) == .zhCN ? "已更新关系。" : "Updated relationship edge."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func deleteRelationshipEdge(_ edge: RelationshipEdge) {
        do {
            if let database {
                try database.deleteRelationshipEdge(id: edge.id)
                try reloadSnapshot()
            } else {
                relationshipEdges.removeAll { $0.id == edge.id }
            }
            statusMessage = resolvedLanguage(settings.language) == .zhCN ? "已删除关系。" : "Deleted relationship edge."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func generateGiftRecommendations(for person: FriendPerson, prompt: String) {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            statusMessage = resolvedLanguage(settings.language) == .zhCN ? "先写一句礼物需求。" : "Enter a gift request first."
            return
        }

        do {
            let ideas = giftWorkflow.recommendations(for: person, prompt: trimmedPrompt)
            try database?.upsertGiftIdeas(ideas)
            try reloadSnapshot()
            selectedPersonID = person.id
            statusMessage = resolvedLanguage(settings.language) == .zhCN ? "已生成 \(ideas.count) 个礼物推荐方向。" : "Generated \(ideas.count) gift directions."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func reminderNotificationPlans() -> [ReminderNotificationPlan] {
        notificationPlanner.plans(for: reminders)
    }

    public func generateAgendaAssistantPlan() {
        agendaAssistantPlan = agendaWorkflow.plan(
            prompt: agendaAssistantPrompt,
            reminders: reminders,
            pendingUpdates: pendingUpdates,
            gifts: gifts,
            language: settings.language
        )
        statusMessage = agendaAssistantPlan.summary
    }

    public func autoOrganizeMemories() {
        pruneSelectedSelfIndexThemeIfNeeded()
        memoryOrganizationSuggestions = memoryOrganizer.suggestions(
            for: memoryAtoms,
            language: settings.language
        )
        statusMessage = resolvedLanguage(settings.language) == .zhCN
            ? "已自动整理 \(memoryOrganizationSuggestions.count) 类记忆；你仍可以编辑标签、档案和关系边。"
            : "Auto-organized \(memoryOrganizationSuggestions.count) memory categories. You can still edit tags, dossiers, and relationship edges."
    }
}

private extension DashboardStore {
    static func loadThemeNamesByMemoryID(
        for memories: [MemoryAtom],
        database: LocalSQLiteStore
    ) -> [String: [String]] {
        let repository = MemoryRepository(database: database)
        return memories.reduce(into: [String: [String]]()) { result, memory in
            result[memory.id] = (try? repository.linkedThemeNames(memoryID: memory.id)) ?? []
        }
    }

    func makeRuntimeDeveloperLogEntries() -> [DeveloperLogEntry] {
        let timestamp = memoriaTimestamp()
        var entries = [
            DeveloperLogEntry(
                id: "app-state",
                title: "App state",
                detail: [
                    "section=\(currentSection.rawValue)",
                    "capture_mode=\(selectedCaptureMode.rawValue)",
                    "review_category=\(selectedReviewCategory?.rawValue ?? "overview")",
                    "capture_phase=\(captureProgress.phase.rawValue)"
                ].joined(separator: " · "),
                createdAt: timestamp
            ),
            DeveloperLogEntry(
                id: "data-counts",
                title: "Loaded data counts",
                detail: [
                    "people=\(people.count)",
                    "pending_updates=\(pendingUpdates.count)",
                    "memory_atoms=\(memoryAtoms.count)",
                    "themes=\(themes.count)",
                    "reminders=\(reminders.count)",
                    "relationship_edges=\(relationshipEdges.count)"
                ].joined(separator: " · "),
                createdAt: timestamp
            )
        ]

        if !statusMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entries.append(
                DeveloperLogEntry(
                    id: "status-message",
                    title: "Status message",
                    detail: developerLogRedactedText(statusMessage),
                    createdAt: timestamp,
                    level: statusMessage.localizedCaseInsensitiveContains("error") ? .warning : .info
                )
            )
        }

        return entries
    }

    func filterBySelectedSelfIndexTheme(_ memories: [MemoryAtom]) -> [MemoryAtom] {
        guard let selectedSelfIndexThemeName,
              !selectedSelfIndexThemeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return memories
        }
        return memories.filter { memory in
            (themeNamesByMemoryID[memory.id] ?? []).contains(selectedSelfIndexThemeName)
        }
    }

    func pruneSelectedSelfIndexThemeIfNeeded() {
        guard let selectedSelfIndexThemeName else { return }
        let trimmedName = selectedSelfIndexThemeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            self.selectedSelfIndexThemeName = nil
            return
        }
        if !themes.contains(where: { $0.name == trimmedName }) {
            self.selectedSelfIndexThemeName = nil
        }
    }

    func saveSelfIndexMemory(_ memory: MemoryAtom, themeNames: [String], successMessage: String) {
        do {
            let normalizedThemes = normalizedNames(themeNames)
            if let database {
                try database.upsertMemoryAtom(memory)
                try database.replaceThemeLinks(memoryID: memory.id, themeNames: normalizedThemes)
                try reloadSnapshot()
            } else {
                if let index = memoryAtoms.firstIndex(where: { $0.id == memory.id }) {
                    memoryAtoms[index] = memory
                } else {
                    memoryAtoms.append(memory)
                }
                themeNamesByMemoryID[memory.id] = normalizedThemes
            }
            statusMessage = successMessage
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func normalizedTitle(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        let fallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? (resolvedLanguage(settings.language) == .zhCN ? "未命名记录" : "Untitled note") : fallback
    }

    func normalizedNames(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { result, value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !result.contains(trimmed) else { return }
            result.append(trimmed)
        }
    }
}

private extension DashboardStore {
    func savePerson(_ person: FriendPerson, successMessage: String) {
        do {
            if let database {
                try database.upsertPerson(person)
                try reloadSnapshot()
            } else if let index = people.firstIndex(where: { $0.id == person.id }) {
                people[index] = person
            } else {
                people.append(person)
            }
            selectedPersonID = person.id
            statusMessage = successMessage
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

private extension DashboardStore {
    func makeTransferBundle() throws -> MemoriaTransferBundle {
        let memoryRepository = database.map(MemoryRepository.init(database:))

        let memoryPersonLinks = memoryAtoms.flatMap { memory in
            ((try? memoryRepository?.linkedPersonIDs(memoryID: memory.id)) ?? []).map { personID in
                TransferMemoryPersonLink(memoryID: memory.id, personID: personID, relationType: "mentioned")
            }
        }

        let memoryThemeLinks = memoryAtoms.flatMap { memory in
            ((try? memoryRepository?.linkedThemeNames(memoryID: memory.id)) ?? []).map { themeName in
                TransferMemoryThemeLink(memoryID: memory.id, themeName: themeName)
            }
        }

        return MemoriaTransferBundle(
            appMetadata: [
                "app": "Memorial",
                "privacy": "Complete local data export; DeepSeek API key and Keychain values are excluded."
            ],
            people: people.map(TransferPerson.init(person:)),
            memoryAtoms: memoryAtoms.map(TransferMemoryAtom.init(memory:)),
            themes: themes.map(TransferTheme.init(theme:)),
            memoryPersonLinks: memoryPersonLinks,
            memoryThemeLinks: memoryThemeLinks,
            relationshipEdges: relationshipEdges.map(TransferRelationshipEdge.init(edge:)),
            relationshipTagPriorities: relationshipTagPriorities.map(TransferRelationshipTagPriority.init(priority:)),
            reminders: reminders.map(TransferReminder.init(reminder:)),
            gifts: gifts.map(TransferGift.init(gift:)),
            files: files.map(TransferFile.init(file:))
        )
    }

    func makeImportPreview(
        filename: String,
        bundle: MemoriaTransferBundle,
        profilePatchProposals: [PersonProfilePatchProposal] = []
    ) -> TransferImportPreview {
        let existingPeopleByID = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0.displayName) })
        let existingPeopleNameToID = Dictionary(uniqueKeysWithValues: people.map { ($0.displayName.lowercased(), $0.id) })
        let existingMemoryIDs = Set(memoryAtoms.map(\.id))
        let existingThemeNames = Set((try? database.map { try ThemeRepository(database: $0).list().map(\.name) }) ?? [])
        let existingEdgeIDs = Set(relationshipEdges.map(\.id))

        let duplicateNames = bundle.people.compactMap { person -> String? in
            let normalizedName = person.displayName.lowercased()
            guard let existingID = existingPeopleNameToID[normalizedName], existingID != person.id else {
                return nil
            }
            return person.displayName
        }

        return TransferImportPreview(
            filename: filename,
            bundle: bundle,
            profilePatchProposals: profilePatchProposals,
            peopleToCreate: bundle.people.filter { existingPeopleByID[$0.id] == nil }.count,
            peopleToUpdate: bundle.people.filter { existingPeopleByID[$0.id] != nil }.count,
            potentialDuplicateNames: duplicateNames,
            memoriesToCreate: bundle.memoryAtoms.filter { !existingMemoryIDs.contains($0.id) }.count,
            memoriesToUpdate: bundle.memoryAtoms.filter { existingMemoryIDs.contains($0.id) }.count,
            themesToCreate: bundle.themes.filter { !existingThemeNames.contains($0.name) }.count,
            relationshipEdgesToCreate: bundle.relationshipEdges.filter { !existingEdgeIDs.contains($0.id) }.count,
            relationshipEdgesToUpdate: bundle.relationshipEdges.filter { existingEdgeIDs.contains($0.id) }.count
        )
    }
}

private func destinationSection(for category: ReviewCategory) -> AppSection {
    switch category {
    case .selfSearch:
        return .selfSearch
    case .friendDossier:
        return .friendDossier
    case .schedule:
        return .schedule
    }
}

private extension ExtractMemoryResponse {
    func constrained(to mode: WorkspaceMode, rawEntry: RawEntry) -> ExtractMemoryResponse {
        switch mode {
        case .schedule:
            let proposals = memoryProposals.isEmpty
                ? [MemoryAtomProposal.scheduleFallback(rawEntry: rawEntry)]
                : memoryProposals.map { $0.asScheduleProposal(rawEntry: rawEntry) }
            return ExtractMemoryResponse(
                entrySummary: entrySummary,
                memoryProposals: proposals,
                personFactProposals: [],
                reminderProposals: reminderProposals,
                giftSignalProposals: giftSignalProposals,
                conflicts: conflicts,
                followUpQuestions: followUpQuestions
            )

        case .friendDossier:
            let proposals = memoryProposals.filter { proposal in
                !proposal.isDuplicatedByProfilePatch(personFactProposals)
            }
            return ExtractMemoryResponse(
                entrySummary: entrySummary,
                memoryProposals: proposals,
                personFactProposals: personFactProposals,
                reminderProposals: reminderProposals,
                giftSignalProposals: giftSignalProposals,
                conflicts: conflicts,
                followUpQuestions: followUpQuestions
            )

        case .selfSearch:
            return self
        }
    }
}

private extension MemoryAtomProposal {
    static func scheduleFallback(rawEntry: RawEntry) -> MemoryAtomProposal {
        MemoryAtomProposal(
            proposalType: .memoryAtom,
            memoryType: .reminderSource,
            title: "行程安排：\(compactCaptureText(rawEntry.rawText))",
            summary: rawEntry.rawText,
            content: rawEntry.rawText,
            sourceQuote: rawEntry.rawText,
            confidence: 0.82,
            sensitivity: .normal,
            isAIInferred: false,
            relatedPeople: [],
            themes: [ThemeProposal(name: "提醒事项", confidence: 0.86)],
            followUpQuestions: ["要不要把这条内容加入行程安排？"],
            suggestedActions: []
        )
    }

    func asScheduleProposal(rawEntry: RawEntry) -> MemoryAtomProposal {
        if reviewCategory == .schedule {
            return self
        }
        return MemoryAtomProposal(
            proposalType: proposalType,
            memoryType: .reminderSource,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "行程安排：\(compactCaptureText(rawEntry.rawText))" : title,
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? rawEntry.rawText : summary,
            content: content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? rawEntry.rawText : content,
            sourceQuote: sourceQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? rawEntry.rawText : sourceQuote,
            confidence: confidence,
            sensitivity: sensitivity,
            isAIInferred: isAIInferred,
            relatedPeople: relatedPeople,
            themes: themes.isEmpty ? [ThemeProposal(name: "提醒事项", confidence: 0.86)] : themes,
            relationshipEdgeProposals: nil,
            followUpQuestions: followUpQuestions,
            suggestedActions: suggestedActions
        )
    }

    var reviewCategory: ReviewCategory {
        ReviewCategory.inferred(from: self)
    }

    func isDuplicatedByProfilePatch(_ patches: [PersonProfilePatchProposal]) -> Bool {
        guard memoryType == .personFact, !patches.isEmpty else { return false }
        let normalizedSource = sourceQuote.normalizedCaptureDedupeText
        return patches.contains { patch in
            guard patch.sourceQuote.normalizedCaptureDedupeText == normalizedSource else { return false }
            let sameTarget = relatedPeople.isEmpty || relatedPeople.contains { person in
                person.matchedPersonID == patch.targetPersonID || person.displayName == patch.targetDisplayName
            }
            guard sameTarget else { return false }
            let proposedValue = patch.proposedValue.normalizedCaptureDedupeText
            return proposedValue.isEmpty ||
                summary.normalizedCaptureDedupeText.contains(proposedValue) ||
                content.normalizedCaptureDedupeText.contains(proposedValue) ||
                proposedValue.contains(summary.normalizedCaptureDedupeText)
        }
    }
}

private extension String {
    var normalizedCaptureDedupeText: String {
        lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
}

private func compactCaptureText(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    guard trimmed.count > 32 else { return trimmed }
    return String(trimmed.prefix(29)) + "..."
}

private func developerLogRedactedText(_ text: String) -> String {
    var redacted = text.replacingOccurrences(of: "api_key", with: "credential", options: .caseInsensitive)
    redacted = redacted.replacingOccurrences(of: "apikey", with: "credential", options: .caseInsensitive)
    redacted = redacted.replacingOccurrences(of: "token", with: "credential", options: .caseInsensitive)
    return redacted
}

private func sortedReminders(_ reminders: [ReminderItem]) -> [ReminderItem] {
    reminders.sorted { lhs, rhs in
        switch (lhs.dueDateValue, rhs.dueDateValue) {
        case let (left?, right?):
            if left != right { return left < right }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            break
        }

        if lhs.timeLabel != rhs.timeLabel {
            return lhs.timeLabel < rhs.timeLabel
        }

        return lhs.title < rhs.title
    }
}

private func countBy(_ values: [String]) -> [CountItem] {
    let counts = values.reduce(into: [String: Int]()) { partialResult, value in
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        partialResult[key.isEmpty ? "Unknown" : key, default: 0] += 1
    }

    return counts
        .map { CountItem(label: $0.key, count: $0.value) }
        .sorted { $0.label < $1.label }
}

private func reminderWindow(_ label: String) -> String {
    let normalized = label.lowercased()

    if normalized.contains("today") || normalized.contains("今天") {
        return "Today"
    }

    if normalized.contains("tomorrow") || normalized.contains("明天") {
        return "Tomorrow"
    }

    if normalized.contains("day") || normalized.contains("week") || normalized.contains("周") || normalized.contains("星期") {
        return "This week"
    }

    return "Scheduled"
}

private extension FriendPerson {
    func matches(query: String) -> Bool {
        [
            displayName,
            nickname,
            englishName,
            relationLabel,
            location,
            hometown,
            languages,
            contactInfo,
            birthday,
            favoriteFoods,
            dietaryRestrictions,
            dislikedThings,
            zodiacSign,
            mbti,
            interests,
            books,
            sports,
            profileTags,
            lastSignal,
            school,
            major,
            company,
            roleTitle,
            researchExperience,
            internshipExperience,
            familyNotes,
            partnerName,
            closenessSignals
        ].contains { $0.lowercased().contains(query) } ||
            categoryNotes.values.contains { $0.lowercased().contains(query) }
    }
}

private extension ReminderItem {
    func matches(query: String) -> Bool {
        [title, personName, dueLabel, dueDate ?? "", timeLabel, context, location]
            .contains { $0.lowercased().contains(query) }
    }
}

private extension GiftIdea {
    func matches(query: String) -> Bool {
        [title, personName, priceBand, rationale, risk, confirmationQuestion, riskLevel, practicality, emotionalValue]
            .contains { $0.lowercased().contains(query) }
    }
}
