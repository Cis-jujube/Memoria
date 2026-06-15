import SwiftUI

struct CalendarView: View {
    let snapshot: DashboardSnapshot
    let language: LanguagePreference

    private var isChinese: Bool {
        resolvedLanguage(language) == .zhCN
    }

    private var events: [CalendarMoment] {
        var moments = snapshot.people.map { person in
            CalendarMoment(
                id: "birthday-\(person.id)",
                title: isChinese ? "\(person.displayName) 生日" : "\(person.displayName) birthday",
                personName: person.displayName,
                dateLabel: person.birthday,
                detail: person.favoriteFoods.isEmpty ? person.lastSignal : person.favoriteFoods,
                symbolName: "gift"
            )
        }

        moments.append(contentsOf: snapshot.reminders.map { reminder in
            CalendarMoment(
                id: "reminder-\(reminder.id)",
                title: reminder.title,
                personName: reminder.personName,
                dateLabel: reminder.dueLabel,
                detail: isChinese ? "需要跟进的关系节点" : "Relationship moment to follow up",
                symbolName: "bell"
            )
        })

        return moments
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(
                        isChinese ? "日历" : "Calendar",
                        subtitle: isChinese ? "生日、提醒、考试和聚会放在一条时间线上看。" : "Birthdays, reminders, exams, and gatherings in one timeline."
                    )

                    if events.isEmpty {
                        EmptyStateView(
                            symbolName: "calendar.badge.plus",
                            title: isChinese ? "还没有日历事件" : "No calendar moments",
                            detail: isChinese ? "确认生日、提醒或计划后，这里会自动出现。" : "Confirmed birthdays, reminders, and plans will appear here."
                        )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                                CalendarMomentRow(index: index + 1, event: event)
                            }
                        }
                    }
                }
                .padding(18)
            }
            .background(Color.memoriaCanvas.ignoresSafeArea())
            .navigationTitle(isChinese ? "日历" : "Calendar")
            .memoriaInlineNavigationTitle()
        }
    }
}

private struct CalendarMoment: Identifiable {
    let id: String
    let title: String
    let personName: String
    let dateLabel: String
    let detail: String
    let symbolName: String
}

private struct CalendarMomentRow: View {
    let index: Int
    let event: CalendarMoment

    var body: some View {
        PremiumCard {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 6) {
                    Text("\(index)")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(Color.memoriaMist)
                        .frame(width: 28, height: 28)
                        .background(Color.memoriaInk)
                        .clipShape(Circle())

                    Rectangle()
                        .fill(Color.memoriaSage.opacity(0.35))
                        .frame(width: 2, height: 34)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Label(event.title, systemImage: event.symbolName)
                        .font(.headline)
                        .foregroundStyle(Color.memoriaInk)

                    Text(event.personName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(event.detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.memoriaInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(event.dateLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.memoriaInk)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.memoriaMist.opacity(0.7))
                    .clipShape(Capsule())
            }
        }
    }
}
