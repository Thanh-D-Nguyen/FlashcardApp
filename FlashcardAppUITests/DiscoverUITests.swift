import XCTest

/// The Discover hub: every card can be tapped and opens its screen (no backend needed for these taps).
final class DiscoverUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func openDiscover() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN"]
        app.launch()
        let tab = app.tabBars.buttons["tab_discover"]
        XCTAssertTrue(tab.waitForExistence(timeout: 40), "The tab bar appears")
        tab.tap()
        XCTAssertTrue(app.scrollViews["discover_screen"].waitForExistence(timeout: 10))
        return app
    }

    func test_tappingMagazineOpensTheMagazine() {
        let app = openDiscover()
        app.buttons["discover_magazine"].tap()
        XCTAssertTrue(app.navigationBars["Tạp chí"].waitForExistence(timeout: 10), "The Magazine screen opens")
    }

    func test_tappingLevelsOpensTheLevels() {
        let app = openDiscover()
        app.buttons["discover_levels"].tap()
        XCTAssertTrue(app.scrollViews["discover_screen"].waitForNonExistence(timeout: 10), "The hub is left")
    }

    func test_tappingLotoOpensTheLotoScreen() {
        let app = openDiscover()
        app.buttons["discover_loto"].tap()
        XCTAssertTrue(app.scrollViews["discover_screen"].waitForNonExistence(timeout: 10), "The hub is left")
    }
}
