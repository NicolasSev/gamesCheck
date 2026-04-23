import SwiftUI

struct GlowDot: View {
    var color: Color = DS.Color.green
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .dsDropShadow(
                .init(
                    color: color.opacity(0.55),
                    radius: size,
                    x: 0,
                    y: 0
                )
            )
    }
}
