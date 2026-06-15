import SwiftUI
import MemoriaCore

struct GiftsView: View {
    @ObservedObject var store: DashboardStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(isChinese ? "礼物推荐" : "Gift Ideas")
                    .font(.largeTitle.weight(.semibold))

                if store.gifts.isEmpty {
                    EmptyState(
                        systemImage: "gift",
                        title: isChinese ? "还没有礼物推荐" : "No gift ideas yet",
                        detail: isChinese ? "礼物推荐需要引用已保存的偏好、状态和记忆。" : "Gift recommendations should cite stored preferences and memories."
                    )
                    .frame(minHeight: 420)
                } else {
                    ForEach(store.gifts) { gift in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(gift.title)
                                        .font(.title3.weight(.semibold))

                                    Text(gift.personName)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(gift.priceBand)
                                    .font(.headline.monospaced())
                                    .foregroundStyle(Color.memoriaGold)
                            }

                            Text(gift.rationale)
                                .fixedSize(horizontal: false, vertical: true)

                            if !gift.risk.isEmpty {
                                Label(gift.risk, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 8) {
                                GiftScorePill(label: isChinese ? "匹配度" : "Match", value: "\(gift.matchScore)")
                                GiftScorePill(label: isChinese ? "惊喜度" : "Surprise", value: "\(gift.surpriseScore)")
                                GiftScorePill(label: isChinese ? "踩雷风险" : "Risk", value: gift.riskLevel)
                                GiftScorePill(label: isChinese ? "需更多信息" : "More Info", value: gift.needsMoreInfo ? (isChinese ? "是" : "Yes") : (isChinese ? "否" : "No"))
                            }

                            Label(isChinese ? "推荐理由引用本地档案和已确认记忆" : "Rationale cites stored profile facts", systemImage: "quote.bubble")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .memoriaCard()
                    }
                }
            }
            .padding(24)
        }
    }

    private var isChinese: Bool {
        resolvedLanguage(store.settings.language) == .zhCN
    }
}

private struct GiftScorePill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
