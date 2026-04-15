import XCTest

enum SystemAlertHandler {
    /// Системный алерт разрешения уведомлений (и похожие) — Allow / Разрешить.
    static func acceptNotificationPermissionIfPresent(app: XCUIApplication) {
        let candidates = ["Allow", "Разрешить"]
        if tryTap(app.alerts.firstMatch, buttonTitles: candidates) { return }

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.wait(for: .runningForeground, timeout: 2) {
            _ = tryTap(springboard.alerts.firstMatch, buttonTitles: candidates)
        }
    }

    @discardableResult
    private static func tryTap(_ alert: XCUIElement, buttonTitles: [String]) -> Bool {
        guard alert.waitForExistence(timeout: 4) else { return false }
        for title in buttonTitles {
            let btn = alert.buttons[title]
            if btn.waitForExistence(timeout: 1) {
                btn.tap()
                return true
            }
        }
        return false
    }
}
