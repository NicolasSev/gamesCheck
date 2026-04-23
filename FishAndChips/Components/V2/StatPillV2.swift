import SwiftUI

struct StatPillV2: View {
    let systemIcon: String
    let value: String
    let label: String
    var accent: Color = DS.Color.green

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemIcon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: value)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(DS.Color.txt)
                Text(verbatim: label)
                    .font(.system(size: 10, weight: .bold, design: .default))
                    .kerning(0.4)
                    .foregroundColor(DS.Color.txt3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .glassCardStyle(.plain)
    }
}
