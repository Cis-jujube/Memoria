import SwiftUI
import MemoriaCore

extension Color {
    static let memoriaInk = Color(red: 0.04, green: 0.14, blue: 0.11)
    static let memoriaSage = Color(red: 0.45, green: 0.58, blue: 0.49)
    static let memoriaGold = Color(red: 0.78, green: 0.63, blue: 0.32)
}

extension View {
    func memoriaCard() -> some View {
        self
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            }
    }
}

struct MetricCard: View {
    let label: String
    let count: Int
    let symbolName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(Color.memoriaSage)

            Text("\(count)")
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))

            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .memoriaCard()
    }
}

struct EmptyState: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(Color.memoriaSage)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

struct CountBarChart: View {
    let title: String
    let items: [CountItem]

    private var maxCount: Int {
        max(items.map(\.count).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            ForEach(items) { item in
                HStack(spacing: 12) {
                    Text(item.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 118, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.memoriaSage.gradient)
                            .frame(width: proxy.size.width * CGFloat(item.count) / CGFloat(maxCount))
                    }
                    .frame(height: 9)

                    Text("\(item.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
        .memoriaCard()
    }
}
