import SwiftUI

struct GreenNumber: View {
    var size: GoldNumber.FontSize = .md
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(size.v2Font)
            .foregroundStyle(DS.Gradient.greenShimmer)
    }
}
