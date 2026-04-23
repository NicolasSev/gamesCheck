import SwiftUI

// MARK: - Press (active scale)

struct PressScale: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

extension View {
    func dsPressableStyle(scale: CGFloat = 0.97) -> some View {
        buttonStyle(PressScale(scale: scale))
    }
}

// MARK: - Hero card outer glow (subtle pulse)

struct HeroGlowModifier: ViewModifier {
    @State private var strong = false

    func body(content: Content) -> some View {
        content
            .dsDropShadow(
                strong
                    ? DS.Shadow.glowGreen
                    : DS.DropShadow(
                        color: DS.Color.green.opacity(0.32),
                        radius: 12,
                        x: 0,
                        y: 0
                    )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    strong = true
                }
            }
    }
}

extension View {
    func dsHeroGlowPulse() -> some View {
        modifier(HeroGlowModifier())
    }
}
