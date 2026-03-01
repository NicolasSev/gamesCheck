import XCTest

struct RegistrationPage {
    let app: XCUIApplication
    
    var usernameField: XCUIElement { app.textFields["register_username"] }
    var emailField: XCUIElement { app.textFields["register_email"] }
    var passwordField: XCUIElement { app.otherElements["register_password"] }
    var confirmPasswordField: XCUIElement { app.otherElements["register_confirm_password"] }
    var registerButton: XCUIElement { app.buttons["register_button"] }
    
    func register(username: String, email: String, password: String) {
        usernameField.tap()
        usernameField.typeText(username)
        emailField.tap()
        emailField.typeText(email)
        
        let passwordSecureField = passwordField.secureTextFields.firstMatch
        passwordSecureField.tap()
        passwordSecureField.typeText(password)
        
        let confirmSecureField = confirmPasswordField.secureTextFields.firstMatch
        confirmSecureField.tap()
        confirmSecureField.typeText(password)
        
        registerButton.tap()
    }
    
    var isDisplayed: Bool {
        usernameField.waitForExistence(timeout: 5)
    }
}
