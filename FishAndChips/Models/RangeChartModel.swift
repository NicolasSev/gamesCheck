import Foundation

// MARK: - Position

enum RangePosition: String, CaseIterable, Codable, Hashable {
    case UTG, MP, CO, BTN, SB, BB

    var displayName: String { rawValue }
}

// MARK: - Hand Kind

enum HandKind {
    case pair, suited, offsuit
}

// MARK: - Domain Model

struct RangeChartModel: Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let position: RangePosition
    var selectedHands: Set<String>
    var updatedAt: Date

    mutating func toggle(hand: String) {
        if selectedHands.contains(hand) {
            selectedHands.remove(hand)
        } else {
            selectedHands.insert(hand)
        }
        updatedAt = Date()
    }
}

// MARK: - Hand Grid

enum HandGrid {
    static let ranks: [Character] = ["A", "K", "Q", "J", "T", "9", "8", "7", "6", "5", "4", "3", "2"]

    /// Returns canonical hand id for a grid cell (row, col).
    /// row == col → pair; row < col → suited; row > col → offsuit.
    static func handId(row: Int, col: Int) -> String {
        let high = ranks[min(row, col)]
        let low  = ranks[max(row, col)]
        if row == col {
            return "\(high)\(low)"
        } else if row < col {
            return "\(high)\(low)s"
        } else {
            return "\(high)\(low)o"
        }
    }

    static func kind(of hand: String) -> HandKind {
        if hand.count == 2 { return .pair }
        return hand.hasSuffix("s") ? .suited : .offsuit
    }

    /// Number of actual starting-hand combinations.
    static func combos(for kind: HandKind) -> Int {
        switch kind {
        case .pair:    return 6
        case .suited:  return 4
        case .offsuit: return 12
        }
    }

    /// Weighted percentage of selected hands out of 1326 total combos.
    static func weightedPercent(_ hands: Set<String>) -> Double {
        let total = 1326.0
        let selected = hands.reduce(0) { $0 + combos(for: kind(of: $1)) }
        return selected / total * 100.0
    }
}
