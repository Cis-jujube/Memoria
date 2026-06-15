import SwiftUI
import MemoriaCore

struct InboxView: View {
    @ObservedObject var store: DashboardStore

    private var isChinese: Bool {
        resolvedLanguage(store.settings.language) == .zhCN
    }

    private var selectedCategory: ReviewCategory? {
        store.selectedReviewCategory
    }

    private var visibleUpdates: [PendingUpdate] {
        guard let selectedCategory else {
            return store.pendingUpdates
        }
        return store.pendingUpdates.filter { $0.reviewCategory == selectedCategory }
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

                if store.pendingUpdates.isEmpty {
                    EmptyState(
                        systemImage: "tray",
                        title: isChinese ? "整理台是空的" : "AI Inbox is clear",
                        detail: isChinese ? "新记录和导入内容会先停在这里等待批准。" : "New captures and imports will wait here for review."
                    )
                    .frame(minHeight: 420)
                } else if visibleUpdates.isEmpty {
                    EmptyState(
                        systemImage: selectedCategory?.systemImage ?? "tray",
                        title: isChinese ? "这个分区没有待确认项" : "No pending items in this category",
                        detail: isChinese ? "切回总览可以查看全部整理建议。" : "Switch back to Overview to see every proposal."
                    )
                    .frame(minHeight: 360)
                } else {
                    ForEach(visibleUpdates) { update in
                        PendingUpdateCard(
                            update: update,
                            language: store.settings.language,
                            whySuggestedLabel: store.copy.whySuggested,
                            onEdit: { title, summary, content in
                                store.edit(update, title: title, summary: summary, content: content)
                            },
                            onConfirm: { store.confirm(update) },
                            onDiscard: { store.discard(update) }
                        )
                    }
                }
            }
            .padding(24)
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

    private func count(for category: ReviewCategory) -> Int {
        store.pendingUpdates.filter { $0.reviewCategory == category }.count
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

private struct PendingUpdateCard: View {
    let update: PendingUpdate
    let language: LanguagePreference
    let whySuggestedLabel: String
    let onEdit: (String, String, String) -> Void
    let onConfirm: () -> Void
    let onDiscard: () -> Void
    @State private var isEditing = false
    @State private var titleDraft = ""
    @State private var summaryDraft = ""
    @State private var contentDraft = ""

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

            metadataChips
            evidenceBlock
            actionBar
        }
        .memoriaCard()
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
                    Text(update.type)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(Capsule())

                    Label(update.reviewCategory.title(for: language), systemImage: update.reviewCategory.systemImage)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.memoriaSage.opacity(0.12))
                        .clipShape(Capsule())

                    Text("\(Int(update.confidence * 100))%")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(update.sensitivity.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(update.sensitivity == .normal ? .secondary : Color.memoriaGold)
                }

                Text(update.title)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(update.createdLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
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
        }
        .padding(14)
        .background(Color.memoriaSage.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.memoriaSage.opacity(0.24), lineWidth: 1)
        }
    }

    private var metadataChips: some View {
        HStack(spacing: 8) {
            ForEach(update.relatedPeople, id: \.displayName) { person in
                Label(person.displayName, systemImage: "person")
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

    private var evidenceBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(whySuggestedLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(update.evidence)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var actionBar: some View {
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

            if isEditing {
                Button(isChinese ? "取消" : "Cancel") {
                    isEditing = false
                }
                Button {
                    onEdit(
                        titleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? update.title : titleDraft,
                        summaryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? update.summary : summaryDraft,
                        contentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? update.summary : contentDraft
                    )
                    isEditing = false
                } label: {
                    Label(isChinese ? "保存修改" : "Save", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            } else {
                if update.proposal != nil {
                    Button {
                        titleDraft = update.title
                        summaryDraft = update.summary
                        contentDraft = update.proposal?.content ?? update.summary
                        isEditing = true
                    } label: {
                        Label(isChinese ? "编辑" : "Edit", systemImage: "pencil")
                    }
                }

                Button(role: .destructive, action: onDiscard) {
                    Label(isChinese ? "丢弃" : "Reject", systemImage: "xmark")
                }
                .keyboardShortcut(.delete, modifiers: [])

                Button(action: onConfirm) {
                    Label(isChinese ? "批准入库" : "Approve", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
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
