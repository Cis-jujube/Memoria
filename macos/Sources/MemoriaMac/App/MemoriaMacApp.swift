import Darwin
import Foundation
import SwiftUI
import MemoriaCore

@main
struct MemoriaMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: DashboardStore

    init() {
        if CommandLine.arguments.contains("--verify") {
            do {
                let directory = FileManager.default.temporaryDirectory
                    .appending(path: "MemorialVerify-\(UUID().uuidString)", directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: directory) }

                let database = try LocalSQLiteStore(filename: "verify.sqlite3", directory: directory, seedDemoData: true)
                let snapshot = try database.loadSnapshot()
                guard !snapshot.people.isEmpty, !snapshot.reminders.isEmpty else {
                    throw VerificationError.emptySnapshot
                }
                print("Memorial verify passed")
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("Memorial verify failed: \(error.localizedDescription)\n".utf8))
                exit(1)
            }
        }

        _store = StateObject(wrappedValue: DashboardStore())
    }

    var body: some Scene {
        WindowGroup("Memorial", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 1040, minHeight: 700)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Quick Capture") {
                    store.navigate(to: .capture)
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Review Next Update") {
                    store.selectFirstPendingUpdate()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(store.pendingUpdates.isEmpty)
            }

            CommandMenu("Navigate") {
                ForEach([AppSection.home, .capture, .aiReview, .selfSearch, .friendDossier, .schedule, .settings], id: \.id) { section in
                    Button(section.title) {
                        if section == .aiReview {
                            store.openReviewDesk()
                        } else {
                            store.navigate(to: section)
                        }
                    }
                }
            }
        }

        Settings {
            SettingsView(store: store)
        }
    }
}

private enum VerificationError: LocalizedError {
    case emptySnapshot

    var errorDescription: String? {
        switch self {
        case .emptySnapshot:
            return "Local snapshot did not seed people and reminders."
        }
    }
}
