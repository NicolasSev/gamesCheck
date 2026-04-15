import XCTest

/// Скриншоты для подстановки в Figma Interactive Prototype (см. figma-sync.mdc).
/// Запуск из `gamesCheck`: задать `FC_TEST_EMAIL`, `FC_TEST_PASSWORD` (если нужен вход с экрана логина).
/// `FIGMA_SCREENSHOT_DIR` — каталог для PNG (по умолчанию `docs/figma-screenshots` рядом с проектом).
final class FigmaScreenshotsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--uitesting",
            "--uitesting-splash-hold",
            "--uitesting-skip-faceid"
        ]
        if let c = UITestCredentials.loadPair() {
            app.launchEnvironment["FC_TEST_EMAIL"] = c.email
            app.launchEnvironment["FC_TEST_PASSWORD"] = c.password
            app.launchArguments.append("--uitesting-auto-submit-login")
        } else {
            app.launchArguments.append("--uitesting-bypass-auth")
        }
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testCaptureFigmaScreenshots() throws {
        let creds = UITestCredentials.loadPair()
        let useBypass = creds == nil
        let email = creds?.email ?? ""
        let password = creds?.password ?? ""

        app.launch()

        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        if app.otherElements["splash_screen"].waitForExistence(timeout: 12) {
            saveScreenshot(named: "splash")
        }

        if app.otherElements["biometric_prompt_root"].waitForExistence(timeout: 4) {
            saveScreenshot(named: "bio")
            if app.buttons["Войти с паролем"].waitForExistence(timeout: 2) {
                app.buttons["Войти с паролем"].tap()
            }
        }

        let loginPage = LoginPage(app: app)
        let mainPage = MainPage(app: app)

        if loginPage.isDisplayed {
            saveScreenshot(named: "login")
            if app.buttons["Нет аккаунта? Зарегистрироваться"].waitForExistence(timeout: 2) {
                app.buttons["Нет аккаунта? Зарегистрироваться"].tap()
                if app.textFields["register_username"].waitForExistence(timeout: 6) {
                    saveScreenshot(named: "registration")
                    app.buttons["Отмена"].firstMatch.tap()
                }
            }
            if useBypass {
                XCTFail("С --uitesting-bypass-auth ожидается вход без экрана логина (проверьте сид в UITestSessionSeeder).")
                return
            }
            guard !email.isEmpty, !password.isEmpty else {
                XCTFail("Нужны FC_TEST_EMAIL и FC_TEST_PASSWORD для входа с экрана логина.")
                return
            }
            loginPage.login(email: email, password: password)
        }

        XCTAssertTrue(mainPage.isDisplayed, "Ожидается главный экран с TabBar после входа.")
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))

        mainPage.switchToOverview()
        saveScreenshot(named: "overview")

        mainPage.switchToGames()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        saveScreenshot(named: "games_list")

        captureGameDetailsAndHandAdd(mainPage: mainPage)

        mainPage.switchToStatistics()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        saveScreenshot(named: "statistics")

        mainPage.switchToPlayers()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        saveScreenshot(named: "players")

        if app.buttons["players_first_profile_row"].waitForExistence(timeout: 8) {
            app.buttons["players_first_profile_row"].tap()
            if app.otherElements["player_public_profile_root"].waitForExistence(timeout: 10) {
                saveScreenshot(named: "player_profile")
            }
            if app.buttons["Закрыть"].firstMatch.waitForExistence(timeout: 4) {
                app.buttons["Закрыть"].firstMatch.tap()
            }
        }

        mainPage.profileButton.tap()
        let profilePage = ProfilePage(app: app)
        XCTAssertTrue(profilePage.isDisplayed, "Профиль должен открыться.")
        saveScreenshot(named: "profile")

        let notifEntry = app.buttons["profile_notifications_history_link"]
        if notifEntry.waitForExistence(timeout: 4) {
            notifEntry.tap()
        } else if app.staticTexts["История уведомлений"].waitForExistence(timeout: 4) {
            app.staticTexts["История уведомлений"].tap()
        }
        if app.navigationBars["Уведомления"].waitForExistence(timeout: 8) {
            saveScreenshot(named: "notifications")
            app.navigationBars.buttons.firstMatch.tap()
        }

        if app.buttons["profile_my_claims_button"].waitForExistence(timeout: 3) {
            app.buttons["profile_my_claims_button"].tap()
            if app.navigationBars["Мои заявки"].waitForExistence(timeout: 8) {
                saveScreenshot(named: "my_claims")
                if app.buttons["Присоединиться"].firstMatch.waitForExistence(timeout: 4) {
                    app.buttons["Присоединиться"].firstMatch.tap()
                    if app.textFields["join_game_code_field"].waitForExistence(timeout: 6) {
                        saveScreenshot(named: "join_code")
                    }
                    if app.buttons["Отмена"].firstMatch.waitForExistence(timeout: 2) {
                        app.buttons["Отмена"].firstMatch.tap()
                    }
                }
            }
            if app.buttons["Закрыть"].firstMatch.waitForExistence(timeout: 4) {
                app.buttons["Закрыть"].firstMatch.tap()
            }
        }

        if app.buttons["profile_pending_claims_button"].waitForExistence(timeout: 2) {
            app.buttons["profile_pending_claims_button"].tap()
            if app.navigationBars["Заявки на игроков"].waitForExistence(timeout: 8) {
                saveScreenshot(named: "pending_claims")
            }
            if app.buttons["Закрыть"].firstMatch.waitForExistence(timeout: 4) {
                app.buttons["Закрыть"].firstMatch.tap()
            }
        }

        if app.buttons["profile_debug_button"].waitForExistence(timeout: 3) {
            app.buttons["profile_debug_button"].tap()
            if app.navigationBars["Debug"].waitForExistence(timeout: 8) {
                saveScreenshot(named: "debug")
            }
            app.swipeDown(velocity: .fast)
        }

        if profilePage.closeButton.waitForExistence(timeout: 3) {
            profilePage.closeButton.tap()
        }

        if mainPage.toolbarMenuButton.waitForExistence(timeout: 4) {
            mainPage.toolbarMenuButton.tap()
            if mainPage.addGameButton.waitForExistence(timeout: 4) {
                mainPage.addGameButton.tap()
            }
            if app.otherElements["add_game_type_picker"].waitForExistence(timeout: 8)
                || app.pickers.firstMatch.waitForExistence(timeout: 3) {
                saveScreenshot(named: "add_game")
            }
            if app.buttons["Отмена"].firstMatch.waitForExistence(timeout: 3) {
                app.buttons["Отмена"].firstMatch.tap()
            }
        }

        if mainPage.toolbarMenuButton.waitForExistence(timeout: 4) {
            mainPage.toolbarMenuButton.tap()
            if mainPage.importButton.waitForExistence(timeout: 4) {
                mainPage.importButton.tap()
            }
            if app.navigationBars["Импорт данных"].waitForExistence(timeout: 8) {
                saveScreenshot(named: "import_data")
            }
            if app.buttons["Отмена"].firstMatch.waitForExistence(timeout: 3) {
                app.buttons["Отмена"].firstMatch.tap()
            }
        }
    }

    private func captureGameDetailsAndHandAdd(mainPage: MainPage) {
        let empty = app.staticTexts["Нет игр"]
        if empty.waitForExistence(timeout: 2), empty.isHittable { return }

        var sawPoker = false
        var sawBilliard = false

        for i in 0 ..< 8 {
            if sawPoker && sawBilliard { break }
            mainPage.switchToGames()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            let row = app.buttons["games_game_row_\(i)"]
            guard row.waitForExistence(timeout: 4) else { break }
            row.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(1.0))

            let isPoker = app.buttons["game_detail_add_hand_button"].waitForExistence(timeout: 6)
            let isBilliard = app.staticTexts["Дата игры"].waitForExistence(timeout: 2)

            if isPoker && !sawPoker {
                saveScreenshot(named: "game_detail")
                sawPoker = true
                if app.buttons["game_detail_add_hand_button"].waitForExistence(timeout: 2) {
                    app.buttons["game_detail_add_hand_button"].tap()
                    if app.otherElements["hand_add_root"].waitForExistence(timeout: 8) {
                        saveScreenshot(named: "hand_add")
                    }
                    if app.buttons["Отмена"].firstMatch.waitForExistence(timeout: 3) {
                        app.buttons["Отмена"].firstMatch.tap()
                    }
                }
            } else if isBilliard && !sawBilliard {
                saveScreenshot(named: "billiard")
                sawBilliard = true
            }

            if app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 3) {
                app.navigationBars.buttons.firstMatch.tap()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
    }

    private func saveScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let png = screenshot.pngRepresentation
        let tmpDefault = (NSTemporaryDirectory() as NSString).appendingPathComponent("FishAndChipsFigmaScreenshots")
        let dir = ProcessInfo.processInfo.environment["FIGMA_SCREENSHOT_DIR"] ?? tmpDefault
        let dirURL = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        let url = dirURL.appendingPathComponent("\(name).png")
        try? png.write(to: url)
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(name).png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
