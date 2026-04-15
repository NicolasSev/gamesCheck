import Foundation

enum AppLaunchConfiguration {
    /// Аргументы для UI-audit и стабильного UITest (без bypass — нужны FC_TEST_*).
    static func uiAuditArguments() -> [String] {
        [
            "--uitesting",
            "--uitesting-splash-hold",
            "--uitesting-skip-faceid",
            // LoginView сам вызовет login() после prefill — тап по SwiftUI «Войти» в XCUITest ненадёжен.
            "--uitesting-auto-submit-login"
        ]
    }
}
