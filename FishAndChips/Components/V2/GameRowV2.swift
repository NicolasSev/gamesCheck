import SwiftUI

struct GameRowV2: View {
    let type: String
    let place: String
    let date: String
    let players: String
    let result: String
    var win: Int = 1
    var mvp: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        let inner = HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(verbatim: type)
                        .font(.subheadline.weight(.semibold))
                    Text(verbatim: "· \(place)")
                        .font(.caption)
                        .foregroundColor(DS.Color.txt3)
                }
                .foregroundColor(DS.Color.txt)
                Text(verbatim: "\(date) · \(players)")
                    .font(.caption2)
                    .foregroundColor(DS.Color.txt2)
                if let mvp, !mvp.isEmpty {
                    Text(verbatim: "MVP \(mvp)")
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DS.Color.gold.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(DS.Color.gold.opacity(0.4), lineWidth: 1)
                        )
                        .foregroundColor(DS.Color.gold)
                }
            }
            Spacer()
            Text(verbatim: result)
                .font(.subheadline.weight(.black))
                .foregroundColor(resultColor)
        }
        .padding(12)
        .glassCardStyle(.plain)

        if let action {
            Button(action: action) { inner }
                .buttonStyle(PressScale())
        } else {
            inner
        }
    }

    private var resultColor: Color {
        if win > 0 { return DS.Color.green }
        if win < 0 { return DS.Color.red }
        return DS.Color.txt2
    }
}
