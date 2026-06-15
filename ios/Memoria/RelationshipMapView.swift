import SwiftUI

struct RelationshipMapView: View {
    let snapshot: DashboardSnapshot
    let language: LanguagePreference

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    SectionHeader(
                        isChinese ? "关系星图" : "Relationship Map",
                        subtitle: isChinese
                            ? "以你为中心，看见分组轨道、关系强度和近期需要关心的人。"
                            : "See group orbits, relationship strength, and people who need attention."
                    )

                    RelationshipOrbitCard(snapshot: snapshot, isChinese: isChinese)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(
                            isChinese ? "维护评分靠前" : "Top maintenance scores",
                            subtitle: isChinese ? "先处理亮度最高的关系节点" : "Start with the brightest relationship nodes"
                        )

                        ForEach(scoredPeople.prefix(4), id: \.person.id) { item in
                            PremiumCard {
                                HStack(spacing: 12) {
                                    Text(item.person.initials)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 38, height: 38)
                                        .background(Color.memoriaInk)
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.person.displayName)
                                            .font(.headline)
                                            .foregroundStyle(Color.memoriaInk)

                                        Text(nextAction(for: item.person))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer(minLength: 8)

                                    Text("\(item.score)")
                                        .font(.headline.monospacedDigit())
                                        .foregroundStyle(Color.memoriaInk)
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }
            .background(Color.memoriaCanvas.ignoresSafeArea())
            .navigationTitle(isChinese ? "关系星图" : "Relationship Map")
            .memoriaInlineNavigationTitle()
        }
    }

    private var scoredPeople: [(person: FriendPerson, score: Int)] {
        snapshot.people.map { person in
            let reminderBoost = snapshot.reminders.contains { $0.personName == person.displayName } ? 10 : 0
            let giftBoost = snapshot.gifts.contains { $0.personName == person.displayName } ? 8 : 0
            let base = person.groupLabel == .homeFriends ? 82 : person.groupLabel == .classmates ? 78 : 70
            return (person, min(96, base + reminderBoost + giftBoost))
        }
        .sorted { $0.score > $1.score }
    }

    private var isChinese: Bool {
        resolvedLanguage(language) == .zhCN
    }

    private func nextAction(for person: FriendPerson) -> String {
        if snapshot.reminders.contains(where: { $0.personName == person.displayName }) {
            return isChinese ? "近期有提醒，先准备一句具体、不模板的关心。" : "Upcoming reminder. Prepare a specific, non-generic check-in."
        }

        if snapshot.gifts.contains(where: { $0.personName == person.displayName }) {
            return isChinese ? "有礼物机会，按偏好和预算先缩小选择。" : "Gift opportunity. Narrow choices by taste and budget."
        }

        return isChinese ? person.lastSignal : person.lastSignal
    }
}

private struct RelationshipOrbitCard: View {
    let snapshot: DashboardSnapshot
    let isChinese: Bool

    var body: some View {
        DarkPremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(isChinese ? "你是中心，越亮越需要关注" : "You are the center; brighter means higher attention")
                        .font(.caption)
                        .foregroundStyle(Color.memoriaMist.opacity(0.85))

                    Spacer()

                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .foregroundStyle(Color.memoriaGold)
                }

                GeometryReader { proxy in
                    let size = proxy.size
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let nodes = nodeLayouts(in: size)

                    ZStack {
                        ForEach(GroupFilter.allCases) { group in
                            Ellipse()
                                .stroke(groupColor(group).opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                                .frame(
                                    width: orbitSize(for: group, in: size).width,
                                    height: orbitSize(for: group, in: size).height
                                )
                                .position(center)
                        }

                        ForEach(nodes) { node in
                            Path { path in
                                path.move(to: center)
                                path.addLine(to: node.point)
                            }
                            .stroke(Color.memoriaMist.opacity(0.32 + node.strength * 0.38), lineWidth: 1.5 + node.strength * 2.5)
                        }

                        Circle()
                            .fill(.white)
                            .frame(width: 64, height: 64)
                            .shadow(color: Color.memoriaSage.opacity(0.75), radius: 24)
                            .overlay {
                                Text("ME")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.memoriaInk)
                            }
                            .position(center)

                        ForEach(nodes) { node in
                            VStack(spacing: 5) {
                                ZStack(alignment: .topTrailing) {
                                    Circle()
                                        .fill(groupColor(node.person.groupLabel).gradient)
                                        .frame(width: 38 + node.strength * 14, height: 38 + node.strength * 14)
                                        .shadow(color: groupColor(node.person.groupLabel).opacity(0.68), radius: 12 + node.strength * 18)
                                        .overlay {
                                            Text(node.person.initials)
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }

                                    if node.hasSignal {
                                        Circle()
                                            .fill(Color.memoriaGold)
                                            .frame(width: 11, height: 11)
                                            .shadow(color: Color.memoriaGold.opacity(0.8), radius: 8)
                                    }
                                }

                                Text(node.person.displayName)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                                    .foregroundStyle(.white)
                            }
                            .position(node.point)
                        }
                    }
                }
                .frame(height: 340)

                HStack(spacing: 8) {
                    ForEach(GroupFilter.allCases) { group in
                        Label(group.title(for: isChinese ? .zhCN : .en), systemImage: "circle.fill")
                            .font(.caption2)
                            .foregroundStyle(groupColor(group))
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func nodeLayouts(in size: CGSize) -> [OrbitNode] {
        snapshot.people.enumerated().map { index, person in
            let groupIndex = GroupFilter.allCases.firstIndex(of: person.groupLabel) ?? 0
            let sameGroupOffset = snapshot.people.prefix(index).filter { $0.groupLabel == person.groupLabel }.count
            let sameGroupCount = max(snapshot.people.filter { $0.groupLabel == person.groupLabel }.count, 1)
            let score = score(for: person)
            let orbit = orbitSize(for: person.groupLabel, in: size)
            let angle = (Double(sameGroupOffset) / Double(sameGroupCount)) * .pi * 2 + Double(groupIndex) * 0.86 - .pi / 2
            let point = CGPoint(
                x: size.width / 2 + CGFloat(cos(angle)) * orbit.width / 2,
                y: size.height / 2 + CGFloat(sin(angle)) * orbit.height / 2
            )

            return OrbitNode(
                id: person.id,
                person: person,
                point: point,
                strength: CGFloat(score) / 100,
                hasSignal: snapshot.reminders.contains { $0.personName == person.displayName } ||
                    snapshot.gifts.contains { $0.personName == person.displayName }
            )
        }
    }

    private func score(for person: FriendPerson) -> Int {
        let reminderBoost = snapshot.reminders.contains { $0.personName == person.displayName } ? 10 : 0
        let giftBoost = snapshot.gifts.contains { $0.personName == person.displayName } ? 8 : 0
        let base = person.groupLabel == .homeFriends ? 82 : person.groupLabel == .classmates ? 78 : 70
        return min(96, base + reminderBoost + giftBoost)
    }

    private func orbitSize(for group: GroupFilter, in size: CGSize) -> CGSize {
        let index = CGFloat((GroupFilter.allCases.firstIndex(of: group) ?? 0) + 1)
        let width = min(size.width - 18, 96 + index * 62)
        return CGSize(width: width, height: width * 0.48)
    }

    private func groupColor(_ group: GroupFilter) -> Color {
        switch group {
        case .all:
            Color.memoriaMist
        case .classmates:
            Color.memoriaSage
        case .studyAbroad:
            Color(red: 0.54, green: 0.66, blue: 0.78)
        case .homeFriends:
            Color.memoriaGold
        case .internship:
            Color(red: 0.62, green: 0.43, blue: 0.30)
        }
    }
}

private struct OrbitNode: Identifiable {
    let id: String
    let person: FriendPerson
    let point: CGPoint
    let strength: CGFloat
    let hasSignal: Bool
}
