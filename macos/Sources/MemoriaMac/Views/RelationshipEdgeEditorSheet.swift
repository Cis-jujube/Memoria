import SwiftUI
import MemoriaCore

struct RelationshipEdgeDraft: Identifiable {
    let id: String
    let edge: RelationshipEdge
    var targetName: String
    var label: String
    var relationKind: String
    var strength: Double
    var tagsText: String
    var manualPrimaryTag: String

    init(edge: RelationshipEdge, priorities: [RelationshipTagPriority]) {
        id = edge.id
        self.edge = edge
        targetName = edge.targetName
        label = edge.label
        relationKind = edge.relationKind
        strength = edge.strength
        tagsText = edge.tags.joined(separator: "，")
        manualPrimaryTag = edge.manualPrimaryTag ?? edge.displayTag(priorities: priorities)
    }

    var tags: [String] {
        tagsText
            .split(whereSeparator: { separator in
                separator == "," || separator == "，" || separator == "\n" || separator == " "
            })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct RelationshipEdgeEditorSheet: View {
    @State private var draft: RelationshipEdgeDraft
    let language: LanguagePreference
    let onCancel: () -> Void
    let onSave: (RelationshipEdgeDraft) -> Void
    let onDelete: (RelationshipEdge) -> Void

    init(
        draft: RelationshipEdgeDraft,
        language: LanguagePreference,
        onCancel: @escaping () -> Void,
        onSave: @escaping (RelationshipEdgeDraft) -> Void,
        onDelete: @escaping (RelationshipEdge) -> Void
    ) {
        _draft = State(initialValue: draft)
        self.language = language
        self.onCancel = onCancel
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(isChinese ? "编辑关系" : "Edit Relationship")
                    .font(.title2.weight(.semibold))
                Text("\(draft.edge.sourceName) -> \(draft.edge.targetName)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(isChinese ? "对方名称" : "Target")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField(isChinese ? "对方名称" : "Target name", text: $draft.targetName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(isChinese ? "关系说明" : "Relationship Label")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField(isChinese ? "例如：男朋友 / 室友 / 项目伙伴" : "Example: partner / roommate / project collaborator", text: $draft.label)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isChinese ? "类型" : "Kind")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("friend / family / partner", text: $draft.relationKind)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(isChinese ? "强度 \(Int(draft.strength * 100))%" : "Strength \(Int(draft.strength * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Slider(value: $draft.strength, in: 0...1)
                        .frame(width: 160)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(isChinese ? "标签" : "Tags")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField(isChinese ? "用逗号分隔，如 核心朋友，室友" : "Comma-separated tags", text: $draft.tagsText)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(isChinese ? "优先显示标签" : "Primary Display Tag")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField(isChinese ? "星图上优先显示这个标签" : "Shown first on the map", text: $draft.manualPrimaryTag)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button(role: .destructive) {
                    onDelete(draft.edge)
                } label: {
                    Label(isChinese ? "删除关系" : "Delete", systemImage: "trash")
                }

                Spacer()

                Button(isChinese ? "取消" : "Cancel", action: onCancel)
                Button(isChinese ? "保存" : "Save") {
                    onSave(draft)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isInvalid)
            }
        }
        .padding(22)
        .frame(width: 520)
    }

    private var isInvalid: Bool {
        draft.targetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            draft.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isChinese: Bool {
        resolvedLanguage(language) == .zhCN
    }
}
