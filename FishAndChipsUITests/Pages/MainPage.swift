import XCTest

struct MainPage {
    let app: XCUIApplication

    /// SwiftUI TabView: вкладки не всегда в `otherElements["…"]`.
    private func element(identifier: String) -> XCUIElement {
        let predicate = NSPredicate(format: "identifier == %@", identifier)
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    var overviewTab: XCUIElement { element(identifier: "tab_overview") }
    var gamesTab: XCUIElement { element(identifier: "tab_games") }
    var statisticsTab: XCUIElement { element(identifier: "tab_statistics") }
    var playersTab: XCUIElement { element(identifier: "tab_players") }

    var profileButton: XCUIElement { app.buttons["main_profile_button"].firstMatch }
    var addGameButton: XCUIElement { app.buttons["main_add_game_button"].firstMatch }
    var importButton: XCUIElement { app.buttons["main_import_button"].firstMatch }
    /// Триггер `Menu` (+): пункты «Создать игру» / «Импортировать игры» в иерархии только после открытия.
    var toolbarMenuButton: XCUIElement { element(identifier: "main_toolbar_menu_button") }

    /// Открывает sheet «Создать игру» (меню + пункт).
    func tapAddGameFromToolbar() {
        XCTAssertTrue(toolbarMenuButton.waitForExistence(timeout: 12), "Кнопка меню действий на главном экране")
        toolbarMenuButton.tap()
        XCTAssertTrue(addGameButton.waitForExistence(timeout: 6), "Пункт «Создать игру» в меню")
        addGameButton.tap()
    }

    /// Открывает sheet импорта (сначала меню, затем пункт).
    func tapImportGamesFromToolbar() {
        XCTAssertTrue(toolbarMenuButton.waitForExistence(timeout: 12), "Кнопка меню действий на главном экране")
        toolbarMenuButton.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        if importButton.waitForExistence(timeout: 6) {
            importButton.tap()
        } else {
            let byLabel = app.buttons["Импортировать игры"].firstMatch
            XCTAssertTrue(byLabel.waitForExistence(timeout: 4), "Пункт «Импортировать игры»")
            byLabel.tap()
        }
    }

    func switchToOverview() { tapTab(overviewTab, label: "Обзор") }
    func switchToGames() { tapTab(gamesTab, label: "Игры") }
    func switchToStatistics() { tapTab(statisticsTab, label: "Статистика") }
    func switchToPlayers() { tapTab(playersTab, label: "Игроки") }

    private func tapTab(_ byId: XCUIElement, label: String) {
        if byId.waitForExistence(timeout: 4), byId.isHittable {
            byId.tap()
            return
        }
        let barBtn = app.tabBars.firstMatch.buttons[label]
        if barBtn.waitForExistence(timeout: 4) {
            barBtn.tap()
        }
    }

    var isDisplayed: Bool {
        app.tabBars.firstMatch.waitForExistence(timeout: 10)
    }
}
