import SwiftUI

struct ProgressBarV2: View {
    let value: Double
    var color: Color = DS.Color.green
    var label: String? = nil
    var trailing: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if label != nil || trailing != nil {
                HStack {
                    if let label { Text(label).font(.caption).foregroundColor(DS.Color.txt2) }
                    Spacer()
                    if let trailing { Text(trailing).font(.caption).foregroundColor(DS.Color.txt2) }
                }
            }
            GeometryReader { g in
                let w = g.size.width * min(1, max(0, value / 100))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DS.Color.bgSurf)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.7), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, w))
                }
            }
            .frame(height: 8)
        }
    }
}
