import SwiftUI

struct StatTileV2: View {
    let systemIcon: String
    let value: String
    let label: String
    var accent: Color = DS.Color.green

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: systemIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(accent)
            }
            Text(verbatim: value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(DS.Color.txt)
            Text(verbatim: label)
                .font(.system(size: 11, weight: .bold, design: .default))
                .kerning(0.4)
                .foregroundColor(DS.Color.txt3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassCardStyle(.plain)
    }
}
