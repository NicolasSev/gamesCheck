import Foundation

/// Стартовые 6-max opening ranges (как в `default-opening-ranges.json`), пока у пользователя нет своей строки в Core Data / Supabase для этой позиции.
enum OpeningRangeDefaults {
    private static let byPosition: [RangePosition: Set<String>] = {
        let name = "default-opening-ranges"
        let ext = "json"
        let urls = [
            Bundle.main.url(forResource: name, withExtension: ext),
            Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Resources"),
        ].compactMap(\.self)

        guard let url = urls.first,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data)
        else {
            debugLog("OpeningRangeDefaults: \(name).\(ext) missing or invalid — using empty defaults")
            return [:]
        }

        var out: [RangePosition: Set<String>] = [:]
        for pos in RangePosition.allCases {
            if let hands = decoded[pos.rawValue] {
                out[pos] = Set(hands)
            }
        }
        return out
    }()

    static func hands(for position: RangePosition) -> Set<String> {
        byPosition[position] ?? []
    }
}
