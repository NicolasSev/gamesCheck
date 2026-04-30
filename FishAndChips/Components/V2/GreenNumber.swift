import SwiftUI

/// Headline number primitive used for balance / profit / KPI values.
///
/// Default `.positive` tone keeps the original green shimmer (`DS.Gradient.greenShimmer`).
/// `.negative` switches to a solid red tint with a soft red glow — used when the
/// underlying value is below zero (loss / negative balance) so it reads as the
/// counterpart of `.positive` instead of being a separate primitive.
/// `.neutral` is a muted `txt2` with no glow, for zero / "—" placeholder states.
struct GreenNumber: View {
    enum Tone: Sendable {
        case positive
        case negative
        case neutral
    }

    var size: GoldNumber.FontSize = .md
    var tone: Tone = .positive
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(size.v2Font)
            .modifier(ToneStyle(tone: tone))
    }

    private struct ToneStyle: ViewModifier {
        let tone: Tone
        func body(content: Content) -> some View {
            switch tone {
            case .positive:
                content.foregroundStyle(DS.Gradient.greenShimmer)
            case .negative:
                content
                    .foregroundStyle(DS.Color.red)
                    .dsDropShadow(DS.Shadow.glowRed)
            case .neutral:
                content.foregroundStyle(DS.Color.txt2)
            }
        }
    }
}
