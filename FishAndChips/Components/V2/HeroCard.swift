import SwiftUI

struct HeroCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(16)
            .glassCardStyle(.hero)
            .dsHeroGlowPulse()
    }
}
