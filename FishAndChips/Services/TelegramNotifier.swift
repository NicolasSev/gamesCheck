//
//  TelegramNotifier.swift
//  Зеркало пользовательских действий в личный TG-чат админа.
//  Принцип: fire-and-forget. Никогда не блокирует UX, любые ошибки гасит.
//
//  Использование:
//    TelegramNotifier.shared.notify(event: "user.login", message: "Вошёл игрок")
//    TelegramNotifier.shared.notify(
//        event: "claim.created",
//        level: .important,
//        meta: ["gameId": gameId.uuidString]
//    )
//

import Foundation
import Supabase

enum TelegramLevel: String, Sendable {
    case low, info, important
}

enum TelegramAudience: String, Sendable {
    case admin, players
}

actor TelegramNotifier {
    static let shared = TelegramNotifier()

    private struct DedupKey: Hashable { let event: String; let message: String }
    private var recent: [DedupKey: Date] = [:]
    private let dedupWindow: TimeInterval = 2.0

    private init() {}

    /// Главная точка входа — fire-and-forget. Не бросает, не блокирует caller.
    /// meta сериализуем синхронно тут же, чтобы не таскать non-Sendable `[String: Any]` через Task.
    nonisolated func notify(
        event: String,
        message: String? = nil,
        level: TelegramLevel = .info,
        audience: TelegramAudience = .admin,
        meta: [String: Any]? = nil,
        userLabel: String? = nil
    ) {
        let metaData: Data? = {
            guard let meta = meta else { return nil }
            let cleaned = sanitizeJSONStatic(meta)
            guard let dict = cleaned as? [String: Any],
                  !dict.isEmpty,
                  JSONSerialization.isValidJSONObject(dict),
                  let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return data
        }()

        Task.detached(priority: .background) { [event, message, level, audience, userLabel, metaData] in
            await TelegramNotifier.shared.send(
                event: event,
                message: message,
                level: level,
                audience: audience,
                metaData: metaData,
                userLabel: userLabel
            )
        }
    }

    private func send(
        event: String,
        message: String?,
        level: TelegramLevel,
        audience: TelegramAudience,
        metaData: Data?,
        userLabel: String?
    ) async {
        // Дедуп одинаковых событий в окне 2 сек.
        let key = DedupKey(event: event, message: message ?? "")
        let now = Date()
        recent = recent.filter { now.timeIntervalSince($0.value) < dedupWindow }
        if let last = recent[key], now.timeIntervalSince(last) < dedupWindow {
            return
        }
        recent[key] = now

        // Подтягиваем user из текущей сессии (если есть).
        var resolvedLabel: String? = userLabel
        var resolvedId: String? = nil
        var bearer: String = SupabaseConfig.anonKey
        if let session = try? await SupabaseConfig.client.auth.session {
            resolvedId = session.user.id.uuidString
            bearer = session.accessToken
            if resolvedLabel == nil {
                let metaJSON = session.user.userMetadata
                let display: String? =
                    metaJSON["display_name"]?.stringValue
                    ?? metaJSON["full_name"]?.stringValue
                    ?? session.user.email
                    ?? session.user.phone
                resolvedLabel = display ?? String(session.user.id.uuidString.prefix(8))
            }
        }

        // metaData уже сериализована в notify(); восстанавливаем dict для общего JSON-payload'а.
        let metaDict: [String: Any]? = metaData
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }

        var payload: [String: Any] = [
            "event": event,
            "source": "ios",
            "audience": audience.rawValue,
            "level": level.rawValue,
        ]
        if let m = message { payload["message"] = m }
        if let l = resolvedLabel { payload["userLabel"] = l }
        if let id = resolvedId { payload["userId"] = id }
        if let mj = metaDict, !mj.isEmpty { payload["meta"] = mj }

        guard JSONSerialization.isValidJSONObject(payload),
              let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return
        }

        let base = SupabaseConfig.url.absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/functions/v1/notify-telegram") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        req.timeoutInterval = 5

        _ = try? await URLSession.shared.data(for: req)
    }

}

/// Срезает не-JSON-совместимые значения (Date, URL и пр.) до строк.
/// Вне actor'а — чтобы можно было вызывать из nonisolated notify().
private func sanitizeJSONStatic(_ value: Any) -> Any {
    switch value {
    case let dict as [String: Any]:
        var out: [String: Any] = [:]
        for (k, v) in dict { out[k] = sanitizeJSONStatic(v) }
        return out
    case let arr as [Any]:
        return arr.map { sanitizeJSONStatic($0) }
    case is String, is NSNumber, is Bool, is Int, is Double, is NSNull:
        return value
    case let date as Date:
        return ISO8601DateFormatter().string(from: date)
    case let url as URL:
        return url.absoluteString
    case let uuid as UUID:
        return uuid.uuidString
    default:
        return String(describing: value)
    }
}
