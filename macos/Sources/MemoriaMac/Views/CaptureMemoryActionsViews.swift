import SwiftUI
import MemoriaCore

struct CaptureView: View {
    @ObservedObject var store: DashboardStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isChinese ? "今天想记点什么？" : "What do you want to remember today?")
                        .font(.largeTitle.weight(.semibold))

                    Text(isChinese ? "先选模式，再写原文。AI 会把建议送到对应整理台；你可以编辑后再批准入库。" : "Choose a mode first, then write the source note. AI sends proposals to that review desk; you can edit before approval.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                modePicker

                TextField(isChinese ? "随便写，Memoria 会先保存原文，再生成待确认建议..." : "Write freely. Memoria saves the raw entry first, then creates reviewable suggestions...", text: $store.quickCaptureText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .lineLimit(8...14)
                    .padding(16)
                    .background(.quinary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack {
                    Spacer()

                    Button {
                        store.quickCapture()
                    } label: {
                        Label(
                            store.isCapturing ? (isChinese ? "整理中..." : "Organizing...") : (isChinese ? "送到整理台" : "Send to Review"),
                            systemImage: store.isCapturing ? "hourglass" : "sparkles"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.quickCaptureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isCapturing)
                    .keyboardShortcut(.return, modifiers: [.command])
                }

                if store.captureProgress.phase != .idle {
                    CaptureProgressStatusView(progress: store.captureProgress, language: store.settings.language)
                }

                Text(isChinese ? "AI 不直接写最终档案；当前模式会打开对应整理台分区，批准一次即入库。" : "AI does not write final records directly. The selected mode opens its review desk category, and one approval saves it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !store.statusMessage.isEmpty {
                    Text(store.statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quinary)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .leading)
        }
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(isChinese ? "记录模式" : "Capture Mode", systemImage: "rectangle.grid.1x2")
                .font(.headline)

            Picker(isChinese ? "记录模式" : "Capture Mode", selection: $store.selectedCaptureMode) {
                ForEach(WorkspaceMode.allCases) { mode in
                    Label(mode.title(for: store.settings.language), systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(store.selectedCaptureMode.subtitle(for: store.settings.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .memoriaCard()
    }

    private var isChinese: Bool {
        resolvedLanguage(store.settings.language) == .zhCN
    }
}

private struct CaptureProgressStatusView: View {
    let progress: CaptureProgressState
    let language: LanguagePreference

    private var stages: [CaptureProgressPhase] {
        [.savingSource, .thinking, .organizing, .delivered]
    }

    private var isChinese: Bool {
        resolvedLanguage(language) == .zhCN
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(progress.phase.title(for: language), systemImage: progress.phase == .failed ? "exclamationmark.triangle" : "sparkles")
                    .font(.callout.weight(.semibold))

                Spacer()

                Text("\(Int(progress.progress * 100))%")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress.progress)
                .progressViewStyle(.linear)

            HStack(spacing: 8) {
                ForEach(stages, id: \.rawValue) { stage in
                    Text(stage.title(for: language))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(stage.defaultProgress <= progress.progress ? Color.memoriaSage : .secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Text(progress.detail(for: language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(progress.phase == .failed ? Color.memoriaGold.opacity(0.1) : Color.memoriaSage.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(progress.phase == .failed ? Color.memoriaGold.opacity(0.24) : Color.memoriaSage.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(progress.phase.title(for: language))
        .accessibilityValue(progress.detail(for: language))
    }
}

struct MemoryPalaceView: View {
    @ObservedObject var store: DashboardStore
    @State private var editingThemeDraft: SelfIndexThemeDraft?
    @State private var editingMemoryDraft: SelfIndexMemoryDraft?
    @State private var pendingMemoryDeletion: MemoryAtom?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isChinese ? "自我检索" : "Self Search")
                        .font(.largeTitle.weight(.semibold))

                    Text(isChinese ? "把确认后的感悟、选择、压力和成长线索按核心标签检索；AI 只提出整理建议。" : "Confirmed reflections, choices, stress, and growth signals are searched through core tags. AI only suggests changes.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                memoryOrganizerPanel
                selfIndexTagShelf
                memoryTypeFilter
                timelineHeader

                if store.selfIndexTimelineMemories.isEmpty {
                    EmptyState(
                        systemImage: "archivebox",
                        title: isChinese ? "这个筛选下还没有帖子" : "No posts in this filter",
                        detail: isChinese ? "从记录页选择自我检索模式，确认后会出现在自我广场。" : "Capture in Self Search mode, approve it, and it will appear in the self plaza."
                    )
                    .frame(minHeight: 420)
                } else {
                    ForEach(store.visibleMemoryAtoms) { memory in
                        MemoryCard(
                            memory: memory,
                            themeNames: store.themeNames(for: memory),
                            language: store.settings.language,
                            onEdit: {
                                editingMemoryDraft = SelfIndexMemoryDraft(
                                    memory: memory,
                                    themeNames: store.themeNames(for: memory)
                                )
                            },
                            onDelete: {
                                pendingMemoryDeletion = memory
                            }
                        )
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .leading)
        }
        .sheet(item: $editingThemeDraft) { draft in
            SelfIndexThemeEditorSheet(
                draft: draft,
                language: store.settings.language,
                onCancel: {
                    editingThemeDraft = nil
                },
                onSave: { draft in
                    if let theme = draft.theme {
                        store.updateSelfIndexTheme(theme, name: draft.name, description: draft.description)
                    } else {
                        store.addSelfIndexTheme(name: draft.name, description: draft.description)
                    }
                    editingThemeDraft = nil
                }
            )
        }
        .sheet(item: $editingMemoryDraft) { draft in
            SelfIndexMemoryEditorSheet(
                draft: draft,
                availableThemes: store.themes,
                language: store.settings.language,
                onCancel: {
                    editingMemoryDraft = nil
                },
                onSave: { draft in
                    if let memory = draft.memory {
                        store.updateSelfIndexMemory(
                            memory,
                            title: draft.title,
                            summary: draft.summary,
                            content: draft.content,
                            type: draft.type,
                            sensitivity: draft.sensitivity,
                            themeNames: draft.selectedThemeNames
                        )
                    } else {
                        store.addSelfIndexMemory(
                            title: draft.title,
                            summary: draft.summary,
                            content: draft.content,
                            type: draft.type,
                            sensitivity: draft.sensitivity,
                            themeNames: draft.selectedThemeNames
                        )
                    }
                    editingMemoryDraft = nil
                }
            )
        }
        .confirmationDialog(
            isChinese ? "删除这条广场内容？" : "Delete this plaza item?",
            isPresented: Binding(
                get: { pendingMemoryDeletion != nil },
                set: { if !$0 { pendingMemoryDeletion = nil } }
            )
        ) {
            Button(isChinese ? "删除" : "Delete", role: .destructive) {
                if let memory = pendingMemoryDeletion {
                    store.deleteSelfIndexMemory(memory)
                }
                pendingMemoryDeletion = nil
            }
            Button(isChinese ? "取消" : "Cancel", role: .cancel) {
                pendingMemoryDeletion = nil
            }
        }
    }

    private var isChinese: Bool {
        resolvedLanguage(store.settings.language) == .zhCN
    }

    private var memoryOrganizerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(isChinese ? "自动标签整理" : "Automatic Tag Organizer", systemImage: "sparkles")
                        .font(.headline)
                    Text(isChinese ? "已确认记忆会按类型和标签自动归位；这里不再有额外审批按钮。需要调整时，直接编辑记忆、标签或朋友档案。" : "Confirmed memories are organized by type and tag automatically. There is no extra approval button here; edit memories, tags, or dossiers when needed.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    store.autoOrganizeMemories()
                } label: {
                    Label(isChinese ? "刷新整理" : "Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(store.memoryAtoms.isEmpty)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], alignment: .leading, spacing: 12) {
                ForEach(organizationSummaries) { suggestion in
                    MemoryOrganizationSuggestionCard(suggestion: suggestion, language: store.settings.language)
                }
            }
        }
        .memoriaCard()
    }

    private var organizationSummaries: [MemoryOrganizationSuggestion] {
        if store.memoryOrganizationSuggestions.isEmpty {
            return MemoryAutoOrganizer().suggestions(
                for: store.memoryAtoms,
                language: store.settings.language
            )
        }
        return store.memoryOrganizationSuggestions
    }

    private var selfIndexTagShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(isChinese ? "核心标签" : "Core Tags", systemImage: "tag")
                    .font(.headline)
                Spacer()
                Button {
                    editingThemeDraft = SelfIndexThemeDraft()
                } label: {
                    Label(isChinese ? "新增标签" : "Add Tag", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .help(isChinese ? "新增标签" : "Add tag")
                Text(isChinese ? "\(store.selfIndexThemeSummaries.count) 个" : "\(store.selfIndexThemeSummaries.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], alignment: .leading, spacing: 8) {
                SelfIndexTagButton(
                    title: isChinese ? "全部" : "All",
                    detail: isChinese ? "自我广场" : "Self plaza",
                    count: store.memoryAtoms.filter(\.isSelfSearchDefault).count,
                    isSelected: store.selectedSelfIndexThemeName == nil
                ) {
                    store.selectAllSelfIndexThemes()
                }

                ForEach(store.selfIndexThemeSummaries) { summary in
                    SelfIndexTagButton(
                        title: summary.theme.name,
                        detail: summary.theme.description,
                        count: summary.memoryCount,
                        isSelected: store.selectedSelfIndexThemeName == summary.theme.name
                    ) {
                        store.selectSelfIndexTheme(named: summary.theme.name)
                    } onEdit: {
                        editingThemeDraft = SelfIndexThemeDraft(theme: summary.theme)
                    } onDelete: {
                        store.deleteSelfIndexTheme(summary.theme)
                    }
                }
            }
        }
        .memoriaCard()
    }

    private var timelineHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(isChinese ? "自我广场" : "Self Plaza", systemImage: "square.stack.3d.up")
                .font(.headline)

            if let selectedTag = store.selectedSelfIndexThemeName {
                Text(selectedTag)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.memoriaSage)
            }

            Spacer()

            Button {
                editingMemoryDraft = SelfIndexMemoryDraft(
                    defaultThemeName: store.selectedSelfIndexThemeName
                )
            } label: {
                Label(isChinese ? "新增内容" : "Add Post", systemImage: "plus")
            }
            .buttonStyle(.bordered)

            Text("\(store.selfIndexTimelineMemories.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var memoryTypeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    store.selectedMemoryType = nil
                } label: {
                    Label(isChinese ? "全部" : "All", systemImage: "tray.full")
                }
                .buttonStyle(.bordered)
                .tint(store.selectedMemoryType == nil ? Color.memoriaSage : nil)

                ForEach(MemoryAtomType.allCases, id: \.rawValue) { type in
                    Button {
                        store.selectedMemoryType = type
                    } label: {
                        Text("\(type.displayName(for: store.settings.language)) \(store.memoryAtoms.filter { $0.type == type }.count)")
                    }
                    .buttonStyle(.bordered)
                    .tint(store.selectedMemoryType == type ? Color.memoriaSage : nil)
                }
            }
        }
    }
}

private struct MemoryCard: View {
    let memory: MemoryAtom
    let themeNames: [String]
    let language: LanguagePreference
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(memory.type.displayName(for: language))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(Capsule())

                Text(memory.sensitivity.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(memory.sensitivity == .normal ? .secondary : Color.memoriaGold)

                Spacer()

                Text(memory.createdAt)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label(isChinese ? "编辑" : "Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label(isChinese ? "删除" : "Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.medium)
                }
                .menuStyle(.button)
                .buttonStyle(.borderless)
                .help(isChinese ? "编辑或删除" : "Edit or delete")
            }

            Text(memory.title)
                .font(.headline)

            Text(memory.summary)
                .fixedSize(horizontal: false, vertical: true)

            if !themeNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(themeNames, id: \.self) { name in
                            Text(name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.memoriaSage)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.memoriaSage.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if let quote = memory.sourceQuote {
                SourceQuoteBlock(text: quote)
            }
        }
        .memoriaCard()
    }

    private var isChinese: Bool {
        resolvedLanguage(language) == .zhCN
    }
}

private struct SelfIndexTagButton: View {
    let title: String
    let detail: String?
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    init(
        title: String,
        detail: String?,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.title = title
        self.detail = detail
        self.count = count
        self.isSelected = isSelected
        self.action = action
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)

                        Spacer()

                        Text("\(count)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(isSelected ? Color.memoriaInk : .secondary)
                    }

                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if onEdit != nil || onDelete != nil {
                Menu {
                    if let onEdit {
                        Button {
                            onEdit()
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                    }
                    if let onDelete {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.button)
                .buttonStyle(.borderless)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(isSelected ? Color.memoriaSage.opacity(0.16) : Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.memoriaSage.opacity(0.42) : Color.clear, lineWidth: 1)
        }
    }
}

private struct SelfIndexThemeDraft: Identifiable {
    let id: String
    let theme: Theme?
    var name: String
    var description: String

    init(theme: Theme? = nil) {
        id = theme?.id ?? "new-theme-\(UUID().uuidString)"
        self.theme = theme
        name = theme?.name ?? ""
        description = theme?.description ?? ""
    }
}

private struct SelfIndexMemoryDraft: Identifiable {
    let id: String
    let memory: MemoryAtom?
    var title: String
    var summary: String
    var content: String
    var type: MemoryAtomType
    var sensitivity: MemorySensitivity
    var selectedThemeNames: [String]

    init(memory: MemoryAtom? = nil, themeNames: [String] = [], defaultThemeName: String? = nil) {
        id = memory?.id ?? "new-memory-\(UUID().uuidString)"
        self.memory = memory
        title = memory?.title ?? ""
        summary = memory?.summary ?? ""
        content = memory?.content ?? ""
        type = memory?.type ?? .personalReflection
        sensitivity = memory?.sensitivity ?? .normal
        selectedThemeNames = themeNames
        if let defaultThemeName,
           !defaultThemeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !selectedThemeNames.contains(defaultThemeName) {
            selectedThemeNames.append(defaultThemeName)
        }
    }
}

private struct SelfIndexThemeEditorSheet: View {
    @State private var draft: SelfIndexThemeDraft
    let language: LanguagePreference
    let onCancel: () -> Void
    let onSave: (SelfIndexThemeDraft) -> Void

    init(
        draft: SelfIndexThemeDraft,
        language: LanguagePreference,
        onCancel: @escaping () -> Void,
        onSave: @escaping (SelfIndexThemeDraft) -> Void
    ) {
        _draft = State(initialValue: draft)
        self.language = language
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.theme == nil ? (isChinese ? "新增标签" : "Add Tag") : (isChinese ? "编辑标签" : "Edit Tag"))
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text(isChinese ? "名称" : "Name")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField(isChinese ? "例如：学业成长" : "Example: Academic growth", text: $draft.name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(isChinese ? "说明" : "Description")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField(isChinese ? "这个标签用来收纳什么内容" : "What this tag collects", text: $draft.description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...5)
            }

            HStack {
                Spacer()
                Button(isChinese ? "取消" : "Cancel", action: onCancel)
                Button(draft.theme == nil ? (isChinese ? "新增" : "Add") : (isChinese ? "保存" : "Save")) {
                    onSave(draft)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 460)
    }

    private var isChinese: Bool {
        resolvedLanguage(language) == .zhCN
    }
}

private struct SelfIndexMemoryEditorSheet: View {
    @State private var draft: SelfIndexMemoryDraft
    let availableThemes: [Theme]
    let language: LanguagePreference
    let onCancel: () -> Void
    let onSave: (SelfIndexMemoryDraft) -> Void

    init(
        draft: SelfIndexMemoryDraft,
        availableThemes: [Theme],
        language: LanguagePreference,
        onCancel: @escaping () -> Void,
        onSave: @escaping (SelfIndexMemoryDraft) -> Void
    ) {
        _draft = State(initialValue: draft)
        self.availableThemes = availableThemes
        self.language = language
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(draft.memory == nil ? (isChinese ? "新增广场内容" : "Add Plaza Post") : (isChinese ? "编辑广场内容" : "Edit Plaza Post"))
                    .font(.title2.weight(.semibold))

                VStack(alignment: .leading, spacing: 8) {
                    Text(isChinese ? "标题" : "Title")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField(isChinese ? "给这条内容一个标题" : "Give this post a title", text: $draft.title)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(isChinese ? "摘要" : "Summary")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField(isChinese ? "一句话概括" : "One-line summary", text: $draft.summary, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(isChinese ? "正文" : "Content")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField(isChinese ? "具体内容" : "Full content", text: $draft.content, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(6...10)
                }

                HStack(spacing: 12) {
                    Picker(isChinese ? "类型" : "Type", selection: $draft.type) {
                        ForEach(MemoryAtomType.allCases, id: \.rawValue) { type in
                            Text(type.displayName(for: language)).tag(type)
                        }
                    }

                    Picker(isChinese ? "敏感级别" : "Sensitivity", selection: $draft.sensitivity) {
                        ForEach(MemorySensitivity.allCases, id: \.rawValue) { sensitivity in
                            Text(sensitivity.rawValue).tag(sensitivity)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(isChinese ? "标签" : "Tags")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if availableThemes.isEmpty {
                        Text(isChinese ? "还没有标签。先在核心标签区新增一个标签。" : "No tags yet. Add a tag from the core tag shelf first.")
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(availableThemes) { theme in
                                Toggle(
                                    theme.name,
                                    isOn: Binding(
                                        get: { draft.selectedThemeNames.contains(theme.name) },
                                        set: { isOn in
                                            if isOn {
                                                if !draft.selectedThemeNames.contains(theme.name) {
                                                    draft.selectedThemeNames.append(theme.name)
                                                }
                                            } else {
                                                draft.selectedThemeNames.removeAll { $0 == theme.name }
                                            }
                                        }
                                    )
                                )
                                .toggleStyle(.checkbox)
                            }
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button(isChinese ? "取消" : "Cancel", action: onCancel)
                    Button(draft.memory == nil ? (isChinese ? "新增" : "Add") : (isChinese ? "保存" : "Save")) {
                        onSave(draft)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isEmptyPost)
                }
            }
            .padding(22)
        }
        .frame(width: 560, height: 620)
    }

    private var isEmptyPost: Bool {
        [draft.title, draft.summary, draft.content].allSatisfy {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var isChinese: Bool {
        resolvedLanguage(language) == .zhCN
    }
}

private enum ScheduleDisplayMode: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    func title(isChinese: Bool) -> String {
        switch self {
        case .week:
            return isChinese ? "周视图" : "Week"
        case .month:
            return isChinese ? "月视图" : "Month"
        }
    }
}

struct ActionsView: View {
    @ObservedObject var store: DashboardStore

    var body: some View {
        ScheduleView(store: store)
    }
}

struct ScheduleView: View {
    @ObservedObject var store: DashboardStore
    @State private var displayMode: ScheduleDisplayMode = .week
    @State private var referenceDate = Date()

    private var calendar: Calendar { .current }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                modeBar

                if displayMode == .week {
                    weekSection
                } else {
                    monthSection
                }

                unscheduledSection
                scheduleReviewSection
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isChinese ? "行程安排" : "Schedule")
                        .font(.largeTitle.weight(.semibold))

                    Text(isChinese ? "按真实日期查看未来提醒、生日、考试、约见和准备事项；没有日期的旧提醒保留在未定日期里。" : "Review reminders, birthdays, exams, meetings, and preparation by real dates. Older text-only reminders stay under unscheduled.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
                ScheduleMetricCard(label: isChinese ? "今天" : "Today", value: store.todayReminders.count, symbolName: "bell.badge")
                ScheduleMetricCard(label: isChinese ? "有日期" : "Dated", value: store.datedReminders.count, symbolName: "calendar")
                ScheduleMetricCard(label: isChinese ? "未定日期" : "Unscheduled", value: store.unscheduledReminders.count, symbolName: "text.badge.clock")
                ScheduleMetricCard(label: isChinese ? "待确认" : "Review", value: schedulePendingUpdates.count, symbolName: "tray")
            }
        }
    }

    private var modeBar: some View {
        HStack(spacing: 10) {
            Picker(isChinese ? "视图" : "View", selection: $displayMode) {
                ForEach(ScheduleDisplayMode.allCases) { mode in
                    Text(mode.title(isChinese: isChinese)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            Spacer()

            Button {
                referenceDate = calendar.date(byAdding: displayMode == .week ? .weekOfYear : .month, value: -1, to: referenceDate) ?? referenceDate
            } label: {
                Label(isChinese ? "上一段" : "Previous", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)

            Text(periodTitle)
                .font(.headline)
                .frame(minWidth: 150)

            Button {
                referenceDate = calendar.date(byAdding: displayMode == .week ? .weekOfYear : .month, value: 1, to: referenceDate) ?? referenceDate
            } label: {
                Label(isChinese ? "下一段" : "Next", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
        }
    }

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(isChinese ? "未来 7 天" : "Next 7 Days", systemImage: "calendar.badge.clock")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], alignment: .leading, spacing: 12) {
                ForEach(weekDates, id: \.self) { date in
                    ScheduleDayCard(
                        date: date,
                        reminders: reminders(on: date),
                        isChinese: isChinese,
                        isToday: calendar.isDateInToday(date)
                    )
                }
            }
        }
        .memoriaCard()
    }

    private var monthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(isChinese ? "月视图" : "Month View", systemImage: "calendar")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 54), spacing: 8), count: 7), spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthCells) { cell in
                    MonthDayCell(
                        date: cell.date,
                        reminders: cell.date.map { reminders(on: $0) } ?? [],
                        isChinese: isChinese,
                        isToday: cell.date.map(calendar.isDateInToday) ?? false
                    )
                }
            }
        }
        .memoriaCard()
    }

    private var unscheduledSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(isChinese ? "未定日期 / 文本时间" : "Unscheduled / Text Dates", systemImage: "text.badge.clock")
                .font(.headline)

            if store.unscheduledReminders.isEmpty {
                Text(isChinese ? "没有未定日期的提醒。" : "No reminders without concrete dates.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], alignment: .leading, spacing: 12) {
                    ForEach(store.unscheduledReminders) { reminder in
                        ReminderActionRow(reminder: reminder, isChinese: isChinese, isToday: false)
                    }
                }
            }
        }
        .memoriaCard()
    }

    private var scheduleReviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(isChinese ? "行程待确认" : "Schedule Review", systemImage: "tray")
                    .font(.headline)
                Spacer()
                Text("\(schedulePendingUpdates.count)")
                    .foregroundStyle(.secondary)
            }

            if let update = schedulePendingUpdates.first {
                Text(update.summary)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.secondary)
                Button {
                    store.selectFirstPendingUpdate()
                } label: {
                    Label(isChinese ? "去整理台确认" : "Review in Inbox", systemImage: "arrow.right")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text(isChinese ? "没有行程类待确认建议。" : "No schedule suggestions are waiting for review.")
                    .foregroundStyle(.secondary)
            }
        }
        .memoriaCard()
    }

    private var schedulePendingUpdates: [PendingUpdate] {
        store.pendingUpdates.filter { $0.reviewCategory == .schedule }
    }

    private var periodTitle: String {
        if displayMode == .week {
            let dates = weekDates
            guard let first = dates.first, let last = dates.last else {
                return referenceDate.formatted(.dateTime.month().day())
            }
            return "\(first.formatted(.dateTime.month().day())) - \(last.formatted(.dateTime.month().day()))"
        }
        return referenceDate.formatted(.dateTime.year().month(.wide))
    }

    private var weekDates: [Date] {
        let start = calendar.startOfDay(for: referenceDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var weekdaySymbols: [String] {
        isChinese ? ["日", "一", "二", "三", "四", "五", "六"] : calendar.shortWeekdaySymbols
    }

    private var monthCells: [ScheduleMonthCell] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: referenceDate),
              let dayRange = calendar.range(of: .day, in: .month, for: referenceDate) else {
            return []
        }
        let leadingBlankCount = calendar.component(.weekday, from: monthInterval.start) - 1
        let blanks = (0..<leadingBlankCount).map { ScheduleMonthCell(id: "blank-\($0)", date: nil) }
        let days = dayRange.compactMap { day -> ScheduleMonthCell? in
            var components = calendar.dateComponents([.year, .month], from: monthInterval.start)
            components.day = day
            guard let date = calendar.date(from: components) else { return nil }
            return ScheduleMonthCell(id: memoriaDateOnlyString(from: date), date: date)
        }
        return blanks + days
    }

    private func reminders(on date: Date) -> [ReminderItem] {
        store.datedReminders.filter { reminder in
            guard let dueDateValue = reminder.dueDateValue else { return false }
            return calendar.isDate(dueDateValue, inSameDayAs: date)
        }
    }

    private var isChinese: Bool {
        resolvedLanguage(store.settings.language) == .zhCN
    }
}

private struct ScheduleMonthCell: Identifiable {
    let id: String
    let date: Date?
}

private struct ScheduleMetricCard: View {
    let label: String
    let value: Int
    let symbolName: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .foregroundStyle(Color.memoriaSage)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.title3.monospacedDigit().weight(.semibold))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ScheduleDayCard: View {
    let date: Date
    let reminders: [ReminderItem]
    let isChinese: Bool
    let isToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.formatted(.dateTime.weekday(.wide)))
                        .font(.headline)
                    Text(date.formatted(.dateTime.month().day()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isToday {
                    Text(isChinese ? "今天" : "Today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.memoriaGold)
                }
            }

            if reminders.isEmpty {
                Text(isChinese ? "没有安排" : "No plans")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 54, alignment: .topLeading)
            } else {
                ForEach(reminders.prefix(3)) { reminder in
                    ScheduleCompactReminder(reminder: reminder, isChinese: isChinese)
                }
                if reminders.count > 3 {
                    Text(isChinese ? "还有 \(reminders.count - 3) 条" : "\(reminders.count - 3) more")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .background(isToday ? Color.memoriaGold.opacity(0.12) : Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MonthDayCell: View {
    let date: Date?
    let reminders: [ReminderItem]
    let isChinese: Bool
    let isToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let date {
                HStack {
                    Text(date.formatted(.dateTime.day()))
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                    if !reminders.isEmpty {
                        Text("\(reminders.count)")
                            .font(.caption2.monospacedDigit().weight(.bold))
                            .foregroundStyle(Color.memoriaInk)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.memoriaGold.opacity(0.28))
                            .clipShape(Capsule())
                    }
                }

                ForEach(reminders.prefix(2)) { reminder in
                    Text(reminder.title)
                        .font(.caption2)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(date == nil ? Color.clear : isToday ? Color.memoriaGold.opacity(0.12) : Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ScheduleCompactReminder: View {
    let reminder: ReminderItem
    let isChinese: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(reminder.timeLabel.isEmpty ? reminder.dueLabel : reminder.timeLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.memoriaGold)
                Text(reminder.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
            }
            Text(reminder.personName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MemoryOrganizationSuggestionCard: View {
    let suggestion: MemoryOrganizationSuggestion
    let language: LanguagePreference

    private var isChinese: Bool {
        resolvedLanguage(language) == .zhCN
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(suggestion.targetType.displayName(for: language))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(Capsule())

                Spacer()

                Text("\(suggestion.memoryCount)")
                    .font(.headline)
                    .foregroundStyle(Color.memoriaGold)
            }

            Text(suggestion.title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            Text(suggestion.rationale)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if suggestion.requiresApproval {
                Label(isChinese ? "需要确认" : "Needs approval", systemImage: "checkmark.seal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.memoriaGold)
            } else {
                Label(isChinese ? "自动整理，可编辑" : "Automatic, editable", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.memoriaSage)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AgendaAssistantItemRow: View {
    let item: AgendaAssistantItem
    let language: LanguagePreference

    private var isChinese: Bool {
        resolvedLanguage(language) == .zhCN
    }

    private var symbolName: String {
        switch item.kind {
        case .calendarBlock:
            return "calendar"
        case .preparation:
            return "bag"
        case .followUp:
            return "bubble.left.and.text.bubble.right"
        case .review:
            return "checklist"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.memoriaInk)
                .frame(width: 34, height: 34)
                .background(Color.memoriaSage.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.kind.title(for: language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(item.timeLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.memoriaGold)
                }

                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if item.requiresApproval {
                    Label(isChinese ? "需确认后同步" : "Approval required", systemImage: "lock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.memoriaGold)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ReminderActionRow: View {
    let reminder: ReminderItem
    let isChinese: Bool
    let isToday: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 3) {
                Text(reminder.timeLabel.isEmpty ? reminder.dueLabel : reminder.timeLabel)
                    .font(.headline)
                Text(isToday ? (isChinese ? "今天" : "Today") : reminder.dueLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 72, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Text(reminder.title)
                    .font(.subheadline.weight(.semibold))
                Text(reminder.personName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !reminder.context.isEmpty {
                    Text(reminder.context)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !reminder.location.isEmpty {
                    Label(reminder.location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(isToday ? Color.memoriaGold.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SourceQuoteBlock: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Source quote")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
