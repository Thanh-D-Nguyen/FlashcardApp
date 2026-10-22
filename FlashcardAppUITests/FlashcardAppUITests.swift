import XCTest

final class FlashcardAppUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    /// The assertions below read Vietnamese and English copy; pin the app language instead of trusting the simulator's.
    private func makeApp(language: String = "vi", locale: String = "vi_VN") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        return app
    }

    func testLiveLevelsAndContentCanBeBrowsedWithoutLogin() {
        let app = makeApp()
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
        let app = makeApp()
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
        let app = makeApp()
        app.launch()
        let cards = app.tabBars.buttons["tab_cards"]
        XCTAssertTrue(cards.waitForExistence(timeout: 40))
        cards.tap()
        XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["tab_settings"].tap()
        XCTAssertTrue(app.tables.firstMatch.waitForExistence(timeout: 5))
    }

    func testCardEditorKeepsToolbarAboveKeyboardAndCanDiscard() {
        let app = makeApp()
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
        let app = makeApp()
        app.launch()
        let settings = app.tabBars.buttons["tab_settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 40))
        settings.tap()
        app.tables.cells.firstMatch.tap()
        let login = app.buttons["website_login_button"]
        XCTAssertTrue(login.waitForExistence(timeout: 5))
        login.tap()
        XCTAssertTrue(app.staticTexts["Nhập địa chỉ email hợp lệ."].waitForExistence(timeout: 5))
        app.buttons["continueWithoutLoginButton"].tap()
        XCTAssertTrue(app.tabBars.buttons["tab_levels"].waitForExistence(timeout: 5))
    }

    /// Levels and a level's content stay reachable at the largest accessibility text size.
    func testLevelsAndContentRemainUsableAtAccessibilityTextSize() {
        let app = makeApp()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let levels = app.tables["home_levels"]
        XCTAssertTrue(levels.waitForExistence(timeout: 40))
        let firstLevel = levels.cells["home_row_J5"]
        XCTAssertTrue(firstLevel.waitForExistence(timeout: 15))
        attachScreenshot(app, name: "levels-ax-xxxl")
        firstLevel.tap()
        let content = app.tables["level_content"]
        XCTAssertTrue(content.waitForExistence(timeout: 10))
        let firstContent = content.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home_row_")).firstMatch
        XCTAssertTrue(firstContent.waitForExistence(timeout: 15))
        XCTAssertTrue(firstContent.isHittable)
        attachScreenshot(app, name: "content-ax-xxxl")
    }

    /// The featured level's primary action opens its vocabulary.
    func testFeaturedStartOpensVocabulary() {
        let app = makeApp()
        app.launch()
        let start = app.buttons["home_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 40))
        start.tap()
        XCTAssertTrue(app.tables["level_content"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.segmentedControls["level_content_kind"].buttons["Từ vựng"].isSelected)
    }

    /// A level's count opens that kind directly, skipping the kind chooser.
    func testLevelCountOpensItsKindDirectly() {
        let app = makeApp()
        app.launch()
        let levels = app.tables["home_levels"]
        XCTAssertTrue(levels.waitForExistence(timeout: 40))
        let grammar = app.buttons["home_kind_J4_grammar"]
        XCTAssertTrue(grammar.waitForExistence(timeout: 15))
        if !grammar.isHittable { levels.swipeUp() }
        grammar.tap()
        XCTAssertTrue(app.tables["level_content"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.segmentedControls["level_content_kind"].buttons["Ngữ pháp"].isSelected)
    }

    /// Appearance is a pop-up menu on the row; the choice is shown immediately and restored afterwards.
    func testSettingsAppearanceMenuChangesSelection() {
        let app = makeApp()
        app.launch()
        let settings = app.tabBars.buttons["tab_settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 40))
        settings.tap()
        let menu = app.buttons["Giao diện"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        // The choice is persisted in the app's defaults; put it back even if an assertion below fails.
        addTeardownBlock {
            guard app.state == .runningForeground, app.buttons["Giao diện"].exists,
                  app.buttons["Giao diện"].value as? String != "Theo hệ thống" else { return }
            app.buttons["Giao diện"].tap()
            app.buttons["Theo hệ thống"].tap()
        }
        menu.tap()
        app.buttons["Tối"].tap()
        XCTAssertEqual(app.buttons["Giao diện"].value as? String, "Tối")
        app.buttons["Giao diện"].tap()
        app.buttons["Theo hệ thống"].tap()
        XCTAssertEqual(app.buttons["Giao diện"].value as? String, "Theo hệ thống")
    }

    /// A longer value replacing a shorter one ("Tối" → "Theo hệ thống") must stay on one line, flush with the trailing edge.
    func testSettingsAppearanceValueStaysOneLineWhenSelectionChanges() {
        let app = makeApp()
        app.launch()
        let settings = app.tabBars.buttons["tab_settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 40))
        settings.tap()
        let menu = app.buttons["Giao diện"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        addTeardownBlock {
            guard app.state == .runningForeground, app.buttons["Giao diện"].exists,
                  app.buttons["Giao diện"].value as? String != "Theo hệ thống" else { return }
            app.buttons["Giao diện"].tap()
            app.buttons["Theo hệ thống"].tap()
        }
        let before = menu.frame
        menu.tap()
        app.buttons["Tối"].tap()
        let short = app.buttons["Giao diện"].frame
        XCTAssertLessThan(short.width, before.width, "Precondition: the shorter value gives a narrower button")
        app.buttons["Giao diện"].tap()
        app.buttons["Theo hệ thống"].tap()
        let after = app.buttons["Giao diện"].frame
        XCTAssertEqual(after.height, before.height, accuracy: 1, "Value wrapped onto a second line")
        XCTAssertEqual(after.width, before.width, accuracy: 1)
        XCTAssertEqual(after.maxX, before.maxX, accuracy: 1, "Value drifted away from the trailing edge")
    }

    /// Flipping a switch reloads the list; the appearance value must keep its single-line size and position.
    func testSettingsAppearanceValueKeepsLayoutAfterTogglingSwitch() {
        let app = makeApp()
        app.launch()
        let settings = app.tabBars.buttons["tab_settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 40))
        settings.tap()
        let menu = app.buttons["Giao diện"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        let before = menu.frame
        let sound = app.switches["Âm thanh và rung"]
        XCTAssertTrue(sound.waitForExistence(timeout: 5))
        sound.tap()
        sound.tap()
        let after = app.buttons["Giao diện"].frame
        XCTAssertEqual(after.height, before.height, accuracy: 1, "Value wrapped onto a second line after the list reloaded")
        XCTAssertEqual(after.width, before.width, accuracy: 1)
        XCTAssertEqual(after.maxX, before.maxX, accuracy: 1, "Value drifted away from the trailing edge")
    }

    /// English and Japanese are required UI languages: tab titles, Settings copy and the level text from the backend follow the language.
    func testInterfaceFollowsTheAppLanguage() {
        let cases: [(language: String, locale: String, levelsTab: String, signIn: String, start: String)] = [
            ("en", "en_US", "Levels", "Sign In", "Start studying vocabulary, J5"),
            ("ja", "ja_JP", "レベル", "ログイン", "J5の単語の学習を始める")
        ]
        for item in cases {
            let app = makeApp(language: item.language, locale: item.locale)
            app.launch()
            let tab = app.tabBars.buttons["tab_levels"]
            XCTAssertTrue(tab.waitForExistence(timeout: 40), item.language)
            XCTAssertEqual(tab.label, item.levelsTab)
            XCTAssertEqual(app.buttons["home_start"].label, item.start)
            app.tabBars.buttons["tab_settings"].tap()
            let signIn = app.buttons["setting_sign_in"]
            XCTAssertTrue(signIn.waitForExistence(timeout: 10), item.language)
            XCTAssertEqual(signIn.label, item.signIn)
            app.terminate()
        }
    }

    /// Signed out, the account header carries the one primary action and it opens the login screen.
    func testSettingsSignInButtonOpensLogin() {
        let app = makeApp()
        app.launch()
        let settings = app.tabBars.buttons["tab_settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 40))
        settings.tap()
        let signIn = app.buttons["setting_sign_in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 10))
        signIn.tap()
        XCTAssertTrue(app.buttons["website_login_button"].waitForExistence(timeout: 5))
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
