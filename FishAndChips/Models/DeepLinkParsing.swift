import Foundation

enum DeepLinkParsing {
    /// Извлекает UUID игры из SPA-пути `/app/games/:id` или `/app/games/:id/hands`.
    static func gameIdFromWebPath(url: URL) -> UUID? {
        let parts = url.path.split(separator: "/").map(String.init)
        // ["app", "games", "<uuid>", "hands"?]
        guard let appIdx = parts.firstIndex(of: "app"),
              parts.count > appIdx + 2,
              parts[appIdx + 1] == "games" else { return nil }
        let idPart = parts[appIdx + 2]
        return UUID(uuidString: idPart)
    }

    /// Достаёт UUID игры из произвольного URL (в т.ч. `action_url` в пуше), если есть `/app/games/:id`.
    static func gameIdFromActionURLString(_ string: String) -> String? {
        guard let url = URL(string: string) else { return nil }
        return gameIdFromWebPath(url: url)?.uuidString
    }
}
