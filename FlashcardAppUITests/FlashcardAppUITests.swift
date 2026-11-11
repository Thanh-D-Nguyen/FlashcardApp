import XCTest

final class FlashcardAppUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    /// The assertions below read Vietnamese and English copy; pin the app language instead of trusting the simulator's.
    private func makeApp(language: String = "vi", locale: String = "vi_VN", pinCardStyle: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        // Study preferences persist between runs; pin the ones the tests depend on. An empty style slug is the app's own card.
        // A pinned value also hides later writes, so the test that changes the card style leaves it unpinned.
        // The sentence panel's open/closed choice is not pinned for the same reason; its test restores it.
        app.launchArguments += ["-com.flashcardapp.study.mode", "flip", "-com.flashcardapp.study.shuffled", "NO",
                                "-com.flashcardapp.study.autoSpeak", "NO"]
        if pinCardStyle { app.launchArguments += ["-com.flashcardapp.study.cardStyle", ""] }
        return app
    }

    /// The first tab is Today; the levels are one tap away on its "Study by level" row.
    private func openLevels(_ app: XCUIApplication) {
        let row = app.buttons["today_levels_row"]
        XCTAssertTrue(row.waitForExistence(timeout: 40), "Today is the first screen")
        row.tap()
    }

    func testLiveLevelsAndContentCanBeBrowsedWithoutLogin() {
        let app = makeApp()
        app.launch()
        openLevels(app)
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
        // A result opens its own detail screen (the entry), not a dialog; the full journeys are in DictionaryUITests.
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "entry_title").firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts.firstMatch.exists)
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

    func testReminderTapOpensCardsReviewOnColdStart() {
        let app = makeApp()
        app.launchArguments += ["-OpenStudyReminder", "-disableAds"]
        app.launch()

        let cards = app.tabBars.buttons["tab_cards"]
        XCTAssertTrue(cards.waitForExistence(timeout: 40))
        XCTAssertTrue(cards.isSelected)
        XCTAssertTrue(app.tables["deck_library"].waitForExistence(timeout: 10))
        let reviewScope = app.buttons.matching(identifier: "cards_scope_review").firstMatch
        XCTAssertTrue(reviewScope.waitForExistence(timeout: 10))
        XCTAssertTrue(reviewScope.isSelected, "The reminder must select the Review section regardless of language or login state")
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
        openLevels(app)
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
        openLevels(app)
        let start = app.buttons["home_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 40))
        start.tap()
        XCTAssertTrue(app.tables["level_content"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.segmentedControls["level_content_kind"].buttons["Từ vựng"].isSelected)
    }

    /// A level with structured lessons offers them from its screen, grouped by week.
    func testLevelScreenOpensItsLessonsGroupedByWeek() {
        let app = makeApp()
        app.launch()
        openLevels(app)
        let start = app.buttons["home_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 40))
        start.tap()
        let lessons = app.buttons["level_lessons"]
        XCTAssertTrue(lessons.waitForExistence(timeout: 10))
        lessons.tap()
        XCTAssertTrue(app.tables["lesson_list"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Tuần 1"].waitForExistence(timeout: 20), "The first week header follows the loaded lessons")
        let row = app.descendants(matching: .any).matching(identifier: "lesson_row_j5-01-greetings-intro").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.tables["lesson_reader"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "lesson_reader_title").firstMatch.waitForExistence(timeout: 20), "The lesson loaded and shows its title")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Tình huống")).firstMatch.waitForExistence(timeout: 5), "The first section is the situation")
    }

    /// A guest answers every activity of a lesson, sees the reveal for each, and finishes with the lesson saved on the device.
    func testGuestCanPractiseALessonToTheEnd() {
        let app = makeApp()
        app.launch()
        openLevels(app)
        let start = app.buttons["home_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 40))
        start.tap()
        let lessons = app.buttons["level_lessons"]
        XCTAssertTrue(lessons.waitForExistence(timeout: 10))
        lessons.tap()
        let row = app.descendants(matching: .any).matching(identifier: "lesson_row_j5-01-greetings-intro").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()
        let practice = app.descendants(matching: .any).matching(identifier: "lesson_practice").firstMatch
        XCTAssertTrue(practice.waitForExistence(timeout: 20), "The lesson loaded and offers its activities")
        practice.tap()
        // The device keeps progress between runs, so a lesson finished earlier opens straight on its summary.
        for _ in 0..<5 {
            let option = app.descendants(matching: .any).matching(identifier: "practice_option_0").firstMatch
            guard option.waitForExistence(timeout: 5) else { break }
            option.tap()
            let next = app.descendants(matching: .any).matching(identifier: "practice_next").firstMatch
            XCTAssertTrue(next.waitForExistence(timeout: 5), "Answering reveals the result and offers the next step")
            next.tap()
        }
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "practice_back").firstMatch.waitForExistence(timeout: 10), "The lesson ends on its summary")
    }

    /// The learner chooses a deck for a lesson's words; saving again is harmless and reports what was already there.
    func testLessonWordsCanBeSavedToADeckTheLearnerPicks() {
        let app = makeApp()
        app.launch()
        openLevels(app)
        let start = app.buttons["home_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 40))
        start.tap()
        let lessons = app.buttons["level_lessons"]
        XCTAssertTrue(lessons.waitForExistence(timeout: 10))
        lessons.tap()
        let row = app.descendants(matching: .any).matching(identifier: "lesson_row_j5-03-email-writing").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()
        let table = app.tables["lesson_reader"]
        XCTAssertTrue(table.waitForExistence(timeout: 10))
        let saveAll = app.descendants(matching: .any).matching(identifier: "lesson_save_all_words").firstMatch
        for _ in 0..<6 where !(saveAll.exists && saveAll.isHittable) { table.swipeUp() }
        XCTAssertTrue(saveAll.waitForExistence(timeout: 10), "The vocabulary section offers to save every word")
        for attempt in 0..<2 {
            saveAll.tap()
            let sheet = app.sheets.firstMatch
            XCTAssertTrue(sheet.waitForExistence(timeout: 5), "The learner is asked which deck")
            let deck = sheet.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Từ các bài học' OR label BEGINSWITH 'Bộ mới'")).firstMatch
            XCTAssertTrue(deck.waitForExistence(timeout: 5))
            deck.tap()
            let alert = app.alerts.firstMatch
            XCTAssertTrue(alert.waitForExistence(timeout: 10), "The result is reported (attempt \(attempt))")
            if attempt == 1 {
                XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS 'đã có sẵn'")).firstMatch.exists, "The repeat reports the words already there")
            }
            alert.buttons.firstMatch.tap()
        }
    }

    /// Today → level → lesson → every activity → back on Today: the lesson slot now offers the learner's next step, and opens it.
    func testTodayOffersTheNextLessonAfterAPracticeAndOpensIt() {
        let app = makeApp()
        app.launch()
        openLevels(app)
        let start = app.buttons["home_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 40))
        start.tap()
        let lessons = app.buttons["level_lessons"]
        XCTAssertTrue(lessons.waitForExistence(timeout: 10))
        lessons.tap()
        let row = app.descendants(matching: .any).matching(identifier: "lesson_row_j5-01-greetings-intro").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()
        let practice = app.descendants(matching: .any).matching(identifier: "lesson_practice").firstMatch
        XCTAssertTrue(practice.waitForExistence(timeout: 20))
        practice.tap()
        for _ in 0..<5 {
            let option = app.descendants(matching: .any).matching(identifier: "practice_option_0").firstMatch
            guard option.waitForExistence(timeout: 5) else { break }
            option.tap()
            let next = app.descendants(matching: .any).matching(identifier: "practice_next").firstMatch
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            next.tap()
        }
        let back = app.descendants(matching: .any).matching(identifier: "practice_back").firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 10))
        // Back out to Today: summary → lesson → lesson list → level → levels → Today.
        for _ in 0..<5 {
            guard app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5) else { break }
            if app.buttons["today_levels_row"].exists || app.scrollViews["today_screen"].exists { break }
            app.navigationBars.buttons.firstMatch.tap()
        }
        let slot = app.descendants(matching: .any).matching(identifier: "today_lesson_slot").firstMatch
        let today = app.scrollViews["today_screen"]
        XCTAssertTrue(today.waitForExistence(timeout: 20))
        for _ in 0..<6 where !(slot.exists && slot.isHittable) { today.swipeUp() }
        XCTAssertTrue(slot.waitForExistence(timeout: 10), "Today shows the lesson slot")
        XCTAssertFalse(slot.label.contains("BÀI HỌC"), "A learner who finished a lesson is not offered the first-time card: \(slot.label)")
        XCTAssertTrue(slot.label.contains("HỌC TIẾP") || slot.label.contains("BÀI TIẾP THEO"), "It continues or offers the next lesson: \(slot.label)")
        slot.tap()
        XCTAssertTrue(app.tables["lesson_reader"].waitForExistence(timeout: 15), "The slot opens the lesson")
    }

    /// A level's count opens that kind directly, skipping the kind chooser.
    func testLevelCountOpensItsKindDirectly() {
        let app = makeApp()
        app.launch()
        openLevels(app)
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
            ("en", "en_US", "Today", "Sign In", "Start studying vocabulary, J5"),
            ("ja", "ja_JP", "今日", "ログイン", "J5の単語の学習を始める")
        ]
        for item in cases {
            let app = makeApp(language: item.language, locale: item.locale)
            app.launch()
            let tab = app.tabBars.buttons["tab_levels"]
            XCTAssertTrue(tab.waitForExistence(timeout: 40), item.language)
            XCTAssertEqual(tab.label, item.levelsTab, "The first tab is Today")
            openLevels(app)
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

    // MARK: Cards: the account's sections

    /// The four sections are always there; the learner's own decks (on the device) are the default and work without an account.
    func testCardsShowsFourSectionsAndOpensOnTheLibraryOnTheDevice() {
        let app = makeApp()
        app.launch()
        openCards(app)
        // The bar is a pinned table header: the accessibility tree lists its chips twice, so every query takes the first match.
        func section(_ id: String) -> XCUIElement { app.buttons.matching(identifier: id).firstMatch }
        let sections = ["cards_scope_review", "cards_scope_mine", "cards_scope_publicDecks", "cards_scope_recent"]
        for id in sections { XCTAssertTrue(section(id).waitForExistence(timeout: 10), id) }
        XCTAssertTrue(section("cards_scope_mine").isSelected, "The decks on the device are the default section")
        section("cards_scope_publicDecks").tap()
        XCTAssertTrue(section("cards_scope_publicDecks").isSelected)
        XCTAssertFalse(section("cards_scope_mine").isSelected)
        attachScreenshot(app, name: "cards-public-section")
        section("cards_scope_mine").tap()
        XCTAssertTrue(app.tables["deck_library"].exists, "Going back shows the library again")
    }

    /// Needs a disposable local account: TEST_RUNNER_FLASHCARD_E2E_EMAIL / TEST_RUNNER_FLASHCARD_E2E_PASSWORD, and a signed build
    /// (the session goes to the Keychain). The Simulator keeps the Keychain after the app is removed, so an existing session is used as it is.
    /// Reads the Review section, the Public section and a public deck against the real backend.
    func testLiveReviewPublicAndRecentSectionsReadTheAccount() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let email = environment["FLASHCARD_E2E_EMAIL"], let password = environment["FLASHCARD_E2E_PASSWORD"] else {
            throw XCTSkip("No disposable local account supplied")
        }
        let app = makeApp()
        app.launch()
        let settings = app.tabBars.buttons["tab_settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 40))
        settings.tap()
        if app.buttons["setting_sign_in"].waitForExistence(timeout: 10) {
            app.buttons["setting_sign_in"].tap()
            XCTAssertTrue(app.buttons["website_login_button"].waitForExistence(timeout: 5))
            submitLogin(app, email: email, password: password)
            XCTAssertTrue(app.tabBars.buttons["tab_levels"].waitForExistence(timeout: 20), "Successful login lands on Main")
        }
        openCards(app)
        func section(_ id: String) -> XCUIElement { app.buttons.matching(identifier: id).firstMatch }
        func deckRows() -> XCUIElement { app.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@", "remote_deck_row_")).firstMatch }

        section("cards_scope_review").tap()
        let caughtUp = app.staticTexts["Bạn đã ôn xong"]
        XCTAssertTrue(app.buttons["review_start"].waitForExistence(timeout: 15) || caughtUp.waitForExistence(timeout: 5),
                      "Review shows what is due, or says nothing is")
        attachScreenshot(app, name: "cards-review-section")

        section("cards_scope_publicDecks").tap()
        XCTAssertTrue(deckRows().waitForExistence(timeout: 15), "The public decks of the website are listed")
        deckRows().tap()
        XCTAssertTrue(app.buttons["remote_deck_study"].waitForExistence(timeout: 15), "A deck opens with its cards and the Study action")
        XCTAssertTrue(app.tables["remote_deck_cards"].cells.firstMatch.exists)
        attachScreenshot(app, name: "cards-public-deck")
        app.navigationBars.buttons.firstMatch.tap()

        section("cards_scope_recent").tap()
        XCTAssertTrue(deckRows().waitForExistence(timeout: 15))
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

        // Study: flip and rate the first card (saved), flip and skip the second, summary
        row.tap()
        let card = app.buttons["study_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("dog"))
        app.buttons["study_primary"].tap()
        XCTAssertTrue(waitForLabel(card, containing: "cho"), "The card flipped to its back")
        XCTAssertFalse(app.buttons["study_primary"].exists, "After the answer is shown the learner rates themselves")
        attachScreenshot(app, name: "study-rating")
        app.buttons["study_rate_remembered"].tap()
        XCTAssertTrue(app.staticTexts["study_save_status"].waitForExistence(timeout: 5), "A saved rating is confirmed")
        XCTAssertTrue(app.staticTexts["study_saved"].label.contains("1"), "One attempt is saved: \(app.staticTexts["study_saved"].label)")
        app.buttons["study_primary"].tap()
        XCTAssertTrue(waitForLabel(card, containing: "cat"))
        app.buttons["study_primary"].tap()
        app.buttons["study_skip_rating"].tap()
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
        waitForDictionaryLookup(app)
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

    /// Needs a disposable local account (TEST_RUNNER_FLASHCARD_E2E_EMAIL / _PASSWORD) and a signed (ad-hoc) build for the Keychain.
    /// The real server creates the deck and the app imports its real cards: the editor opens with filled-in cards and the
    /// deck is in the library. Generation is not idempotent, so this runs once per tap and the deck is deleted afterwards.
    func testLiveAutoGenerateCreatesARealDeckWithServerCards() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let email = environment["FLASHCARD_E2E_EMAIL"], let password = environment["FLASHCARD_E2E_PASSWORD"] else {
            throw XCTSkip("No disposable local account supplied")
        }
        let app = makeApp()
        app.launch()
        openLogin(app)
        submitLogin(app, email: email, password: password)
        XCTAssertTrue(app.tabBars.buttons["tab_levels"].waitForExistence(timeout: 20), "Successful login lands on Main")
        openCards(app)

        let name = "UI gen \(UUID().uuidString.prefix(6))"
        addTeardownBlock { self.deleteDeckIfPresent(named: name, orNamed: name) }
        app.buttons["create_deck_button"].tap()
        XCTAssertTrue(app.buttons["new_deck_auto"].waitForExistence(timeout: 5))
        app.buttons["new_deck_auto"].tap()
        let nameField = app.textFields["generator_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        // The field starts with a suggested name: delete it, then type ours.
        nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (nameField.value as? String ?? "").count))
        nameField.typeText(name)
        app.keyboards.buttons["Done"].tap()

        // The server counts the cards it can supply (N5 vocabulary is the seeded content) before anything is created.
        let generate = app.buttons["generate_deck"]
        let enabled = NSPredicate(format: "isEnabled == true")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: enabled, object: generate)], timeout: 20), .completed,
                       "The server reports enough N5 cards to generate")
        attachScreenshot(app, name: "generator-ready")
        generate.tap()

        // The deck opens in the editor with the server's cards.
        let firstFront = app.textViews.matching(identifier: "card_front").element(boundBy: 0)
        XCTAssertTrue(firstFront.waitForExistence(timeout: 30), "The generated cards are opened for review")
        XCTAssertFalse((firstFront.value as? String ?? "").isEmpty, "The first card has real front text")
        attachScreenshot(app, name: "generated-deck-editor")
        app.buttons["close_deck_editor"].tap()
        XCTAssertTrue(app.tables["deck_library"].waitForExistence(timeout: 5))
        XCTAssertTrue(deckRow(app, named: name).waitForExistence(timeout: 10), "The generated deck is in the library")
    }

    /// After the flip the card shows example sentences from the dictionary API (hidden before it), which can be hidden,
    /// read aloud and copied; the card style is chosen from a sheet and remembered.
    func testStudyShowsExampleSentencesAfterTheFlipAndTheCardStyleCanBeChosen() {
        let app = makeApp(pinCardStyle: false)
        app.launch()
        openCards(app)
        let name = "UI \(UUID().uuidString.prefix(6))"
        addTeardownBlock { self.deleteDeckIfPresent(named: name, orNamed: name) }
        openNewDeckEditor(app)
        let nameField = app.textViews["deck_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        fillCard(app, index: 0, front: "犬", back: "chó")
        fillCard(app, index: 1, front: "猫", back: "mèo")
        app.buttons["save_deck"].tap()
        let row = deckRow(app, named: name)
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let card = app.buttons["study_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))

        XCTAssertFalse(app.buttons["study_example_speak_0"].exists, "The front must not show sentences")
        app.buttons["study_primary"].tap()
        let speak = app.buttons["study_example_speak_0"]
        XCTAssertTrue(speak.waitForExistence(timeout: 20), "Example sentences for 犬 come from the API")
        XCTAssertTrue(app.buttons["study_example_copy_0"].exists)
        attachScreenshot(app, name: "study-examples")

        app.buttons["study_example_copy_0"].tap()
        XCTAssertTrue(waitForLabel(app.buttons["study_example_copy_0"], containing: "Đã sao chép"), "Copying is confirmed")

        let toggle = app.buttons["study_examples_toggle"]
        if waitForLabel(toggle, containing: "Hiện", timeout: 1) { toggle.tap() }   // a run that stopped half way left it collapsed
        XCTAssertTrue(waitForLabel(toggle, containing: "Ẩn"), "The panel is open")
        toggle.tap()
        XCTAssertTrue(waitForLabel(toggle, containing: "Hiện"), "The panel collapsed")
        XCTAssertFalse(speak.exists)
        toggle.tap()
        XCTAssertTrue(app.buttons["study_example_speak_0"].waitForExistence(timeout: 5), "The panel expanded again")

        // Card style: the sheet marks the current style, a choice is remembered and the default can be restored.
        func tile(_ slug: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: "card_style_\(slug)").firstMatch }
        app.buttons["study_options"].tap()
        app.buttons["study_card_style"].tap()
        XCTAssertTrue(tile("minimal-ink").waitForExistence(timeout: 5))
        tile("default").tap()   // the style persists between runs: start from the app's own card
        XCTAssertTrue(tile("default").isSelected)
        tile("minimal-ink").tap()
        XCTAssertFalse(tile("default").isSelected, "Only one style is marked")
        XCTAssertTrue(tile("minimal-ink").isSelected)
        attachScreenshot(app, name: "card-style-sheet")
        app.buttons["card_style_done"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        app.buttons["study_options"].tap()
        app.buttons["study_card_style"].tap()
        XCTAssertTrue(tile("minimal-ink").waitForExistence(timeout: 5))
        XCTAssertTrue(tile("minimal-ink").isSelected, "The choice is remembered")
        tile("default").tap()
        XCTAssertTrue(tile("default").isSelected)
        app.buttons["card_style_done"].tap()
    }

    /// Today offers the deck the learner studies, starts a session on it, then shows what was saved; the session length can be
    /// changed and the levels are one tap away. Real UI, real Realm.
    func testTodayStartsASessionAndShowsWhatWasSavedAndTheSessionLengthCanBeChanged() {
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
        fillCard(app, index: 0, front: "dog", back: "cho")
        fillCard(app, index: 1, front: "cat", back: "meo")
        app.buttons["save_deck"].tap()
        XCTAssertTrue(deckRow(app, named: name).waitForExistence(timeout: 10))

        // Today: with several decks the learner chooses once; the choice is the deck planned.
        app.tabBars.buttons["tab_levels"].tap()
        let primary = app.buttons["today_primary"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10))
        // A deck chosen in an earlier run may still be the one planned: choose this one through the row, or through the button
        // when nothing is chosen yet.
        let chooser = primary.label.contains("Chọn bộ thẻ") ? primary : app.buttons["today_deck_row"]
        chooser.tap()
        let choice = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
        // The deck's name is the hero's title, and the title is the control that changes the deck.
        XCTAssertTrue(app.buttons["today_deck_row"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["today_deck_row"].label.hasSuffix(name), "The hero names the deck being studied")
        XCTAssertTrue(app.staticTexts["today_figure"].label.hasPrefix("2"), "A new deck of two cards: practise it, nothing is 'due'")
        attachScreenshot(app, name: "today-practice")

        // The session length is a choice and is kept.
        app.buttons["today_time_row"].tap()
        let ten = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "10 phút")).firstMatch
        XCTAssertTrue(ten.waitForExistence(timeout: 5))
        ten.tap()
        XCTAssertTrue(app.buttons["today_time_row"].label.contains("10"))

        // Start, flip and rate the first card, leave: Today now counts what was saved, and nothing is due.
        primary.tap()
        XCTAssertTrue(app.buttons["study_card"].waitForExistence(timeout: 5))
        app.buttons["study_primary"].tap()
        app.buttons["study_rate_remembered"].tap()
        XCTAssertTrue(app.staticTexts["study_save_status"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["today_primary"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["today_progress"].label, "Đã lưu 1 lượt học", "One saved attempt today")
        XCTAssertTrue(app.buttons["today_primary"].label.contains("Luyện thêm"), "Done for today, with practice as a choice")
        attachScreenshot(app, name: "today-done")

        // The levels are one tap away and Back returns to Today.
        app.buttons["today_levels_row"].tap()
        XCTAssertTrue(app.tables["home_levels"].waitForExistence(timeout: 20))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["today_primary"].waitForExistence(timeout: 5))
    }

    /// An answer that cannot be saved is never shown as saved: the learner stays on the card, can try again, and the count only
    /// moves once the save worked. The first save is made to fail by a debug launch argument.
    func testAFailedSaveKeepsTheLearnerOnTheCardUntilItIsRetried() {
        let app = makeApp()
        app.launchArguments += ["-FailReviewSaves", "1"]
        app.launch()
        openCards(app)
        let name = "UI \(UUID().uuidString.prefix(6))"
        addTeardownBlock { self.deleteDeckIfPresent(named: name, orNamed: name) }
        openNewDeckEditor(app)
        let nameField = app.textViews["deck_name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        fillCard(app, index: 0, front: "dog", back: "cho")
        fillCard(app, index: 1, front: "cat", back: "meo")
        app.buttons["save_deck"].tap()
        let row = deckRow(app, named: name)
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()

        let card = app.buttons["study_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        app.buttons["study_primary"].tap()
        XCTAssertTrue(waitForLabel(card, containing: "cho"))
        app.buttons["study_rate_remembered"].tap()

        let retry = app.buttons["study_retry_save"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5), "A failed save offers a retry")
        attachScreenshot(app, name: "study-save-failed")
        XCTAssertTrue(app.staticTexts["study_save_status"].exists)
        XCTAssertTrue(app.staticTexts["study_saved"].label.contains("0"), "Nothing counts as saved: \(app.staticTexts["study_saved"].label)")
        XCTAssertFalse(app.buttons["study_primary"].exists, "The learner cannot move on with an unsaved answer")
        XCTAssertFalse(app.buttons["study_rate_remembered"].exists)
        XCTAssertTrue(card.label.contains("cho"), "The answer stays on screen")

        // Leaving with an unsaved answer asks first and staying changes nothing.
        app.buttons["study_leave_unsaved"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5), "Leaving with an unsaved answer asks first")
        app.alerts.buttons["Ở lại"].tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["study_saved"].label.contains("0"))

        retry.tap()
        XCTAssertTrue(app.buttons["study_primary"].waitForExistence(timeout: 5), "After the retry worked the learner can move on")
        XCTAssertFalse(retry.exists)
        XCTAssertTrue(app.staticTexts["study_saved"].label.contains("1"), "Now it counts: \(app.staticTexts["study_saved"].label)")

        // Leaving with everything saved needs no question.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 1))
        XCTAssertTrue(deckRow(app, named: name).waitForExistence(timeout: 5))
    }

    /// The learner can add, edit and remove sentences on a card. Removing the server's sentence only hides it (and it can
    /// be restored); what the learner wrote is deleted; changes survive leaving the card. Needs the local backend.
    func testExampleSentencesCanBeAddedEditedRemovedAndRestored() {
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
        fillCard(app, index: 0, front: "犬", back: "chó")
        fillCard(app, index: 1, front: "猫", back: "mèo")
        app.buttons["save_deck"].tap()
        let row = deckRow(app, named: name)
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["study_card"].waitForExistence(timeout: 5))
        app.buttons["study_primary"].tap()
        XCTAssertTrue(app.buttons["study_example_speak_0"].waitForExistence(timeout: 20), "The server's sentences are the default")

        func tags() -> [String] {
            app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "study_example_tag_")).allElementsBoundByIndex.map(\.label)
        }
        func rowCount() -> Int { app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "study_example_more_")).count }
        func fillEditor(_ sentence: String, meaning: String = "") {
            let field = app.textViews["example_editor_japanese"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText(sentence)
            if !meaning.isEmpty {
                app.textViews["example_editor_translation"].tap()
                app.textViews["example_editor_translation"].typeText(meaning)
            }
        }
        let initialRows = rowCount()
        XCTAssertGreaterThan(initialRows, 0)
        XCTAssertTrue(tags().isEmpty)

        // Add: a sentence of the learner's own, listed after the server's.
        app.buttons["study_examples_add"].tap()
        fillEditor("私は犬を飼っています。", meaning: "Tôi nuôi chó.")
        attachScreenshot(app, name: "example-editor")
        app.buttons["example_editor_save"].tap()
        XCTAssertTrue(app.staticTexts["study_example_tag_\(initialRows)"].waitForExistence(timeout: 5))
        XCTAssertEqual(rowCount(), initialRows + 1)
        XCTAssertEqual(tags().count, 1)

        // The same sentence twice is refused and the form stays open with the reason.
        app.buttons["study_examples_add"].tap()
        fillEditor("私は犬を飼っています。")
        app.buttons["example_editor_save"].tap()
        XCTAssertTrue(app.staticTexts["example_editor_problem"].waitForExistence(timeout: 5))
        app.buttons["example_editor_cancel"].tap()
        app.alerts.buttons["Bỏ"].tap()   // typing is not thrown away without asking
        XCTAssertTrue(app.buttons["study_examples_add"].waitForExistence(timeout: 5))
        XCTAssertEqual(rowCount(), initialRows + 1)

        // Edit a server sentence: it becomes the learner's version, tagged.
        app.buttons["study_example_more_0"].tap()
        app.buttons["Sửa"].tap()
        let field = app.textViews["example_editor_japanese"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse((field.value as? String ?? "").isEmpty, "The form starts from the sentence")
        app.textViews["example_editor_translation"].tap()
        app.textViews["example_editor_translation"].typeText(" (đã sửa)")
        app.buttons["example_editor_save"].tap()
        XCTAssertTrue(app.staticTexts["study_example_tag_0"].waitForExistence(timeout: 5))
        XCTAssertEqual(tags().count, 2)
        attachScreenshot(app, name: "examples-edited")

        // Remove a server sentence: asked first, then only hidden; it can be restored.
        app.buttons["study_example_more_1"].tap()
        app.buttons["Gỡ khỏi ví dụ của tôi"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["Huỷ"].tap()
        XCTAssertEqual(rowCount(), initialRows + 1, "Cancelling the question changes nothing")
        app.buttons["study_example_more_1"].tap()
        app.buttons["Gỡ khỏi ví dụ của tôi"].tap()
        app.alerts.buttons["Gỡ"].tap()
        XCTAssertTrue(app.buttons["study_examples_restore"].waitForExistence(timeout: 5))
        XCTAssertEqual(rowCount(), initialRows)

        // The changes stay when the learner leaves the card and comes back.
        app.buttons["study_skip_rating"].tap()   // next card
        app.buttons["study_previous"].tap()
        app.buttons["study_primary"].tap()   // flip again
        XCTAssertTrue(app.buttons["study_examples_restore"].waitForExistence(timeout: 20))
        XCTAssertEqual(tags().count, 2)

        // Restore the removed one; delete the learner's own sentence (final); bring back the original text.
        app.buttons["study_examples_restore"].tap()
        XCTAssertFalse(app.buttons["study_examples_restore"].exists)
        XCTAssertEqual(rowCount(), initialRows + 1)
        let mine = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS[c] %@", "study_example_tag_", "BẠN")).allElementsBoundByIndex
        XCTAssertEqual(mine.count, 2)
        app.buttons["study_example_more_\(initialRows)"].tap()
        app.buttons["Xoá"].tap()
        app.alerts.buttons["Xoá"].tap()
        XCTAssertTrue(waitForCount(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "study_example_more_")), equals: initialRows))
        app.buttons["study_example_more_0"].tap()
        app.buttons["Khôi phục bản gốc"].tap()
        XCTAssertTrue(waitForCount(app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "study_example_tag_")), equals: 0), "Back to the server's sentences")
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

    private func waitForCount(_ query: XCUIElementQuery, equals count: Int, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while query.count != count, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
        return query.count == count
    }

    private func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }

    /// The dictionary bar above the keyboard asks the API after the learner stops typing and changes the layout when it
    /// answers; a test that taps the next field meanwhile can hit a chip. Wait until the lookup is no longer running.
    private func waitForDictionaryLookup(_ app: XCUIApplication, timeout: TimeInterval = 10) {
        let searching = app.staticTexts["Đang tra từ điển…"]
        let deadline = Date().addingTimeInterval(timeout)
        // The lookup starts after a 300 ms pause, so give it a moment to appear before waiting for it to finish.
        _ = searching.waitForExistence(timeout: 1)
        while searching.exists, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
    }

    private func fillCard(_ app: XCUIApplication, index: Int, front: String, back: String) {
        let frontField = app.textViews.matching(identifier: "card_front").element(boundBy: index)
        if !frontField.isHittable { app.tables["deck_editor_table"].swipeUp() }
        frontField.tap()
        frontField.typeText(front)
        waitForDictionaryLookup(app)
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

    // MARK: Learn from Life (the hub on Today)

    /// Brings a hub card into view to be tapped: the card strip scrolls sideways, Today scrolls down. A ready card is opened by a tap on it.
    private func revealLifeCard(_ app: XCUIApplication, idPrefix: String, timeout: TimeInterval = 40) -> XCUIElement? {
        let card = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "life_card_\(idPrefix)")).firstMatch
        let strip = app.scrollViews["today_life_cards"]
        guard strip.waitForExistence(timeout: timeout) else { return nil }
        let today = app.scrollViews["today_screen"]
        var attempts = 0
        while !(card.exists && card.isHittable) && attempts < 14 {
            if strip.isHittable, !card.exists || card.frame.minX > app.frame.maxX || card.frame.maxX < 0 { strip.swipeLeft() }
            else { today.swipeUp() }
            attempts += 1
        }
        return card.exists && card.isHittable ? card : nil
    }

    /// Opens a lesson from Today and runs it to the save step, typing `answer` into the recall exercise and picking choice `pick`.
    /// Returns the feedback text of the recall exercise.
    @discardableResult
    private func playLifeLesson(_ app: XCUIApplication, idPrefix: String, answer: String, pick: Int = 0) throws -> String {
        guard let open = revealLifeCard(app, idPrefix: idPrefix) else {
            throw XCTSkip("The \(idPrefix) card is not on Today (the backend does not offer it, or the build points elsewhere).")
        }
        open.tap()
        XCTAssertTrue(app.staticTexts["life_story_title"].waitForExistence(timeout: 10), "The story opens")
        let story = app.scrollViews["life_screen"]
        let start = app.buttons["life_story_start"]
        var swipes = 0
        while !start.isHittable && swipes < 8 { story.swipeUp(); swipes += 1 }
        start.tap()

        let field = app.textFields["life_answer_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "The recall exercise asks for a typed answer")
        field.tap()
        field.typeText(answer)
        app.buttons["life_primary"].tap()
        let feedback = app.otherElements["life_feedback"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 5), "Feedback follows the answer")
        let text = feedback.label
        app.buttons["life_primary"].tap()                              // next

        let choice = app.buttons["life_choice_\(pick)"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5), "The second exercise is a choice")
        choice.tap()
        app.buttons["life_primary"].tap()                              // check
        XCTAssertTrue(app.otherElements["life_feedback"].waitForExistence(timeout: 5))
        app.buttons["life_primary"].tap()                              // see results
        XCTAssertTrue(app.buttons["life_save_primary"].waitForExistence(timeout: 5), "The save step follows the exercises")
        return text
    }

    /// Saves the words, continues, and returns to Today.
    private func saveLifeWordsAndReturn(_ app: XCUIApplication) -> String {
        app.buttons["life_save_primary"].tap()
        let saved = app.otherElements["life_save_done"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5), "Saved is reported after the store accepted the words")
        let message = saved.label
        app.buttons["life_save_primary"].tap()                         // continue
        XCTAssertTrue(app.staticTexts["life_done_title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["life_done_save"].exists)
        app.buttons["life_done_back"].tap()
        return message
    }

    func testTheLifeHubShowsTheDateAndTheLabelledCardsOnToday() throws {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.otherElements["today_date_header"].waitForExistence(timeout: 40), "The date header is the learner's own calendar")
        XCTAssertTrue(app.buttons["today_primary"].exists, "The review button is still there")
        let strip = app.scrollViews["today_life_cards"]
        XCTAssertTrue(strip.waitForExistence(timeout: 10))
        // The date card is worked out on the device; it needs no server.
        XCTAssertNotNil(revealLifeCard(app, idPrefix: "date:"), "A date card is on Today")
        try XCTSkipUnless(app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "life_card_sample:")).count > 0 || revealLifeCard(app, idPrefix: "sample:transit", timeout: 5) != nil,
                          "The backend already provides a life feed: no example cards to check.")
    }

    /// Today leads with the life hub: at the default text size its first card is above the tab bar without scrolling, and the deck
    /// being studied comes below it (the learner scrolls for that).
    func testTodayLeadsWithTheLifeHubAndItsFirstCardIsVisibleWithoutScrolling() throws {
        let app = makeApp()
        // Sample decks, so that Today has a deck being studied (the block this layout is about).
        app.launchArguments += ["-SeedCardsFixture"]
        app.launch()
        XCTAssertTrue(app.buttons["today_primary"].waitForExistence(timeout: 40), "Today is the first screen")
        XCTAssertTrue(app.otherElements["today_life_hub"].waitForExistence(timeout: 40), "The life hub is on Today")
        // Several sample decks: Today asks for one first. Choose the first; the deck then is the hero's block.
        let primary = app.buttons["today_primary"]
        if primary.label.contains("Chọn bộ thẻ") {
            primary.tap()
            let choice = app.sheets.buttons.element(boundBy: 0)
            XCTAssertTrue(choice.waitForExistence(timeout: 5), "The deck chooser lists the sample decks")
            choice.tap()
        }
        XCTAssertTrue(app.buttons["today_deck_row"].waitForExistence(timeout: 10), "The deck being studied is on Today")
        let tabBarTop = app.tabBars.firstMatch.frame.minY
        let hub = app.otherElements["today_life_hub"].frame
        let deck = app.buttons["today_deck_row"].frame
        let firstCard = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'life_card_'")).firstMatch.frame
        let report = "tab bar top \(tabBarTop), hub \(hub), deck \(deck), first card \(firstCard)"
        XCTAssertLessThan(hub.minY, deck.minY, "The life hub comes before the deck being studied. \(report)")
        XCTAssertLessThanOrEqual(firstCard.maxY, tabBarTop, "The first life card is above the tab bar without scrolling. \(report)")
        attachScreenshot(app, name: "today-hub-first")
    }

    func testAnExampleLessonRunsFromTodayAndItsWordsAreSavedOnceOnly() throws {
        let app = makeApp()
        app.launch()
        // The trains example: 遅れて is the answer; choice 1 (ちえん) is the right reading.
        try playLifeLesson(app, idPrefix: "sample:transit", answer: "遅れて", pick: 1)
        XCTAssertTrue(app.buttons["life_save_primary"].exists)
        let first = saveLifeWordsAndReturn(app)
        XCTAssertFalse(first.isEmpty)
        // Again: the same words are reported as already there and nothing is added twice.
        let feedback = try playLifeLesson(app, idPrefix: "sample:transit", answer: "遅れて", pick: 1)
        XCTAssertTrue(feedback.contains("Chính xác"), "A correct answer is confirmed: \(feedback)")
        app.buttons["life_save_primary"].tap()
        let saved = app.otherElements["life_save_done"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertTrue(saved.label.contains("Đã có trong"), "The same words are reported as already there: \(saved.label)")
    }

    func testLifeLessonFromTheServerCanBeCompletedSavedAndFoundAgainWithoutDuplicates() throws {
        let app = makeApp()
        app.launch()

        // First pass: a wrong answer shows the right one; saving stores the words.
        let wrong = try playLifeLesson(app, idPrefix: "weather:", answer: "zzz")
        _ = saveLifeWordsAndReturn(app)

        // The words are in the learner's decks.
        app.tabBars.buttons["tab_cards"].tap()
        XCTAssertTrue(app.tables["deck_library"].waitForExistence(timeout: 10))
        // The deck keeps the name it was created with (another language may have created it on this simulator before).
        let names = ["Học từ cuộc sống", "Learn from Life", "暮らしから学ぶ"]
        func lifeDeckExists() -> Bool { names.contains { deckRow(app, named: $0).exists } }
        var scrolls = 0
        while !lifeDeckExists() && scrolls < 8 { app.tables["deck_library"].swipeUp(); scrolls += 1 }
        XCTAssertTrue(lifeDeckExists(), "The Learn from Life deck is in the library")
        app.tables["deck_library"].swipeDown()
        app.tabBars.buttons["tab_levels"].tap()

        // Second pass: the answer read from the first feedback ("… Đáp án: 雨 (あめ) — mưa.") is accepted, and nothing is added twice.
        var answer = "zzz"
        if let range = wrong.range(of: "Đáp án: "), let end = wrong[range.upperBound...].firstIndex(of: " ") { answer = String(wrong[range.upperBound..<end]) }
        let again = try playLifeLesson(app, idPrefix: "weather:", answer: answer)
        XCTAssertTrue(again.contains("Chính xác"), "A correct answer is confirmed: \(again)")
        app.buttons["life_save_primary"].tap()
        let saved = app.otherElements["life_save_done"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertTrue(saved.label.contains("Đã có trong"), "The same words are reported as already there: \(saved.label)")
    }
}
