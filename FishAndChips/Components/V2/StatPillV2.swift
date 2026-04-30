import SwiftUI

/// Vertical stat pill matching `proto/ios-app-v2.jsx` → `StatPill`.
///
/// Layout (top → bottom):
///   - 30×30 icon tile (accent tint 13.4% bg), 10pt radius, icon centered
///   - label: 10pt uppercase, letter-spacing 0.5, color txt3
///   - value: 18pt/800 accent color, letter-spacing -0.5, subtle glow
///
/// API is intentionally unchanged from the previous horizontal variant —
/// existing callsites (`DesignPreviewView`) compile as-is.
struct StatPillV2: View {
    let systemIcon: String
    let value: String
    let label: String
    var accent: Color = DS.Color.green

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.134))
                Image(systemName: systemIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(accent)
            }
            .frame(width: 30, height: 30)
            .padding(.bottom, 7)

            Text(verbatim: label)
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundColor(DS.Color.txt3)
                .padding(.bottom, 3)

            Text(verbatim: value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .kerning(-0.5)
                .foregroundColor(accent)
                .shadow(color: accent.opacity(0.45), radius: 8, x: 0, y: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 14, leading: 12, bottom: 12, trailing: 12))
        .glassCardStyle(.plain)
    }
}

#Preview("StatPillV2 grid") {
    ZStack {
        DS.Color.bgBase.ignoresSafeArea()
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 8
        ) {
            StatPillV2(systemIcon: "target", value: "23", label: "Сессии", accent: DS.Color.sky)
            StatPillV2(systemIcon: "trophy.fill", value: "8", label: "MVP", accent: DS.Color.orange)
            StatPillV2(systemIcon: "chart.line.uptrend.xyaxis", value: "65%", label: "Винрейт", accent: DS.Color.green)
            StatPillV2(systemIcon: "star.fill", value: "35%", label: "MVP Rate", accent: DS.Color.gold)
            StatPillV2(systemIcon: "flame.fill", value: "+12K", label: "Лучшая", accent: DS.Color.green)
            StatPillV2(systemIcon: "diamond.fill", value: "+3.6K", label: "Средняя", accent: DS.Color.violet)
        }
        .padding()
    }
}
