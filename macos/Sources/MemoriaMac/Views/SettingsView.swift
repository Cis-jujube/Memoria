import SwiftUI
import MemoriaCore
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: DashboardStore
    let embedded: Bool
    @AppStorage("memoriaAllowLocalNotifications") private var allowLocalNotifications = true
    @AppStorage("memoriaShowDemoSources") private var showDemoSources = true
    @AppStorage("memoriaHideSensitiveByDefault") private var hideSensitiveByDefault = true
    @AppStorage("memoriaDeveloperLogs") private var developerLogs = false
    @State private var apiKey = ""
    @State private var notificationStatus = ""
    @State private var isImportingData = false

    init(store: DashboardStore, embedded: Bool = false) {
        self.store = store
        self.embedded = embedded
    }

    var body: some View {
        Form {
            Section(store.copy.deepSeekSectionTitle) {
                SecureField(store.copy.apiKeyPlaceholder, text: $apiKey)

                Picker(store.copy.modelLabel, selection: modelBinding) {
                    ForEach(DeepSeekModel.allCases) { model in
                        Text(model.title).tag(model)
                    }
                }
                .pickerStyle(.segmented)

                Toggle(store.copy.deepThinkingLabel, isOn: deepThinkingBinding)

                HStack {
                    Button(store.copy.saveKey) {
                        store.saveAPIKey(apiKey)
                        apiKey = ""
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(store.copy.testConnection) {
                        store.testConnection()
                    }
                    .disabled(!store.settings.hasAPIKey)

                    Button(store.copy.removeKey, role: .destructive) {
                        store.removeAPIKey()
                    }
                    .disabled(!store.settings.hasAPIKey)
                }
            }

            Section(store.copy.languageLabel) {
                Picker(store.copy.languageLabel, selection: languageBinding) {
                    Text("跟随系统 / System").tag(LanguagePreference.system)
                    Text("中文").tag(LanguagePreference.zhCN)
                    Text("English").tag(LanguagePreference.en)
                }
            }

            Section(isChinese ? "账号与同步" : "Account & Sync") {
                Text(isChinese
                    ? "之后可以登录同一个账号，把手机和电脑上的联系人、记忆、提醒同步到你的自托管服务器。DeepSeek API key 不参与同步，只留在这台 Mac。"
                    : "Sign in later to sync people, memories, and reminders across your devices through your self-hosted server. The DeepSeek API key stays on this Mac and is never synced."
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                Label(isChinese ? "本地优先，离线也能用" : "Local-first and usable offline", systemImage: "internaldrive")
                Label(isChinese ? "服务器地址和账号登录待接入" : "Server URL and account login are planned next", systemImage: "arrow.triangle.2.circlepath")
            }

            Section(isChinese ? "本地提醒通知" : "Local Notifications") {
                Toggle(isChinese ? "开启本地提醒通知" : "Enable local reminder notifications", isOn: $allowLocalNotifications)
                Button(isChinese ? "同步今天的提醒通知" : "Sync today's reminder notifications") {
                    syncNotifications(enabled: allowLocalNotifications)
                }
                if !notificationStatus.isEmpty {
                    Text(notificationStatus)
                        .foregroundStyle(.secondary)
                }
            }
            Toggle(isChinese ? "显示来源线索" : "Show source citations", isOn: $showDemoSources)
            Toggle(isChinese ? "默认隐藏敏感记忆" : "Hide sensitive memories by default", isOn: $hideSensitiveByDefault)
            Toggle(isChinese ? "开发者日志" : "Developer logs", isOn: $developerLogs)

            Section(isChinese ? "本地数据" : "Local Data") {
                Text(isChinese
                    ? "导出会生成完整本地数据副本，包含私密记忆、朋友档案、关系边、提醒和礼物建议；不会包含 DeepSeek API key。"
                    : "Export creates a full local data copy, including private memories, friend dossiers, relationship edges, reminders, and gift ideas. It never includes the DeepSeek API key."
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                Button(isChinese ? "导出 JSON 迁移包" : "Export JSON transfer bundle") {
                    store.exportLocalData()
                }

                Button(isChinese ? "导入 JSON 迁移包" : "Import JSON transfer bundle") {
                    isImportingData = true
                }

                if let preview = store.importPreview {
                    importPreviewView(preview)
                }

                Button(isChinese ? "删除全部本地数据" : "Delete all local data", role: .destructive) {
                    store.deleteAllLocalData()
                }
            }

            Section(isChinese ? "隐私说明" : "Privacy") {
                Text(store.copy.deepseekPrivacyNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !store.statusMessage.isEmpty {
                Section(isChinese ? "状态" : "Status") {
                    Text(store.statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(embedded ? 32 : 24)
        .frame(maxWidth: embedded ? 760 : 460, alignment: .leading)
        .fileImporter(
            isPresented: $isImportingData,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    store.previewImportBundle(from: url)
                }
            case .failure(let error):
                store.statusMessage = error.localizedDescription
            }
        }
        .onChange(of: allowLocalNotifications) { _, enabled in
            syncNotifications(enabled: enabled)
        }
    }

    @ViewBuilder
    private func importPreviewView(_ preview: TransferImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(isChinese ? "导入预览" : "Import Preview", systemImage: "doc.badge.gearshape")
                .font(.headline)

            Text(preview.filename)
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], alignment: .leading, spacing: 8) {
                ImportPreviewMetric(label: isChinese ? "新增朋友" : "New people", value: preview.peopleToCreate)
                ImportPreviewMetric(label: isChinese ? "更新朋友" : "Updated people", value: preview.peopleToUpdate)
                ImportPreviewMetric(label: isChinese ? "待审档案事实" : "Profile facts", value: preview.profilePatchesToReview)
                ImportPreviewMetric(label: isChinese ? "新增记忆" : "New memories", value: preview.memoriesToCreate)
                ImportPreviewMetric(label: isChinese ? "更新记忆" : "Updated memories", value: preview.memoriesToUpdate)
                ImportPreviewMetric(label: isChinese ? "新增标签" : "New tags", value: preview.themesToCreate)
                ImportPreviewMetric(label: isChinese ? "关系边" : "Relationship edges", value: preview.relationshipEdgesToCreate + preview.relationshipEdgesToUpdate)
            }

            if !preview.potentialDuplicateNames.isEmpty {
                Text(isChinese
                    ? "可能重复：\(preview.potentialDuplicateNames.joined(separator: "、"))。导入不会自动合并同名不同 ID。"
                    : "Possible duplicates: \(preview.potentialDuplicateNames.joined(separator: ", ")). Same-name records with different IDs are not auto-merged."
                )
                .font(.caption)
                .foregroundStyle(Color.orange)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button(isChinese ? "确认合并" : "Merge") {
                    store.confirmImportPreview()
                }
                .disabled(preview.totalChanges == 0)

                Button(isChinese ? "取消" : "Cancel") {
                    store.cancelImportPreview()
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var modelBinding: Binding<DeepSeekModel> {
        Binding(
            get: { store.settings.model },
            set: { value in
                var settings = store.settings
                settings.model = value
                store.updateSettings(settings)
            }
        )
    }

    private var deepThinkingBinding: Binding<Bool> {
        Binding(
            get: { store.settings.deepThinking },
            set: { value in
                var settings = store.settings
                settings.deepThinking = value
                store.updateSettings(settings)
            }
        )
    }

    private var languageBinding: Binding<LanguagePreference> {
        Binding(
            get: { store.settings.language },
            set: { value in
                var settings = store.settings
                settings.language = value
                store.updateSettings(settings)
            }
        )
    }

    private var isChinese: Bool {
        switch store.settings.language {
        case .zhCN:
            return true
        case .en:
            return false
        case .system:
            return Locale.current.language.languageCode?.identifier == "zh"
        }
    }

    private func syncNotifications(enabled: Bool) {
        LocalReminderNotificationScheduler().sync(
            plans: store.reminderNotificationPlans(),
            enabled: enabled
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    notificationStatus = enabled
                        ? (isChinese ? "已同步 \(count) 条今天的提醒通知。" : "Synced \(count) reminder notifications for today.")
                        : (isChinese ? "已关闭今天的本地提醒通知。" : "Disabled today's local reminder notifications.")
                case .failure(let error):
                    notificationStatus = error.localizedDescription
                }
            }
        }
    }
}

private struct ImportPreviewMetric: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
