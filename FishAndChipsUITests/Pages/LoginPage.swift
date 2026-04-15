import XCTest

struct LoginPage {
    let app: XCUIApplication

    /// SwiftUI-компоненты не всегда попадают в `textFields` / `secureTextFields`; идентификатор надёжнее искать в дереве.
    private func element(identifier: String) -> XCUIElement {
        let predicate = NSPredicate(format: "identifier == %@", identifier)
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    var emailField: XCUIElement { element(identifier: "login_email") }
    var passwordField: XCUIElement { element(identifier: "login_password") }
    var loginButton: XCUIElement { element(identifier: "login_button") }
    var registerButton: XCUIElement { app.buttons["Нет аккаунта? Зарегистрироваться"] }

    func login(email: String, password: String) {
        // Приложение могло само отправить форму (--uitesting-auto-submit-login).
        if app.otherElements["screen.main"].waitForExistence(timeout: 6) { return }
        if app.tabBars.firstMatch.waitForExistence(timeout: 2) { return }
        if app.staticTexts["Вход..."].waitForExistence(timeout: 3) { return }

        XCTAssertTrue(emailField.waitForExistence(timeout: 20), "Поле login_email не появилось")
        waitHittable(emailField, timeout: 15)

        // Резерв: тап по «Войти» (SwiftUI часто не отдаёт стабильный hittable).
        if waitAndTapLoginButton(timeout: 12) {
            return
        }

        emailField.tap()
        emailField.typeText(email)

        XCTAssertTrue(passwordField.waitForExistence(timeout: 10), "Поле login_password не появилось")
        waitHittable(passwordField, timeout: 10)
        passwordField.tap()
        passwordField.typeText(password)

        XCTAssertTrue(loginButton.waitForExistence(timeout: 8), "Кнопка login_button не найдена")
        if loginButton.isHittable {
            loginButton.tap()
        } else {
            loginButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// Ждём кнопку «Войти» и жмём; если за timeout так и не isHittable — тап по центру (SwiftUI).
    private func waitAndTapLoginButton(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if loginButton.exists, loginButton.isHittable {
                loginButton.tap()
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        guard loginButton.exists else { return false }
        loginButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        return true
    }

    private func waitHittable(_ element: XCUIElement, timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isHittable { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(element.isHittable, "Элемент не стал доступен для нажатия за \(timeout)s")
    }

    var isDisplayed: Bool {
        if app.otherElements["screen.login"].waitForExistence(timeout: 3) { return true }
        return emailField.waitForExistence(timeout: 10)
    }
}
