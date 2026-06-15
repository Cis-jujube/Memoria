import SwiftUI

struct SearchView: View {
    let snapshot: DashboardSnapshot
    @State private var query = ""

    private var results: [SearchResult] {
        snapshot.search(query)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SectionHeader("Search", subtitle: "Answers stay grounded in your stored memories")

                    searchField

                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        suggestions
                    } else if results.isEmpty {
                        EmptyStateView(
                            symbolName: "magnifyingglass",
                            title: "No cited memory found",
                            detail: "Try a friend's name, a preference, or a reminder keyword."
                        )
                    } else {
                        ForEach(results) { result in
                            SearchResultCard(result: result)
                        }
                    }
                }
                .padding(18)
            }
            .background(Color.memoriaCanvas.ignoresSafeArea())
            .navigationTitle("Search")
            .memoriaInlineNavigationTitle()
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Ask about people, gifts, or reminders", text: $query)
                .memoriaNoAutocapitalization()
                .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try asking")
                .font(.headline)
                .foregroundStyle(Color.memoriaInk)

            ForEach(snapshot.askSuggestions, id: \.self) { suggestion in
                Button {
                    query = suggestion
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .foregroundStyle(Color.memoriaSage)

                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundStyle(Color.memoriaInk)
                            .multilineTextAlignment(.leading)

                        Spacer()
                    }
                    .padding(13)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SearchResultCard: View {
    let result: SearchResult

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "quote.bubble")
                        .foregroundStyle(Color.memoriaSage)

                    Text(result.title)
                        .font(.headline)
                        .foregroundStyle(Color.memoriaInk)

                    Spacer()
                }

                Text(result.excerpt)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(result.source)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.memoriaCanvas)
                    .clipShape(Capsule())
            }
        }
    }
}
