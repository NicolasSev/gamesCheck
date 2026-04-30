import SwiftUI

/// V2 component gallery (use Preview or embed behind debug flag in settings).
struct DesignPreviewView: View {
    @State private var chip = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("V2 components")
                    .font(.title.weight(.black))
                    .foregroundColor(DS.Color.txt)
                HStack {
                    GoldNumber(size: .md, text: "1 240")
                    GreenNumber(size: .md, text: "+₸ 10k")
                }
                HStack(spacing: 12) {
                    GreenNumber(size: .md, tone: .positive, text: "+₸ 12k")
                    GreenNumber(size: .md, tone: .negative, text: "−₸ 4k")
                    GreenNumber(size: .md, tone: .neutral, text: "₸ 0")
                }
                GlowDot()
                HeroCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Баланс")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(DS.Color.txt3)
                        GreenNumber(size: .lg, text: "+₸ 5 000")
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 8) {
                    StatPillV2(systemIcon: "trophy.fill", value: "64%", label: "Винрейт", accent: DS.Color.green)
                    StatPillV2(systemIcon: "star.fill", value: "3", label: "MVP", accent: DS.Color.gold)
                    StatTileV2(systemIcon: "flame.fill", value: "5", label: "Серия", accent: DS.Color.orange)
                }
                SectionDividerV2(label: "ПОСЛЕДНИЕ ИГРЫ")
                GameRowV2(
                    type: "Cash",
                    place: "—",
                    date: "2 апр.",
                    result: "+₸\u{00A0}1k",
                    win: 1,
                    mvpName: nil,
                    action: {}
                )
                HStack {
                    FilterChipV2(title: "Мои", isActive: chip == 0) { chip = 0 }
                    FilterChipV2(title: "Все", isActive: chip == 1) { chip = 1 }
                }
                ProgressBarV2(value: 60, color: DS.Color.gold, label: "По типу", trailing: "60%")
            }
            .padding()
        }
        .background(GameBackgroundView(variant: .subtle))
    }
}

#Preview {
    DesignPreviewView()
}
