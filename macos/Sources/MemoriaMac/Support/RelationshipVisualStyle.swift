import SwiftUI
import MemoriaCore

extension Color {
    static let relationshipNormalBlue = Color(red: 0.20, green: 0.47, blue: 0.88)
    static let relationshipUnfriendlyRed = Color(red: 0.82, green: 0.18, blue: 0.20)
}

extension RelationshipVisualTone {
    var lineColor: Color {
        switch self {
        case .normal:
            return .relationshipNormalBlue
        case .intimate:
            return .memoriaGold
        case .unfriendly:
            return .relationshipUnfriendlyRed
        }
    }

    var softFill: Color {
        lineColor.opacity(self == .intimate ? 0.15 : 0.11)
    }
}

struct RelationshipToneLegend: View {
    let language: LanguagePreference

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RelationshipVisualTone.allCases, id: \.self) { tone in
                HStack(spacing: 6) {
                    Capsule()
                        .fill(tone.lineColor)
                        .frame(width: 22, height: 3)
                    Text(tone.title(for: language))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(tone.softFill)
                .clipShape(Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }
}
