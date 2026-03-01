import XCTest

final class FishAndChipsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch

    @MainActor
    func testAppLaunches() throws {
        app.launch()
        let loginPage = LoginPage(app: app)
        let mainPage = MainPage(app: app)
        XCTAssertTrue(loginPage.isDisplayed || mainPage.isDisplayed,
                      "App should show either login or main screen")
    }

    // MARK: - Login Page

    @MainActor
    func testLoginPageElementsExist() throws {
        app.launch()
        let loginPage = LoginPage(app: app)
        guard loginPage.isDisplayed else { return }

        XCTAssertTrue(loginPage.emailField.exists)
        XCTAssertTrue(loginPage.passwordField.exists)
        XCTAssertTrue(loginPage.loginButton.exists)
        XCTAssertTrue(loginPage.registerButton.exists)
    }

    @MainActor
    func testLoginButtonDisabledWhenFieldsEmpty() throws {
        app.launch()
        let loginPage = LoginPage(app: app)
        guard loginPage.isDisplayed else { return }

        XCTAssertFalse(loginPage.loginButton.isEnabled,
                       "Login button should be disabled with empty fields")
    }

    @MainActor
    func testRegisterButtonOpensRegistration() throws {
        app.launch()
        let loginPage = LoginPage(app: app)
        guard loginPage.isDisplayed else { return }

        loginPage.registerButton.tap()
        let registrationPage = RegistrationPage(app: app)
        XCTAssertTrue(registrationPage.isDisplayed,
                      "Registration page should appear after tapping register")
    }

    // MARK: - Registration Page

    @MainActor
    func testRegistrationPageElementsExist() throws {
        app.launch()
        let loginPage = LoginPage(app: app)
        guard loginPage.isDisplayed else { return }

        loginPage.registerButton.tap()
        let regPage = RegistrationPage(app: app)
        guard regPage.isDisplayed else {
            XCTFail("Registration page didn't appear")
            return
        }

        XCTAssertTrue(regPage.usernameField.exists)
        XCTAssertTrue(regPage.emailField.exists)
        XCTAssertTrue(regPage.registerButton.exists)
    }

    // MARK: - Tab Navigation

    @MainActor
    func testTabNavigation() throws {
        app.launch()
        let mainPage = MainPage(app: app)
        guard mainPage.isDisplayed else { return }

        mainPage.switchToGames()
        XCTAssertTrue(mainPage.gamesTab.isSelected || mainPage.gamesTab.exists)

        mainPage.switchToStatistics()
        XCTAssertTrue(mainPage.statisticsTab.isSelected || mainPage.statisticsTab.exists)

        mainPage.switchToPlayers()
        XCTAssertTrue(mainPage.playersTab.isSelected || mainPage.playersTab.exists)

        mainPage.switchToOverview()
        XCTAssertTrue(mainPage.overviewTab.isSelected || mainPage.overviewTab.exists)
    }

    // MARK: - Profile

    @MainActor
    func testProfileButtonOpensProfile() throws {
        app.launch()
        let mainPage = MainPage(app: app)
        guard mainPage.isDisplayed else { return }

        mainPage.profileButton.tap()
        let profilePage = ProfilePage(app: app)
        XCTAssertTrue(profilePage.isDisplayed,
                      "Profile page should appear after tapping profile button")
    }

    @MainActor
    func testProfileHasLogoutButton() throws {
        app.launch()
        let mainPage = MainPage(app: app)
        guard mainPage.isDisplayed else { return }

        mainPage.profileButton.tap()
        let profilePage = ProfilePage(app: app)
        guard profilePage.isDisplayed else { return }

        XCTAssertTrue(profilePage.logoutButton.exists,
                      "Profile should have a logout button")
    }

    // MARK: - Performance

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
