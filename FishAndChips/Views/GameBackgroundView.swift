import SwiftUI

/// V2 animated background: base color, drifting orbs, optional suit symbols.
struct GameBackgroundView: View {
    enum Variant: Equatable {
        case subtle
        case rich
    }

    var variant: Variant = .subtle

    private let suits = "♠♥♦♣"

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { _ in
            ZStack {
                DS.Color.bgBase.ignoresSafeArea()

                orb(
                    size: 520,
                    offset: CGSize(width: -120, height: -180),
                    color: DS.Color.green.opacity(0.18),
                    seconds: 17
                )
                orb(
                    size: 440,
                    offset: CGSize(width: 80, height: 220),
                    color: DS.Color.gold.opacity(0.14),
                    seconds: 21
                )
                orb(
                    size: 300,
                    offset: CGSize(width: -40, height: 80),
                    color: DS.Color.violet.opacity(0.09),
                    seconds: 19
                )

                if variant == .rich {
                    suitLayer
                }
            }
        }
    }

    @ViewBuilder
    private func orb(
        size: CGFloat,
        offset: CGSize,
        color: Color,
        seconds: Double
    ) -> some View {
        let t = Date().timeIntervalSinceReferenceDate
        let phase = CGFloat(t.truncatingRemainder(dividingBy: seconds) / seconds) * 2 * .pi
        let wobble = sin(phase) * 12

        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0.02)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.5
                )
            )
            .frame(width: size, height: size)
            .blur(radius: 50)
            .offset(x: offset.width + wobble, y: offset.height - wobble * 0.4)
    }

    private var suitLayer: some View {
        let count = 10
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                let t = Date().timeIntervalSinceReferenceDate
                let symbol = String(
                    suits[suits.index(suits.startIndex, offsetBy: i % 4)]
                )
                let x = Double((i * 37) % 100)
                let delay = Double(i) * 0.85
                let total = 14.0 + Double(i % 5) * 3.0
                let y = (t + delay).truncatingRemainder(dividingBy: total) / total

                Text(verbatim: symbol)
                    .font(.system(size: 32, design: .serif))
                    .foregroundStyle(
                        (i % 2 == 0)
                            ? Color.white.opacity(0.055)
                            : Color.red.opacity(0.05)
                    )
                    .offset(
                        x: CGFloat(x - 50) * 3.2,
                        y: CGFloat(400 - y * 500)
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    GameBackgroundView(variant: .rich)
}

extension View {
    /// Full-screen V2 background for auth, sheets, and modal flows (replaces `casinoBackground()`).
    func v2ScreenBackground(_ variant: GameBackgroundView.Variant = .subtle) -> some View {
        background {
            GameBackgroundView(variant: variant)
                .ignoresSafeArea()
        }
    }
}
