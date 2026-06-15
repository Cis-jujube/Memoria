import SwiftUI
import MemoriaCore

struct SidebarView: View {
    @ObservedObject var store: DashboardStore

    var body: some View {
        List(selection: sidebarSelection) {
            ForEach(memoriaSidebarNavigationGroups(for: store.settings.language)) { group in
                Section(group.title) {
                    ForEach(group.sections) { section in
                        sidebarRow(section)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Memoria")
    }

    private var sidebarSelection: Binding<SidebarSelection?> {
        Binding(
            get: { store.sidebarSelection },
            set: { selection in
                if selection == .section(.aiReview) {
                    store.openReviewDesk()
                } else {
                    store.sidebarSelection = selection
                }
            }
        )
    }

    private var isChinese: Bool {
        resolvedLanguage(store.settings.language) == .zhCN
    }

    private func badge(for section: AppSection) -> Int? {
        switch section {
        case .aiReview:
            store.pendingUpdates.count
        case .selfSearch:
            store.pendingUpdates.filter { $0.reviewCategory == .selfSearch }.count
        case .memory:
            store.memoryAtoms.count
        case .friendDossier:
            store.pendingUpdates.filter { $0.reviewCategory == .friendDossier }.count
        case .relationshipMap:
            store.relationshipEdges.count
        case .schedule:
            store.reminders.count + store.pendingUpdates.filter { $0.reviewCategory == .schedule }.count
        case .actions:
            store.pendingUpdates.count + store.reminders.count + store.gifts.count
        default:
            nil
        }
    }

    private func sidebarRow(_ section: AppSection) -> some View {
        SidebarRow(
            title: section.title(for: store.settings.language),
            systemImage: section.systemImage,
            badge: badge(for: section)
        )
        .tag(SidebarSelection.section(section))
    }
}

private struct SidebarRow: View {
    let title: String
    let systemImage: String
    let badge: Int?

    var body: some View {
        Label {
            HStack {
                Text(title)
                    .lineLimit(1)

                Spacer()

                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }
}
