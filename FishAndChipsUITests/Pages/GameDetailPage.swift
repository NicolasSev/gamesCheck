import XCTest

struct GameDetailPage {
    let app: XCUIApplication

    var navigationBar: XCUIElement { app.navigationBars.firstMatch }
    var backButton: XCUIElement { app.navigationBars.buttons.element(boundBy: 0) }
    
    var claimButton: XCUIElement { app.buttons["game_detail_claim_button"] }
    var addPlayerButton: XCUIElement { app.buttons["game_detail_add_player_button"] }
    var addHandButton: XCUIElement { app.buttons["game_detail_add_hand_button"] }
    var deleteButton: XCUIElement { app.buttons["game_detail_delete_button"] }
    var shareLinkButton: XCUIElement { app.buttons["game_detail_share_link_button"] }
    var shareStatsButton: XCUIElement { app.buttons["game_detail_share_stats_button"] }

    var isDisplayed: Bool {
        navigationBar.waitForExistence(timeout: 5)
    }
}
