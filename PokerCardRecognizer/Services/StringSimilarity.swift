//
//  StringSimilarity.swift
//  PokerCardRecognizer
//
//  Task 1.4: Fuzzy matching utilities for player names
//

import Foundation

extension String {
    /// Вычислить расстояние Левенштейна между строками
    func levenshteinDistance(to other: String) -> Int {
        let a = Array(self)
        let b = Array(other)

        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = (a[i - 1] == b[j - 1]) ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,
                    curr[j - 1] + 1,
                    prev[j - 1] + cost
                )
            }
            prev = curr
        }

        return prev[n]
    }

    /// Проверить схожесть с другой строкой (0.0 - 1.0)
    func similarity(to other: String) -> Double {
        let distance = levenshteinDistance(to: other)
        let maxLength = max(self.count, other.count)
        guard maxLength > 0 else { return 1.0 }
        return 1.0 - (Double(distance) / Double(maxLength))
    }

    /// Найти похожие строки из массива
    func findSimilar(in strings: [String], threshold: Double = 0.7) -> [String] {
        strings.filter { similarity(to: $0) >= threshold }
    }
}

// MARK: - Player Name Suggestions
struct PlayerNameMatcher {
    static func suggestSimilarNames(for name: String, from allNames: [String]) -> [String] {
        let lowercasedName = name.lowercased()

        // 1. Точное совпадение (case-insensitive)
        let exactMatches = allNames.filter { $0.lowercased() == lowercasedName }
        if !exactMatches.isEmpty {
            return exactMatches
        }

        // 2. Начинается с...
        let prefixMatches = allNames.filter { $0.lowercased().hasPrefix(lowercasedName) }
        if !prefixMatches.isEmpty {
            return prefixMatches
        }

        // 3. Fuzzy matching
        let similarNames = allNames.filter { name.similarity(to: $0) >= 0.7 }
        return similarNames.sorted { name.similarity(to: $0) > name.similarity(to: $1) }
    }
}

