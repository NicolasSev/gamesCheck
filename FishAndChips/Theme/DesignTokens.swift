import SwiftUI

// MARK: - FishAndChips V2 design system (FISHCHIPS_V2_DESIGN_PLAN)

enum DS {
    enum Color {
        static let green = SwiftUI.Color(hex: 0x33CC80)
        static let gold = SwiftUI.Color(hex: 0xF2C74C)
        static let red = SwiftUI.Color(hex: 0xEF4444)
        static let sky = SwiftUI.Color(hex: 0x38BDF8)
        static let violet = SwiftUI.Color(hex: 0xA78BFA)
        static let orange = SwiftUI.Color(hex: 0xFB923C)
        static let bgBase = SwiftUI.Color(hex: 0x07070E)
        static let bgSurf = SwiftUI.Color(hex: 0x111126)
        static let txt = SwiftUI.Color.white
        static let txt2 = SwiftUI.Color.white.opacity(0.62)
        static let txt3 = SwiftUI.Color.white.opacity(0.36)
        static let glass = SwiftUI.Color.white.opacity(0.07)
        static let border = SwiftUI.Color.white.opacity(0.10)
        static let borderG = SwiftUI.Color.white.opacity(0.16)
    }

    enum Radius {
        static let hero: CGFloat = 22
        static let card: CGFloat = 18
        static let pill: CGFloat = 14
        static let chip: CGFloat = 20
    }

    enum Gradient {
        static let holoBorder = LinearGradient(
            colors: [
                DS.Color.gold,
                DS.Color.green,
                DS.Color.violet,
                DS.Color.gold
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let greenShimmer = LinearGradient(
            colors: [
                DS.Color.green.opacity(0.45),
                DS.Color.green,
                SwiftUI.Color(hex: 0x6EE7A8),
                DS.Color.green,
                DS.Color.green.opacity(0.45)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        static let goldShimmer = LinearGradient(
            colors: [
                DS.Color.gold.opacity(0.5),
                DS.Color.gold,
                SwiftUI.Color(hex: 0xFFF4C8),
                DS.Color.gold,
                DS.Color.gold.opacity(0.5)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    struct DropShadow: Sendable {
        /// Use `SwiftUI.Color` to avoid clashing with nested `DS.Color`.
        let color: SwiftUI.Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    enum Shadow {
        static let glowGreen = DropShadow(
            color: DS.Color.green.opacity(0.5),
            radius: 20,
            x: 0,
            y: 0
        )
        static let glowGold = DropShadow(
            color: DS.Color.gold.opacity(0.45),
            radius: 20,
            x: 0,
            y: 0
        )
        static let glowRed = DropShadow(
            color: DS.Color.red.opacity(0.4),
            radius: 20,
            x: 0,
            y: 0
        )
    }
}

extension View {
    func dsDropShadow(_ s: DS.DropShadow) -> some View {
        shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}

// Bridge for legacy `Color.casinoAccentGreen` usages → DS
extension Color {
    static var casinoAccentGreen: Color { DS.Color.green }
    static var casinoAccentGold: Color { DS.Color.gold }
}
