import XCTest

final class FlashcardAppUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    /// The assertions below read Vietnamese and English copy; pin the app language instead of trusting the simulator's.
    private func makeApp(language: String = "vi", locale: String = "vi_VN") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        // Study preferences persist between runs; pin the ones the tests depend on.
        app.launchArguments += ["-com.flashcardapp.study.mode", "flip", "-com.flashcardapp.study.shuffled", "NO",
                                "-com.flashcardapp.study.autoSpeak", "NO"]
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
        XCTAssertTrue(app.tables["deck_library"].waitForExistence(timeout: 10))
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
        app.buttons["new_deck_manual"].tap()
        let name = app.textViews["deck_name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Bộ kiểm tra bàn phím")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let toolbar = app.otherElements["deck_keyboard_toolbar"]
        XCTAssertTrue(toolbar.exists)
        XCTAssertLessThanOrEqual(toolbar.frame.maxY, app.keyboards.firstMatch.frame.minY + 2)
        app.buttons["close_deck_editor"].tap()
        let discard = app.alerts.buttons["Bỏ thay đổi"]
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

    // MARK: Website account against the local backend

    private func openLogin(_ app: XCUIApplication) {
        let settings = app.tabBars.buttons["tab_settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 40))
        settings.tap()
        let signIn = app.buttons["setting_sign_in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 10))
        signIn.tap()
        XCTAssertTrue(app.buttons["website_login_button"].waitForExistence(timeout: 5))
    }

    private func submitLogin(_ app: XCUIApplication, email: String, password: String) {
        let emailField = app.textFields["website_email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(email)
        let passwordField = app.secureTextFields["website_password"]
        passwordField.tap()
        passwordField.typeText(password)
        // The software keyboard must leave the focused field and the primary action reachable.
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "Software keyboard is showing")
        XCTAssertLessThanOrEqual(passwordField.frame.maxY, keyboard.frame.minY, "Password field is not covered")
        XCTAssertTrue(app.buttons["website_login_button"].isHittable, "Sign In stays reachable above the keyboard")
        let signInFrame = app.buttons["website_login_button"].frame
        XCTAssertGreaterThanOrEqual(signInFrame.minX, 0, "Form is not scrolled sideways: \(signInFrame) in \(app.frame)")
        XCTAssertLessThanOrEqual(signInFrame.maxX, app.frame.width, "Form is not scrolled sideways: \(signInFrame) in \(app.frame)")
        attachScreenshot(app, name: "login-filled-keyboard")
        app.buttons["website_login_button"].tap()
    }

    /// Wrong credentials are refused by the real server and leave the user on the login screen, signed out.
    func testLiveLoginRejectsWrongPassword() {
        let app = makeApp()
        app.launch()
        openLogin(app)
        submitLogin(app, email: "nobody-\(UUID().uuidString.prefix(8))@example.com", password: UUID().uuidString)
        let message = app.staticTexts["Email hoặc mật khẩu không đúng."]
        XCTAssertTrue(message.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["website_login_button"].isEnabled, "The form is usable again after the failure")
        attachScreenshot(app, name: "login-wrong-password")
        XCTAssertFalse(app.tabBars.buttons["tab_levels"].exists)
    }

    /// Needs a disposable local account: TEST_RUNNER_FLASHCARD_E2E_EMAIL / TEST_RUNNER_FLASHCARD_E2E_PASSWORD.
    /// Login, session shown in Settings, restored after relaunch, then logout clears it.
    func testLiveLoginSurvivesRelaunchAndLogoutEndsTheSession() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let email = environment["FLASHCARD_E2E_EMAIL"], let password = environment["FLASHCARD_E2E_PASSWORD"] else {
            throw XCTSkip("No disposable local account supplied")
        }
        let app = makeApp()
        app.launch()
        openLogin(app)
        submitLogin(app, email: email, password: password)
        XCTAssertTrue(app.tabBars.buttons["tab_levels"].waitForExistence(timeout: 20), "Successful login lands on Main")

        let signedIn = NSPredicate(format: "label CONTAINS %@", email)
        func showSettingsAccount(_ app: XCUIApplication) {
            app.tabBars.buttons["tab_settings"].tap()
            XCTAssertTrue(app.cells["setting_account"].waitForExistence(timeout: 10))
            XCTAssertFalse(app.buttons["setting_sign_in"].exists)
        }
        showSettingsAccount(app)
        XCTAssertTrue(app.descendants(matching: .any).matching(signedIn).firstMatch.waitForExistence(timeout: 15))
        attachScreenshot(app, name: "settings-signed-in")

        // Restart: the Keychain session is restored and confirmed by the server.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["tab_settings"].waitForExistence(timeout: 40))
        showSettingsAccount(app)
        XCTAssertTrue(app.descendants(matching: .any).matching(signedIn).firstMatch.waitForExistence(timeout: 15))
        let displayName = NSPredicate(format: "label CONTAINS %@", "iOS Auth Test")
        XCTAssertTrue(app.descendants(matching: .any).matching(displayName).firstMatch.waitForExistence(timeout: 15),
                      "Profile refreshed from /auth/me")
        attachScreenshot(app, name: "settings-restored-after-relaunch")

        // Logout: confirm, land on the login screen, and stay signed out after another relaunch.
        let logout = app.cells["setting_logout"]
        for _ in 0..<4 where !logout.isHittable { app.tables["settings_list"].swipeUp() }
        logout.tap()
        let confirm = app.alerts.buttons["Đăng xuất"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.buttons["website_login_button"].waitForExistence(timeout: 15))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["tab_settings"].waitForExistence(timeout: 40))
        app.tabBars.buttons["tab_settings"].tap()
        XCTAssertTrue(app.buttons["setting_sign_in"].waitForExistence(timeout: 10), "No session survives logout")
    }

    // MARK: Cards: create, study, edit, persist, delete

    /// The whole learner journey on real UI and the real Realm store: make a deck, study it (flip, quiz, summary),
    /// add a card to it, relaunch the app and find the change, then delete it.
    func testDeckCanBeCreatedStudiedEditedPersistedAndDeleted() {
        let app = makeApp()
        app.launch()
        let name = "UI \(UUID().uuidString.prefix(6))"
        addTeardownBlock { self.deleteDeckIfPresent(named: name, orNamed: name) }
        openCards(app)

        // Create
        openNewDeckEditor(app)
        let nameField = app.textViews["deck_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        fillCard(app, index: 0, front: "dog", back: "cho")
        fillCard(app, index: 1, front: "cat", back: "meo")
        attachScreenshot(app, name: "editor-filled")
        app.buttons["save_deck"].tap()
        let row = deckRow(app, named: name)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The saved deck appears in the library")

        // Study: flip, next, finish, summary
        row.tap()
        let card = app.buttons["study_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("dog"))
        app.buttons["study_primary"].tap()
        XCTAssertTrue(waitForLabel(card, containing: "cho"), "The card flipped to its back")
        app.buttons["study_primary"].tap()
        XCTAssertTrue(waitForLabel(card, containing: "cat"))
        app.buttons["study_primary"].tap()
        app.buttons["study_primary"].tap()
        XCTAssertTrue(app.otherElements["study_summary"].waitForExistence(timeout: 5))
        attachScreenshot(app, name: "study-summary")
        app.buttons["study_restart"].tap()
        XCTAssertTrue(app.buttons["study_card"].waitForExistence(timeout: 5))

        // Quiz: the right option is accepted, the primary button then moves on
        app.buttons["study_options"].tap()
        app.buttons["Trắc nghiệm"].tap()
        let correct = app.buttons["study_option_0"].label == "cho" ? app.buttons["study_option_0"] : app.buttons["study_option_1"]
        XCTAssertTrue(correct.waitForExistence(timeout: 5))
        correct.tap()
        XCTAssertTrue(app.staticTexts["study_feedback"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["study_feedback"].label, "Chính xác")
        attachScreenshot(app, name: "quiz-answered")

        // Edit from the study screen: the stored values are loaded, an added card is saved
        app.buttons["study_options"].tap()
        app.buttons["Sửa bộ thẻ"].tap()
        let editedName = app.textViews["deck_name"]
        XCTAssertTrue(editedName.waitForExistence(timeout: 5))
        XCTAssertEqual(editedName.value as? String, name)
        XCTAssertEqual(app.textViews.matching(identifier: "card_front").element(boundBy: 0).value as? String, "dog")
        app.cells["add_card"].tap()
        let newFront = app.textViews.matching(identifier: "card_front").element(boundBy: 2)
        XCTAssertTrue(newFront.waitForExistence(timeout: 5))
        newFront.typeText("bird")
        app.textViews.matching(identifier: "card_back").element(boundBy: 2).tap()
        app.textViews.matching(identifier: "card_back").element(boundBy: 2).typeText("chim")
        app.buttons["save_deck"].tap()
        XCTAssertTrue(app.buttons["study_card"].waitForExistence(timeout: 5), "Saving returns to the study screen")

        // The edit survives a relaunch of the app
        app.terminate()
        app.launch()
        openCards(app)
        let reloaded = deckRow(app, named: name)
        XCTAssertTrue(reloaded.waitForExistence(timeout: 10), "The deck is still there after relaunch")
        XCTAssertTrue(reloaded.label.contains("3 thẻ"), "The added card was saved: \(reloaded.label)")

        // Delete
        deleteDeckIfPresent(named: name, orNamed: name)
        app.terminate()
        app.launch()
        openCards(app)
        XCTAssertFalse(deckRow(app, named: name).waitForExistence(timeout: 3), "The deleted deck is gone after a relaunch")
    }

    /// With no matching deck the library says so instead of showing an empty table.
    func testSearchWithoutMatchesShowsAMessage() {
        let app = makeApp()
        app.launch()
        openCards(app)
        let name = "UI \(UUID().uuidString.prefix(6))"
        addTeardownBlock { self.deleteDeckIfPresent(named: name, orNamed: name) }
        openNewDeckEditor(app)
        let nameField = app.textViews["deck_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        fillCard(app, index: 0, front: "a", back: "b")
        fillCard(app, index: 1, front: "c", back: "d")
        app.buttons["save_deck"].tap()
        XCTAssertTrue(deckRow(app, named: name).waitForExistence(timeout: 10))
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("zzzz-no-such-deck")
        attachScreenshot(app, name: "search-no-results")
        XCTAssertTrue(app.staticTexts["Không có bộ thẻ phù hợp"].waitForExistence(timeout: 5), "A search without results says so")
        XCTAssertTrue(app.staticTexts["Không có gì khớp với “zzzz-no-such-deck”."].exists, "The message names the search that found nothing")
        // Clearing the search brings the deck back (and lets the cleanup in teardown reach its row).
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "zzzz-no-such-deck".count))
        XCTAssertTrue(deckRow(app, named: name).waitForExistence(timeout: 5), "Clearing the search lists the deck again")
    }

    /// Saving without a name or cards shows what is missing and keeps the editor open.
    func testSavingAnEmptyDeckShowsInlineProblems() {
        let app = makeApp()
        app.launch()
        openCards(app)
        openNewDeckEditor(app)
        XCTAssertTrue(app.buttons["save_deck"].waitForExistence(timeout: 5))
        app.buttons["save_deck"].tap()
        XCTAssertTrue(app.staticTexts["Hãy nhập tên bộ thẻ."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["save_deck"].exists, "The editor stays open")
        attachScreenshot(app, name: "editor-problems")
        app.buttons["close_deck_editor"].tap()
        XCTAssertTrue(app.tables["deck_library"].waitForExistence(timeout: 5), "A clean editor closes without a prompt")
    }

    /// Unsaved work from an earlier run is offered back; these tests want a blank editor.
    private func openNewDeckEditor(_ app: XCUIApplication) {
        app.buttons["create_deck_button"].tap()
        XCTAssertTrue(app.buttons["new_deck_manual"].waitForExistence(timeout: 5), "Creating a deck first offers typing it or generating it")
        app.buttons["new_deck_manual"].tap()
        let prompt = app.alerts["Tìm thấy bản nháp chưa lưu"]
        if prompt.waitForExistence(timeout: 4) { prompt.buttons["Bỏ bản nháp"].tap() }
    }

    /// Typing is autosaved as a draft; after the app is killed the editor offers it back and restores it.
    func testUnsavedDeckIsRecoveredAfterTheAppIsKilled() {
        let app = makeApp()
        app.launch()
        openCards(app)
        openNewDeckEditor(app)
        let name = "Draft \(UUID().uuidString.prefix(6))"
        let nameField = app.textViews["deck_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        fillCard(app, index: 0, front: "dog", back: "cho")
        sleep(2)   // the draft is written shortly after the last keystroke
        app.terminate()
        app.launch()
        openCards(app)
        app.buttons["create_deck_button"].tap()
        app.buttons["new_deck_manual"].tap()
        let prompt = app.alerts["Tìm thấy bản nháp chưa lưu"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5), "The unsaved draft is offered after a relaunch")
        attachScreenshot(app, name: "draft-offer")
        prompt.buttons["Khôi phục bản nháp"].tap()
        XCTAssertEqual(app.textViews["deck_name"].value as? String, name)
        XCTAssertEqual(app.textViews.matching(identifier: "card_front").element(boundBy: 0).value as? String, "dog")
        // Leave without saving and without leaving a draft behind for the next run.
        app.buttons["close_deck_editor"].tap()
        app.alerts.buttons["Bỏ thay đổi"].tap()
        XCTAssertTrue(app.tables["deck_library"].waitForExistence(timeout: 5))
    }

    // MARK: Deck creation: two methods, dictionary suggestions, picture search

    /// The two creation methods are offered side by side, and auto-generate opens its own screen with every choice.
    func testCreatingADeckOffersTypingOrGeneratingAndTheGeneratorShowsItsChoices() {
        let app = makeApp()
        app.launch()
        openCards(app)
        app.buttons["create_deck_button"].tap()
        XCTAssertTrue(app.buttons["new_deck_manual"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["new_deck_auto"].exists)
        attachScreenshot(app, name: "new-deck-options")
        app.buttons["new_deck_auto"].tap()
        XCTAssertTrue(app.segmentedControls["generator_level"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.segmentedControls["generator_level"].buttons.count, 5, "N5 to N1")
        for type in ["lexeme", "kanji", "grammar"] { XCTAssertTrue(app.buttons["generator_type_\(type)"].exists, type) }
        XCTAssertTrue(app.buttons["generator_direction"].exists)
        XCTAssertTrue(app.sliders["generator_count"].exists)
        XCTAssertTrue(app.buttons["generate_deck"].exists)
        // Signed out the primary action is disabled and the summary offers signing in; signed in it waits for the count.
        let summary = app.otherElements["generator_summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        attachScreenshot(app, name: "generator")
        app.buttons["close_generator"].tap()
        XCTAssertTrue(app.tables["deck_library"].waitForExistence(timeout: 5), "Closing the generator returns to the library")
    }

    /// Typing a Japanese word offers dictionary entries; choosing one fills the card, and a field the learner already
    /// wrote is left alone.
    func testTypingAJapaneseWordOffersDictionaryEntriesThatFillTheCard() {
        let app = makeApp()
        app.launch()
        openCards(app)
        let name = "UI \(UUID().uuidString.prefix(6))"
        addTeardownBlock { self.deleteDeckIfPresent(named: name, orNamed: name) }
        openNewDeckEditor(app)
        let nameField = app.textViews["deck_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        let front = app.textViews.matching(identifier: "card_front").element(boundBy: 0)
        front.tap()
        front.typeText("犬")
        let suggestion = app.buttons["dictionary_suggestion_1"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 10), "The dictionary API answers")
        attachScreenshot(app, name: "dictionary-suggestions")
        suggestion.tap()
        let back = app.textViews.matching(identifier: "card_back").element(boundBy: 0)
        XCTAssertFalse((back.value as? String ?? "").isEmpty, "The meaning was filled in")
        XCTAssertTrue((front.value as? String ?? "").contains("犬"), "The Japanese word stays on the front")
        XCTAssertFalse(app.buttons["dictionary_suggestion_1"].exists, "The bar clears after choosing")
        attachScreenshot(app, name: "dictionary-applied")
        app.buttons["close_deck_editor"].tap()
        app.alerts.buttons["Bỏ thay đổi"].tap()
        XCTAssertTrue(app.tables["deck_library"].waitForExistence(timeout: 5))
    }

    /// Picture search is reachable from a card, says honestly when it cannot help, and never blocks the editor.
    func testPictureSearchOpensFromACardAndCanBeClosed() {
        let app = makeApp()
        app.launch()
        openCards(app)
        openNewDeckEditor(app)
        let front = app.textViews.matching(identifier: "card_front").element(boundBy: 0)
        XCTAssertTrue(front.waitForExistence(timeout: 5))
        front.tap()
        front.typeText("chó")
        app.buttons.matching(identifier: "card_picture").element(boundBy: 0).tap()
        let find = app.buttons["Tìm ảnh…"]
        XCTAssertTrue(find.waitForExistence(timeout: 5), "The picture menu offers a search next to Photos and a web address")
        find.tap()
        XCTAssertTrue(app.otherElements["picture_search_state"].waitForExistence(timeout: 10)
                      || app.collectionViews["picture_search_results"].waitForExistence(timeout: 1))
        attachScreenshot(app, name: "picture-search")
        app.buttons["picture_search_close"].tap()
        XCTAssertTrue(app.buttons["save_deck"].waitForExistence(timeout: 5), "Editing continues after the search is closed")
        app.buttons["close_deck_editor"].tap()
        app.alerts.buttons["Bỏ thay đổi"].tap()
    }

    private func openCards(_ app: XCUIApplication) {
        let cards = app.tabBars.buttons["tab_cards"]
        XCTAssertTrue(cards.waitForExistence(timeout: 40))
        cards.tap()
        XCTAssertTrue(app.tables["deck_library"].waitForExistence(timeout: 10))
    }

    private func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }

    private func fillCard(_ app: XCUIApplication, index: Int, front: String, back: String) {
        let frontField = app.textViews.matching(identifier: "card_front").element(boundBy: index)
        if !frontField.isHittable { app.tables["deck_editor_table"].swipeUp() }
        frontField.tap()
        frontField.typeText(front)
        let backField = app.textViews.matching(identifier: "card_back").element(boundBy: index)
        backField.tap()
        backField.typeText(back)
    }

    private func deckRow(_ app: XCUIApplication, named name: String) -> XCUIElement {
        app.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "deck_row_", name)).firstMatch
    }

    /// Cleans up the deck a test made (whichever name it ended with) through the editor's "Delete deck", so runs do not
    /// accumulate decks. Best effort: it only acts when the library is on screen.
    private func deleteDeckIfPresent(named first: String, orNamed second: String) {
        let app = XCUIApplication()
        guard app.state == .runningForeground else { return }
        if !app.tables["deck_library"].exists, app.tabBars.buttons["tab_cards"].exists { app.tabBars.buttons["tab_cards"].tap() }
        guard app.tables["deck_library"].waitForExistence(timeout: 3) else { return }
        for name in first == second ? [first] : [first, second] {
            let row = deckRow(app, named: name)
            guard row.waitForExistence(timeout: 2) else { continue }
            // Bring the list to its top (the large title / search field overlap a scrolled list), then tap the row's centre.
            app.tables["deck_library"].swipeDown()
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            guard app.buttons["study_options"].waitForExistence(timeout: 5) else { continue }
            app.buttons["study_options"].tap()
            app.buttons["Sửa bộ thẻ"].tap()
            guard app.buttons["deck_more"].waitForExistence(timeout: 5) else { continue }
            app.buttons["deck_more"].tap()
            app.buttons["Xoá bộ thẻ"].tap()
            let confirm = app.alerts.buttons["Xoá"]
            if confirm.waitForExistence(timeout: 3) { confirm.tap() }
            _ = app.tables["deck_library"].waitForExistence(timeout: 5)
        }
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
