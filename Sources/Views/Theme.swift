import SwiftUI

enum LabTheme {
    static let paper = Color(red: 0.969, green: 0.961, blue: 0.937)       // #F7F5EF warm archival paper
    static let card = Color.white
    static let ink = Color(red: 0.082, green: 0.082, blue: 0.078)         // #151514 carbon ink
    static let muted = Color(red: 0.42, green: 0.41, blue: 0.38)          // warm slate
    static let hairline = Color.black.opacity(0.08)

    static let danger = Color(red: 0.855, green: 0.145, blue: 0.145)      // #DA2525 vermilion stamp
    static let dangerSoft = Color(red: 0.992, green: 0.929, blue: 0.925)
    static let caution = Color(red: 0.851, green: 0.467, blue: 0.024)     // #D97706 amber
    static let cautionSoft = Color(red: 0.996, green: 0.953, blue: 0.867)
    static let clean = Color(red: 0.067, green: 0.541, blue: 0.329)       // #118A54 emerald
    static let cleanSoft = Color(red: 0.902, green: 0.973, blue: 0.933)

    static func color(for grade: VerdictGrade) -> Color {
        switch grade {
        case .clean: return clean
        case .mild: return caution
        case .warning, .danger: return danger
        }
    }

    static func softColor(for grade: VerdictGrade) -> Color {
        switch grade {
        case .clean: return cleanSoft
        case .mild: return cautionSoft
        case .warning, .danger: return dangerSoft
        }
    }

    static func color(for risk: RiskLevel) -> Color {
        switch risk {
        case .safe: return clean
        case .caution: return caution
        case .danger: return danger
        }
    }

    static func softColor(for risk: RiskLevel) -> Color {
        switch risk {
        case .safe: return cleanSoft
        case .caution: return cautionSoft
        case .danger: return dangerSoft
        }
    }
}

struct StampBadge: View {
    let text: String
    let color: Color
    var angle: Double = -4

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .black))
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color, style: StrokeStyle(lineWidth: 2))
            )
            .rotationEffect(.degrees(angle))
    }
}

struct LabCardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(LabTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(LabTheme.hairline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
    }
}

extension View {
    func labCard(padding: CGFloat = 16) -> some View {
        modifier(LabCardModifier(padding: padding))
    }
}
