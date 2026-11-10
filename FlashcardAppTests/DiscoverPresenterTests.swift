import XCTest
@testable import FlashcardApp

/// The Discover hub lists only the features that are built, and opens the one the learner picks.
final class DiscoverPresenterTests: XCTestCase {
    private final class FakeWireframe: DiscoverWireframeInterface {
        var shown: [DiscoverFeature] = []
        func show(_ feature: DiscoverFeature) { shown.append(feature) }
    }

    func test_theHubOffersEveryBuiltFeatureAndEachIsComplete() {
        let presenter = DiscoverPresenter(wireframe: FakeWireframe())
        XCTAssertEqual(presenter.features, [.loto, .magazine, .levels])
        for feature in DiscoverFeature.available {
            XCTAssertFalse(feature.title.isEmpty)
            XCTAssertFalse(feature.subtitle.isEmpty)
            XCTAssertNotNil(UIImage(systemName: feature.symbol), "\(feature) names an SF Symbol that does not exist")
            XCTAssertFalse(feature.accessibilityIdentifier.isEmpty)
        }
    }

    func test_choosingAFeatureOpensIt() {
        let wireframe = FakeWireframe()
        let presenter = DiscoverPresenter(wireframe: wireframe)
        DiscoverFeature.available.forEach(presenter.select)
        XCTAssertEqual(wireframe.shown, DiscoverFeature.available)
    }

    func test_everyFeatureBelongsToASectionThatIsShown() {
        XCTAssertEqual(Set(DiscoverFeature.available.map(\.section)), Set(DiscoverFeature.Section.allCases))
        XCTAssertEqual(Set(DiscoverFeature.available.map(\.accessibilityIdentifier)).count, DiscoverFeature.available.count)
    }

    func test_aFeatureThatIsNotOfferedCannotBeOpened() {
        let wireframe = FakeWireframe()
        DiscoverPresenter(wireframe: wireframe, features: []).select(.magazine)
        XCTAssertTrue(wireframe.shown.isEmpty)
    }

    func test_theTabIsTheFourthAndSettingsStaysLast() {
        XCTAssertEqual(MainTab.discover.rawValue, 3)
        XCTAssertEqual(MainTab.settings.rawValue, 4)
        XCTAssertEqual(MainTabbarName.discover.title, NSLocalizedString("Discover", comment: ""))
    }

    // MARK: Today's find

    private func page(words: [[String]]) -> MagazinePage {
        let items = words.enumerated().map { index, words in
            MagazineSummary(id: "id\(index)", slug: "a\(index)", kind: .vocabulary, titleJapanese: "題\(index)", titleVietnamese: "Tiêu đề",
                            summary: nil, level: nil, day: nil, words: words)
        }
        return MagazinePage(items: items, page: 1, hasMore: false)
    }

    func test_theFindIsAWordOfTheLatestArticlesAndStaysTheSameAllDay() throws {
        let page = page(words: [["梅雨", "傘"], [], ["残業"]])
        let morning = Date(timeIntervalSince1970: 1_793_000_000)   // same Japanese day
        let evening = morning.addingTimeInterval(3 * 3_600)
        let first = try XCTUnwrap(DiscoverPresenter.find(in: page, now: morning))
        XCTAssertEqual(DiscoverPresenter.find(in: page, now: evening), first)
        XCTAssertTrue(["梅雨", "傘", "残業"].contains(first.word))
        XCTAssertTrue(["題0", "題2"].contains(first.articleJapanese))
    }

    func test_theFindChangesAcrossDaysAndNeverInventsAWord() {
        let page = page(words: [["a", "b", "c", "d", "e", "f", "g", "h"]])
        let days = (0..<14).compactMap { DiscoverPresenter.find(in: page, now: Date(timeIntervalSince1970: 1_793_000_000 + Double($0) * 86_400))?.word }
        XCTAssertGreaterThan(Set(days).count, 1)
        XCTAssertNil(DiscoverPresenter.find(in: self.page(words: [[], [""]]), now: Date()))
        XCTAssertNil(DiscoverPresenter.find(in: self.page(words: []), now: Date()))
    }

    func test_noDrawMeansNoCountdown() {
        XCTAssertNil(DiscoverPresenter.nextDraw(in: LotoOverview(draws: []), now: Date()))
    }
}
