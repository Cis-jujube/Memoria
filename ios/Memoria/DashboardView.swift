import SwiftUI

struct DashboardView: View {
    let snapshot: DashboardSnapshot
    @Binding var selectedTab: AppTab
    let copy: NativeCopy
    let statusMessage: String
    let onCapture: (String) -> Void
    @State private var captureText = ""

    private let metricColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header

                    LazyVGrid(columns: metricColumns, spacing: 10) {
                        MetricTile(label: isChinese ? "联系人" : "Active people", value: snapshot.activePeopleCount, symbolName: "person.2")
                        MetricTile(label: isChinese ? "待确认" : "AI updates", value: snapshot.pendingReviewCount, symbolName: "tray")
                        MetricTile(label: isChinese ? "提醒" : "Reminders", value: snapshot.upcomingReminderCount, symbolName: "bell")
                        MetricTile(label: isChinese ? "礼物想法" : "Gift ideas", value: snapshot.giftOpportunityCount, symbolName: "gift")
                    }

                    quickCapture
                    focusList
                    suggestions
                }
                .padding(18)
            }
            .background(Color.memoriaCanvas.ignoresSafeArea())
            .navigationTitle("Memoria")
            .memoriaInlineNavigationTitle()
        }
    }

    private var header: some View {
        DarkPremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(isChinese ? "今日概览" : "Daily Brief", systemImage: "sparkles")
                        .font(.headline)

                    Spacer()

                    Text("\(snapshot.focusItems.count)")
                        .font(.headline)
                        .foregroundStyle(Color.memoriaInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.memoriaMist)
                        .clipShape(Capsule())
                }

                Text(isChinese ? "今天值得处理的关系线索，就看这几条。" : "Review the few relationship signals that matter today.")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(isChinese ? "本地私密关系工作台" : "Private command center")
                    .font(.caption)
                    .foregroundStyle(Color.memoriaMist.opacity(0.75))
            }
        }
    }

    private var quickCapture: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(copy.quickCaptureTitle)
                    .font(.headline)
                    .foregroundStyle(Color.memoriaInk)

                TextEditor(text: $captureText)
                    .frame(minHeight: 92)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color.memoriaCanvas)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if captureText.isEmpty {
                            Text(copy.quickCapturePlaceholder)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                                .allowsHitTesting(false)
                        }
                    }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    let text = captureText
                    captureText = ""
                    onCapture(text)
                    selectedTab = .inbox
                } label: {
                    Label(copy.sendToInbox, systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.memoriaInk)
                .disabled(captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var focusList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(isChinese ? "今日重点" : "Today Focus", subtitle: isChinese ? "先处理最值得跟进的人和事" : "AI-sorted next actions")

            if snapshot.focusItems.isEmpty {
                EmptyStateView(
                    symbolName: "checkmark.circle",
                    title: isChinese ? "今天没有特别急的关系事项" : "No urgent relationship work",
                    detail: isChinese ? "有新事情时，随手记一条或创建提醒。" : "Capture a memory or create a reminder when something new happens."
                )
            } else {
                ForEach(snapshot.focusItems) { item in
                    Button {
                        selectedTab = item.targetTab
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(item.priority.tint)
                                .frame(width: 10, height: 10)
                                .padding(.top, 7)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.label)
                                    .font(.headline)
                                    .foregroundStyle(Color.memoriaInk)

                                Text(item.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.memoriaSage)
                                .padding(.top, 4)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(isChinese ? "可以问的事" : "Ask Suggestions", subtitle: isChinese ? "只基于已保存的记忆和档案" : "Grounded in stored memories")

            ForEach(snapshot.askSuggestions, id: \.self) { suggestion in
                HStack(spacing: 12) {
                    Image(systemName: "quote.bubble")
                        .foregroundStyle(Color.memoriaSage)
                        .frame(width: 26)

                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundStyle(Color.memoriaInk)

                    Spacer()
                }
                .padding(13)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var isChinese: Bool {
        copy.aiInboxTitle == "待确认"
    }
}
