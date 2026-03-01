import XCTest

struct ProfilePage {
    let app: XCUIApplication
    
    var syncButton: XCUIElement { app.buttons["profile_sync_button"] }
    var logoutButton: XCUIElement { app.buttons["profile_logout_button"] }
    var closeButton: XCUIElement { app.buttons["profile_button"] }
    
    func logout() {
        logoutButton.tap()
    }
    
    func sync() {
        syncButton.tap()
    }
    
    var isDisplayed: Bool {
        logoutButton.waitForExistence(timeout: 5)
    }
}
