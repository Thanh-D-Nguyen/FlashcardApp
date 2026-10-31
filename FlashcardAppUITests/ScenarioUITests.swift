import XCTest

/// The everyday-situation lessons, from the card on Today to the summary. Needs a disposable local account
/// (TEST_RUNNER_FLASHCARD_E2E_EMAIL / _PASSWORD), a backend that carries the daily-life catalogue (build setting PRODUCT_BASE_URL),
/// and a signed (ad-hoc) build, because the session goes to the Keychain. The Simulator keeps the Keychain after the app is removed,
/// so an existing session is used as it is.
final class ScenarioUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func signInIfNeeded(_ app: XCUIApplication, email: String, password: String) {
        let settings = app.tabBars.buttons["tab_settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 40))
        settings.tap()
        guard app.buttons["setting_sign_in"].waitForExistence(timeout: 10) else { return }
        app.buttons["setting_sign_in"].tap()
        let emailField = app.textFields["website_email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(email)
        let passwordField = app.secureTextFields["website_password"]
        passwordField.tap()
        passwordField.typeText(password)
        app.buttons["website_login_button"].tap()
        XCTAssertTrue(app.tabBars.buttons["tab_levels"].waitForExistence(timeout: 20), "Successful login lands on Main")
    }

    private func scrollToBanner(_ app: XCUIApplication) -> XCUIElement {
        let banner = app.buttons["today_scenarios"]
        let today = app.scrollViews["today_screen"]
        XCTAssertTrue(today.waitForExistence(timeout: 20))
        for _ in 0..<6 where !(banner.exists && banner.isHittable) { today.swipeUp() }
        XCTAssertTrue(banner.isHittable, "The situations card can be reached on Today")
        return banner
    }

    func testLiveSituationCanBeFoundPlayedAndFinished() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let email = environment["FLASHCARD_E2E_EMAIL"], let password = environment["FLASHCARD_E2E_PASSWORD"] else {
            throw XCTSkip("No disposable local account supplied")
        }
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN"]
        app.launch()
        signInIfNeeded(app, email: email, password: password)

        let today = app.tabBars.buttons["tab_levels"]
        XCTAssertTrue(today.waitForExistence(timeout: 10))
        today.tap()
        let banner = scrollToBanner(app)
        attach(app, "scenario-1-today-banner")
        banner.tap()

        // The catalogue: grouped, with a chip per group.
        let list = app.tables["scenario_list"]
        XCTAssertTrue(list.waitForExistence(timeout: 20), "The situations load")
        XCTAssertTrue(app.buttons["scenario_chip_beauty"].exists, "Hair and beauty is one of the groups")
        attach(app, "scenario-2-list")

        // Search finds a haircut without accents.
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("cat toc")
        let row = list.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "'cat toc' finds a haircut situation")
        attach(app, "scenario-3-search")
        row.tap()

        // Play: choose a phrase, hear the verdict, finish.
        let firstChoice = app.buttons["scenario_choice_A"]
        XCTAssertTrue(firstChoice.waitForExistence(timeout: 15), "The situation opens with its phrases")
        attach(app, "scenario-4-step")
        firstChoice.tap()
        XCTAssertTrue(app.otherElements["scenario_feedback"].waitForExistence(timeout: 10), "The verdict appears")
        attach(app, "scenario-5-feedback")
        let next = app.buttons["scenario_continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        while !app.staticTexts["scenario_summary_headline"].exists {
            // More steps: answer the first phrase of each.
            guard app.buttons["scenario_choice_A"].waitForExistence(timeout: 10) else { break }
            app.buttons["scenario_choice_A"].tap()
            XCTAssertTrue(app.buttons["scenario_continue"].waitForExistence(timeout: 10))
            app.buttons["scenario_continue"].tap()
        }
        XCTAssertTrue(app.staticTexts["scenario_summary_headline"].waitForExistence(timeout: 10), "The summary appears after the last step")
        let status = app.descendants(matching: .any)["scenario_save_status"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        attach(app, "scenario-6-summary")
        XCTAssertTrue(app.buttons["scenario_done"].exists)
        app.buttons["scenario_done"].tap()
        XCTAssertTrue(list.waitForExistence(timeout: 10), "Back to the situations")
    }
}
