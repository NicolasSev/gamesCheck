//
//  CurrencyFormatting.swift
//  FishAndChips
//

import Foundation

extension Decimal {
    /// Форматирует сумму в тенге (₸). Префикс "+" не добавляется автоматически.
    func formatCurrency() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₸"
        formatter.currencyCode = "KZT"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "₸0"
    }

    /// Тенге в proto-формате: префикс ₸ + знак (`+₸ 84 000` / `−₸ 23 000` / `₸ 0`).
    /// Параллель к `formatTengeProto(n)` на вебе. Используется в HeroCard и
    /// GameRow, где макет требует символ валюты слева.
    ///
    /// Знак: `+` для положительных, `−` (U+2212, как у `NumberFormatter`) для
    /// отрицательных, без знака для нуля. Пробел между ₸ и числом —
    /// неразрывный (U+00A0), чтобы валюта и число никогда не разъезжались.
    func formatTengeProto() -> String {
        let value = NSDecimalNumber(decimal: self).doubleValue
        let abs = Swift.abs(value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.groupingSeparator = "\u{00A0}"
        let grouped = formatter.string(from: NSNumber(value: abs)) ?? "0"
        if value > 0 { return "+₸\u{00A0}\(grouped)" }
        if value < 0 { return "−₸\u{00A0}\(grouped)" }
        return "₸\u{00A0}0"
    }

    /// Compact "+12K" / "−3.6K" representation used in the 6-tile stat grid on the
    /// Overview screen (Q3 decision: iOS uses compact form). For the hero balance
    /// keep the full `formatCurrency()` output.
    ///
    /// Rules:
    /// - `|x| < 1000` → falls back to `formatCurrency()` (small amounts read better with ₸).
    /// - `1000 ≤ |x| < 1_000_000` → `"±N[.N]K"` (one decimal only when not whole).
    /// - `|x| ≥ 1_000_000` → `"±N[.N]M"`.
    /// Sign uses the proper minus glyph (U+2212) to align with `NumberFormatter` output.
    func compactKTenge() -> String {
        let value = (self as NSDecimalNumber).doubleValue
        let absValue = Swift.abs(value)
        let sign = value > 0 ? "+" : value < 0 ? "−" : ""

        if absValue < 1000 {
            return self.formatCurrency()
        }

        func format(_ x: Double, suffix: String) -> String {
            let rounded = (x * 10).rounded() / 10
            return rounded == rounded.rounded()
                ? String(format: "%.0f%@", rounded, suffix)
                : String(format: "%.1f%@", rounded, suffix)
        }

        if absValue < 1_000_000 {
            return "\(sign)\(format(absValue / 1000.0, suffix: "K"))"
        }
        return "\(sign)\(format(absValue / 1_000_000.0, suffix: "M"))"
    }
}

enum RussianPlural {
    /// Picks one of three Russian plural forms based on a count.
    /// Example: `pick(1, one: "стопка", few: "стопки", many: "стопок")` → "стопка".
    static func pick(_ count: Int, one: String, few: String, many: String) -> String {
        let mod10 = abs(count) % 10
        let mod100 = abs(count) % 100
        if mod100 >= 11 && mod100 <= 14 { return many }
        if mod10 == 1 { return one }
        if (2...4).contains(mod10) { return few }
        return many
    }
}
