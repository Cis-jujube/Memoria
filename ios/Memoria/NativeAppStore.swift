import Foundation

@MainActor
final class NativeAppStore: ObservableObject {
    @Published var snapshot: DashboardSnapshot
    @Published var settings: NativeSettings
    @Published var statusMessage = ""

    private var database: LocalSQLiteStore?
    private let keyStore = SecureAPIKeyStore()
    private let deepSeek = DeepSeekClient()

    init() {
        do {
            let database = try LocalSQLiteStore()
            var loadedSettings = try database.loadSettings()
            loadedSettings.hasAPIKey = keyStore.read() != nil
            self.database = database
            self.snapshot = try database.loadSnapshot()
            self.settings = loadedSettings
        } catch {
            self.database = nil
            self.snapshot = .demo
            self.settings = NativeSettings(hasAPIKey: keyStore.read() != nil)
            self.statusMessage = "Local database failed: \(error.localizedDescription)"
        }
    }

    var copy: NativeCopy {
        nativeCopy(for: settings.language)
    }

    func updateSettings(_ settings: NativeSettings) {
        self.settings = settings
        persistSettings()
    }

    func saveAPIKey(_ apiKey: String) {
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

    func removeAPIKey() {
        do {
            try keyStore.remove()
            settings.hasAPIKey = false
            statusMessage = "DeepSeek key removed."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func testConnection() async {
        guard let apiKey = keyStore.read() else {
            statusMessage = copy.missingKeyMessage
            return
        }

        do {
            try await deepSeek.testConnection(apiKey: apiKey, settings: settings)
            statusMessage = "DeepSeek connection is working."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func capture(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            _ = try database?.addMemory(text: trimmed)

            guard let apiKey = keyStore.read() else {
                let fallback = PendingUpdate(
                    id: "local-\(UUID().uuidString)",
                    type: "Capture",
                    summary: trimmed.count > 96 ? String(trimmed.prefix(93)) + "..." : trimmed,
                    evidence: copy.missingKeyMessage,
                    personName: "New friend",
                    createdLabel: Date.now.formatted(date: .omitted, time: .shortened)
                )
                try database?.addPendingUpdate(fallback)
                try reloadSnapshot()
                statusMessage = copy.missingKeyMessage
                return
            }

            let update = try await deepSeek.extract(text: trimmed, apiKey: apiKey, settings: settings)
            try database?.addPendingUpdate(update)
            try reloadSnapshot()
            statusMessage = "Created one pending update."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func review(_ update: PendingUpdate) {
        do {
            try database?.removePendingUpdate(id: update.id)
            try reloadSnapshot()
            statusMessage = "Update reviewed."
        } catch {
            snapshot.pendingUpdates.removeAll { $0.id == update.id }
            statusMessage = error.localizedDescription
        }
    }

    private func persistSettings() {
        do {
            try database?.saveSettings(settings)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func reloadSnapshot() throws {
        if let database {
            snapshot = try database.loadSnapshot()
        }
    }
}
