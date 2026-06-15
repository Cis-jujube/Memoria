import SwiftUI
import MemoriaCore

struct HomeModeView: View {
    @ObservedObject var store: DashboardStore

    private var isChinese: Bool {
        resolvedLanguage(store.settings.language) == .zhCN
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                workflowActions

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], alignment: .leading, spacing: 16) {
                    HomeEntryCard(
                        title: isChinese ? "自我检索" : "Self Search",
                        subtitle: isChinese ? "按 12 个核心标签检索自己的感悟、选择、压力和成长线索。" : "Search reflections, choices, stress, and growth signals through core tags.",
                        systemImage: "magnifyingglass.circle",
                        primaryLabel: isChinese ? "记忆" : "Memories",
                        primaryMetric: store.memoryAtoms.count,
                        secondaryLabel: isChinese ? "反思" : "Reflections",
                        secondaryMetric: store.memoryAtoms.filter { $0.type == .personalReflection || $0.type == .idea }.count
                    ) {
                        store.navigate(to: .selfSearch)
                    }

                    HomeEntryCard(
                        title: isChinese ? "朋友档案管理" : "Friend Dossier Management",
                        subtitle: isChinese ? "阅读人物档案、确认记忆和两层 2D 关系网。" : "Read quiet dossiers, confirmed memories, and two-hop 2D networks.",
                        systemImage: "person.text.rectangle",
                        primaryLabel: isChinese ? "朋友" : "People",
                        primaryMetric: store.people.count,
                        secondaryLabel: isChinese ? "关系边" : "Edges",
                        secondaryMetric: store.relationshipEdges.count
                    ) {
                        store.navigate(to: .friendDossier)
                    }

                    HomeEntryCard(
                        title: isChinese ? "行程安排" : "Schedule",
                        subtitle: isChinese ? "按周和月查看提醒、生日、考试、约见和准备事项。" : "Review reminders, birthdays, exams, meetings, and preparation by week or month.",
                        systemImage: "calendar",
                        primaryLabel: isChinese ? "提醒" : "Reminders",
                        primaryMetric: store.reminders.count,
                        secondaryLabel: isChinese ? "待确认" : "Review",
                        secondaryMetric: store.pendingUpdates.filter { $0.reviewCategory == .schedule }.count
                    ) {
                        store.navigate(to: .schedule)
                    }
                }

                workflowStrip
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isChinese ? "Memoria" : "Memoria")
                .font(.largeTitle.weight(.semibold))

            Text(isChinese ? "先记录，再批准整理建议；之后进入自我检索、朋友档案管理或行程安排阅读长期记忆。" : "Capture first, approve organization, then read long-term memory through Self Search, Friend Dossiers, or Schedule.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var workflowActions: some View {
        HStack(spacing: 12) {
            Button {
                store.navigate(to: .capture)
            } label: {
                Label(isChinese ? "去记录" : "Capture", systemImage: "square.and.pencil")
                    .frame(minWidth: 132)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                store.openReviewDesk()
            } label: {
                Label(isChinese ? "打开整理台" : "Open Review Desk", systemImage: "tray")
                    .frame(minWidth: 150)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Spacer()
        }
        .memoriaCard()
    }

    private var workflowStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(isChinese ? "稳定流程" : "Stable Flow", systemImage: "checkmark.seal")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], alignment: .leading, spacing: 10) {
                WorkflowStep(title: isChinese ? "记录" : "Capture", detail: isChinese ? "保存原文" : "Save source", symbolName: "square.and.pencil")
                WorkflowStep(title: isChinese ? "自动分流" : "Auto Route", detail: isChinese ? "自我/朋友/行程" : "Self/Friend/Schedule", symbolName: "arrow.triangle.branch")
                WorkflowStep(title: isChinese ? "整理台" : "Review Desk", detail: isChinese ? "只批准一次" : "Approve once", symbolName: "tray")
                WorkflowStep(title: isChinese ? "阅读" : "Read", detail: isChinese ? "进入三种模式" : "Open a mode", symbolName: "rectangle.grid.2x2")
            }
        }
        .memoriaCard()
    }
}

private struct HomeEntryCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let primaryLabel: String
    let primaryMetric: Int
    let secondaryLabel: String
    let secondaryMetric: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Image(systemName: systemImage)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.memoriaInk)
                        .frame(width: 46, height: 46)
                        .background(Color.memoriaSage.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    MetricPill(
                        label: primaryLabel,
                        value: primaryMetric
                    )
                    MetricPill(
                        label: secondaryLabel,
                        value: secondaryMetric
                    )
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct MetricPill: View {
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.memoriaInk)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05))
        .clipShape(Capsule())
    }
}

private struct WorkflowStep: View {
    let title: String
    let detail: String
    let symbolName: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.memoriaSage)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
