import SwiftUI
import MemoriaCore

struct OverviewView: View {
    @ObservedObject var store: DashboardStore

    private let metricColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                LazyVGrid(columns: metricColumns, spacing: 14) {
                    MetricCard(label: isChinese ? "联系人" : "Active people", count: store.people.count, symbolName: "person.2")
                    MetricCard(label: isChinese ? "待确认" : "AI updates", count: store.pendingUpdates.count, symbolName: "tray")
                    MetricCard(label: isChinese ? "提醒" : "Reminders", count: store.reminders.count, symbolName: "bell")
                    MetricCard(label: isChinese ? "礼物想法" : "Gift ideas", count: store.gifts.count, symbolName: "gift")
                }

                HStack(alignment: .top, spacing: 16) {
                    focusPanel
                    VStack(spacing: 16) {
                        CountBarChart(title: isChinese ? "分组分布" : "Group distribution", items: store.groupCounts)
                        CountBarChart(title: isChinese ? "提醒分布" : "Reminder workload", items: store.reminderWindowCounts)
                    }
                    .frame(maxWidth: 420)
                }

                quickCapture
            }
            .padding(24)
        }
        .background(.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isChinese ? "安静但有用的关系工作台" : "Quiet Premium command center")
                .font(.largeTitle.weight(.semibold))

            Text(isChinese ? "把待确认、提醒、礼物、文件和搜索放在一个本地私密空间里。" : "A private relationship memory workspace for review, reminders, gifts, files, and grounded search.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var focusPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(isChinese ? "今日重点" : "Today Focus", systemImage: "sparkles")
                    .font(.headline)

                Spacer()

                Text("\(store.focusItems.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            if store.focusItems.isEmpty {
                Text(isChinese ? "今天没有特别急的关系事项。" : "No urgent relationship work.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ForEach(store.focusItems) { item in
                    Button {
                        store.sidebarSelection = item.target
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(item.priority.color)
                                .frame(width: 9, height: 9)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.label)
                                    .font(.headline)

                                Text(item.detail)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(.quinary)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .memoriaCard()
    }

    private var quickCapture: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(isChinese ? "快速记录" : "Quick Capture", systemImage: "square.and.pencil")
                .font(.headline)

            Text(isChinese ? "记录前先选自我检索、朋友档案管理或行程安排；AI 会把建议送到对应整理台。" : "Choose Self Search, Friend Dossier Management, or Schedule before writing. AI routes proposals to that review desk.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(isChinese ? "避免从总览直接写入默认模式。" : "Avoid saving into a default mode from overview.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    store.navigate(to: .capture)
                } label: {
                    Label(isChinese ? "去记录" : "Open Capture", systemImage: "arrow.right")
                }
                .buttonStyle(.borderedProminent)
            }

            if !store.statusMessage.isEmpty {
                Text(store.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .memoriaCard()
    }

    private var isChinese: Bool {
        resolvedLanguage(store.settings.language) == .zhCN
    }
}
