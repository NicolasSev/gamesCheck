import SwiftUI

struct SectionDividerV2: View {
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            rectangle
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .default))
                .tracking(1.1)
                .foregroundColor(DS.Color.txt3)
            rectangle
        }
    }

    private var rectangle: some View {
        Rectangle()
            .fill(DS.Color.border)
            .frame(height: 1)
    }
}
