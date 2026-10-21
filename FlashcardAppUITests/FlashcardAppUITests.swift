import XCTest

final class FlashcardAppUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testLiveLevelsAndContentCanBeBrowsedWithoutLogin() {
        let app = XCUIApplication()
        app.launch()
        let levels = app.tables["home_levels"]
        XCTAssertTrue(levels.waitForExistence(timeout: 40))
        let firstLevel = levels.cells["home_row_J5"]
        XCTAssertTrue(firstLevel.waitForExistence(timeout: 15))
        firstLevel.tap()
        let content = app.tables["level_content"]
        XCTAssertTrue(content.waitForExistence(timeout: 10))
        let firstContent = content.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home_row_")).firstMatch
        XCTAssertTrue(firstContent.waitForExistence(timeout: 15))
        firstContent.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
    }

    func testLiveDictionarySearchDisplaysJapaneseAndVietnamese() {
        let app = XCUIApplication()
        app.launch()
        let dictionary = app.tabBars.buttons["tab_dictionary"]
        XCTAssertTrue(dictionary.waitForExistence(timeout: 40))
        dictionary.tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("日本")
        let result = app.tables["dictionary_results"].cells.firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 15))
        XCTAssertTrue(result.label.contains("日本"))
        result.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
    }

    func testOfflineCardsAndAccountEntryRemainReachable() {
        let app = XCUIApplication()
        app.launch()
        let cards = app.tabBars.buttons["tab_cards"]
        XCTAssertTrue(cards.waitForExistence(timeout: 40))
        cards.tap()
        XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["tab_settings"].tap()
        XCTAssertTrue(app.tables.firstMatch.waitForExistence(timeout: 5))
    }

    func testCardEditorKeepsToolbarAboveKeyboardAndCanDiscard() {
        let app = XCUIApplication()
        app.launch()
        let cards = app.tabBars.buttons["tab_cards"]
        XCTAssertTrue(cards.waitForExistence(timeout: 40))
        cards.tap()
        app.buttons["create_deck_button"].tap()
        let name = app.textViews["deck_name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Bộ kiểm tra bàn phím")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let toolbar = app.otherElements["deck_keyboard_toolbar"]
        XCTAssertTrue(toolbar.exists)
        XCTAssertLessThanOrEqual(toolbar.frame.maxY, app.keyboards.firstMatch.frame.minY + 2)
        app.buttons["close_deck_editor"].tap()
        let discard = app.alerts.buttons["Đồng ý"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()
        XCTAssertTrue(app.tabBars.buttons["tab_cards"].waitForExistence(timeout: 5))
    }

    func testWebsiteLoginValidatesEmptyFormAndAllowsGuestReturn() {
        let app = XCUIApplication()
        app.launch()
        let settings = app.tabBars.buttons["tab_settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 40))
        settings.tap()
        app.tables.cells.firstMatch.tap()
        let login = app.buttons["website_login_button"]
        XCTAssertTrue(login.waitForExistence(timeout: 5))
        login.tap()
        XCTAssertTrue(app.staticTexts["Enter a valid email address."].waitForExistence(timeout: 5))
        app.buttons["continueWithoutLoginButton"].tap()
        XCTAssertTrue(app.tabBars.buttons["tab_levels"].waitForExistence(timeout: 5))
    }
}
