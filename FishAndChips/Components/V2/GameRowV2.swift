import SwiftUI

/// Recent-games row matching `proto/ios-app-v2.jsx` → `GameCard`.
///
/// Layout (left → right):
///   - 40×40 suit tile (win → ♠ green tint+glow; loss → ♣ red tint+glow;
///                       neutral → ♦ muted), radius 13, 1pt border, soft glow.
///   - VStack: title row (`type` + optional MVP badge),
///     subtitle (`place · date`, plus optional `· players` segment when set).
///   - Result on the right: number 16pt rounded heavy + auto-derived
///     "профит"/"убыток" caption below (suppressed for neutral rows).
///   - Optional chevron when tappable.
///
/// API note (Phase 5 parity tweak):
/// - `players` is now optional (default `nil`). When `nil` or empty the
///   subtitle drops the third segment, matching the proto's `place · date`.
/// - Result caption ("профит"/"убыток") is automatic from `win`. Pass
///   `resultCaption: ""` to opt-out (e.g. neutral rows).
struct GameRowV2: View {
    let type: String
    let place: String
    let date: String
    var players: String? = nil
    let result: String
    var win: Int = 1
    var mvpName: String? = nil
    var isSelfMvp: Bool = false
    var resultCaption: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        let inner = HStack(alignment: .center, spacing: 11) {
            suitTile

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(verbatim: type)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DS.Color.txt)
                        .lineLimit(1)
                    if isSelfMvp {
                        mvpBadge
                    }
                }
                subtitleView
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(verbatim: result)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(resultColor)
                    .shadow(color: resultColor.opacity(0.45), radius: 10, x: 0, y: 0)
                if let caption = resolvedResultCaption, !caption.isEmpty {
                    Text(verbatim: caption)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(DS.Color.txt3)
                }
            }

            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DS.Color.txt3)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .glassCardStyle(.plain)

        if let action {
            Button(action: action) { inner }
                .buttonStyle(PressScale())
        } else {
            inner
        }
    }

    private var mainSubtitle: String {
        if let players, !players.isEmpty {
            return "\(place) · \(date) · \(players)"
        }
        return "\(place) · \(date)"
    }

    @ViewBuilder
    private var subtitleView: some View {
        if let mvpName, !mvpName.isEmpty {
            (Text(verbatim: mainSubtitle + " · ")
                .foregroundColor(DS.Color.txt3)
            + Text(verbatim: "MVP: \(mvpName)")
                .foregroundColor(DS.Color.gold))
                .font(.system(size: 11, weight: .regular))
                .lineLimit(1)
        } else {
            Text(verbatim: mainSubtitle)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(DS.Color.txt3)
                .lineLimit(1)
        }
    }

    /// Caption rendered under the result number. Explicit `resultCaption`
    /// wins; otherwise auto-derive from `win` (`>0` → "профит", `<0` → "убыток").
    /// Neutral rows (`win == 0`) → no caption unless explicitly provided.
    private var resolvedResultCaption: String? {
        if let resultCaption { return resultCaption }
        if win > 0 { return "профит" }
        if win < 0 { return "убыток" }
        return nil
    }

    // MARK: - Suit tile

    @ViewBuilder
    private var suitTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(suitBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(suitBorder, lineWidth: 1)
                )
                .shadow(color: suitGlow, radius: 12, x: 0, y: 0)
            Image(systemName: suitSymbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(suitTint)
        }
        .frame(width: 40, height: 40)
    }

    private var suitSymbol: String {
        if win > 0 { return "suit.spade.fill" }
        if win < 0 { return "suit.club.fill" }
        return "suit.diamond.fill"
    }

    private var suitTint: Color {
        if win > 0 { return DS.Color.green }
        if win < 0 { return DS.Color.red }
        return DS.Color.txt2
    }

    private var suitBg: Color {
        if win > 0 { return DS.Color.green.opacity(0.15) }
        if win < 0 { return DS.Color.red.opacity(0.12) }
        return Color.white.opacity(0.06)
    }

    private var suitBorder: Color {
        if win > 0 { return DS.Color.green.opacity(0.30) }
        if win < 0 { return DS.Color.red.opacity(0.22) }
        return Color.white.opacity(0.10)
    }

    private var suitGlow: Color {
        if win > 0 { return DS.Color.green.opacity(0.20) }
        if win < 0 { return DS.Color.red.opacity(0.16) }
        return .clear
    }

    // MARK: - MVP badge

    @ViewBuilder
    private var mvpBadge: some View {
        Text("MVP")
            .font(.system(size: 9, weight: .heavy))
            .kerning(0.3)
            .foregroundColor(DS.Color.gold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DS.Color.gold.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(DS.Color.gold.opacity(0.32), lineWidth: 1)
            )
    }

    private var resultColor: Color {
        if win > 0 { return DS.Color.green }
        if win < 0 { return DS.Color.red }
        return DS.Color.txt2
    }
}

#Preview("GameRowV2 — три состояния") {
    ZStack {
        DS.Color.bgBase.ignoresSafeArea()
        VStack(spacing: 10) {
            GameRowV2(
                type: "Cash Game",
                place: "HomePOKER",
                date: "21 апр",
                result: "+₸\u{00A0}6\u{00A0}000",
                win: 1,
                mvpName: "Никита",
                isSelfMvp: true,
                action: {}
            )
            GameRowV2(
                type: "Tournament",
                place: "ClubGreen",
                date: "19 апр",
                result: "−₸\u{00A0}2\u{00A0}000",
                win: -1,
                mvpName: "Сергей",
                action: {}
            )
            GameRowV2(
                type: "Cash Game",
                place: "PokerRoom",
                date: "18 апр",
                result: "₸\u{00A0}0",
                win: 0
            )
        }
        .padding()
    }
}
