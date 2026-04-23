import SwiftUI

struct GlassCardStyle: ViewModifier {
    enum Variant {
        case plain
        case hero
        case elevated
    }

    let variant: Variant

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(tint)
                }
            }
            .clipShape(shape)
            .overlay {
                shape.stroke(border, lineWidth: borderWidth)
            }
    }

    private var radius: CGFloat {
        switch variant {
        case .plain, .elevated: return DS.Radius.card
        case .hero: return DS.Radius.hero
        }
    }

    private var tint: Color {
        switch variant {
        case .plain: return DS.Color.glass
        case .hero: return Color(red: 9 / 255, green: 9 / 255, blue: 20 / 255).opacity(0.75)
        case .elevated: return DS.Color.bgSurf.opacity(0.5)
        }
    }

    private var border: Color {
        switch variant {
        case .hero: return DS.Color.borderG
        case .plain, .elevated: return DS.Color.border
        }
    }

    private var borderWidth: CGFloat {
        variant == .hero ? 1.5 : 1
    }
}

extension View {
    /// Glass surface (V2)
    func glassCardStyle(_ variant: GlassCardStyle.Variant = .plain) -> some View {
        modifier(GlassCardStyle(variant: variant))
    }
}
