import SwiftUI
import MemoriaCore

struct FilesView: View {
    @ObservedObject var store: DashboardStore
    @State private var bulkImportText = ""

    private var isChinese: Bool {
        resolvedLanguage(store.settings.language) == .zhCN
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                bulkFriendImportPanel

                if let preview = store.importPreview {
                    importPreviewPanel(preview)
                }

                CountBarChart(title: "Import funnel", items: store.fileStatusCounts)

                if store.files.isEmpty {
                    EmptyState(
                        systemImage: "doc.badge.plus",
                        title: "No imported files",
                        detail: "Photos, PDFs, and chat exports will show parse status here."
                    )
                    .frame(minHeight: 420)
                } else {
                    ForEach(store.files) { file in
                        HStack(spacing: 14) {
                            Image(systemName: file.progress >= 1 ? "doc.text.magnifyingglass" : "doc.badge.clock")
                                .font(.title3)
                                .foregroundStyle(Color.memoriaSage)
                                .frame(width: 34)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(file.filename)
                                        .font(.headline)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Spacer()

                                    Text("\(Int(file.progress * 100))%")
                                        .font(.caption.monospacedDigit().weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }

                                ProgressView(value: file.progress)
                                    .tint(Color.memoriaSage)

                                Text(file.status)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .memoriaCard()
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 880, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isChinese ? "文件与导入" : "Files & Imports")
                .font(.largeTitle.weight(.semibold))

            Text(isChinese
                ? "CSV 或结构化文本会先进入预览；确认后只创建朋友草稿和待审核档案事实。"
                : "CSV or structured text is previewed first; confirmation creates friend drafts and reviewable profile facts."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bulkFriendImportPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.headline)
                    .foregroundStyle(Color.memoriaSage)
                    .frame(width: 32, height: 32)
                    .background(Color.memoriaSage.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(isChinese ? "批量导入朋友" : "Bulk Friend Import")
                        .font(.headline)
                    Text(isChinese
                        ? "支持 CSV 表头：display_name, nickname, relation_label, group, contact, birthday, food_preference, dietary_allergy, interests, notes。"
                        : "Supported CSV headers: display_name, nickname, relation_label, group, contact, birthday, food_preference, dietary_allergy, interests, notes."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            TextEditor(text: $bulkImportText)
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 150)
                .background(.quinary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }

            HStack {
                Button {
                    bulkImportText = sampleImportText
                } label: {
                    Label(isChinese ? "填入示例" : "Use Sample", systemImage: "text.badge.plus")
                }

                Button {
                    bulkImportText = ""
                } label: {
                    Label(isChinese ? "清空" : "Clear", systemImage: "xmark")
                }
                .disabled(bulkImportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()

                Button {
                    store.previewBulkFriendImport(text: bulkImportText, filename: "pasted-friends.csv")
                } label: {
                    Label(isChinese ? "生成预览" : "Preview Import", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .disabled(bulkImportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .memoriaCard()
    }

    private func importPreviewPanel(_ preview: TransferImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(isChinese ? "导入预览" : "Import Preview", systemImage: "doc.badge.gearshape")
                    .font(.headline)

                Spacer()

                Text(preview.filename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8)], alignment: .leading, spacing: 8) {
                ImportPreviewStat(label: isChinese ? "新增朋友" : "New people", value: preview.peopleToCreate)
                ImportPreviewStat(label: isChinese ? "更新朋友" : "Updated people", value: preview.peopleToUpdate)
                ImportPreviewStat(label: isChinese ? "待审事实" : "Profile facts", value: preview.profilePatchesToReview)
                ImportPreviewStat(label: isChinese ? "新增记忆" : "New memories", value: preview.memoriesToCreate)
                ImportPreviewStat(label: isChinese ? "更新记忆" : "Updated memories", value: preview.memoriesToUpdate)
                ImportPreviewStat(label: isChinese ? "关系边" : "Edges", value: preview.relationshipEdgesToCreate + preview.relationshipEdgesToUpdate)
            }

            if !preview.potentialDuplicateNames.isEmpty {
                Text(isChinese
                    ? "可能重复：\(preview.potentialDuplicateNames.joined(separator: "、"))。确认前请检查是否需要整理姓名或联系方式。"
                    : "Possible duplicates: \(preview.potentialDuplicateNames.joined(separator: ", ")). Review names or contact text before confirming."
                )
                .font(.caption)
                .foregroundStyle(Color.orange)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button {
                    store.cancelImportPreview()
                } label: {
                    Label(isChinese ? "取消" : "Cancel", systemImage: "xmark")
                }

                Spacer()

                Button {
                    store.confirmImportPreview()
                    bulkImportText = ""
                } label: {
                    Label(isChinese ? "确认导入到整理台" : "Confirm to Review", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(preview.totalChanges == 0)
            }
        }
        .memoriaCard()
    }

    private var sampleImportText: String {
        """
        display_name,nickname,relation_label,group,contact,birthday,food_preference,dietary_allergy,interests,notes
        Alex Chen,Alex,Friend,close,email alex@example.com,1999-05-02,火锅,不吃香菜,摄影,最近在准备作品集
        Riley Zhang,,Classmate,school,wechat riley_zhang,,咖啡,,机器学习,下次可以约自习
        """
    }
}

private struct ImportPreviewStat: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.title3.monospacedDigit().weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
