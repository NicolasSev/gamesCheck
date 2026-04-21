import SwiftUI

// MARK: - Range Colors

private extension Color {
    // Имена не пересекаются с Asset symbols (`rangePairOn` и т.д. в xcassets).
    // Pair: синий
    static let gridPairOn  = Color(red: 0.145, green: 0.388, blue: 0.922)  // #2563eb
    static let gridPairOff = Color(red: 0.859, green: 0.937, blue: 1.0)    // #dbeafe

    // Suited: золотой
    static let gridSuitedOn  = Color(red: 0.961, green: 0.620, blue: 0.043) // #f59e0b
    static let gridSuitedOff = Color(red: 0.996, green: 0.953, blue: 0.780) // #fef3c7

    // Offsuit: красный
    static let gridOffsuitOn  = Color(red: 0.863, green: 0.149, blue: 0.149) // #dc2626
    static let gridOffsuitOff = Color(red: 0.996, green: 0.886, blue: 0.886) // #fee2e2
}

// MARK: - Cell View

private struct RangeCell: View {
    let handId: String
    let kind: HandKind
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(handId)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundColor(isSelected ? .white : .primary.opacity(0.7))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(cellColor)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(handId)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var cellColor: Color {
        switch kind {
        case .pair:
            return isSelected ? .gridPairOn    : .gridPairOff
        case .suited:
            return isSelected ? .gridSuitedOn  : .gridSuitedOff
        case .offsuit:
            return isSelected ? .gridOffsuitOn : .gridOffsuitOff
        }
    }
}

// MARK: - Grid View

struct RangeChartGridView: View {
    let selectedHands: Set<String>
    let onToggle: (String) -> Void

    // Drag-paint state
    @State private var isDragging = false
    @State private var paintValue = true  // true = set open, false = set fold

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 13)

    var body: some View {
        GeometryReader { geo in
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<13, id: \.self) { row in
                    ForEach(0..<13, id: \.self) { col in
                        let hand = HandGrid.handId(row: row, col: col)
                        let kind = HandGrid.kind(of: hand)
                        let selected = selectedHands.contains(hand)

                        RangeCell(handId: hand, kind: kind, isSelected: selected) {
                            onToggle(hand)
                        }
                        .frame(height: cellSize(in: geo))
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !isDragging {
                                        isDragging = true
                                        paintValue = !selectedHands.contains(hand)
                                    }
                                    let current = selectedHands.contains(hand)
                                    if current != paintValue {
                                        onToggle(hand)
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                    }
                }
            }
        }
    }

    private func cellSize(in geo: GeometryProxy) -> CGFloat {
        let available = geo.size.width - 2 * 12  // minimal total spacing
        return min(available / 13, 32)
    }
}
