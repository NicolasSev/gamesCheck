import XCTest

/// Автоматический UI-audit: скрины + `artifacts/ui-audit/screenflow.json`.
/// Основной сценарий: `testUIAuditScreenFlowWithImport` — после входа импорт из `TestData/ui_audit_import_games.txt`, затем обход (см. `scripts/run_ui_audit.sh`).
/// Без данных: `testUIAuditScreenFlow` (или `UI_AUDIT_SKIP_IMPORT=1` для скрипта).
/// Запуск: `UI_AUDIT_ARTIFACTS_ROOT` → абсолютный путь к `.../gamesCheck/artifacts/ui-audit`.
/// Учётные данные: `FC_TEST_EMAIL`, `FC_TEST_PASSWORD` (без них тест пропускается через XCTSkip).
final class UIAuditUITests: XCTestCase {

    var app: XCUIApplication!
    private var interruption: NSObjectProtocol?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = AppLaunchConfiguration.uiAuditArguments()
        // В процесс приложения (LoginView читает FC_TEST_* из launchEnvironment).
        if let c = UITestCredentials.loadPair() {
            app.launchEnvironment["FC_TEST_EMAIL"] = c.email
            app.launchEnvironment["FC_TEST_PASSWORD"] = c.password
        }
        interruption = addUIInterruptionMonitor(withDescription: "System alerts") { alert in
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            if alert.buttons["Разрешить"].exists {
                alert.buttons["Разрешить"].tap()
                return true
            }
            return false
        }
    }

    override func tearDownWithError() throws {
        if let interruption {
            removeUIInterruptionMonitor(interruption)
        }
        app = nil
    }

    @MainActor
    func testUIAuditScreenFlow() throws {
        guard let creds = UITestCredentials.loadPair() else {
            throw XCTSkip(
                "Нет кредов: добавь gamesCheck/.env.ui-audit (FC_TEST_EMAIL / FC_TEST_PASSWORD) или задай переменные в окружении UITest (xcodebuild не всегда пробрасывает export в процесс теста)."
            )
        }
        let email = creds.email
        let password = creds.password

        let audit = UIAuditCoordinator(testCase: self)
        app.launch()
        app.tap()

        SystemAlertHandler.acceptNotificationPermissionIfPresent(app: app)

        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        if app.otherElements["splash_screen"].waitForExistence(timeout: 12) {
            try audit.recordIfNew(
                screenId: "splash",
                title: "Splash",
                parentScreenId: nil,
                navigationAction: "launch",
                screenType: .root
            )
        }

        if app.otherElements["biometric_prompt_root"].waitForExistence(timeout: 4) {
            try audit.recordIfNew(
                screenId: "bio",
                title: "Biometric prompt",
                parentScreenId: "splash",
                navigationAction: "biometric_prompt",
                screenType: .dialog
            )
            if app.buttons["Войти с паролем"].waitForExistence(timeout: 2) {
                app.buttons["Войти с паролем"].tap()
            }
        }

        let loginPage = LoginPage(app: app)
        let mainPage = MainPage(app: app)
        var mainParentId: String = "splash"
        var didShowLoginScreen = false

        // После smartSync логин может появиться позже, чем 5 s — ждём явно.
        _ = waitForLoginOrMain(timeout: 90)

        if loginPage.isDisplayed {
            didShowLoginScreen = true
            mainParentId = "login"
            try audit.recordIfNew(
                screenId: "login",
                title: "Login",
                parentScreenId: nil,
                navigationAction: "login_screen_visible",
                screenType: .form,
                notes: "legacy roots: screen.login, login_email, login_password"
            )
            // Не открываем регистрацию перед логином: sheet перекрывает форму и ломает typeText/hittable.
            loginPage.login(email: email, password: password)
        }

        XCTAssertTrue(
            waitForMainShell(timeout: 120),
            "Ожидается главный экран (TabBar или tab_overview) после входа / sync — smartSync может занять до ~2 мин."
        )
        try audit.recordIfNew(
            screenId: "main_root",
            title: "Main (TabBar)",
            parentScreenId: mainParentId,
            navigationAction: didShowLoginScreen ? "after_login_submit" : "existing_keychain_session",
            screenType: .root,
            notes: "legacy: screen.main"
        )

        try runTraversalAfterMain(audit: audit, mainPage: mainPage)
        try audit.finish()
    }

    /// Сначала импорт из `TestData/ui_audit_import_games.txt` (игрок «Ник»), затем тот же обход, что в `testUIAuditScreenFlow`.
    @MainActor
    func testUIAuditScreenFlowWithImport() throws {
        guard let creds = UITestCredentials.loadPair() else {
            throw XCTSkip(
                "Нет кредов: добавь gamesCheck/.env.ui-audit (FC_TEST_EMAIL / FC_TEST_PASSWORD) или задай переменные в окружении UITest."
            )
        }
        guard let root = UITestCredentials.resolveRepoRoot() else {
            throw XCTSkip("Не найден корень gamesCheck (SRCROOT / UITEST_REPO_ROOT) для TestData.")
        }
        let importPath = root.appendingPathComponent("TestData/ui_audit_import_games.txt").path
        guard FileManager.default.fileExists(atPath: importPath) else {
            throw XCTSkip("Нет файла TestData/ui_audit_import_games.txt")
        }
        app.launchArguments.append("--uitesting-import-file")
        app.launchEnvironment["UITEST_IMPORT_FILE_PATH"] = importPath

        let email = creds.email
        let password = creds.password
        let audit = UIAuditCoordinator(testCase: self)
        app.launch()
        app.tap()

        SystemAlertHandler.acceptNotificationPermissionIfPresent(app: app)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        if app.otherElements["splash_screen"].waitForExistence(timeout: 12) {
            try audit.recordIfNew(
                screenId: "splash",
                title: "Splash",
                parentScreenId: nil,
                navigationAction: "launch",
                screenType: .root
            )
        }

        if app.otherElements["biometric_prompt_root"].waitForExistence(timeout: 4) {
            try audit.recordIfNew(
                screenId: "bio",
                title: "Biometric prompt",
                parentScreenId: "splash",
                navigationAction: "biometric_prompt",
                screenType: .dialog
            )
            if app.buttons["Войти с паролем"].waitForExistence(timeout: 2) {
                app.buttons["Войти с паролем"].tap()
            }
        }

        let loginPage = LoginPage(app: app)
        let mainPage = MainPage(app: app)
        var mainParentId: String = "splash"
        var didShowLoginScreen = false

        _ = waitForLoginOrMain(timeout: 90)

        if loginPage.isDisplayed {
            didShowLoginScreen = true
            mainParentId = "login"
            try audit.recordIfNew(
                screenId: "login",
                title: "Login",
                parentScreenId: nil,
                navigationAction: "login_screen_visible",
                screenType: .form,
                notes: "legacy roots: screen.login, login_email, login_password"
            )
            loginPage.login(email: email, password: password)
        }

        XCTAssertTrue(
            waitForMainShell(timeout: 120),
            "Ожидается главный экран (TabBar или tab_overview) после входа / sync — smartSync может занять до ~2 мин."
        )
        try audit.recordIfNew(
            screenId: "main_root",
            title: "Main (TabBar)",
            parentScreenId: mainParentId,
            navigationAction: didShowLoginScreen ? "after_login_submit" : "existing_keychain_session",
            screenType: .root,
            notes: "legacy: screen.main"
        )

        try performBulkImportFixture(audit: audit, mainPage: mainPage)
        try runTraversalAfterMain(audit: audit, mainPage: mainPage)
        try audit.finish()
    }

    private func runTraversalAfterMain(audit: UIAuditCoordinator, mainPage: MainPage) throws {
        mainPage.switchToOverview()
        try audit.recordIfNew(
            screenId: "tab_overview",
            title: "Обзор",
            parentScreenId: "main_root",
            navigationAction: "tab_overview",
            screenType: .tab
        )

        mainPage.switchToGames()
        try audit.recordIfNew(
            screenId: "tab_games",
            title: "Игры",
            parentScreenId: "main_root",
            navigationAction: "tab_games",
            screenType: .tab
        )

        try captureGameDetailsIfPossible(audit: audit, mainPage: mainPage)

        mainPage.switchToStatistics()
        try audit.recordIfNew(
            screenId: "tab_statistics",
            title: "Статистика",
            parentScreenId: "main_root",
            navigationAction: "tab_statistics",
            screenType: .tab
        )

        mainPage.switchToPlayers()
        try audit.recordIfNew(
            screenId: "tab_players",
            title: "Игроки",
            parentScreenId: "main_root",
            navigationAction: "tab_players",
            screenType: .tab
        )

        if app.buttons["players_first_profile_row"].waitForExistence(timeout: 8) {
            app.buttons["players_first_profile_row"].tap()
            if app.otherElements["player_public_profile_root"].waitForExistence(timeout: 10) {
                try audit.recordIfNew(
                    screenId: "player_profile",
                    title: "Публичный профиль игрока",
                    parentScreenId: "tab_players",
                    navigationAction: "open_first_player",
                    screenType: .detail
                )
            }
            if app.buttons["Закрыть"].firstMatch.waitForExistence(timeout: 4) {
                app.buttons["Закрыть"].firstMatch.tap()
            }
        }

        mainPage.profileButton.tap()
        let profilePage = ProfilePage(app: app)
        XCTAssertTrue(profilePage.isDisplayed, "Профиль должен открыться.")
        try audit.recordIfNew(
            screenId: "profile",
            title: "Профиль",
            parentScreenId: "main_root",
            navigationAction: "toolbar_profile",
            screenType: .modal
        )

        let notifEntry = app.buttons["profile_notifications_history_link"]
        if notifEntry.waitForExistence(timeout: 4) {
            notifEntry.tap()
        } else if app.staticTexts["История уведомлений"].waitForExistence(timeout: 4) {
            app.staticTexts["История уведомлений"].tap()
        }
        if app.navigationBars["Уведомления"].waitForExistence(timeout: 8) {
            try audit.recordIfNew(
                screenId: "notifications",
                title: "Уведомления",
                parentScreenId: "profile",
                navigationAction: "notifications_history",
                screenType: .detail
            )
            app.navigationBars.buttons.firstMatch.tap()
        }

        if app.buttons["profile_my_claims_button"].waitForExistence(timeout: 3) {
            app.buttons["profile_my_claims_button"].tap()
            if app.navigationBars["Мои заявки"].waitForExistence(timeout: 8) {
                try audit.recordIfNew(
                    screenId: "my_claims",
                    title: "Мои заявки",
                    parentScreenId: "profile",
                    navigationAction: "my_claims",
                    screenType: .detail
                )
                if app.buttons["Присоединиться"].firstMatch.waitForExistence(timeout: 4) {
                    app.buttons["Присоединиться"].firstMatch.tap()
                    if app.textFields["join_game_code_field"].waitForExistence(timeout: 8) {
                        try audit.recordIfNew(
                            screenId: "join_code",
                            title: "Код игры",
                            parentScreenId: "my_claims",
                            navigationAction: "join_by_code_sheet",
                            screenType: .sheet
                        )
                    }
                    // Закрытие только через кнопку (свайп sheet нестабилен в XCUITest).
                    dismissJoinGameByCodeSheet(app: app)
                }
            }
            if app.buttons["Закрыть"].firstMatch.waitForExistence(timeout: 4) {
                app.buttons["Закрыть"].firstMatch.tap()
            }
        }

        if app.buttons["profile_pending_claims_button"].waitForExistence(timeout: 2) {
            app.buttons["profile_pending_claims_button"].tap()
            if app.navigationBars["Заявки на игроков"].waitForExistence(timeout: 8) {
                try audit.recordIfNew(
                    screenId: "pending_claims",
                    title: "Заявки на игроков",
                    parentScreenId: "profile",
                    navigationAction: "pending_claims",
                    screenType: .detail
                )
            }
            if app.buttons["Закрыть"].firstMatch.waitForExistence(timeout: 4) {
                app.buttons["Закрыть"].firstMatch.tap()
            }
        }

        let debugBtn = app.buttons["profile_debug_button"].firstMatch
        if debugBtn.waitForExistence(timeout: 3) {
            for _ in 0 ..< 6 where !debugBtn.isHittable {
                app.swipeUp(velocity: .fast)
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
            if debugBtn.isHittable {
                debugBtn.tap()
                if app.navigationBars["Debug"].waitForExistence(timeout: 8) {
                    try audit.recordIfNew(
                        screenId: "debug",
                        title: "Debug",
                        parentScreenId: "profile",
                        navigationAction: "debug",
                        screenType: .detail
                    )
                }
                app.swipeDown(velocity: .fast)
            }
        }

        if profilePage.closeButton.waitForExistence(timeout: 3) {
            profilePage.closeButton.tap()
        }

        if mainPage.toolbarMenuButton.waitForExistence(timeout: 4) {
            mainPage.toolbarMenuButton.tap()
            if mainPage.addGameButton.waitForExistence(timeout: 4) {
                mainPage.addGameButton.tap()
            }
            if app.otherElements["add_game_date_picker"].waitForExistence(timeout: 8)
                || app.pickers.firstMatch.waitForExistence(timeout: 3) {
                try audit.recordIfNew(
                    screenId: "add_game",
                    title: "Создать игру",
                    parentScreenId: "main_root",
                    navigationAction: "add_game_sheet",
                    screenType: .sheet
                )
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
                try audit.recordIfNew(
                    screenId: "import_data",
                    title: "Импорт данных",
                    parentScreenId: "main_root",
                    navigationAction: "import_sheet",
                    screenType: .sheet
                )
            }
            if app.buttons["Отмена"].firstMatch.waitForExistence(timeout: 3) {
                app.buttons["Отмена"].firstMatch.tap()
            }
        }
    }

    /// Прокрутка списка конфликтов к самому низу, чтобы синяя кнопка «Импортировать» (замена всех дат, кроме явно пропущенных) попала в зону тапа.
    private func scrollImportConflictsSheetToBottom() {
        let scroll = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "import_conflicts_scroll")).firstMatch
        let fallback = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "import_conflicts_root")).firstMatch
        let target = scroll.exists ? scroll : fallback
        for _ in 0 ..< 64 {
            if target.exists {
                target.swipeUp(velocity: .fast)
            } else {
                app.swipeUp(velocity: .fast)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.06))
        }
    }

    private func tapPlayerSelectionRow(named name: String) {
        let id = "player_pick_\(name)"
        let byId = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", id)).firstMatch
        if byId.waitForExistence(timeout: 6) {
            byId.tap()
            return
        }
        let btn = app.buttons[id].firstMatch
        if btn.waitForExistence(timeout: 2) {
            btn.tap()
            return
        }
        for _ in 0 ..< 8 {
            let t = app.staticTexts[name].firstMatch
            if t.waitForExistence(timeout: 1), t.isHittable {
                t.tap()
                return
            }
            app.swipeUp(velocity: .fast)
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }
        XCTFail("Не найдена строка выбора игрока «\(name)» (player_pick_ / staticText).")
    }

    private func performBulkImportFixture(audit: UIAuditCoordinator, mainPage: MainPage) throws {
        mainPage.tapImportGamesFromToolbar()
        XCTAssertTrue(
            app.navigationBars["Импорт данных"].waitForExistence(timeout: 20)
                || app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", "import_data_root")).firstMatch
                .waitForExistence(timeout: 2),
            "Sheet «Импорт данных» после выбора пункта меню"
        )
        let importRoot = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", "import_data_root")).firstMatch
        _ = importRoot.waitForExistence(timeout: 8)
        _ = app.textViews["import_text_editor"].waitForExistence(timeout: 8)
        try audit.recordIfNew(
            screenId: "import_data",
            title: "Импорт данных (фикстура UITest)",
            parentScreenId: "main_root",
            navigationAction: "import_sheet_uitest_fixture",
            screenType: .sheet
        )
        let validate = app.buttons["import_validate_button"]
        XCTAssertTrue(validate.waitForExistence(timeout: 8))
        validate.tap()
        let conflictsRoot = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "import_conflicts_root")).firstMatch
        if conflictsRoot.waitForExistence(timeout: 8) {
            scrollImportConflictsSheetToBottom()
            let replace = app.buttons["import_conflicts_confirm_replace"].firstMatch
            XCTAssertTrue(
                replace.waitForExistence(timeout: 6),
                "Кнопка «Импортировать» при конфликтах дат (заменить все непропущенные)"
            )
            if !replace.isHittable {
                let sheetScroll = app.descendants(matching: .any)
                    .matching(NSPredicate(format: "identifier == %@", "import_data_root")).firstMatch
                for _ in 0 ..< 28 {
                    if replace.isHittable { break }
                    if sheetScroll.exists {
                        sheetScroll.swipeUp(velocity: .fast)
                    } else {
                        app.swipeUp(velocity: .fast)
                    }
                    RunLoop.current.run(until: Date().addingTimeInterval(0.12))
                }
            }
            if replace.isHittable {
                replace.tap()
            } else {
                replace.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        }
        XCTAssertTrue(
            app.navigationBars["Кто вы?"].waitForExistence(timeout: 120),
            "После валидации ожидается выбор игрока (большой файл может парситься долго)."
        )
        tapPlayerSelectionRow(named: "Ник")
        let confirm = app.buttons["import_player_confirm_button"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 6))
        confirm.tap()
        // Большой дамп + replace по датам может держать sheet открытым несколько минут.
        let closeDeadline = Date().addingTimeInterval(900)
        while Date() < closeDeadline {
            if !app.navigationBars["Импорт данных"].exists
                && !app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", "import_data_root")).firstMatch.exists {
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        // Дождаться строк на «Игры»: Core Data + refresh MainViewModel; строка — NavigationLink, не всегда `buttons`.
        RunLoop.current.run(until: Date().addingTimeInterval(2.0))
        let syncing = app.staticTexts["Синхронизация..."]
        let syncDeadline = Date().addingTimeInterval(90)
        while Date() < syncDeadline, syncing.exists {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        mainPage.switchToOverview()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        mainPage.switchToGames()
        let row0 = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "games_game_row_0")).firstMatch
        XCTAssertTrue(
            row0.waitForExistence(timeout: 180),
            "После импорта ожидается хотя бы одна игра (creatorUserId / конфликт дат / повторный импорт?)."
        )
    }

    private func captureGameDetailsIfPossible(audit: UIAuditCoordinator, mainPage: MainPage) throws {
        let empty = app.staticTexts["Нет игр"]
        if empty.waitForExistence(timeout: 2), empty.isHittable {
            try audit.recordIfNew(
                screenId: "games_empty",
                title: "Игры (пусто)",
                parentScreenId: "tab_games",
                navigationAction: "empty_list",
                screenType: .empty_state,
                notes: "Нет строк для game_detail"
            )
            return
        }

        var sawPoker = false

        for i in 0 ..< 8 {
            if sawPoker { break }
            mainPage.switchToGames()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            let row = app.buttons["games_game_row_\(i)"]
            guard row.waitForExistence(timeout: 4) else { break }
            row.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(1.0))

            let isPoker = app.buttons["game_detail_add_hand_button"].waitForExistence(timeout: 6)

            if isPoker && !sawPoker {
                try audit.recordIfNew(
                    screenId: "game_detail",
                    title: "Детали игры (покер)",
                    parentScreenId: "tab_games",
                    navigationAction: "open_game_row_\(i)",
                    screenType: .detail
                )
                sawPoker = true
                if app.buttons["game_detail_add_hand_button"].waitForExistence(timeout: 2) {
                    app.buttons["game_detail_add_hand_button"].tap()
                    if app.otherElements["hand_add_root"].waitForExistence(timeout: 8) {
                        try audit.recordIfNew(
                            screenId: "hand_add",
                            title: "Добавить раздачу",
                            parentScreenId: "game_detail",
                            navigationAction: "add_hand",
                            screenType: .form
                        )
                    }
                    if app.buttons["Отмена"].firstMatch.waitForExistence(timeout: 3) {
                        app.buttons["Отмена"].firstMatch.tap()
                    }
                }
            }

            if app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 3) {
                app.navigationBars.buttons.firstMatch.tap()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
    }

    /// Ждём появления главного UI после launch/login (долгий `smartSync` в AppBodyView).
    private func waitForMainShell(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.otherElements["tab_overview"].exists { return true }
            if app.tabBars.firstMatch.exists { return true }
            if app.otherElements["screen.main"].exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        return app.otherElements["tab_overview"].waitForExistence(timeout: 1)
            || app.tabBars.firstMatch.waitForExistence(timeout: 1)
    }

    /// Пока идёт sync, сначала может быть только splash — затем login или сразу main.
    private func waitForLoginOrMain(timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if LoginPage(app: app).emailField.exists { return }
            if app.otherElements["tab_overview"].exists { return }
            if app.tabBars.firstMatch.exists { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
    }

    /// Sheet JoinGameByCode: закрытие только кнопкой «Отмена» (в toolbar), не swipe.
    private func dismissJoinGameByCodeSheet(app: XCUIApplication) {
        let byId = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "join_game_sheet_cancel"))
            .firstMatch
        if byId.waitForExistence(timeout: 4), byId.isHittable {
            byId.tap()
            return
        }
        let inNav = app.navigationBars["Присоединиться"].buttons["Отмена"]
        if inNav.waitForExistence(timeout: 6) {
            inNav.tap()
            return
        }
        let fallback = app.buttons["Отмена"].firstMatch
        if fallback.waitForExistence(timeout: 3) {
            fallback.tap()
        }
    }
}
