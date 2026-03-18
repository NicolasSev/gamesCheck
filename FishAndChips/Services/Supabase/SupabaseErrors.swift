import Foundation

enum SupabaseServiceError: LocalizedError {
    case notAuthenticated
    case networkError(underlying: Error)
    case serverError(statusCode: Int, message: String)
    case notFound(table: String, id: UUID)
    case conflict(message: String)
    case rateLimited(retryAfter: TimeInterval?)
    case invalidData(message: String)
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Требуется авторизация"
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Ошибка сервера (\(code)): \(message)"
        case .notFound(let table, let id):
            return "Запись не найдена: \(table)/\(id)"
        case .conflict(let message):
            return "Конфликт: \(message)"
        case .rateLimited:
            return "Слишком много запросов. Повторите позже"
        case .invalidData(let message):
            return "Некорректные данные: \(message)"
        case .unknown(let error):
            return "Неизвестная ошибка: \(error.localizedDescription)"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .rateLimited, .serverError(statusCode: 503, _):
            return true
        default:
            return false
        }
    }

    var retryDelay: TimeInterval {
        switch self {
        case .rateLimited(let retryAfter):
            return retryAfter ?? 5.0
        case .networkError:
            return 2.0
        case .serverError(statusCode: 503, _):
            return 3.0
        default:
            return 0
        }
    }
}
