import Foundation

/// Базовый URL веб-приложения (SPA) для шаринга и парсинга ссылок `/app/games/:id`.
/// Задаётся в Info.plist ключом `WEB_APP_BASE_URL` (без завершающего `/`), иначе прод-дефолт.
enum AppWebConfig {
    private static let plistKey = "WEB_APP_BASE_URL"

    static var baseURLString: String {
        if let raw = Bundle.main.object(forInfoDictionaryKey: plistKey) as? String,
           !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return "https://185.146.3.87"
    }

    /// Публичная ссылка на игру в пользовательском приложении (не админ `/games/:id`).
    static func gameURL(gameId: UUID) -> URL {
        URL(string: "\(baseURLString)/app/games/\(gameId.uuidString.lowercased())")!
    }
}
