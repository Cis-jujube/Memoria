import SwiftUI
import MemoriaCore

struct InboxView: View {
    @ObservedObject var store: DashboardStore
    @FocusState private var focusedReviewID: String?
    @State private var skippedUpdateIDs: [PendingUpdate.ID] = []

    private var isChinese: Bool {
        resolvedLanguage(store.settings.language) == .zhCN
    }

    private var selectedCategory: ReviewCategory? {
        store.selectedReviewCategory
    }

    private var visibleUpdates: [PendingUpdate] {
        let base: [PendingUpdate]
        if let selectedCategory {
            base = store.pendingUpdates
                .filter { $0.reviewCategory == selectedCategory }
                .deduplicatedForReviewDisplay()
        } else {
            base = store.pendingUpdates.deduplicatedForReviewDisplay()
        }
        let skipped = Set(skippedUpdateIDs)
        return base.filter { !skipped.contains($0.id) } + base.filter { skipped.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isChinese ? "整理台" : store.copy.aiInboxTitle)
                        .font(.title2.weight(.semibold))

                    Text(isChinese ? "总览和三类分区共用同一批待确认项；批准一次后立即入库，不会再出现第二次确认。" : "Overview and categories share the same pending proposals. One approval saves the item; no second confirmation appears.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                categoryPicker

                if let undoable = store.recentUndoableUpdate {
                    undoBanner(undoable)
                }

                if store.pendingUpdates.isEmpty {
                    EmptyState(
                        systemImage: "tray",
                        title: isChinese ? "整理台是空的" : "AI Inbox is clear",
                        detail: isChinese ? "新记录和导入内容会先停在这里等待批准。" : "New captures and imports will wait here for review."
                    )
                    .frame(minHeight: 420)
                    .focusable()
                    .focused($focusedReviewID, equals: "empty")
                } else if visibleUpdates.isEmpty {
                    EmptyState(
                        systemImage: selectedCategory?.systemImage ?? "tray",
                        title: isChinese ? "这个分区没有待确认项" : "No pending items in this category",
                        detail: isChinese ? "切回总览可以查看全部整理建议。" : "Switch back to Overview to see every proposal."
                    )
                    .frame(minHeight: 360)
                    .focusable()
                    .focused($focusedReviewID, equals: "empty")
                } else {
                    ForEach(visibleUpdates) { update in
                        PendingUpdateCard(
                            update: update,
                            people: store.people,
                            language: store.settings.language,
                            whySuggestedLabel: store.copy.whySuggested,
                            onEditMemory: { draft in
                                store.editMemoryReview(
                                    update,
                                    title: draft.title,
                                    summary: draft.summary,
                                    content: draft.content,
                                    memoryType: draft.memoryType,
                                    targetPersonID: draft.targetPersonID,
                                    targetDisplayName: draft.targetDisplayName,
                                    reminderDueAt: draft.reminderDueAt,
                                    reminderDueLabel: draft.reminderDueLabel,
                                    giftBudgetHint: draft.giftBudgetHint,
                                    giftOccasion: draft.giftOccasion,
                                    giftRisk: draft.giftRisk,
                                    giftConfirmationQuestion: draft.giftConfirmationQuestion,
                                    giftRiskTags: draft.giftRiskTags
                                )
                            },
                            onEditProfilePatch: { draft in
                                store.editProfilePatchReview(
                                    update,
                                    targetPersonID: draft.targetPersonID,
                                    targetDisplayName: draft.targetDisplayName,
                                    profileCategory: draft.profileCategory,
                                    proposedValue: draft.proposedValue,
                                    valueStruct: draft.valueStruct
                                )
                            },
                            onConfirm: {
                                let next = nextReviewID(after: update)
                                store.confirm(update)
                                focusedReviewID = next
                            },
                            onDiscard: { reason in
                                let next = nextReviewID(after: update)
                                store.discard(update, reason: reason)
                                skippedUpdateIDs.removeAll { $0 == update.id }
                                focusedReviewID = next
                            },
                            onSkip: {
                                let next = nextReviewID(after: update)
                                if !skippedUpdateIDs.contains(update.id) {
                                    skippedUpdateIDs.append(update.id)
                                }
                                focusedReviewID = next
                            }
                        )
                        .focusable()
                        .focused($focusedReviewID, equals: update.id)
                    }
                }
            }
            .padding(24)
        }
        .onChange(of: visibleUpdates.map(\.id)) { _, ids in
            skippedUpdateIDs.removeAll { !ids.contains($0) }
            if let focusedReviewID, ids.contains(focusedReviewID) {
                return
            }
            focusedReviewID = ids.first ?? "empty"
        }
    }

    private var categoryPicker: some View {
        Picker(isChinese ? "整理分区" : "Review Category", selection: selectedCategoryID) {
            Text(isChinese ? "总览 \(store.pendingUpdates.count)" : "Overview \(store.pendingUpdates.count)").tag("all")
            ForEach(ReviewCategory.allCases) { category in
                Text("\(category.title(for: store.settings.language)) \(count(for: category))").tag(category.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 680)
    }

    private func undoBanner(_ update: PendingUpdate) -> some View {
        HStack(spacing: 12) {
            Label(isChinese ? "刚才的保存可以撤销" : "Last approval can be undone", systemImage: "arrow.uturn.backward")
                .font(.callout.weight(.medium))
            Spacer()
            Button {
                store.undoLastApproval()
            } label: {
                Label(isChinese ? "撤销刚才的保存" : "Undo last save", systemImage: "arrow.uturn.backward.circle")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(isChinese ? "撤销刚才的保存" : "Undo last save")
            .accessibilityIdentifier("pending-update-undo-\(update.id)")
        }
        .padding(12)
        .background(Color.memoriaGold.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func count(for category: ReviewCategory) -> Int {
        store.pendingUpdates.filter { $0.reviewCategory == category }.count
    }

    private func nextReviewID(after update: PendingUpdate) -> String {
        guard let index = visibleUpdates.firstIndex(where: { $0.id == update.id }) else {
            return visibleUpdates.first?.id ?? "empty"
        }
        let nextIndex = visibleUpdates.index(after: index)
        if nextIndex < visibleUpdates.endIndex {
            return visibleUpdates[nextIndex].id
        }
        return visibleUpdates.first(where: { $0.id != update.id })?.id ?? "empty"
    }

    private var selectedCategoryID: Binding<String> {
        Binding(
            get: { store.selectedReviewCategory?.rawValue ?? "all" },
            set: { value in
                store.selectedReviewCategory = ReviewCategory(rawValue: value)
            }
        )
    }
}

private extension Array where Element == PendingUpdate {
    func deduplicatedForReviewDisplay() -> [PendingUpdate] {
        var seenKeys = Set<String>()
        return filter { update in
            seenKeys.insert(update.reviewDisplayDedupeKey).inserted
        }
    }
}

private extension PendingUpdate {
    var reviewDisplayDedupeKey: String {
        [
            sourceEntryID ?? "no-source",
            proposalType.rawValue,
            title,
            summary.isEmpty ? evidence : summary
        ]
        .joined(separator: "|")
        .lowercased()
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
    }
}

private struct ReviewStatusLabel: Identifiable {
    let text: String
    let systemImage: String
    let tint: Color

    var id: String { text }
}

private struct ReviewExplanationRow: Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

private struct MemoryReviewDraft {
    let title: String
    let summary: String
    let content: String
    let memoryType: MemoryAtomType?
    let targetPersonID: String?
    let targetDisplayName: String?
    let reminderDueAt: String?
    let reminderDueLabel: String?
    let giftBudgetHint: String?
    let giftOccasion: String?
    let giftRisk: String?
    let giftConfirmationQuestion: String?
    let giftRiskTags: [GiftSocialRisk]?
}

private struct ProfilePatchReviewDraft {
    let targetPersonID: String?
    let targetDisplayName: String
    let profileCategory: PersonProfileCategory
    let proposedValue: String
    let valueStruct: ProfileValueStruct?
}

private struct PendingUpdateCard: View {
    let update: PendingUpdate
    let people: [FriendPerson]
    let language: LanguagePreference
    let whySuggestedLabel: String
    let onEditMemory: (MemoryReviewDraft) -> Void
    let onEditProfilePatch: (ProfilePatchReviewDraft) -> Void
    let onConfirm: () -> Void
    let onDiscard: (String?) -> Void
    let onSkip: () -> Void
    @State private var isEditing = false
    @State private var sourceExpanded = false
    @State private var riskAcknowledged = false
    @State private var rejectReasonDraft = ""
    @State private var titleDraft = ""
    @State private var summaryDraft = ""
    @State private var contentDraft = ""
    @State private var targetPersonIDDraft = ""
    @State private var targetDisplayNameDraft = ""
    @State private var memoryTypeDraft: MemoryAtomType = .personalReflection
    @State private var profileCategoryDraft: PersonProfileCategory = .identity
    @State private var proposedValueDraft = ""
    @State private var reminderDueAtDraft = ""
    @State private var reminderDueLabelDraft = ""
    @State private var giftBudgetDraft = ""
    @State private var giftOccasionDraft = ""
    @State private var giftRiskDraft = ""
    @State private var giftConfirmationQuestionDraft = ""
    @State private var giftRiskTagsDraft = ""
    @State private var valueKindDraft = ""
    @State private var valueDateLabelDraft = ""
    @State private var valueMonthDraft = ""
    @State private var valueDayDraft = ""
    @State private var valueYearDraft = ""
    @State private var valueItemDraft = ""
    @State private var valueSeverityDraft = ""
    @State private var valueChannelDraft = ""
    @State private var valueTextDraft = ""
    @State private var valueVisibilityDraft = ""

    private var isChinese: Bool {
        resolvedLanguage(language) == .zhCN
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if isEditing {
                editForm
            } else {
                readOnlySummary
            }

            oldNewComparison
            explanationBlock
            freshnessBlock
            metadataChips
            sourceDisclosure
            actionBar
        }
        .memoriaCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pending-update-card-\(update.id)")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.headline)
                .foregroundStyle(Color.memoriaGold)
                .frame(width: 34, height: 34)
                .background(Color.memoriaGold.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    ForEach(Array(statusLabels.prefix(2))) { label in
                        Label(label.text, systemImage: label.systemImage)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(label.tint.opacity(0.12))
                            .foregroundStyle(label.tint)
                            .clipShape(Capsule())
                    }

                    Label(update.reviewCategory.title(for: language), systemImage: update.reviewCategory.systemImage)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.memoriaSage.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(update.title)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(writeDestinationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(targetText)，\(update.title)，\(statusAccessibilityText)，将写入 \(writeDestinationText)")
        .accessibilityHint(isChinese ? "继续浏览可查看来源原文、判断依据和操作按钮" : "Continue to review source quote, rationale, and action buttons.")
    }

    private var readOnlySummary: some View {
        Text(update.summary)
            .font(.body)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            DraftField(label: isChinese ? "标题" : "Title", text: $titleDraft, lineLimit: 1...2)
            DraftField(label: isChinese ? "摘要" : "Summary", text: $summaryDraft, lineLimit: 2...4)
            DraftField(label: isChinese ? "正文/原子记忆" : "Content", text: $contentDraft, lineLimit: 4...7)

            DraftField(label: isChinese ? "目标人物 ID（可空）" : "Target person ID (optional)", text: $targetPersonIDDraft, lineLimit: 1...1)
            DraftField(label: isChinese ? "目标人物显示名" : "Target display name", text: $targetDisplayNameDraft, lineLimit: 1...2)

            if update.profilePatchProposal != nil {
                Picker(isChinese ? "朋友档案类别" : "Profile category", selection: $profileCategoryDraft) {
                    ForEach(PersonProfileCategory.allCases) { category in
                        Text(category.title(for: language)).tag(category)
                    }
                }
                DraftField(label: isChinese ? "新建议" : "Proposed value", text: $proposedValueDraft, lineLimit: 2...5)
                valueStructEditor
            } else {
                Picker(isChinese ? "写入位置" : "Destination", selection: $memoryTypeDraft) {
                    ForEach(MemoryAtomType.allCases, id: \.rawValue) { type in
                        Text(type.displayName(for: language)).tag(type)
                    }
                }
            }

            if update.structuredReviewContext?.reminder != nil {
                candidateSelector
                DraftField(label: isChinese ? "提醒日期（ISO，可空则不可批准）" : "Due date (ISO, required before approval)", text: $reminderDueAtDraft, lineLimit: 1...1)
                DraftField(label: isChinese ? "日期来源说明" : "Due label", text: $reminderDueLabelDraft, lineLimit: 1...2)
            }

            if update.structuredReviewContext?.giftSignal != nil {
                candidateSelector
                DraftField(label: isChinese ? "预算" : "Budget", text: $giftBudgetDraft, lineLimit: 1...1)
                DraftField(label: isChinese ? "场合" : "Occasion", text: $giftOccasionDraft, lineLimit: 1...1)
                DraftField(label: isChinese ? "风险标签（逗号分隔）" : "Risk tags (comma separated)", text: $giftRiskTagsDraft, lineLimit: 1...2)
                DraftField(label: isChinese ? "风险说明" : "Risk", text: $giftRiskDraft, lineLimit: 2...4)
                DraftField(label: isChinese ? "确认问题" : "Confirmation question", text: $giftConfirmationQuestionDraft, lineLimit: 2...4)
            }
        }
        .padding(14)
        .background(Color.memoriaSage.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.memoriaSage.opacity(0.24), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var candidateSelector: some View {
        let candidateIDs = update.structuredReviewContext?.reminder?.candidatePersonIDs ??
            update.structuredReviewContext?.giftSignal?.candidatePersonIDs ?? []
        let candidates = candidateIDs.compactMap { id in people.first { $0.id == id } }
        if !candidates.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(isChinese ? "找到多个可能的人，请选一个" : "Multiple possible people found")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(candidates) { person in
                        Button {
                            targetPersonIDDraft = person.id
                            targetDisplayNameDraft = person.displayName
                        } label: {
                            Label(
                                person.displayName,
                                systemImage: targetPersonIDDraft == person.id ? "checkmark.circle.fill" : "person.crop.circle"
                            )
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var valueStructEditor: some View {
        if [.anniversaries, .dietaryAllergy, .contact].contains(profileCategoryDraft) {
            VStack(alignment: .leading, spacing: 10) {
                Text(isChinese ? "结构化字段" : "Structured value")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                switch profileCategoryDraft {
                case .anniversaries:
                    DraftField(label: isChinese ? "类型（birthday/anniversary/exam/work_start/other）" : "Kind", text: $valueKindDraft, lineLimit: 1...1)
                    DraftField(label: isChinese ? "原文日期" : "Date label", text: $valueDateLabelDraft, lineLimit: 1...1)
                    HStack {
                        DraftField(label: isChinese ? "月" : "Month", text: $valueMonthDraft, lineLimit: 1...1)
                        DraftField(label: isChinese ? "日" : "Day", text: $valueDayDraft, lineLimit: 1...1)
                        DraftField(label: isChinese ? "年（可空）" : "Year", text: $valueYearDraft, lineLimit: 1...1)
                    }
                case .dietaryAllergy:
                    DraftField(label: isChinese ? "类型（dislike/allergy/religious/health/unknown）" : "Kind", text: $valueKindDraft, lineLimit: 1...1)
                    DraftField(label: isChinese ? "对象" : "Item", text: $valueItemDraft, lineLimit: 1...1)
                    DraftField(label: isChinese ? "严重度（low/medium/high/unknown）" : "Severity", text: $valueSeverityDraft, lineLimit: 1...1)
                case .contact:
                    DraftField(label: isChinese ? "渠道（wechat/phone/email/instagram/linkedin/other）" : "Channel", text: $valueChannelDraft, lineLimit: 1...1)
                    DraftField(label: isChinese ? "值" : "Value", text: $valueTextDraft, lineLimit: 1...2)
                    DraftField(label: isChinese ? "可见性（private/normal）" : "Visibility", text: $valueVisibilityDraft, lineLimit: 1...1)
                default:
                    EmptyView()
                }
            }
        }
    }

    private var metadataChips: some View {
        HStack(spacing: 8) {
            ForEach(update.relatedPeople, id: \.displayName) { person in
                Label(maskIfSensitive(person.displayName), systemImage: "person")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            ForEach(update.themeNames, id: \.self) { theme in
                Text(theme)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private var oldNewComparison: some View {
        if let patch = update.profilePatchProposal {
            VStack(alignment: .leading, spacing: 10) {
                Text(isChinese ? "旧值 vs 新建议" : "Existing vs proposed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Label(isChinese ? "旧值：\(oldProfileValue(for: patch))" : "Existing: \(oldProfileValue(for: patch))", systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(.secondary)
                    Label(isChinese ? "新建议：\(maskIfSensitive(patch.proposedValue))" : "Proposed: \(maskIfSensitive(patch.proposedValue))", systemImage: "sparkles")
                        .foregroundStyle(.primary)
                }
                .font(.callout)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.memoriaSage.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @ViewBuilder
    private var explanationBlock: some View {
        let explanations = explanationRows
        if !explanations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(isChinese ? "判断依据" : "Review rationale")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(explanations) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(row.value)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityIdentifier("pending-update-explanation-\(update.id)")
        }
    }

    @ViewBuilder
    private var freshnessBlock: some View {
        if let freshness = update.freshness {
            Label(freshnessText(freshness), systemImage: freshnessIcon(freshness.effectiveStatus))
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var sourceDisclosure: some View {
        VStack(alignment: .leading, spacing: 6) {
            DisclosureGroup(isExpanded: $sourceExpanded) {
                Text(maskIfSensitive(update.evidence))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(sourceExpanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            } label: {
                Label(isChinese ? "来自这句话" : "Source quote", systemImage: "quote.bubble")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(sourceExpanded ? (isChinese ? "收起来源原文" : "Collapse source quote") : (isChinese ? "展开来源原文" : "Expand source quote"))
            .accessibilityIdentifier("pending-update-source-\(update.id)")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var actionBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if update.isAIInferred {
                    Label(isChinese ? "AI 推断，需要确认" : "AI inferred, needs review", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if update.profilePatchProposal != nil {
                    Label(isChinese ? "批准后写入朋友档案" : "Approves into People", systemImage: "person.text.rectangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if highRiskGiftNeedsAcknowledgement {
                Toggle(isChinese ? "已确认送礼风险和确认问题" : "Gift risk and confirmation question reviewed", isOn: $riskAcknowledged)
                    .font(.callout)
            }

            DraftField(label: isChinese ? "拒绝原因（可选）" : "Reject reason (optional)", text: $rejectReasonDraft, lineLimit: 1...3)

            if let approvalBlockReason {
                Label(approvalBlockReason, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                Spacer()

                if isEditing {
                    Button(isChinese ? "放弃修改" : "Cancel") {
                        isEditing = false
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    Button {
                        saveDrafts()
                        isEditing = false
                        onConfirm()
                    } label: {
                        Label(isChinese ? "保存修改并批准" : "Save and approve", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(approvalBlockReason != nil)
                    Button {
                        saveDrafts()
                        isEditing = false
                    } label: {
                        Label(isChinese ? "保存修改并继续审核" : "Save edits", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        beginEditing()
                    } label: {
                        Label(isChinese ? "编辑" : "Edit", systemImage: "pencil")
                    }
                    .keyboardShortcut("e", modifiers: [.command])
                    .accessibilityLabel(isChinese ? "编辑这条建议" : "Edit this suggestion")
                    .accessibilityIdentifier("pending-update-edit-\(update.id)")

                    Button(action: onConfirm) {
                        Label(isChinese ? "批准" : "Approve", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(approvalBlockReason != nil)
                    .help(approvalBlockReason ?? "")
                    .accessibilityLabel(isChinese ? "批准并保存这条建议" : "Approve and save this suggestion")
                    .accessibilityIdentifier("pending-update-approve-\(update.id)")

                    Button(role: .destructive) {
                        onDiscard(rejectReasonDraft)
                    } label: {
                        Label(isChinese ? "拒绝" : "Reject", systemImage: "xmark")
                    }
                    .keyboardShortcut(.delete, modifiers: [])
                    .accessibilityLabel(isChinese ? "拒绝这条建议" : "Reject this suggestion")
                    .accessibilityIdentifier("pending-update-reject-\(update.id)")

                    Button {
                        onSkip()
                    } label: {
                        Label(isChinese ? "跳过" : "Skip", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var highRiskGiftNeedsAcknowledgement: Bool {
        update.structuredReviewContext?.giftSignal?.riskTags.isEmpty == false
    }

    private var approvalBlockReason: String? {
        if let reminder = update.structuredReviewContext?.reminder {
            if reminder.needsSlotConfirmation || !reminder.confirmationBlockers.isEmpty {
                let reasons = reminder.confirmationReasons.isEmpty
                    ? reminder.confirmationBlockers.map(\.code)
                    : reminder.confirmationReasons
                let suffix = reasons.isEmpty ? "" : " · \(reasons.joined(separator: ", "))"
                return isChinese
                    ? "行程还缺必要信息，不能直接批准执行\(suffix)。"
                    : "Schedule still needs required details before approval\(suffix)."
            }
            let dueAt = reminder.dueAt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if dueAt.isEmpty && reminder.scheduleExecutionState == "executable_reminder" {
                return isChinese ? "未定日期：先编辑并确认具体提醒日期。" : "Date unclear: edit and confirm a due date first."
            }
            if !reminder.candidatePersonIDs.isEmpty, reminder.targetPersonID == nil {
                return isChinese ? "找到多个可能的人，请先选择目标人物。" : "Multiple possible people found. Choose a target first."
            }
        }
        if let gift = update.structuredReviewContext?.giftSignal {
            if !gift.candidatePersonIDs.isEmpty, gift.targetPersonID == nil {
                return isChinese ? "找到多个可能的人，请先选择礼物对象。" : "Multiple possible people found. Choose the gift target first."
            }
            if !gift.riskTags.isEmpty, !riskAcknowledged {
                return isChinese ? "高风险礼物：先确认风险问题。" : "High-risk gift signal: review the risk first."
            }
        }
        return nil
    }

    private func beginEditing() {
        titleDraft = update.title
        summaryDraft = update.summary
        contentDraft = update.proposal?.content ?? update.summary
        if let proposal = update.proposal {
            memoryTypeDraft = proposal.memoryType
            targetPersonIDDraft = proposal.relatedPeople.first?.matchedPersonID ?? ""
            targetDisplayNameDraft = proposal.relatedPeople.first?.displayName ?? ""
        }
        if let patch = update.profilePatchProposal {
            targetPersonIDDraft = patch.targetPersonID ?? ""
            targetDisplayNameDraft = patch.targetDisplayName
            profileCategoryDraft = patch.profileCategory
            proposedValueDraft = patch.proposedValue
            populateValueStruct(patch.valueStruct)
        }
        if let reminder = update.structuredReviewContext?.reminder {
            reminderDueAtDraft = reminder.dueAt ?? ""
            reminderDueLabelDraft = reminder.dueLabel
            targetPersonIDDraft = reminder.targetPersonID ?? targetPersonIDDraft
            targetDisplayNameDraft = reminder.targetDisplayName ?? targetDisplayNameDraft
        }
        if let gift = update.structuredReviewContext?.giftSignal {
            giftBudgetDraft = gift.budgetHint ?? ""
            giftOccasionDraft = gift.occasion ?? ""
            giftRiskDraft = gift.risk
            giftConfirmationQuestionDraft = gift.confirmationQuestion
            giftRiskTagsDraft = gift.riskTags.map(\.rawValue).joined(separator: ", ")
            targetPersonIDDraft = gift.targetPersonID ?? targetPersonIDDraft
            targetDisplayNameDraft = gift.targetDisplayName ?? targetDisplayNameDraft
        }
        isEditing = true
    }

    private func saveDrafts() {
        if update.profilePatchProposal != nil {
            onEditProfilePatch(
                ProfilePatchReviewDraft(
                    targetPersonID: targetPersonIDDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    targetDisplayName: targetDisplayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines),
                    profileCategory: profileCategoryDraft,
                    proposedValue: proposedValueDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? update.summary : proposedValueDraft,
                    valueStruct: makeValueStruct()
                )
            )
        } else {
            onEditMemory(
                MemoryReviewDraft(
                    title: titleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? update.title : titleDraft,
                    summary: summaryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? update.summary : summaryDraft,
                    content: contentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? update.summary : contentDraft,
                    memoryType: memoryTypeDraft,
                    targetPersonID: targetPersonIDDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    targetDisplayName: targetDisplayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    reminderDueAt: reminderDueAtDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    reminderDueLabel: reminderDueLabelDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    giftBudgetHint: giftBudgetDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    giftOccasion: giftOccasionDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    giftRisk: giftRiskDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    giftConfirmationQuestion: giftConfirmationQuestionDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    giftRiskTags: parsedRiskTags()
                )
            )
        }
    }

    private func populateValueStruct(_ valueStruct: ProfileValueStruct?) {
        valueKindDraft = valueStruct?.kind ?? ""
        valueDateLabelDraft = valueStruct?.dateLabel ?? ""
        valueMonthDraft = valueStruct?.month.map(String.init) ?? ""
        valueDayDraft = valueStruct?.day.map(String.init) ?? ""
        valueYearDraft = valueStruct?.year.map(String.init) ?? ""
        valueItemDraft = valueStruct?.item ?? ""
        valueSeverityDraft = valueStruct?.severity ?? ""
        valueChannelDraft = valueStruct?.channel ?? ""
        valueTextDraft = valueStruct?.value ?? ""
        valueVisibilityDraft = valueStruct?.visibility ?? ""
    }

    private func makeValueStruct() -> ProfileValueStruct? {
        switch profileCategoryDraft {
        case .anniversaries:
            return ProfileValueStruct(
                kind: valueKindDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                dateLabel: valueDateLabelDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                month: Int(valueMonthDraft.trimmingCharacters(in: .whitespacesAndNewlines)),
                day: Int(valueDayDraft.trimmingCharacters(in: .whitespacesAndNewlines)),
                year: Int(valueYearDraft.trimmingCharacters(in: .whitespacesAndNewlines))
            )
        case .dietaryAllergy:
            return ProfileValueStruct(
                kind: valueKindDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                item: valueItemDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                severity: valueSeverityDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
        case .contact:
            return ProfileValueStruct(
                channel: valueChannelDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                value: valueTextDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                visibility: valueVisibilityDraft.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
        default:
            return nil
        }
    }

    private func parsedRiskTags() -> [GiftSocialRisk]? {
        let tags = giftRiskTagsDraft
            .split { $0 == "," || $0 == "，" || $0 == " " || $0 == "\n" }
            .compactMap { GiftSocialRisk(rawValue: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
        return tags.isEmpty ? nil : tags
    }

    private var targetText: String {
        if let patch = update.profilePatchProposal {
            return patch.targetDisplayName
        }
        if let person = update.relatedPeople.first {
            return person.displayName
        }
        return update.reviewCategory.title(for: language)
    }

    private var writeDestinationText: String {
        if let patch = update.profilePatchProposal {
            return isChinese
                ? "将写入：朋友档案的「\(patch.profileCategory.title(for: language))」"
                : "Writes to People · \(patch.profileCategory.title(for: language))"
        }
        return isChinese
            ? "将写入：\(update.reviewCategory.title(for: language))"
            : "Writes to \(update.reviewCategory.title(for: language))"
    }

    private var statusLabels: [ReviewStatusLabel] {
        var labels: [ReviewStatusLabel] = []
        if update.errorMessage != nil {
            labels.append(ReviewStatusLabel(text: isChinese ? "AI 输出结构不完整" : "Schema issue", systemImage: "exclamationmark.triangle", tint: .orange))
        }
        if update.sensitivity == .private {
            labels.append(ReviewStatusLabel(text: isChinese ? "私密内容" : "Private", systemImage: "lock", tint: Color.memoriaGold))
        } else if update.sensitivity == .sensitive {
            labels.append(ReviewStatusLabel(text: isChinese ? "敏感内容" : "Sensitive", systemImage: "lock.shield", tint: Color.memoriaGold))
        }
        if update.isAIInferred {
            labels.append(ReviewStatusLabel(text: isChinese ? "AI 推断" : "AI inferred", systemImage: "sparkles", tint: Color.secondary))
        }
        if update.structuredReviewContext?.reminder?.dueAt == nil,
           update.reviewCategory == .schedule {
            labels.append(ReviewStatusLabel(text: isChinese ? "未定日期" : "Date unclear", systemImage: "calendar.badge.exclamationmark", tint: .orange))
        }
        if update.structuredReviewContext?.reminder?.needsSlotConfirmation == true {
            labels.append(ReviewStatusLabel(text: isChinese ? "需补充槽位" : "Needs details", systemImage: "questionmark.circle", tint: .orange))
        }
        if update.structuredReviewContext?.giftSignal?.riskTags.isEmpty == false {
            labels.append(ReviewStatusLabel(text: isChinese ? "高风险礼物" : "Gift risk", systemImage: "giftcard", tint: .orange))
        }
        if labels.isEmpty {
            labels.append(ReviewStatusLabel(text: update.type, systemImage: "checkmark.seal", tint: Color.secondary))
        }
        return labels
    }

    private var statusAccessibilityText: String {
        statusLabels.map(\.text).joined(separator: "，")
    }

    private var explanationRows: [ReviewExplanationRow] {
        if let explanation = update.reviewExplanation {
            let baseRows: [(String, String?)] = [
                (isChinese ? "为什么是这个人" : "Target rationale", explanation.targetMatchReason),
                (isChinese ? "为什么归到这里" : "Category rationale", explanation.categoryReason),
                (isChinese ? "为什么日期这样处理" : "Date rationale", explanation.dateParseReason),
                (isChinese ? "送礼前需要确认" : "Gift risk", explanation.riskReason),
                (isChinese ? "可信度依据" : "Confidence rationale", explanation.confidenceReason)
            ]
            var rows: [ReviewExplanationRow] = baseRows.compactMap { label, value in
                guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return ReviewExplanationRow(label: label, value: value)
            }
            if let reminder = update.structuredReviewContext?.reminder {
                let subtype = [reminder.scheduleSubtype, reminder.scheduleExecutionState]
                    .compactMap { $0 }
                    .joined(separator: " / ")
                if !subtype.isEmpty {
                    rows.append(ReviewExplanationRow(label: isChinese ? "行程边界" : "Schedule boundary", value: subtype))
                }
                if !reminder.confirmationReasons.isEmpty {
                    rows.append(
                        ReviewExplanationRow(
                            label: isChinese ? "还需确认" : "Still needs",
                            value: reminder.confirmationReasons.joined(separator: ", ")
                        )
                    )
                }
            }
            return rows
        }

        if let patch = update.profilePatchProposal {
            return [
                ReviewExplanationRow(label: isChinese ? "为什么是这个人" : "Target rationale", value: isChinese ? "目标人物来自 AI 提取，可在批准前编辑。" : "The target person comes from AI extraction and can be edited before approval."),
                ReviewExplanationRow(label: isChinese ? "为什么归到这里" : "Category rationale", value: isChinese ? "这条建议会写入朋友档案的「\(patch.profileCategory.title(for: language))」。" : "This proposal writes to the People category \(patch.profileCategory.title(for: language)).")
            ]
        }

        return [
            ReviewExplanationRow(label: isChinese ? "为什么归到这里" : "Category rationale", value: whySuggestedLabel),
            ReviewExplanationRow(label: isChinese ? "可信度依据" : "Confidence rationale", value: "\(Int(update.confidence * 100))%")
        ]
    }

    private func freshnessText(_ freshness: PendingUpdateFreshness) -> String {
        let status: String
        switch freshness.effectiveStatus {
        case "stale":
            status = isChinese ? "这条可能已经过期" : "This may be stale"
        case "conflict":
            status = isChinese ? "这条和旧记录冲突" : "This may conflict with older records"
        case "temporary":
            status = isChinese ? "这可能只是暂时状态" : "This may be temporary"
        case "superseded":
            status = isChinese ? "这条会替代旧记录" : "This supersedes an older record"
        default:
            status = isChinese ? "当前有效" : "Current"
        }
        if let lastObserved = freshness.lastObserved {
            return isChinese ? "\(status) · 最后确认：\(lastObserved)" : "\(status) · Last observed: \(lastObserved)"
        }
        return isChinese ? "\(status) · 最后确认时间未知" : "\(status) · Last observed unknown"
    }

    private func freshnessIcon(_ status: String) -> String {
        switch status {
        case "stale":
            return "clock.badge.questionmark"
        case "conflict":
            return "exclamationmark.triangle"
        case "temporary":
            return "hourglass"
        case "superseded":
            return "arrow.triangle.2.circlepath"
        default:
            return "checkmark.seal"
        }
    }

    private func maskIfSensitive(_ text: String) -> String {
        guard update.sensitivity != .normal else { return text }
        if update.profilePatchProposal?.profileCategory == .contact {
            return isChinese ? "联系方式：已隐藏，展开后查看" : "Contact details hidden. Expand to view."
        }
        return text
    }

    private func oldProfileValue(for patch: PersonProfilePatchProposal) -> String {
        let person = people.first { person in
            if let targetPersonID = patch.targetPersonID, person.id == targetPersonID {
                return true
            }
            return person.displayName.localizedCaseInsensitiveCompare(patch.targetDisplayName) == .orderedSame ||
                person.nickname.localizedCaseInsensitiveCompare(patch.targetDisplayName) == .orderedSame ||
                person.englishName.localizedCaseInsensitiveCompare(patch.targetDisplayName) == .orderedSame
        }
        let value = person?.categoryNote(patch.profileCategory).trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty {
            return isChinese ? "暂无旧值" : "No existing value"
        }
        return maskIfSensitive(value)
    }
}

private struct DraftField: View {
    let label: String
    @Binding var text: String
    let lineLimit: ClosedRange<Int>

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

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
