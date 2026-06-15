import SwiftUI
import MemoriaCore

struct SearchView: View {
    @ObservedObject var store: DashboardStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isChinese ? "对话检索" : "Search")
                        .font(.largeTitle.weight(.semibold))

                    Text(isChinese ? "搜索朋友档案、分类记忆、提醒和礼物建议；结果只来自本地已保存内容。" : "Answers stay grounded in the current user's people, memories, reminders, and gifts.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                TextField(isChinese ? "搜索朋友、生日、礼物、忌口、考试、旅行、工作状态..." : "Ask about a friend, gift, birthday, preference, or reminder", text: $store.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)

                if store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    suggestions
                } else if store.searchResults.isEmpty {
                    EmptyState(
                        systemImage: "magnifyingglass",
                        title: isChinese ? "没有找到本地记录" : "No cited memory found",
                        detail: isChinese ? "试试朋友姓名、生日、礼物、忌口、提醒或旅行关键词。" : "Try a friend name, preference, reminder, or gift keyword."
                    )
                    .frame(minHeight: 360)
                } else {
                    ForEach(store.searchResults) { result in
                        SearchResultCard(result: result)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .searchable(text: $store.searchQuery, prompt: isChinese ? "搜索本地记忆" : "Search stored memories")
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isChinese ? "可以这样问" : "Try asking")
                .font(.headline)

            ForEach(store.askSuggestions, id: \.self) { suggestion in
                Button {
                    store.searchQuery = suggestion
                } label: {
                    HStack {
                        Image(systemName: "sparkle.magnifyingglass")
                            .foregroundStyle(Color.memoriaSage)

                        Text(suggestion)

                        Spacer()
                    }
                    .padding(12)
                    .background(.quinary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .memoriaCard()
    }

    private var isChinese: Bool {
        resolvedLanguage(store.settings.language) == .zhCN
    }
}

private struct SearchResultCard: View {
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(result.title, systemImage: "quote.bubble")
                    .font(.headline)

                Spacer()
            }

            Text(result.excerpt)
                .fixedSize(horizontal: false, vertical: true)

            Text(result.source)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.quaternary)
                .clipShape(Capsule())
        }
        .memoriaCard()
    }
}
