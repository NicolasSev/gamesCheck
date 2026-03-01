import XCTest

struct LoginPage {
    let app: XCUIApplication

    var emailField: XCUIElement { app.textFields["login_email"] }
    var passwordField: XCUIElement { app.secureTextFields["login_password"] }
    var loginButton: XCUIElement { app.buttons["login_button"] }
    var registerButton: XCUIElement { app.buttons["Нет аккаунта? Зарегистрироваться"] }

    func login(email: String, password: String) {
        emailField.tap()
        emailField.typeText(email)
        passwordField.tap()
        passwordField.typeText(password)
        loginButton.tap()
    }

    var isDisplayed: Bool {
        emailField.waitForExistence(timeout: 5)
    }
}
