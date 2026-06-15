import SwiftUI
import MemoriaCore

struct DetailView: View {
    @ObservedObject var store: DashboardStore

    var body: some View {
        switch store.currentSection {
        case .home:
            HomeModeView(store: store)
        case .capture:
            CaptureView(store: store)
        case .aiReview:
            InboxView(store: store)
        case .selfSearch, .memory:
            MemoryPalaceView(store: store)
        case .friendDossier, .people:
            PeopleView(store: store)
        case .relationshipMap:
            RelationshipMapView(store: store)
        case .schedule, .actions:
            ActionsView(store: store)
        case .ask:
            SearchView(store: store)
        case .settings:
            SettingsView(store: store, embedded: true)
        }
    }
}
