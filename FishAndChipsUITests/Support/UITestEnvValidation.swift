import Foundation

/// Если в Xcode Scheme указано `$(FC_TEST_EMAIL)`, а переменная не задана в окружении при запуске,
/// в процесс попадает буквальная строка `$(FC_TEST_EMAIL)` — не подставлять её как логин.
enum UITestEnvValidation {
    static func isUnresolvedSchemePlaceholder(_ value: String) -> Bool {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix("$(") && t.hasSuffix(")")
    }
}
