import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: NativeAppStore
    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(store.copy.deepSeekSectionTitle) {
                    SecureField(store.copy.apiKeyPlaceholder, text: $apiKey)
                        .textContentType(.password)

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
                            Task { await store.testConnection() }
                        }
                        .disabled(!store.settings.hasAPIKey)
                    }

                    Button(role: .destructive) {
                        store.removeAPIKey()
                    } label: {
                        Text(store.copy.removeKey)
                    }
                    .disabled(!store.settings.hasAPIKey)
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
                        ? "之后可以登录同一个账号，把手机和电脑上的联系人、记忆、提醒同步到你的自托管服务器。DeepSeek API key 不参与同步，只留在这台设备。"
                        : "Sign in later to sync people, memories, and reminders across your devices through your self-hosted server. The DeepSeek API key stays on this device and is never synced."
                    )
                    .foregroundStyle(.secondary)

                    Label(isChinese ? "本地优先，离线也能用" : "Local-first and usable offline", systemImage: "internaldrive")
                    Label(isChinese ? "服务器地址和账号登录待接入" : "Server URL and account login are planned next", systemImage: "arrow.triangle.2.circlepath")
                }

                Section(isChinese ? "隐私说明" : "Privacy") {
                    Text(store.copy.deepseekPrivacyNote)
                        .foregroundStyle(.secondary)
                }

                if !store.statusMessage.isEmpty {
                    Section {
                        Text(store.statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(store.copy.settingsTitle)
        }
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
}
