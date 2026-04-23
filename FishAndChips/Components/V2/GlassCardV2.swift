import SwiftUI

/// V2 glass wrapper (name avoids clash with legacy project types).
struct GlassCardV2<Content: View>: View {
    var variant: GlassCardStyle.Variant = .plain
    @ViewBuilder let content: () -> Content

    init(
        variant: GlassCardStyle.Variant = .plain,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.variant = variant
        self.content = content
    }

    var body: some View {
        content()
            .glassCardStyle(variant)
    }
}
