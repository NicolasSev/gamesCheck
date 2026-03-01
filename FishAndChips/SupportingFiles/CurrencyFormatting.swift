//
//  CurrencyFormatting.swift
//  FishAndChips
//

import Foundation

extension Decimal {
    /// Форматирует сумму в тенге (₸)
    func formatCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₸"
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "₸0"
    }
}
