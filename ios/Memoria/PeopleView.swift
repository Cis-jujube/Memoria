import SwiftUI

struct PeopleView: View {
    @Binding var snapshot: DashboardSnapshot
    let language: LanguagePreference
    @State private var selectedGroup: GroupFilter = .all

    private var visiblePeople: [FriendPerson] {
        if selectedGroup == .all {
            return snapshot.people
        }

        return snapshot.people.filter { $0.groupLabel == selectedGroup }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SectionHeader(isChinese ? "联系人" : "People", subtitle: isChinese ? "按真实关系分组查看联系人档案" : "Filter by real relationship groups")
                    groupFilter

                    if visiblePeople.isEmpty {
                        EmptyStateView(
                            symbolName: "person.crop.circle.badge.plus",
                            title: isChinese ? "这个分组还没有人" : "No people in this group",
                            detail: isChinese ? "换个分组，或者先记录一条新的关系线索。" : "Add someone or switch to another group."
                        )
                    } else {
                        ForEach(visiblePeople) { person in
                            PersonCard(person: person, nextAction: snapshot.nextAction(for: person), isChinese: isChinese)
                        }
                    }
                }
                .padding(18)
            }
            .background(Color.memoriaCanvas.ignoresSafeArea())
            .navigationTitle(isChinese ? "联系人" : "People")
            .memoriaInlineNavigationTitle()
        }
    }

    private var isChinese: Bool {
        resolvedLanguage(language) == .zhCN
    }

    private var groupFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GroupFilter.allCases) { group in
                    Button {
                        withAnimation(.snappy) {
                            selectedGroup = group
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(group.title(for: language))
                            Text("\(snapshot.groupCount(group))")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(selectedGroup == group ? Color.memoriaMist.opacity(0.22) : Color.memoriaMist)
                                .clipShape(Capsule())
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(selectedGroup == group ? Color.memoriaMist : Color.memoriaInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(selectedGroup == group ? Color.memoriaInk : Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(group.title(for: language)), \(snapshot.groupCount(group)) people")
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct PersonCard: View {
    let person: FriendPerson
    let nextAction: String
    let isChinese: Bool

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Text(person.initials)
                        .font(.headline)
                        .foregroundStyle(Color.memoriaMist)
                        .frame(width: 48, height: 48)
                        .background(Color.memoriaInk)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.displayName)
                            .font(.headline)
                            .foregroundStyle(Color.memoriaInk)

                        Text(person.relationLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(person.location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)
                }

                HStack(spacing: 10) {
                    InfoPill(symbolName: "gift", text: person.birthday)
                    InfoPill(symbolName: "person.2", text: isChinese ? person.groupLabel.title(for: .zhCN) : person.groupLabel.rawValue)
                    InfoPill(symbolName: "sparkles", text: person.zodiacSign)
                    InfoPill(symbolName: "brain.head.profile", text: person.mbti)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 8)], alignment: .leading, spacing: 8) {
                    ProfileFact(label: isChinese ? "忌口" : "Dietary", value: person.dietaryRestrictions)
                    ProfileFact(label: isChinese ? "喜欢吃的" : "Favorite foods", value: person.favoriteFoods)
                    ProfileFact(label: isChinese ? "不喜欢" : "Dislikes", value: person.dislikedThings)
                    ProfileFact(label: isChinese ? "兴趣爱好" : "Interests", value: person.interests)
                    ProfileFact(label: isChinese ? "在看的书" : "Books", value: person.books)
                    ProfileFact(label: isChinese ? "运动" : "Sports", value: person.sports)
                    ProfileFact(label: isChinese ? "标签" : "Tags", value: person.profileTags)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(isChinese ? "最近线索" : "Last signal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(person.lastSignal)
                        .font(.subheadline)
                        .foregroundStyle(Color.memoriaInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .foregroundStyle(Color.memoriaSage)

                    Text(nextAction)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.memoriaInk)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.memoriaCanvas)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

private struct ProfileFact: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value.isEmpty ? "—" : value)
                .font(.caption)
                .foregroundStyle(Color.memoriaInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.memoriaCanvas)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct InfoPill: View {
    let symbolName: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbolName)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.memoriaInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.memoriaMist.opacity(0.7))
            .clipShape(Capsule())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}
