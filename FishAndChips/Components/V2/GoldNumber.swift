import SwiftUI

struct GoldNumber: View {
    var size: FontSize = .md
    let text: String

    enum FontSize: Sendable {
        case sm, md, lg, xl
    }

    var body: some View {
        Text(verbatim: text)
            .font(size.v2Font)
            .foregroundStyle(DS.Gradient.goldShimmer)
    }
}

extension GoldNumber.FontSize {
    var v2Font: Font {
        switch self {
        case .sm: return .system(size: 20, weight: .black, design: .rounded)
        case .md: return .system(size: 28, weight: .black, design: .rounded)
        case .lg: return .system(size: 40, weight: .black, design: .rounded)
        case .xl: return .system(size: 48, weight: .black, design: .rounded)
        }
    }
}
