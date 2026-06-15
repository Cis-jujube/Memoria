import SwiftUI

struct RootView: View {
    @StateObject private var store = NativeAppStore()
    @State private var selectedTab: AppTab = .focus

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(
                snapshot: store.snapshot,
                selectedTab: $selectedTab,
                copy: store.copy,
                statusMessage: store.statusMessage,
                onCapture: { text in
                    Task { await store.capture(text) }
                }
            )
                .tabItem {
                    Label(AppTab.focus.title(for: store.settings.language), systemImage: AppTab.focus.symbolName)
                }
                .tag(AppTab.focus)

            InboxView(
                snapshot: store.snapshot,
                copy: store.copy,
                onConfirm: { store.review($0) },
                onDiscard: { store.review($0) }
            )
                .tabItem {
                    Label(store.copy.aiInboxTitle, systemImage: AppTab.inbox.symbolName)
                }
                .badge(store.snapshot.pendingReviewCount)
                .tag(AppTab.inbox)

            PeopleView(snapshot: .constant(store.snapshot), language: store.settings.language)
                .tabItem {
                    Label(AppTab.people.title(for: store.settings.language), systemImage: AppTab.people.symbolName)
                }
                .tag(AppTab.people)

            CalendarView(snapshot: store.snapshot, language: store.settings.language)
                .tabItem {
                    Label(AppTab.calendar.title(for: store.settings.language), systemImage: AppTab.calendar.symbolName)
                }
                .tag(AppTab.calendar)

            RelationshipMapView(snapshot: store.snapshot, language: store.settings.language)
                .tabItem {
                    Label(AppTab.relationshipMap.title(for: store.settings.language), systemImage: AppTab.relationshipMap.symbolName)
                }
                .tag(AppTab.relationshipMap)

            SearchView(snapshot: store.snapshot)
                .tabItem {
                    Label(AppTab.search.title(for: store.settings.language), systemImage: AppTab.search.symbolName)
                }
                .tag(AppTab.search)

            FilesView(snapshot: store.snapshot)
                .tabItem {
                    Label(AppTab.files.title(for: store.settings.language), systemImage: AppTab.files.symbolName)
                }
                .badge(store.snapshot.files.filter { $0.progress < 1 }.count)
                .tag(AppTab.files)

            SettingsView(store: store)
                .tabItem {
                    Label(store.copy.settingsTitle, systemImage: AppTab.settings.symbolName)
                }
                .tag(AppTab.settings)
        }
        .tint(Color.memoriaInk)
    }
}

struct RootViewPreviews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
