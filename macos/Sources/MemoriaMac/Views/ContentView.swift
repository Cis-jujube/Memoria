import SwiftUI
import MemoriaCore

struct ContentView: View {
    @ObservedObject var store: DashboardStore

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
        } detail: {
            DetailView(store: store)
                .navigationTitle(store.currentSection.title(for: store.settings.language))
                .toolbar {
                    ToolbarItemGroup {
                        Button {
                            store.navigate(to: .selfSearch)
                        } label: {
                            Label(isChinese ? "自我检索" : "Self Search", systemImage: "magnifyingglass")
                        }

                        Button {
                            store.navigate(to: .capture)
                        } label: {
                            Label(isChinese ? "记录" : "Capture", systemImage: "plus")
                        }
                    }
                }
        }
    }

    private var isChinese: Bool {
        resolvedLanguage(store.settings.language) == .zhCN
    }
}
