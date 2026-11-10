import XCTest

/// The dictionary's user journeys against the real backend (`/api/search`, `/content/...`, `/kanji/...`) and the real app.
/// They need the local API running, like the other live UI tests. The assertions read Vietnamese copy, so the language is pinned.
final class DictionaryUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func makeApp(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN", "-com.flashcardapp.dictionary.showReadings", "YES"]
        app.launchArguments += extra
        return app
    }

    private func openDictionary(_ app: XCUIApplication) {
        let tab = app.tabBars.buttons["tab_dictionary"]
        XCTAssertTrue(tab.waitForExistence(timeout: 40), "The tab bar appears")
        tab.tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10))
    }

    private func search(_ app: XCUIApplication, _ text: String) {
        let field = app.searchFields.firstMatch
        field.tap()
        field.typeText(text)
    }

    /// The search field's own clear button (its label is the localized "Clear text").
    private func clearSearchField(_ app: XCUIApplication) {
        let clear = app.searchFields.firstMatch.buttons.matching(NSPredicate(format: "label == 'Xóa văn bản' OR label == 'Clear text'")).firstMatch
        // The clear button only exists while the field is being edited.
        if !clear.waitForExistence(timeout: 1) { app.searchFields.firstMatch.tap() }
        if !clear.waitForExistence(timeout: 3) { attach(app, "no-clear-button"); print(app.searchFields.firstMatch.debugDescription) }
        XCTAssertTrue(clear.exists, "The field has a clear button")
        clear.tap()
    }

    private func row(_ app: XCUIApplication, _ number: Int = 1) -> XCUIElement {
        app.tables["dictionary_results"].cells["dictionary_row_\(number)"]
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 10) -> Bool {
        XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: element)], timeout: timeout) == .completed
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func back(_ app: XCUIApplication) {
        let button = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    /// Scrolls the entry screen until `target` is on screen (the screen is one scroll view).
    private func scrollTo(_ target: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        var swipes = 0
        while !target.isHittable, swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
    }

    // MARK: 1–2. Search, vocabulary detail, return to the results

    func testSearchOpenVocabularyDetailAndReturnKeepsTheSearch() {
        let app = makeApp()
        app.launch()
        openDictionary(app)
        search(app, "食べる")

        let first = row(app)
        XCTAssertTrue(first.waitForExistence(timeout: 20), "Real results arrive")
        XCTAssertTrue(first.label.contains("食べる") && first.label.contains("ăn"), "The exact word is the first result: \(first.label)")
        attach(app, "dictionary-results")

        first.tap()
        let title = element(app, "entry_title")
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "食べる")
        XCTAssertTrue(waitForLabel(element(app, "entry_meaning_1"), containing: "ăn"), "The Vietnamese meaning from the API")
        XCTAssertTrue(waitForLabel(element(app, "entry_reading"), containing: "たべる"))
        XCTAssertTrue(element(app, "entry_example_1").waitForExistence(timeout: 15), "Example sentences load")
        attach(app, "vocabulary-detail")

        back(app)
        XCTAssertTrue(first.waitForExistence(timeout: 5), "The results are still there")
        XCTAssertEqual(app.searchFields.firstMatch.value as? String, "食べる", "The query is kept")
    }

    // MARK: 3. Categories, kanji detail with stroke order

    func testSwitchingCategoriesFindsKanjiAndItsStrokeOrderPlays() {
        let app = makeApp()
        app.launch()
        openDictionary(app)
        search(app, "食")
        XCTAssertTrue(row(app).waitForExistence(timeout: 20))

        app.buttons["Kanji"].tap()
        let kanjiRow = row(app)
        XCTAssertTrue(waitForLabel(kanjiRow, containing: "THỰC", timeout: 20), "The kanji category returns the kanji row")
        kanjiRow.tap()

        XCTAssertTrue(element(app, "entry_title").waitForExistence(timeout: 10))
        let canvas = element(app, "stroke_order_canvas")
        scrollTo(canvas, in: app)
        XCTAssertTrue(canvas.waitForExistence(timeout: 15), "The verified stroke drawing is shown")
        let progress = element(app, "stroke_progress")
        XCTAssertTrue(waitForLabel(progress, containing: "9 / 9"), "Starts complete: \(progress.label)")
        attach(app, "kanji-stroke-order")

        element(app, "stroke_back").tap()
        XCTAssertTrue(waitForLabel(progress, containing: "8 / 9"), "Step back one stroke")
        element(app, "stroke_forward").tap()
        XCTAssertTrue(waitForLabel(progress, containing: "9 / 9"))

        element(app, "stroke_replay").tap()
        XCTAssertTrue(waitForLabel(progress, containing: "0 / 9", timeout: 3), "Replay starts from the first stroke")
        XCTAssertTrue(waitForLabel(progress, containing: "9 / 9", timeout: 20), "…and plays to the end")
        element(app, "stroke_play").tap()
        XCTAssertTrue(waitForLabel(progress, containing: "0 / 9", timeout: 3), "Play from the end starts again")
        element(app, "stroke_play").tap() // pause
        XCTAssertTrue(app.state == .runningForeground)
    }

    // MARK: 4. Grammar and sentences

    func testGrammarAndSentenceCategoriesOpenTheirOwnDetail() {
        let app = makeApp()
        app.launch()
        openDictionary(app)
        search(app, "ても")
        app.buttons["Ngữ pháp"].tap()
        let grammarRow = row(app)
        XCTAssertTrue(grammarRow.waitForExistence(timeout: 20))
        grammarRow.tap()
        XCTAssertTrue(element(app, "entry_formation_1").waitForExistence(timeout: 10), "Formation from the grammar detail endpoint")
        XCTAssertTrue(element(app, "entry_example_1").waitForExistence(timeout: 15), "Sentences containing the pattern")
        attach(app, "grammar-detail")
        back(app)

        app.buttons["Câu"].tap()
        let sentence = row(app)
        XCTAssertTrue(sentence.waitForExistence(timeout: 20))
        sentence.tap()
        XCTAssertTrue(element(app, "entry_title").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "entry_translation").exists, "The Vietnamese translation")
        attach(app, "sentence-detail")
    }

    // MARK: 5. Pronunciation

    func testListenButtonSpeaksOrExplainsThatNoJapaneseVoiceIsInstalled() {
        let app = makeApp()
        app.launch()
        openDictionary(app)
        search(app, "食べる")
        row(app).tap()
        let listen = element(app, "entry_speak")
        XCTAssertTrue(listen.waitForExistence(timeout: 15))
        listen.tap()
        // With a Japanese voice the device speaks; without one the learner is told how to get it. Either way the app stays usable.
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 2) { alert.buttons.element(boundBy: 1).tap() }
        XCTAssertTrue(element(app, "entry_title").exists)
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: 6. Guests are sent to sign in before a favourite is saved

    func testSavingAsAGuestOpensSignIn() {
        let app = makeApp()
        app.launch()
        openDictionary(app)
        search(app, "食べる")
        row(app).tap()
        let save = element(app, "entry_favorite")
        XCTAssertTrue(save.waitForExistence(timeout: 15))
        save.tap()
        XCTAssertTrue(app.buttons["website_login_button"].waitForExistence(timeout: 10), "The sign-in screen opens; nothing was saved")
    }

    func testSavedEntriesAsAGuestAsksToSignIn() {
        let app = makeApp()
        app.launch()
        openDictionary(app)
        app.buttons["dictionary_saved"].tap()
        XCTAssertTrue(app.staticTexts["Đăng nhập để xem mục đã lưu"].waitForExistence(timeout: 10))
        attach(app, "saved-signed-out")
    }

    // MARK: 7. Add to flashcards (always into a deck the learner picks)

    func testAddVocabularyToAFlashcardDeckTheLearnerChooses() {
        let app = makeApp(["-SeedCardsFixture"])
        app.launch()
        openDictionary(app)
        search(app, "食べる")
        row(app).tap()
        let add = element(app, "entry_add_deck")
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        XCTAssertTrue(waitForLabel(element(app, "entry_meaning_1"), containing: "ăn"), "The meaning is loaded before saving")
        add.tap()

        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "The deck chooser appears; nothing is saved until a deck is picked")
        attach(app, "deck-chooser")
        let deck = sheet.buttons.matching(NSPredicate(format: "label CONTAINS %@", "thẻ")).firstMatch
        XCTAssertTrue(deck.exists, "Existing decks are listed with their card counts")
        deck.tap()
        let toast = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Đã thêm vào' OR label BEGINSWITH 'Đã có trong'")).firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "The result is confirmed")

        add.tap()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5))
        app.sheets.firstMatch.buttons.matching(NSPredicate(format: "label CONTAINS %@", "thẻ")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Đã có trong'")).firstMatch.waitForExistence(timeout: 5),
                      "Saving the same word again is reported, not duplicated")
    }

    // MARK: 8. Empty results, offline error, retry

    func testEmptyResultsAndANetworkErrorThatRecoversOnRetry() {
        let app = makeApp(["-FailFirstSearch"])
        app.launch()
        openDictionary(app)
        search(app, "食べる")

        let retry = app.buttons["Thử lại"]
        XCTAssertTrue(retry.waitForExistence(timeout: 15), "The first request fails as if offline, with a retry action")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'ngoại tuyến' OR label CONTAINS 'kết nối'")).firstMatch.exists, "A readable reason")
        attach(app, "search-error")
        retry.tap()
        XCTAssertTrue(row(app).waitForExistence(timeout: 20), "Retry recovers with the same query")

        let field = app.searchFields.firstMatch
        clearSearchField(app)
        field.typeText("zzzzqqxx")
        XCTAssertTrue(app.staticTexts["Không có kết quả cho “zzzzqqxx”"].waitForExistence(timeout: 15), "Empty is an answer, not an error")
        attach(app, "search-empty")
    }

    // MARK: 9. History

    func testViewedEntriesAndSearchesAppearOnTheHomeAndCanBeCleared() {
        let app = makeApp()
        app.launch()
        openDictionary(app)
        search(app, "食べる")
        row(app).tap()
        XCTAssertTrue(element(app, "entry_title").waitForExistence(timeout: 10))
        back(app)

        let field = app.searchFields.firstMatch
        clearSearchField(app)
        let viewed = app.tables["dictionary_results"].cells["dictionary_viewed_1"]
        XCTAssertTrue(viewed.waitForExistence(timeout: 5), "The entry just opened is in Recently viewed")
        XCTAssertTrue(viewed.label.contains("食べる"))
        XCTAssertTrue(app.tables["dictionary_results"].cells["dictionary_recent_1"].exists, "…and the query is in Recent searches")
        attach(app, "dictionary-home-history")

        app.buttons["dictionary_clear_queries"].firstMatch.tap()
        XCTAssertFalse(app.tables["dictionary_results"].cells["dictionary_recent_1"].waitForExistence(timeout: 2))
        app.buttons["dictionary_clear_viewed"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Tra cứu tiếng Nhật"].waitForExistence(timeout: 5), "Back to the empty home")
    }

    // MARK: 10. Camera / photo text: recognize, correct, look up

    func testRecognizedTextCanBeCorrectedAndLookedUp() {
        let app = makeApp(["-ScanFixtureText", "今日は天気がいいです"])
        app.launch()
        openDictionary(app)
        app.buttons["dictionary_scan"].tap()
        let text = app.textViews["scan_text"]
        XCTAssertTrue(text.waitForExistence(timeout: 30), "Vision reads the picture on the device")
        XCTAssertTrue((text.value as? String ?? "").contains("天気"), "Recognized: \(text.value as? String ?? "")")
        attach(app, "scan-recognized")

        let lookUp = app.buttons["scan_lookup"]
        XCTAssertTrue(lookUp.isEnabled)
        lookUp.tap()
        XCTAssertTrue(row(app).waitForExistence(timeout: 25), "The scanner closes and the dictionary shows results for the text")
        XCTAssertTrue((app.searchFields.firstMatch.value as? String ?? "").contains("天気"))
    }

    // MARK: 11. Handwriting: draw, pick the candidate, look up

    func testADrawnCharacterIsRecognizedPickedAndLookedUp() {
        let app = makeApp()
        app.launch()
        openDictionary(app)
        app.buttons["dictionary_handwriting"].tap()
        let canvas = app.descendants(matching: .any)["handwriting_canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["handwriting_lookup"].isEnabled, "Nothing to look up yet")

        // 日 with real touches: left side, top and right side, middle bar, bottom bar (five strokes; the matcher tolerates the split corner).
        let strokes: [((CGFloat, CGFloat), (CGFloat, CGFloat))] = [((0.3, 0.12), (0.3, 0.88)), ((0.3, 0.12), (0.7, 0.12)), ((0.7, 0.12), (0.7, 0.88)),
                                                                   ((0.3, 0.5), (0.7, 0.5)), ((0.3, 0.88), (0.7, 0.88))]
        for (from, to) in strokes {
            canvas.coordinate(withNormalizedOffset: CGVector(dx: from.0, dy: from.1))
                .press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: to.0, dy: to.1)))
        }
        let candidate = app.buttons["handwriting_candidate_日"]
        XCTAssertTrue(candidate.waitForExistence(timeout: 15), "日 is among the candidates")
        attach(app, "handwriting-candidates")
        candidate.tap()

        XCTAssertEqual(app.staticTexts["handwriting_text"].label, "日")
        XCTAssertFalse(app.buttons["handwriting_undo"].isEnabled, "The pad is empty again for the next character")
        app.buttons["handwriting_lookup"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10), "The sheet closes")
        XCTAssertEqual(app.searchFields.firstMatch.value as? String, "日")
    }

    func testScannerOffersPhotosAndOnlyOffersTheCameraWhenThereIsOne() {
        let app = makeApp()
        app.launch()
        openDictionary(app)
        app.buttons["dictionary_scan"].tap()
        XCTAssertTrue(app.buttons["scan_photos"].waitForExistence(timeout: 10))
        // A camera is offered only when the device has one; otherwise the screen says so instead of showing a dead button.
        let camera = app.buttons["scan_camera"]
        let noCamera = app.staticTexts["Thiết bị này không có camera. Bạn vẫn có thể chọn một ảnh có sẵn."]
        XCTAssertTrue(camera.exists != noCamera.exists, "Exactly one of: camera button, no-camera explanation")
        attach(app, "scan-chooser")
        app.buttons["scan_close"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
    }

    // MARK: 11. Related content navigation keeps the original search

    func testOpeningARelatedKanjiAndGoingBackReturnsToTheWordThenToTheResults() {
        let app = makeApp()
        app.launch()
        openDictionary(app)
        search(app, "食べる")
        row(app).tap()
        let chip = element(app, "entry_kanji_食")
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        scrollTo(chip, in: app, maxSwipes: 2)
        chip.tap()
        XCTAssertTrue(waitForLabel(element(app, "entry_title"), containing: "食", timeout: 10))
        XCTAssertTrue(waitForLabel(element(app, "entry_title"), containing: "THỰC", timeout: 10), "The kanji detail (its title reads the character and meaning)")
        back(app)
        XCTAssertEqual(element(app, "entry_title").label, "食べる")
        back(app)
        XCTAssertTrue(row(app).waitForExistence(timeout: 5))
        XCTAssertEqual(app.searchFields.firstMatch.value as? String, "食べる")
    }

    // MARK: 12. Signed in: save an entry to the account, see it in Saved, remove it

    /// Needs a disposable local account (TEST_RUNNER_FLASHCARD_E2E_EMAIL / _PASSWORD) and a signed (ad-hoc) build, because the
    /// session lives in the Keychain. It talks to the real bookmark endpoints of the local backend.
    func testSignedInLearnerSavesAnEntryFindsItInSavedAndRemovesIt() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let email = environment["FLASHCARD_E2E_EMAIL"], let password = environment["FLASHCARD_E2E_PASSWORD"] else {
            throw XCTSkip("No disposable local account supplied")
        }
        let app = makeApp()
        app.launch()
        openDictionary(app)
        search(app, "食べる")
        row(app).tap()
        let save = element(app, "entry_favorite")
        XCTAssertTrue(save.waitForExistence(timeout: 15))
        save.tap()

        // A guest is sent to sign in, then returned to the entry. (A session left in the Keychain by an earlier run skips this.)
        let emailField = app.textFields["website_email"]
        if emailField.waitForExistence(timeout: 8) {
            emailField.tap()
            emailField.typeText(email)
            let passwordField = app.secureTextFields["website_password"]
            passwordField.tap()
            passwordField.typeText(password)
            app.buttons["website_login_button"].tap()
        }
        XCTAssertTrue(element(app, "entry_title").waitForExistence(timeout: 30), "Back on the entry after signing in")

        let saveButton = element(app, "entry_favorite")
        XCTAssertTrue(waitForEnabled(saveButton, timeout: 15), "The saved state has been read from the server")
        if saveButton.label == "Đã lưu" { // a run that did not finish left it saved: start unsaved
            saveButton.tap()
            XCTAssertTrue(app.staticTexts["Đã bỏ khỏi mục đã lưu"].waitForExistence(timeout: 15))
            XCTAssertTrue(waitForEnabled(saveButton))
        }
        XCTAssertTrue(waitForEnabled(saveButton))
        saveButton.tap()
        XCTAssertTrue(app.staticTexts["Đã lưu vào tài khoản"].waitForExistence(timeout: 15), "The server confirmed the bookmark")
        XCTAssertTrue(waitForLabel(saveButton, containing: "Đã lưu", timeout: 5), "The button shows the saved state")
        attach(app, "entry-saved")

        back(app)
        // While searching the bar buttons are replaced by the search field's own Close; leave the search first.
        let close = app.buttons["Đóng"]
        if close.waitForExistence(timeout: 3) { close.tap() }
        app.buttons["dictionary_saved"].tap()
        let saved = app.tables["saved_list"].cells["saved_row_1"]
        XCTAssertTrue(saved.waitForExistence(timeout: 30), "The saved word is listed")
        XCTAssertTrue(saved.label.contains("食べる"))
        attach(app, "saved-list")

        saved.swipeLeft()
        app.buttons["Gỡ"].tap()
        XCTAssertTrue(app.staticTexts["Chưa lưu mục nào"].waitForExistence(timeout: 15), "Removing the last entry empties the list")
    }

    private func waitForEnabled(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: element)], timeout: timeout) == .completed
    }

    // MARK: 13. Voice search sheet

    func testVoiceSearchOpensFromTheSearchFieldAndExplainsItsState() {
        let app = makeApp()
        app.launch()
        openDictionary(app)
        let field = app.searchFields.firstMatch
        // The search field's trailing button (the system calls it "Bookmarks" in English, "dấu trang" in Vietnamese; it shows a microphone).
        let mic = field.buttons.firstMatch
        XCTAssertTrue(mic.waitForExistence(timeout: 5), "A button sits at the end of the search field")
        mic.tap()
        let start = app.buttons["voice_mic"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "The voice sheet opens")
        attach(app, "voice-sheet")
        XCTAssertEqual(app.state, .runningForeground)
        app.buttons["voice_close"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
    }
}
