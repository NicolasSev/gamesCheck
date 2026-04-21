import Foundation

/// Соответствует SQL `buyin_to_tenge_units()` (миграция 017): 1 бай-ин в фишках → ₸.
enum ChipValue {
    static let tengePerChip: Int64 = 2000

    static func chipsToTenge(_ chips: Int) -> Int64 {
        Int64(chips) * tengePerChip
    }

    static func chipsToTenge(_ chips: Int64) -> Int64 {
        chips * tengePerChip
    }

    static func chipsToTenge(_ chips: Double) -> Double {
        chips * Double(tengePerChip)
    }

    static func chipsToTengeDecimal(_ chips: Int) -> Decimal {
        Decimal(chips) * Decimal(tengePerChip)
    }
}
