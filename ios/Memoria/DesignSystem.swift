import SwiftUI

extension Color {
    static let memoriaCanvas = Color(red: 0.93, green: 0.95, blue: 0.93)
    static let memoriaInk = Color(red: 0.04, green: 0.14, blue: 0.11)
    static let memoriaPanel = Color(red: 0.10, green: 0.21, blue: 0.17)
    static let memoriaPanelLift = Color(red: 0.15, green: 0.27, blue: 0.23)
    static let memoriaMist = Color(red: 0.82, green: 0.88, blue: 0.84)
    static let memoriaSage = Color(red: 0.50, green: 0.64, blue: 0.54)
    static let memoriaGold = Color(red: 0.78, green: 0.65, blue: 0.34)
}

extension Font {
    static let memoriaTitle = Font.system(.largeTitle, design: .rounded, weight: .semibold)
    static let memoriaSectionTitle = Font.system(.title3, design: .rounded, weight: .semibold)
    static let memoriaBody = Font.system(.body, design: .rounded)
}

struct PremiumCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
    }
}

struct DarkPremiumCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.memoriaInk)
            .foregroundStyle(Color.memoriaMist)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
    }
}

struct MetricTile: View {
    let label: String
    let value: Int
    let symbolName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbolName)
                .font(.headline)
                .foregroundStyle(Color.memoriaInk)
                .frame(width: 28, height: 28)
                .background(Color.memoriaMist.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text("\(value)")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.memoriaInk)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.memoriaSectionTitle)
                .foregroundStyle(Color.memoriaInk)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyStateView: View {
    let symbolName: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.title2)
                .foregroundStyle(Color.memoriaSage)

            Text(title)
                .font(.headline)
                .foregroundStyle(Color.memoriaInk)

            Text(detail)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension View {
    @ViewBuilder
    func memoriaInlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func memoriaNoAutocapitalization() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
        #else
        self
        #endif
    }
}
