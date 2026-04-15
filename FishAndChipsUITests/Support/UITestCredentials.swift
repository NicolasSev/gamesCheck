import Foundation

/// Креды для UI-audit: из окружения процесса UITest или из `gamesCheck/.env.ui-audit` (xcodebuild часто не пробрасывает произвольные env в UITest).
enum UITestCredentials {
    struct Pair {
        let email: String
        let password: String
    }

    /// Порядок: валидный env → файл `.env.ui-audit` в корне репо.
    static func loadPair() -> Pair? {
        let e0 = ProcessInfo.processInfo.environment["FC_TEST_EMAIL"] ?? ""
        let p0 = ProcessInfo.processInfo.environment["FC_TEST_PASSWORD"] ?? ""
        if !e0.isEmpty, !p0.isEmpty,
           !UITestEnvValidation.isUnresolvedSchemePlaceholder(e0),
           !UITestEnvValidation.isUnresolvedSchemePlaceholder(p0) {
            return Pair(email: e0, password: p0)
        }
        guard let root = Self.resolveRepoRoot() else { return nil }
        let dotenv = root.appendingPathComponent(".env.ui-audit", isDirectory: false)
        return parseDotEnv(at: dotenv)
    }

    /// Корень `gamesCheck` (`.env.ui-audit`, `TestData/…` для UITest).
    static func resolveRepoRoot() -> URL? {
        let keys = ["UITEST_REPO_ROOT", "SRCROOT", "PROJECT_DIR"]
        for key in keys {
            if let v = ProcessInfo.processInfo.environment[key], !v.isEmpty {
                let u = URL(fileURLWithPath: v, isDirectory: true)
                let proj = u.appendingPathComponent("FishAndChips.xcodeproj")
                let dotenv = u.appendingPathComponent(".env.ui-audit")
                if FileManager.default.fileExists(atPath: proj.path)
                    || FileManager.default.fileExists(atPath: dotenv.path) {
                    return u
                }
            }
        }
        // UITest часто без SRCROOT; путь к этому файлу: …/gamesCheck/FishAndChipsUITests/Support/…
        let fromSources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let proj = fromSources.appendingPathComponent("FishAndChips.xcodeproj")
        let dotenv = fromSources.appendingPathComponent(".env.ui-audit")
        if FileManager.default.fileExists(atPath: proj.path)
            || FileManager.default.fileExists(atPath: dotenv.path) {
            return fromSources
        }
        return nil
    }

    private static func parseDotEnv(at url: URL) -> Pair? {
        guard let data = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var email = ""
        var password = ""
        for line in data.split(whereSeparator: \.isNewline) {
            var s = String(line).trimmingCharacters(in: .whitespaces)
            if s.hasPrefix("#") || s.isEmpty { continue }
            if s.hasPrefix("export ") { s.removeFirst(7) }
            let parts = s.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            var val = String(parts[1]).trimmingCharacters(in: .whitespaces)
            if (val.hasPrefix("'") && val.hasSuffix("'")) || (val.hasPrefix("\"") && val.hasSuffix("\"")) {
                val = String(val.dropFirst().dropLast())
            }
            switch key {
            case "FC_TEST_EMAIL": email = val
            case "FC_TEST_PASSWORD": password = val
            default: break
            }
        }
        if email.isEmpty || password.isEmpty { return nil }
        if UITestEnvValidation.isUnresolvedSchemePlaceholder(email)
            || UITestEnvValidation.isUnresolvedSchemePlaceholder(password) {
            return nil
        }
        return Pair(email: email, password: password)
    }
}
