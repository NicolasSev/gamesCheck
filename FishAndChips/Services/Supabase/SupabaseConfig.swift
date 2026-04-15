import Foundation
import Supabase

enum SupabaseConfig {
    // MARK: - Canonical project (FishAndChips Cloud)

    /// Единственный верный ref проекта Supabase.
    /// Частые опечатки: `uffgwdsw…` (sw↔mw), `uffgwfmw…` (f↔d перед mw), `…mrufqw…`, `uffgwdxw…` (xw↔mw).
    private static let canonicalProjectRef = "uffgwdmwufqududpyhbg"
    private static let canonicalSupabaseURLString = "https://\(canonicalProjectRef).supabase.co"

    /// Известные неверные ref → всегда приводим к `canonicalProjectRef`.
    private static let knownWrongProjectRefs: [String] = [
        "uffgwdswufqududpyhbg", // sw вместо mw
        "uffgwfmwufqududpyhbg", // f вместо d (uffgw**f**mw vs uffgw**d**mw)
        "uffgwdmrufqwdudpyhbg", // mr↔mw, qwd↔qud (чужой хост в логах → invalid_credentials)
        "uffgwdxwufqududpyhbg", // xw вместо mw (частая опечатка → другой проект / invalid_credentials)
    ]

    /// Exposed for unit tests (`@testable`).
    static func normalizedSupabaseURLString(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for wrong in knownWrongProjectRefs {
            s = s.replacingOccurrences(of: wrong, with: canonicalProjectRef, options: .caseInsensitive)
        }
        // Любой *.supabase.co, кроме канонического хоста → принудительно канон (один проект в приложении).
        guard var components = URLComponents(string: s), let host = components.host?.lowercased() else {
            return s
        }
        let expectedHost = "\(canonicalProjectRef).supabase.co"
        if host.hasSuffix(".supabase.co"), host != expectedHost {
            components.host = expectedHost
            if let fixed = components.url?.absoluteString {
                #if DEBUG
                debugLog("⚠️ [SupabaseConfig] host приведён к канону: \(host) → \(expectedHost)")
                #endif
                return fixed
            }
        }
        return s
    }

    // MARK: - Environment

    /// Supabase Project URL из Info.plist или Environment
    static var url: URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !raw.isEmpty else {
            #if DEBUG
            return URL(string: canonicalSupabaseURLString)!
            #else
            fatalError("SUPABASE_URL not configured in Info.plist")
            #endif
        }
        let urlString = normalizedSupabaseURLString(raw)
        guard let parsed = URL(string: urlString) else {
            fatalError("SUPABASE_URL is not a valid URL: \(urlString)")
        }
        let expectedHost = "\(canonicalProjectRef).supabase.co"
        if parsed.host?.lowercased() != expectedHost {
            #if DEBUG
            debugLog("⚠️ [SupabaseConfig] после нормализации host=\(parsed.host ?? "?") ≠ \(expectedHost) — принудительно канон")
            #endif
            guard let fallback = URL(string: canonicalSupabaseURLString) else {
                fatalError("canonicalSupabaseURLString invalid")
            }
            return fallback
        }
        #if DEBUG
        if raw != urlString {
            debugLog("⚠️ [SupabaseConfig] SUPABASE_URL исправлена опечатка в ref: \(raw) → \(urlString)")
        }
        #endif
        return parsed
    }

    /// Supabase Anon Key из Info.plist или Environment
    static var anonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty else {
            #if DEBUG
            return "YOUR_ANON_KEY"
            #else
            fatalError("SUPABASE_ANON_KEY not configured in Info.plist")
            #endif
        }
        #if DEBUG
        if let jwtRef = jwtProjectRef(fromAnonJWT: key), jwtRef != canonicalProjectRef {
            debugLog("⚠️ [SupabaseConfig] В JWT anon-ключа поле ref=\(jwtRef) ≠ канон \(canonicalProjectRef). URL и ключ должны быть из одного проекта в Dashboard → Settings → API, иначе будет invalid_credentials.")
        }
        #endif
        return key
    }

    /// Декодирует `ref` из payload JWT (anon / service role), без проверки подписи — только для диагностики.
    private static func jwtProjectRef(fromAnonJWT jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1])
        while b64.count % 4 != 0 { b64.append("=") }
        guard let data = Data(base64Encoded: b64),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ref = obj["ref"] as? String else { return nil }
        return ref
    }

    // MARK: - Client

    /// `emitLocalSessionAsInitialSession: true` — рекомендация supabase-swift (PR #822): сразу отдавать локальную сессию как initial, а не после refresh (убирает предупреждение в консоли и стабилизирует старт).
    /// Если полагаетесь на первую сессию, проверяйте `session.isExpired` перед «автовходом».
    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: anonKey,
        options: SupabaseClientOptions(
            auth: .init(emitLocalSessionAsInitialSession: true)
        )
    )
}
