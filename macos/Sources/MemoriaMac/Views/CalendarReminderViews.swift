import SwiftUI
import MemoriaCore

struct CalendarView: View {
    @ObservedObject var store: DashboardStore

    var body: some View {
        RemindersBoardView(
            title: resolvedLanguage(store.settings.language) == .zhCN ? "日历" : "Calendar",
            subtitle: resolvedLanguage(store.settings.language) == .zhCN ? "生日、提醒、考试和聚会按时间排在一起。" : "Upcoming relationship moments by date",
            isChinese: resolvedLanguage(store.settings.language) == .zhCN,
            reminders: store.reminders
        )
    }
}

struct RemindersView: View {
    @ObservedObject var store: DashboardStore

    var body: some View {
        RemindersBoardView(
            title: resolvedLanguage(store.settings.language) == .zhCN ? "提醒" : "Reminders",
            subtitle: resolvedLanguage(store.settings.language) == .zhCN ? "近期要跟进的事情和人生节点。" : "Workload view for follow-ups and life events",
            isChinese: resolvedLanguage(store.settings.language) == .zhCN,
            reminders: store.reminders
        )
    }
}

private struct RemindersBoardView: View {
    let title: String
    let subtitle: String
    let isChinese: Bool
    let reminders: [ReminderItem]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.largeTitle.weight(.semibold))

                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                if reminders.isEmpty {
                    EmptyState(
                        systemImage: "calendar.badge.plus",
                        title: isChinese ? "还没有提醒" : "No reminders",
                        detail: isChinese ? "从联系人、记录或导入内容里创建提醒。" : "Create reminders from people, captures, or imported memories."
                    )
                    .frame(minHeight: 420)
                } else {
                    ForEach(reminders) { reminder in
                        HStack(spacing: 14) {
                            Image(systemName: "bell")
                                .font(.title3)
                                .foregroundStyle(Color.memoriaSage)
                                .frame(width: 34)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(reminder.title)
                                    .font(.headline)

                                Text(reminder.personName)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(reminder.dueLabel)
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .memoriaCard()
                    }
                }
            }
            .padding(24)
        }
    }
}
