import SwiftUI
import MemoriaCore

struct PeopleView: View {
    @ObservedObject var store: DashboardStore
    @SceneStorage("memoria.people.directoryCollapsed") private var directoryCollapsed = false
    @SceneStorage("memoria.people.forceDirectoryVisible") private var forceDirectoryVisible = false
    @State private var newPersonDraft: PersonProfileDraft?

    private var isChinese: Bool {
        resolvedLanguage(store.settings.language) == .zhCN
    }

    var body: some View {
        GeometryReader { proxy in
            let policyMode = PeoplePresentationPolicy.mode(forAvailableWidth: proxy.size.width)
            let automaticallyFocused = policyMode == .focusedProfile
            let hideDirectory = directoryCollapsed || (automaticallyFocused && !forceDirectoryVisible)

            HStack(spacing: 0) {
                if !hideDirectory {
                    peopleDirectoryPane
                        .frame(minWidth: 250, idealWidth: automaticallyFocused ? 280 : 310, maxWidth: automaticallyFocused ? 300 : 360)
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    Divider()
                }

                if let person = store.selectedPerson {
                    PersonDetailView(
                        store: store,
                        person: person,
                        memories: store.memories(for: person),
                        relationshipEdges: store.relationshipEdges(for: person),
                        gifts: store.gifts(for: person),
                        isChinese: isChinese,
                        directoryHidden: hideDirectory,
                        automaticallyFocused: automaticallyFocused,
                        onToggleDirectory: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                if hideDirectory {
                                    directoryCollapsed = false
                                    forceDirectoryVisible = true
                                } else {
                                    directoryCollapsed = true
                                    forceDirectoryVisible = false
                                }
                            }
                        }
                    )
                } else {
                    EmptyState(
                        systemImage: "person.crop.circle",
                        title: isChinese ? "还没有选中联系人" : "No person selected",
                        detail: isChinese ? "从左侧列表选一个人查看档案。" : "Choose a person from the list."
                    )
                }
            }
        }
        .onAppear {
            if store.selectedPersonID == nil {
                store.selectedPersonID = store.visiblePeople.first?.id
            }
        }
        .sheet(item: $newPersonDraft) { draft in
            ProfileEditorSheet(
                draft: draft,
                title: isChinese ? "添加朋友" : "Add Friend",
                saveTitle: isChinese ? "添加" : "Add",
                language: store.settings.language,
                onCancel: { newPersonDraft = nil },
                onSave: { person in
                    store.addPerson(person)
                    newPersonDraft = nil
                }
            )
        }
    }

    private var peopleDirectoryPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isChinese ? "朋友分组" : "Groups")
                    .font(.headline)

                Spacer()

                Button {
                    newPersonDraft = PersonProfileDraft(defaultGroup: store.selectedGroup ?? .classmates)
                } label: {
                    Label(isChinese ? "添加朋友" : "Add Friend", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help(isChinese ? "添加朋友" : "Add Friend")

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        directoryCollapsed = true
                        forceDirectoryVisible = false
                    }
                } label: {
                    Label(isChinese ? "收起" : "Collapse", systemImage: "sidebar.left")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            groupFilterBar
                .padding(.horizontal, 12)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(store.visiblePeople) { person in
                        PersonDirectoryRow(
                            person: person,
                            language: store.settings.language,
                            isSelected: store.selectedPersonID == person.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.14)) {
                                store.selectedPersonID = person.id
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
        }
    }

    private var groupFilterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            PeopleGroupFilterButton(
                title: isChinese ? "全部朋友" : "All People",
                count: store.people.count,
                isSelected: store.selectedGroup == nil
            ) {
                store.navigate(to: .people)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(GroupFilter.allCases) { group in
                    PeopleGroupFilterButton(
                        title: group.title(for: store.settings.language),
                        count: store.count(for: group),
                        isSelected: store.selectedGroup == group
                    ) {
                        store.navigate(to: group)
                    }
                }
            }
        }
        .font(.callout)
    }
}

private struct PeopleGroupFilterButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.callout.weight(isSelected ? .semibold : .medium))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text("\(count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(isSelected ? Color.memoriaInk : .secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(isSelected ? Color.memoriaGold.opacity(0.28) : Color.primary.opacity(0.06))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(isSelected ? Color.memoriaSage.opacity(0.18) : Color.primary.opacity(0.035))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.memoriaSage.opacity(0.42) : Color.primary.opacity(0.05), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PersonDirectoryRow: View {
    let person: FriendPerson
    let language: LanguagePreference
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(person.displayName)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Text("\(person.manualClosenessLevel)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.memoriaGold)
                }

                Text(person.relationLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    ForEach(person.groupLabels, id: \.rawValue) { group in
                        Text(group.title(for: language))
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.memoriaSage.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.memoriaSage.opacity(0.18) : Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.memoriaSage.opacity(0.42) : Color.primary.opacity(0.06), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PersonDetailView: View {
    @ObservedObject var store: DashboardStore
    let person: FriendPerson
    let memories: [MemoryAtom]
    let relationshipEdges: [RelationshipEdge]
    let gifts: [GiftIdea]
    let isChinese: Bool
    let directoryHidden: Bool
    let automaticallyFocused: Bool
    let onToggleDirectory: () -> Void
    @State private var relationshipTargetName = ""
    @State private var relationshipLabel = ""
    @State private var relationshipKind = ""
    @State private var giftPrompt = "给小雨推荐生日礼物，预算 300 到 500 元，不要太普通，最好有一点心意。"
    @State private var editingDraft: PersonProfileDraft?
    @State private var editingRelationshipDraft: RelationshipEdgeDraft?
    @State private var confirmingDelete = false
    @State private var showManualRelationshipEditor = false
    @State private var showCategorySchema = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                profileToolbar
                header
                profileSummarySection
                relatedMemorySection
                relationshipAndClosenessGrid
                giftSection
                detailedFactsSection
                categoryArchiveSection
            }
            .padding(automaticallyFocused ? 18 : 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: $editingRelationshipDraft) { draft in
            RelationshipEdgeEditorSheet(
                draft: draft,
                language: store.settings.language,
                onCancel: {
                    editingRelationshipDraft = nil
                },
                onSave: { draft in
                    store.updateRelationshipEdge(
                        draft.edge,
                        targetName: draft.targetName,
                        label: draft.label,
                        relationKind: draft.relationKind,
                        strength: draft.strength,
                        tags: draft.tags,
                        manualPrimaryTag: draft.manualPrimaryTag
                    )
                    editingRelationshipDraft = nil
                },
                onDelete: { edge in
                    store.deleteRelationshipEdge(edge)
                    editingRelationshipDraft = nil
                }
            )
        }
    }

    private var profileToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                directoryToggleButton
                personPicker
                editProfileButton
                deleteProfileButton
                compactProfileNote
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    directoryToggleButton
                    personPicker
                }
                HStack(spacing: 10) {
                    editProfileButton
                    deleteProfileButton
                    compactProfileNote
                }
            }
        }
        .sheet(item: $editingDraft) { draft in
            ProfileEditorSheet(
                draft: draft,
                title: isChinese ? "编辑朋友档案" : "Edit Friend Profile",
                saveTitle: isChinese ? "保存修改" : "Save",
                language: store.settings.language,
                onCancel: { editingDraft = nil },
                onSave: { updatedPerson in
                    store.savePerson(updatedPerson)
                    editingDraft = nil
                }
            )
        }
        .confirmationDialog(
            isChinese ? "删除这个朋友？" : "Delete this friend?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button(isChinese ? "删除 \(person.displayName)" : "Delete \(person.displayName)", role: .destructive) {
                store.deletePerson(person)
            }
            Button(isChinese ? "取消" : "Cancel", role: .cancel) {}
        } message: {
            Text(isChinese ? "会从本地朋友列表删除，并清理这个人的关系网、提醒和礼物建议。" : "This removes the local profile and clears related relationship edges, reminders, and gift ideas.")
        }
    }

    private var directoryToggleButton: some View {
        Button {
            onToggleDirectory()
        } label: {
            Label(
                directoryHidden ? (isChinese ? "展开朋友列表" : "Show Directory") : (isChinese ? "收起朋友列表" : "Hide Directory"),
                systemImage: "sidebar.left"
            )
        }
        .buttonStyle(.bordered)
    }

    private var personPicker: some View {
        Picker(isChinese ? "当前朋友" : "Current Person", selection: $store.selectedPersonID) {
            ForEach(store.visiblePeople.isEmpty ? store.people : store.visiblePeople) { candidate in
                Text(candidate.displayName).tag(Optional(candidate.id))
            }
        }
        .labelsHidden()
        .frame(maxWidth: 240)
    }

    private var editProfileButton: some View {
        Button {
            editingDraft = PersonProfileDraft(person: person)
        } label: {
            Label(isChinese ? "编辑档案" : "Edit Profile", systemImage: "pencil")
        }
        .buttonStyle(.borderedProminent)
    }

    private var deleteProfileButton: some View {
        Button(role: .destructive) {
            confirmingDelete = true
        } label: {
            Label(isChinese ? "删除朋友" : "Delete Friend", systemImage: "trash")
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var compactProfileNote: some View {
        if automaticallyFocused {
            Text(isChinese ? "窄窗已优先展示完整档案" : "Compact window focuses the profile")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(person.initials)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color.memoriaInk.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(person.displayName)
                        .font(.title.weight(.semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if !person.nickname.isEmpty {
                        Text(person.nickname)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(person.relationLabel)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        ProfilePill(systemImage: "mappin.and.ellipse", text: person.location)
                        ProfilePill(systemImage: "gift", text: person.birthday)
                        ProfilePill(systemImage: "person.2", text: person.groupLabelsTitle(for: store.settings.language))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        ProfilePill(systemImage: "mappin.and.ellipse", text: person.location)
                        ProfilePill(systemImage: "gift", text: person.birthday)
                        ProfilePill(systemImage: "person.2", text: person.groupLabelsTitle(for: store.settings.language))
                    }
                }

                profileTagChips
            }

            Spacer(minLength: 12)

            Menu {
                ForEach(GroupFilter.allCases) { group in
                    Button {
                        store.toggleGroup(group, for: person)
                    } label: {
                        Label(
                            group.title(for: store.settings.language),
                            systemImage: person.belongs(to: group) ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }
            } label: {
                Label(isChinese ? "管理分组" : "Groups", systemImage: "folder.badge.gearshape")
            }
            .menuStyle(.borderlessButton)
        }
    }

    private var profileTagChips: some View {
        let tags = splitTags(person.profileTags)
        return HStack(spacing: 6) {
            ForEach(tags.prefix(5), id: \.self) { tag in
                Text(tag)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.memoriaSage.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    private var profileSummarySection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], alignment: .leading, spacing: 12) {
            DossierHighlightCard(
                title: isChinese ? "人物摘要" : "Profile Summary",
                systemImage: "person.text.rectangle",
                lines: [
                    person.categoryNote(.relationship),
                    person.lastSignal,
                    person.categoryNote(.currentState)
                ]
            )

            DossierHighlightCard(
                title: isChinese ? "相处方式" : "How To Relate",
                systemImage: "bubble.left.and.text.bubble.right",
                lines: [
                    person.categoryNote(.communicationPreference),
                    person.categoryNote(.emotionalPreference),
                    person.categoryNote(.tabooBoundary)
                ]
            )

            DossierHighlightCard(
                title: isChinese ? "兴趣与礼物线索" : "Interests & Gift Signals",
                systemImage: "gift",
                lines: [
                    person.interests,
                    person.favoriteFoods,
                    person.categoryNote(.giftHistory)
                ]
            )
        }
    }

    private var relationshipAndClosenessGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], alignment: .leading, spacing: 12) {
            closenessSection
            relationshipGraphSection
        }
    }

    private var closenessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isChinese ? "亲近度" : "Closeness")
                    .font(.headline)
                Spacer()
                Text("\(person.manualClosenessLevel) · \(person.manualClosenessTitle(for: store.settings.language))")
                    .font(.headline)
                    .foregroundStyle(Color.memoriaGold)
            }

            ClosenessRangeBar(level: person.manualClosenessLevel, language: store.settings.language)

            if !person.closenessSignalsList.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isChinese ? "AI 辅助信号" : "AI-assisted signals")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(person.closenessSignalsList.prefix(4), id: \.self) { signal in
                            Label(signal, systemImage: "sparkles")
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .memoriaCard()
    }

    private var relationshipGraphSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(isChinese ? "关系星图摘要" : "Relationship Map Summary")
                    .font(.headline)
                Spacer()
                Button {
                    store.navigate(to: .relationshipMap)
                } label: {
                    Label(isChinese ? "完整星图" : "Full Map", systemImage: "point.3.connected.trianglepath.dotted")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                Text(isChinese ? "批准入库后自动整理" : "Organized after approval")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            RelationshipToneLegend(language: store.settings.language)

            RelationshipMiniGraph(
                person: person,
                edges: relationshipEdges,
                priorities: store.relationshipTagPriorities
            ) { edge in
                editingRelationshipDraft = RelationshipEdgeDraft(edge: edge, priorities: store.relationshipTagPriorities)
            }
                .frame(height: 230)

            if relationshipEdges.isEmpty {
                Text(isChinese ? "还没有确认过的关系边。记录一条和朋友网络有关的记忆，整理台批准后会出现在这里。" : "No confirmed relationship edges yet. Capture a relationship memory, approve it in review, and it will appear here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isChinese ? "点击任一关系可编辑标签、说明和强度。" : "Click any relationship to edit its tag, label, and strength.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(relationshipEdges) { edge in
                            RelationshipEdgeInlineButton(
                                edge: edge,
                                centerPersonID: person.id,
                                priorities: store.relationshipTagPriorities,
                                isChinese: isChinese
                            ) {
                                editingRelationshipDraft = RelationshipEdgeDraft(edge: edge, priorities: store.relationshipTagPriorities)
                            }
                        }
                    }
                }
            }

            DisclosureGroup(isExpanded: $showManualRelationshipEditor) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(isChinese ? "默认让 AI 从已确认记忆里整理星图。只有很确定、但还没有来源记忆的关系，才手动补充。" : "By default, let AI organize the map from approved memory. Use this only for certain relationships that do not yet have a source memory.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 8)], alignment: .leading, spacing: 8) {
                        TextField(isChinese ? "对方姓名，如 Leo / 室友" : "Name, e.g. Leo / roommate", text: $relationshipTargetName)
                            .textFieldStyle(.roundedBorder)
                        TextField(isChinese ? "关系说明，如 男朋友 / 关系很好" : "Label, e.g. partner / close", text: $relationshipLabel)
                            .textFieldStyle(.roundedBorder)
                        TextField(isChinese ? "类型，如 partner / family" : "Kind, e.g. partner / family", text: $relationshipKind)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            store.addRelationship(
                                for: person,
                                targetName: relationshipTargetName,
                                label: relationshipLabel,
                                relationKind: relationshipKind
                            )
                            relationshipTargetName = ""
                            relationshipLabel = ""
                            relationshipKind = ""
                        } label: {
                            Label(isChinese ? "补充关系" : "Add", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 8)
            } label: {
                Label(isChinese ? "手动补充关系" : "Manually add relationship", systemImage: "slider.horizontal.3")
                    .font(.callout.weight(.medium))
            }
        }
        .memoriaCard()
    }

    private var detailedFactsSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 14) {
                ProfileFactsTable(
                    title: isChinese ? "基本信息" : "Basic Info",
                    facts: [
                        (isChinese ? "姓名" : "Name", person.displayName),
                        (isChinese ? "昵称" : "Nickname", person.nickname),
                        (isChinese ? "英文名" : "English Name", person.englishName),
                        (isChinese ? "关系" : "Relation", person.relationLabel),
                        (isChinese ? "城市" : "City", person.location),
                        (isChinese ? "家乡" : "Hometown", person.hometown),
                        ("MBTI", person.mbti),
                        (isChinese ? "星座" : "Zodiac", person.zodiacSign),
                        (isChinese ? "学校" : "School", person.school),
                        (isChinese ? "职业" : "Career", [person.company, person.roleTitle].filter { !$0.isEmpty }.joined(separator: " · "))
                    ]
                )

                ProfileFactsTable(
                    title: isChinese ? "关系信息" : "Relationship Info",
                    facts: [
                        (isChinese ? "共同朋友" : "Mutual Friends", person.categoryNote(.friendNetwork)),
                        (isChinese ? "关系阶段" : "Stage", person.categoryNote(.relationship)),
                        (isChinese ? "伴侣" : "Partner", person.partnerName),
                        (isChinese ? "重要回忆" : "Important Memories", person.lastSignal),
                        (isChinese ? "边界" : "Boundaries", person.categoryNote(.tabooBoundary))
                    ]
                )

                ProfileFactsTable(
                    title: isChinese ? "兴趣图谱" : "Interest Map",
                    facts: [
                        (isChinese ? "兴趣" : "Interests", person.interests),
                        (isChinese ? "书" : "Books", person.books),
                        (isChinese ? "运动" : "Sports", person.sports),
                        (isChinese ? "书影音" : "Media", person.categoryNote(.media)),
                        (isChinese ? "旅行" : "Travel", person.categoryNote(.travelPreference)),
                        (isChinese ? "穿搭/品牌" : "Style/Brands", person.categoryNote(.styleAesthetic))
                    ]
                )

                ProfileFactsTable(
                    title: isChinese ? "饮食生活" : "Food & Life",
                    facts: [
                        (isChinese ? "喜欢吃什么" : "Favorite Foods", person.favoriteFoods),
                        (isChinese ? "忌口" : "Dietary", person.dietaryRestrictions),
                        (isChinese ? "饮料/酒精" : "Drinks", person.categoryNote(.foodPreference)),
                        (isChinese ? "餐厅偏好" : "Restaurants", person.categoryNote(.foodPreference)),
                        (isChinese ? "作息/习惯" : "Routine", person.categoryNote(.lifestyle))
                    ]
                )

                ProfileFactsTable(
                    title: isChinese ? "教育与职业" : "Education & Career",
                    facts: [
                        (isChinese ? "学校" : "School", person.school),
                        (isChinese ? "专业" : "Major", person.major),
                        (isChinese ? "研究经历" : "Research", person.researchExperience),
                        (isChinese ? "实习经历" : "Internship", person.internshipExperience),
                        (isChinese ? "职业目标" : "Career Goal", person.categoryNote(.career))
                    ]
                )

                ProfileFactsTable(
                    title: isChinese ? "人生事件与文件" : "Life Events & Files",
                    facts: [
                        (isChinese ? "家庭事件" : "Family", person.familyNotes),
                        (isChinese ? "人生事件" : "Life Events", person.categoryNote(.lifeEvents)),
                        (isChinese ? "提醒" : "Reminders", person.categoryNote(.reminders)),
                        (isChinese ? "文件" : "Files", person.categoryNote(.files)),
                        (isChinese ? "AI 推断" : "AI Inference", person.categoryNote(.aiInference))
                    ]
                )
            }
            .padding(.top, 10)
        } label: {
            Label(isChinese ? "完整字段档案" : "Full Field Archive", systemImage: "list.bullet.rectangle")
                .font(.headline)
        }
        .memoriaCard()
    }

    private var giftSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isChinese ? "生日礼物推荐" : "Gift Recommendations")
                .font(.headline)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    giftPromptField
                    giftButton
                }
                VStack(alignment: .leading, spacing: 8) {
                    giftPromptField
                    giftButton
                }
            }

            if gifts.isEmpty {
                Text(isChinese ? "还没有这个朋友的礼物画像。" : "No gift profile yet.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], alignment: .leading, spacing: 12) {
                    ForEach(gifts) { gift in
                        GiftRecommendationCard(gift: gift, isChinese: isChinese)
                    }
                }
            }
        }
        .memoriaCard()
    }

    private var giftPromptField: some View {
        TextField(isChinese ? "例如：给小雨推荐生日礼物，预算 300 到 500 元..." : "Example: recommend a birthday gift, budget 300-500...", text: $giftPrompt, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(2...4)
    }

    private var giftButton: some View {
        Button {
            store.generateGiftRecommendations(for: person, prompt: giftPrompt)
        } label: {
            Label(isChinese ? "生成推荐" : "Generate", systemImage: "sparkles")
        }
        .buttonStyle(.borderedProminent)
    }

    private var categoryArchiveSection: some View {
        DisclosureGroup(isExpanded: $showCategorySchema) {
            VStack(alignment: .leading, spacing: 12) {
                Text(isChinese ? "这是 AI 和 SQLite 用来归类朋友事实的后台字典。档案页会把这些字段整理成更好读的人物画像，不需要把 Schema 当作主要内容浏览。" : "This is the background dictionary used by AI and SQLite to classify profile facts. The dossier turns these fields into readable profile sections.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)], alignment: .leading, spacing: 10) {
                    ForEach(PersonProfileCategory.allCases) { category in
                        ProfileCategoryCard(
                            category: category,
                            value: person.categoryNote(category),
                            language: store.settings.language
                        )
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Label(isChinese ? "AI 分类规则" : "AI Classification Rules", systemImage: "curlybraces")
                    .font(.headline)
                Spacer()
                Text("\(PersonProfileCategory.allCases.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .memoriaCard()
    }

    private var relatedMemorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isChinese ? "来源记忆" : "Source Memories")
                .font(.headline)

            if memories.isEmpty {
                Text(isChinese ? "还没有和这个人直接关联的确认记忆。" : "No confirmed memories directly linked to this person yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(memories) { memory in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(memory.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(memory.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Menu {
                                Button {
                                    store.markMemoryWrong(memory)
                                } label: {
                                    Label(isChinese ? "标记错误" : "Mark wrong", systemImage: "exclamationmark.triangle")
                                }
                                Button {
                                    store.createChangePersonCorrection(for: memory)
                                } label: {
                                    Label(isChinese ? "改给另一个人" : "Move to another person", systemImage: "person.2")
                                }
                                Button {
                                    store.createReplacementFactCorrection(for: memory, person: person)
                                } label: {
                                    Label(isChinese ? "替换事实" : "Replace fact", systemImage: "arrow.triangle.2.circlepath")
                                }
                                Button {
                                    store.createStaleCorrection(for: memory)
                                } label: {
                                    Label(isChinese ? "标记过期" : "Mark stale", systemImage: "clock.badge.questionmark")
                                }
                            } label: {
                                Label(isChinese ? "纠错" : "Correct", systemImage: "pencil.and.outline")
                                    .labelStyle(.iconOnly)
                            }
                            .menuStyle(.borderlessButton)
                            .help(isChinese ? "对这条已确认记忆发起纠错" : "Start a correction for this confirmed memory")
                        }

                        if memory.status == .disputed {
                            Label(isChinese ? "已标记错误" : "Disputed", systemImage: "exclamationmark.triangle")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quinary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .memoriaCard()
    }

    private func splitTags(_ value: String) -> [String] {
        value
            .split { character in
                character == "," || character == "，" || character == "、" || character == ";" || character == "；"
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct ProfileEditorSheet: View {
    @State private var draft: PersonProfileDraft
    let title: String
    let saveTitle: String
    let language: LanguagePreference
    let onCancel: () -> Void
    let onSave: (FriendPerson) -> Void

    private var isChinese: Bool {
        resolvedLanguage(language) == .zhCN
    }

    private var editorColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 220), spacing: 12)]
    }

    init(
        draft: PersonProfileDraft,
        title: String,
        saveTitle: String,
        language: LanguagePreference,
        onCancel: @escaping () -> Void,
        onSave: @escaping (FriendPerson) -> Void
    ) {
        _draft = State(initialValue: draft)
        self.title = title
        self.saveTitle = saveTitle
        self.language = language
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    basicSection
                    groupSection
                    preferenceSection
                    educationCareerSection
                    relationshipSection
                    categoryNotesSection
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button(isChinese ? "取消" : "Cancel") {
                    onCancel()
                }
                Button {
                    onSave(draft.makePerson())
                } label: {
                    Label(saveTitle, systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!draft.canSave)
            }
            .padding(20)
        }
        .frame(minWidth: 680, idealWidth: 760, maxWidth: 860, minHeight: 640, idealHeight: 760, maxHeight: 860)
    }

    private var basicSection: some View {
        ProfileEditorSection(title: isChinese ? "基本信息" : "Basic Info") {
            LazyVGrid(columns: editorColumns, alignment: .leading, spacing: 12) {
                ProfileEditorTextField(label: isChinese ? "姓名" : "Name", text: $draft.displayName)
                ProfileEditorTextField(label: isChinese ? "昵称" : "Nickname", text: $draft.nickname)
                ProfileEditorTextField(label: isChinese ? "英文名" : "English Name", text: $draft.englishName)
                ProfileEditorTextField(label: isChinese ? "关系标签" : "Relationship Label", text: $draft.relationLabel)
                ProfileEditorTextField(label: isChinese ? "城市" : "City", text: $draft.location)
                ProfileEditorTextField(label: isChinese ? "家乡" : "Hometown", text: $draft.hometown)
                ProfileEditorTextField(label: isChinese ? "语言" : "Languages", text: $draft.languages)
                ProfileEditorTextField(label: isChinese ? "联系方式" : "Contact", text: $draft.contactInfo)
                ProfileEditorTextField(label: isChinese ? "生日" : "Birthday", text: $draft.birthday)
                ProfileEditorTextField(label: "MBTI", text: $draft.mbti)
                ProfileEditorTextField(label: isChinese ? "星座" : "Zodiac", text: $draft.zodiacSign)
                ProfileEditorTextField(label: isChinese ? "标签" : "Tags", text: $draft.profileTags)
            }
        }
    }

    private var groupSection: some View {
        ProfileEditorSection(title: isChinese ? "分组与亲近度" : "Groups & Closeness") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
                ForEach(GroupFilter.allCases) { group in
                    Toggle(group.title(for: language), isOn: groupBinding(group))
                        .toggleStyle(.checkbox)
                }
            }

            Stepper(value: $draft.manualClosenessLevel, in: 1...6) {
                Text(isChinese ? "手动亲近等级：\(draft.manualClosenessLevel)" : "Manual closeness: \(draft.manualClosenessLevel)")
                    .font(.callout.weight(.medium))
            }
        }
    }

    private var preferenceSection: some View {
        ProfileEditorSection(title: isChinese ? "饮食与兴趣" : "Food & Interests") {
            LazyVGrid(columns: editorColumns, alignment: .leading, spacing: 12) {
                ProfileEditorTextField(label: isChinese ? "喜欢吃什么" : "Favorite Foods", text: $draft.favoriteFoods, lineLimit: 2...4)
                ProfileEditorTextField(label: isChinese ? "忌口/过敏" : "Dietary Restrictions", text: $draft.dietaryRestrictions, lineLimit: 2...4)
                ProfileEditorTextField(label: isChinese ? "不喜欢/雷点" : "Dislikes", text: $draft.dislikedThings, lineLimit: 2...4)
                ProfileEditorTextField(label: isChinese ? "兴趣" : "Interests", text: $draft.interests, lineLimit: 2...4)
                ProfileEditorTextField(label: isChinese ? "书影音" : "Books / Media", text: $draft.books, lineLimit: 2...4)
                ProfileEditorTextField(label: isChinese ? "运动" : "Sports", text: $draft.sports, lineLimit: 2...4)
            }
        }
    }

    private var educationCareerSection: some View {
        ProfileEditorSection(title: isChinese ? "教育与职业" : "Education & Career") {
            LazyVGrid(columns: editorColumns, alignment: .leading, spacing: 12) {
                ProfileEditorTextField(label: isChinese ? "学校" : "School", text: $draft.school)
                ProfileEditorTextField(label: isChinese ? "专业" : "Major", text: $draft.major)
                ProfileEditorTextField(label: isChinese ? "公司/组织" : "Company", text: $draft.company)
                ProfileEditorTextField(label: isChinese ? "职位/身份" : "Role", text: $draft.roleTitle)
                ProfileEditorTextField(label: isChinese ? "研究经历" : "Research", text: $draft.researchExperience, lineLimit: 2...4)
                ProfileEditorTextField(label: isChinese ? "实习经历" : "Internship", text: $draft.internshipExperience, lineLimit: 2...4)
            }
        }
    }

    private var relationshipSection: some View {
        ProfileEditorSection(title: isChinese ? "关系与近况" : "Relationship & Signals") {
            LazyVGrid(columns: editorColumns, alignment: .leading, spacing: 12) {
                ProfileEditorTextField(label: isChinese ? "最近重要信息" : "Latest Signal", text: $draft.lastSignal, lineLimit: 2...4)
                ProfileEditorTextField(label: isChinese ? "亲近度信号" : "Closeness Signals", text: $draft.closenessSignals, lineLimit: 3...6)
                ProfileEditorTextField(label: isChinese ? "家庭备注" : "Family Notes", text: $draft.familyNotes, lineLimit: 2...4)
                ProfileEditorTextField(label: isChinese ? "伴侣/重要关系" : "Partner / Key Relation", text: $draft.partnerName)
            }
        }
    }

    private var categoryNotesSection: some View {
        ProfileEditorSection(title: isChinese ? "分类档案备注" : "Profile Category Notes") {
            LazyVGrid(columns: editorColumns, alignment: .leading, spacing: 12) {
                ForEach(PersonProfileCategory.allCases) { category in
                    ProfileEditorTextField(
                        label: category.title(for: language),
                        text: categoryBinding(category),
                        lineLimit: 2...5
                    )
                }
            }
        }
    }

    private func groupBinding(_ group: GroupFilter) -> Binding<Bool> {
        Binding(
            get: { draft.groupLabels.contains(group) },
            set: { isSelected in
                draft.setGroup(group, isSelected: isSelected)
            }
        )
    }

    private func categoryBinding(_ category: PersonProfileCategory) -> Binding<String> {
        Binding(
            get: { draft.categoryNotes[category] ?? "" },
            set: { value in
                draft.categoryNotes[category] = value
            }
        )
    }
}

private struct ProfileEditorSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProfileEditorTextField: View {
    let label: String
    @Binding var text: String
    var lineLimit: ClosedRange<Int> = 1...1

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(label, text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(lineLimit)
        }
    }
}

private struct PersonProfileDraft: Identifiable, Equatable {
    let id: String
    var displayName: String
    var nickname: String
    var englishName: String
    var relationLabel: String
    var groupLabels: [GroupFilter]
    var location: String
    var hometown: String
    var languages: String
    var contactInfo: String
    var birthday: String
    var dietaryRestrictions: String
    var favoriteFoods: String
    var dislikedThings: String
    var zodiacSign: String
    var mbti: String
    var interests: String
    var books: String
    var sports: String
    var profileTags: String
    var lastSignal: String
    var school: String
    var major: String
    var company: String
    var roleTitle: String
    var researchExperience: String
    var internshipExperience: String
    var familyNotes: String
    var partnerName: String
    var manualClosenessLevel: Int
    var closenessSignals: String
    var categoryNotes: [PersonProfileCategory: String]

    var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(defaultGroup: GroupFilter) {
        id = "manual-\(UUID().uuidString)"
        displayName = ""
        nickname = ""
        englishName = ""
        relationLabel = "朋友"
        groupLabels = [defaultGroup]
        location = ""
        hometown = ""
        languages = ""
        contactInfo = ""
        birthday = ""
        dietaryRestrictions = ""
        favoriteFoods = ""
        dislikedThings = ""
        zodiacSign = ""
        mbti = ""
        interests = ""
        books = ""
        sports = ""
        profileTags = ""
        lastSignal = ""
        school = ""
        major = ""
        company = ""
        roleTitle = ""
        researchExperience = ""
        internshipExperience = ""
        familyNotes = ""
        partnerName = ""
        manualClosenessLevel = 3
        closenessSignals = ""
        categoryNotes = [:]
    }

    init(person: FriendPerson) {
        id = person.id
        displayName = person.displayName
        nickname = person.nickname
        englishName = person.englishName
        relationLabel = person.relationLabel
        groupLabels = person.groupLabels
        location = person.location
        hometown = person.hometown
        languages = person.languages
        contactInfo = person.contactInfo
        birthday = person.birthday
        dietaryRestrictions = person.dietaryRestrictions
        favoriteFoods = person.favoriteFoods
        dislikedThings = person.dislikedThings
        zodiacSign = person.zodiacSign
        mbti = person.mbti
        interests = person.interests
        books = person.books
        sports = person.sports
        profileTags = person.profileTags
        lastSignal = person.lastSignal
        school = person.school
        major = person.major
        company = person.company
        roleTitle = person.roleTitle
        researchExperience = person.researchExperience
        internshipExperience = person.internshipExperience
        familyNotes = person.familyNotes
        partnerName = person.partnerName
        manualClosenessLevel = person.manualClosenessLevel
        closenessSignals = person.closenessSignals
        categoryNotes = person.categoryNotes
    }

    mutating func setGroup(_ group: GroupFilter, isSelected: Bool) {
        if isSelected, !groupLabels.contains(group) {
            groupLabels.append(group)
        } else if !isSelected, groupLabels.count > 1 {
            groupLabels.removeAll { $0 == group }
        }
    }

    func makePerson() -> FriendPerson {
        let groups = groupLabels.isEmpty ? [.classmates] : groupLabels
        let name = trimmed(displayName)
        return FriendPerson(
            id: id,
            displayName: name,
            nickname: trimmed(nickname),
            englishName: trimmed(englishName),
            relationLabel: trimmed(relationLabel, fallback: "朋友"),
            groupLabel: groups[0],
            groupLabels: groups,
            location: trimmed(location),
            hometown: trimmed(hometown),
            languages: trimmed(languages),
            contactInfo: trimmed(contactInfo),
            birthday: trimmed(birthday),
            dietaryRestrictions: trimmed(dietaryRestrictions),
            favoriteFoods: trimmed(favoriteFoods),
            dislikedThings: trimmed(dislikedThings),
            zodiacSign: trimmed(zodiacSign),
            mbti: trimmed(mbti),
            interests: trimmed(interests),
            books: trimmed(books),
            sports: trimmed(sports),
            profileTags: trimmed(profileTags),
            lastSignal: trimmed(lastSignal),
            initials: Self.initials(for: name),
            school: trimmed(school),
            major: trimmed(major),
            company: trimmed(company),
            roleTitle: trimmed(roleTitle),
            researchExperience: trimmed(researchExperience),
            internshipExperience: trimmed(internshipExperience),
            familyNotes: trimmed(familyNotes),
            partnerName: trimmed(partnerName),
            manualClosenessLevel: manualClosenessLevel,
            closenessSignals: trimmed(closenessSignals),
            categoryNotes: cleanedCategoryNotes
        )
    }

    private var cleanedCategoryNotes: [PersonProfileCategory: String] {
        categoryNotes.reduce(into: [PersonProfileCategory: String]()) { result, pair in
            let value = trimmed(pair.value)
            guard !value.isEmpty else { return }
            result[pair.key] = value
        }
    }

    private func trimmed(_ value: String, fallback: String = "") -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? fallback : trimmedValue
    }

    private static func initials(for name: String) -> String {
        let parts = name
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        if parts.count >= 2 {
            return parts.prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
        }

        return String(name.prefix(2)).uppercased()
    }
}

private struct RelationshipEdgeInlineButton: View {
    let edge: RelationshipEdge
    let centerPersonID: String
    let priorities: [RelationshipTagPriority]
    let isChinese: Bool
    let action: () -> Void

    var body: some View {
        let tone = edge.visualTone

        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(tone.lineColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text(edge.counterpartName(for: centerPersonID))
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(edge.displayTag(priorities: priorities))
                        Text(tone.title(for: isChinese ? .zhCN : .en))
                            .foregroundStyle(tone.lineColor)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tone.softFill)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tone.lineColor.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(isChinese ? "编辑关系" : "Edit relationship")
    }
}

private struct RelationshipMiniGraph: View {
    let person: FriendPerson
    let edges: [RelationshipEdge]
    let priorities: [RelationshipTagPriority]
    let onEditEdge: (RelationshipEdge) -> Void

    var body: some View {
        GeometryReader { proxy in
            let visibleEdges = Array(edges.prefix(8))
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radiusX = max(58, proxy.size.width / 2 - 62)
            let radiusY = max(46, proxy.size.height / 2 - 42)
            let radius = min(radiusX, radiusY)

            ZStack {
                Canvas { context, _ in
                    let ringRect = CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.stroke(
                        Path(ellipseIn: ringRect),
                        with: .color(Color.primary.opacity(0.045)),
                        style: StrokeStyle(lineWidth: 1)
                    )

                    for (index, edge) in visibleEdges.enumerated() {
                        let angle = angle(for: index, count: visibleEdges.count)
                        let point = CGPoint(
                            x: center.x + CGFloat(cos(angle)) * radius,
                            y: center.y + CGFloat(sin(angle)) * radius
                        )
                        var path = Path()
                        path.move(to: center)
                        path.addLine(to: point)
                        let dash: [CGFloat] = edge.visualTone == .unfriendly ? [6, 4] : []
                        context.stroke(
                            path,
                            with: .color(edge.visualTone.lineColor.opacity(0.16)),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: dash)
                        )
                        context.stroke(
                            path,
                            with: .color(edge.visualTone.lineColor.opacity(0.78)),
                            style: StrokeStyle(lineWidth: edge.visualTone == .intimate ? 2.4 : 2.0, lineCap: .round, dash: dash)
                        )
                    }
                }

                ForEach(Array(visibleEdges.enumerated()), id: \.element.id) { index, edge in
                    let angle = angle(for: index, count: visibleEdges.count)
                    let point = CGPoint(
                        x: center.x + CGFloat(cos(angle)) * radius,
                        y: center.y + CGFloat(sin(angle)) * radius
                    )

                    Button {
                        onEditEdge(edge)
                    } label: {
                        RelationshipMiniNode(
                            initials: initials(for: edge.counterpartName(for: person.id)),
                            name: edge.counterpartName(for: person.id),
                            tag: edge.displayTag(priorities: priorities),
                            tone: edge.visualTone
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Edit relationship")
                    .position(point)
                }

                RelationshipMiniCenterNode(person: person)
                    .position(center)

                if edges.count > visibleEdges.count {
                    Text("+\(edges.count - visibleEdges.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.memoriaInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.memoriaGold.opacity(0.24))
                        .clipShape(Capsule())
                        .position(x: proxy.size.width - 28, y: proxy.size.height - 22)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func angle(for index: Int, count: Int) -> Double {
        guard count > 0 else { return -.pi / 2 }
        return Double(index) / Double(count) * Double.pi * 2 - Double.pi / 2
    }

    private func initials(for name: String) -> String {
        let parts = name
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        if parts.count >= 2 {
            return parts.prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
        }

        return String(name.prefix(2)).uppercased()
    }
}

private struct RelationshipMiniNode: View {
    let initials: String
    let name: String
    let tag: String
    let tone: RelationshipVisualTone

    var body: some View {
        VStack(spacing: 3) {
            Text(initials)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.memoriaInk)
                .frame(width: 34, height: 34)
                .background(tone.softFill)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(tone.lineColor.opacity(0.62), lineWidth: 1)
                }

            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(tag)
                .font(.caption2.weight(.medium))
                .foregroundStyle(tone.lineColor)
                .lineLimit(1)
        }
        .frame(width: 92)
        .padding(.vertical, 5)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tone.lineColor.opacity(0.24), lineWidth: 1)
        }
    }
}

private struct RelationshipMiniCenterNode: View {
    let person: FriendPerson

    var body: some View {
        VStack(spacing: 5) {
            Text(person.initials)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.memoriaInk)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color.memoriaGold.opacity(0.68), lineWidth: 1.4)
                }
            Text(person.displayName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .frame(width: 92)
    }
}

private struct ClosenessRangeBar: View {
    let level: Int
    let language: LanguagePreference

    private var isChinese: Bool {
        resolvedLanguage(language) == .zhCN
    }

    private var clampedLevel: Int {
        min(max(level, 1), 6)
    }

    private var markerRatio: CGFloat {
        CGFloat(6 - clampedLevel) / 5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let width = max(proxy.size.width - 18, 1)
                let x = markerRatio * width + 9

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.memoriaGold.opacity(0.9),
                                    Color.memoriaSage.opacity(0.62),
                                    Color.primary.opacity(0.12)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 10)

                    Circle()
                        .fill(.background)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Circle()
                                .stroke(Color.memoriaInk, lineWidth: 2)
                        }
                        .shadow(color: Color.primary.opacity(0.16), radius: 5, y: 2)
                        .offset(x: x - 9)
                }
                .frame(height: 20)
            }
            .frame(height: 20)

            HStack {
                Text(isChinese ? "亲密" : "Intimate")
                Spacer()
                Text(isChinese ? "生疏" : "Distant")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isChinese ? "亲近度 \(clampedLevel)，左侧亲密，右侧生疏" : "Closeness \(clampedLevel), intimate on the left and distant on the right")
    }
}

private struct ProfileFactsTable: View {
    let title: String
    let facts: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(facts.enumerated()), id: \.offset) { index, fact in
                    ProfileFactRow(label: fact.0, value: fact.1)
                    if index < facts.count - 1 {
                        Divider()
                    }
                }
            }
            .background(Color.primary.opacity(0.025))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProfileFactRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 108, alignment: .leading)
                .lineLimit(2)

            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : value)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct DossierHighlightCard: View {
    let title: String
    let systemImage: String
    let lines: [String]

    private var visibleLines: [String] {
        lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            if visibleLines.isEmpty {
                Text("—")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleLines.prefix(3), id: \.self) { line in
                    Text(line)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct ProfileCategoryCard: View {
    let category: PersonProfileCategory
    let value: String
    let language: LanguagePreference

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.title(for: language))
                .font(.caption.weight(.semibold))
            Text(value.isEmpty ? category.fieldExamples : value)
                .font(.caption)
                .foregroundStyle(value.isEmpty ? .secondary : .primary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct GiftRecommendationCard: View {
    let gift: GiftIdea
    let isChinese: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(gift.title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Label(gift.rationale, systemImage: "checkmark.seal")
                Label(gift.risk, systemImage: "exclamationmark.triangle")
                Label(gift.confirmationQuestion, systemImage: "questionmark.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ScoreBadge(label: isChinese ? "匹配度" : "Match", value: "\(gift.matchScore)")
                ScoreBadge(label: isChinese ? "惊喜度" : "Surprise", value: "\(gift.surpriseScore)")
                ScoreBadge(label: isChinese ? "风险" : "Risk", value: gift.riskLevel)
            }

            HStack(spacing: 8) {
                ScoreBadge(label: isChinese ? "实用性" : "Use", value: gift.practicality)
                ScoreBadge(label: isChinese ? "情感价值" : "Emotion", value: gift.emotionalValue)
                ScoreBadge(label: isChinese ? "需补充" : "Need Info", value: gift.needsMoreInfo ? (isChinese ? "是" : "Yes") : (isChinese ? "否" : "No"))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ScoreBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ProfilePill: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.quaternary)
            .clipShape(Capsule())
    }
}
