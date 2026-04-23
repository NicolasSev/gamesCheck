import SwiftUI

/// Legacy glass (pre–V2). Prefer ``GlassCardStyle`` / ``View/glassCardStyle(_:)``.
struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial.opacity(0.8))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
    }
}

extension View {
    @available(
        *,
        deprecated,
        message: "Use glassCardStyle(.plain) (or .hero) for V2 glass surfaces."
    )
    func liquidGlass(cornerRadius: CGFloat = 20) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }
}
