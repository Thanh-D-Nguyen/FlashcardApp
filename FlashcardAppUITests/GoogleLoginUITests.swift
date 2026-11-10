import XCTest

/// Drives the real Google SDK up to its system consent prompt. Completing a sign-in needs a person's Google account, so
/// the exchange with the server is covered by the unit tests; this checks the screen and the cancel path on a device.
/// The button only exists when the build has an iOS OAuth client (`GOOGLE_IOS_CLIENT_ID_PREFIX`); without one the tests skip.
final class GoogleLoginUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func openLogin() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let settings = app.tabBars.buttons["tab_settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 40))
        settings.tap()
        let signIn = app.buttons["setting_sign_in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 10))
        signIn.tap()
        XCTAssertTrue(app.buttons["website_login_button"].waitForExistence(timeout: 5))
        return app
    }

    func testGoogleButtonIsOfferedNextToEmailSignInAndIsAccessible() throws {
        let app = openLogin()
        let google = app.buttons["google_login_button"]
        try XCTSkipUnless(google.waitForExistence(timeout: 3), "No GOOGLE_IOS_CLIENT_ID_PREFIX in this build")
        XCTAssertEqual(google.label, "Continue with Google")
        XCTAssertTrue(google.isEnabled && google.isHittable)
        XCTAssertGreaterThanOrEqual(google.frame.height, 44, "Minimum touch target")
        XCTAssertLessThan(app.buttons["website_login_button"].frame.minY, google.frame.minY)
        XCTAssertLessThan(google.frame.minY, app.buttons["continueWithoutLoginButton"].frame.minY)
    }

    func testCancellingGoogleReturnsToTheFormWithoutAnErrorAndCanBeRetried() throws {
        let app = openLogin()
        let google = app.buttons["google_login_button"]
        try XCTSkipUnless(google.waitForExistence(timeout: 3), "No GOOGLE_IOS_CLIENT_ID_PREFIX in this build")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        for attempt in 1...2 {
            google.tap()
            let prompt = springboard.alerts.firstMatch
            XCTAssertTrue(prompt.waitForExistence(timeout: 10), "Google's system consent prompt appears (attempt \(attempt))")
            XCTAssertTrue(app.buttons["google_login_button"].label.hasPrefix("Signing in"), "Busy while the sheet is open")
            XCTAssertFalse(app.buttons["website_login_button"].isEnabled, "Other sign-in actions are paused")
            prompt.buttons["Cancel"].tap()

            let idle = NSPredicate(format: "label == 'Continue with Google' AND isEnabled == true")
            expectation(for: idle, evaluatedWith: app.buttons["google_login_button"])
            waitForExpectations(timeout: 10)
            XCTAssertTrue(app.buttons["website_login_button"].isEnabled)
            XCTAssertFalse(app.images["exclamationmark.circle.fill"].exists, "Cancelling is not an error")
        }
    }
}
