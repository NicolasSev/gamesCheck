import XCTest

struct MainPage {
    let app: XCUIApplication

    var overviewTab: XCUIElement { app.otherElements["tab_overview"] }
    var gamesTab: XCUIElement { app.otherElements["tab_games"] }
    var statisticsTab: XCUIElement { app.otherElements["tab_statistics"] }
    var playersTab: XCUIElement { app.otherElements["tab_players"] }
    
    var profileButton: XCUIElement { app.buttons["main_profile_button"] }
    var addGameButton: XCUIElement { app.buttons["main_add_game_button"] }
    var importButton: XCUIElement { app.buttons["main_import_button"] }

    func switchToOverview() { overviewTab.tap() }
    func switchToGames() { gamesTab.tap() }
    func switchToStatistics() { statisticsTab.tap() }
    func switchToPlayers() { playersTab.tap() }

    var isDisplayed: Bool {
        app.tabBars.firstMatch.waitForExistence(timeout: 10)
    }
}
