import RxSwift
import XCTest
@testable import FlashcardApp

private final class FakeWeatherLoader: TodayLifeLoading {
    var section: TodayLifeSection?
    var lesson: LifeLesson?
    var cityID = "tokyo"
    var onChange: (() -> Void)?
    var refreshes = 0, retries = 0
    var selected: [String] = []

    func refresh() { refreshes += 1 }
    func retry() { retries += 1 }
    func selectCity(_ id: String) { selected.append(id); cityID = id }
    func update(_ section: TodayLifeSection?, lesson: LifeLesson? = nil) { self.section = section; self.lesson = lesson; onChange?() }
}

private final class FakeFeedAPI: BJTLifeFeedAPIInterface {
    var calls: [String] = []
    var result: (String) -> Single<BJTLifeFeedDTO> = { _ in .error(LearnerAPIError.notFound) }
    func feed(cityID: String) -> Single<BJTLifeFeedDTO> { calls.append(cityID); return result(cityID) }
}

private final class FakePlaces: LifePlaceProviding {
    var authorization = LifeLocationAuthorization.notDetermined
    var calls = 0
    var subject = PublishSubject<LifePlace>()
    func currentPlace() -> Single<LifePlace> { calls += 1; return subject.asSingle() }
}

private final class FakeHubPrefs: LifeHubPreferencesInterface {
    var showsSamples = true
    var opted: [String: Bool] = [:]
    func nearbyOptedIn(ownerKey: String) -> Bool { opted[ownerKey] ?? false }
    func setNearbyOptedIn(_ value: Bool, ownerKey: String) { opted[ownerKey] = value }
}

/// How the hub puts the date, the weather, the place, the server's feed and the examples together, and what it asks of whom.
final class TodayLifeHubLoaderTests: XCTestCase {
    private var weather: FakeWeatherLoader!
    private var api: FakeFeedAPI!
    private var places: FakePlaces!
    private var prefs: FakeHubPrefs!
    private var hub: TodayLifeHubLoader!
    private var now = LifeLessonFixtures.morning
    private var changes = 0
    private let place = LifePlace(adminArea: "東京都", locality: "港区", nearby: [.init(kind: .station, meters: 300)])

    override func setUp() {
        weather = FakeWeatherLoader()
        api = FakeFeedAPI()
        places = FakePlaces()
        prefs = FakeHubPrefs()
        makeHub()
    }

    private func makeHub() {
        hub = TodayLifeHubLoader(weather: weather, remote: api, places: places, preferences: prefs, ownerKey: { "owner" }, now: { [unowned self] in now },
                                 calendar: LifeLessonFixtures.japanCalendar, language: { .vietnamese })
        hub.onChange = { [unowned self] in changes += 1 }
    }

    private var cards: [LifeFeedCard] { hub.section?.cards ?? [] }
    private func card(_ topic: LifeTopic) -> LifeFeedCard? { cards.first { $0.topic == topic } }
    private func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    private func weatherLoaded() throws {
        let lesson = try LifeLessonFixtures.lesson()
        weather.update(TodayLifeSection(content: .loaded(TodayLifeLoader.card(for: lesson, language: .vietnamese)), exploreValue: ""), lesson: lesson)
    }

    // MARK: Composition without a feed from the server

    func test_withoutAServerFeedTheHubHasTheDateTheWeatherNearbyAndLabelledExamples() throws {
        try weatherLoaded()
        hub.refresh()
        XCTAssertEqual(cards.map(\.topic), [.date, .weather, .nearby, .transit, .shopping, .news, .food, .culture, .money, .lottery])
        XCTAssertEqual(card(.date)?.provenance, .onDevice, "The date is worked out here")
        XCTAssertEqual(card(.weather)?.provenance, .live)
        XCTAssertEqual(cards.filter { $0.provenance == .sample }.count, 7, "Every other topic is an example and says so")
        XCTAssertTrue(cards.filter { $0.provenance == .sample }.allSatisfy { $0.meta.contains(text("Example content · not live data yet")) })
        XCTAssertTrue(cards.filter { $0.provenance == .sample }.allSatisfy { $0.status == .ready && $0.lesson != nil })
        XCTAssertEqual(hub.section?.header.dateText, "10月24日（土）")
        XCTAssertEqual(hub.section?.cityName, "Tokyo")
    }

    func test_examplesCanBeSwitchedOffAndThenOnlyRealThingsRemain() throws {
        prefs.showsSamples = false
        try weatherLoaded()
        hub.refresh()
        XCTAssertEqual(cards.map(\.topic), [.date, .weather, .nearby])
        XCTAssertTrue(cards.allSatisfy { $0.provenance != .sample })
    }

    func test_readyCardsOpenTheirLessonAndOthersDoNot() throws {
        try weatherLoaded()
        hub.refresh()
        XCTAssertEqual(hub.lesson(forCard: "date:2026-10-24")?.topic, .date)
        XCTAssertEqual(hub.lesson(forCard: "weather:tokyo:2026-10-24")?.topic, .weather)
        XCTAssertNil(hub.lesson(forCard: "nearby:ask"), "A card that still asks for the location has no lesson")
        XCTAssertNil(hub.lesson(forCard: "nothing"))
    }

    func test_theWeatherCardFollowsTheWeatherRequest() throws {
        hub.refresh()
        XCTAssertNil(card(.weather), "A server without weather lessons: no weather card")
        weather.update(TodayLifeSection(content: .loading, exploreValue: ""))
        XCTAssertEqual(card(.weather)?.status, .loading)
        weather.update(TodayLifeSection(content: .failed(title: "No", message: "offline"), exploreValue: ""))
        XCTAssertEqual(card(.weather)?.status, .failed(message: "offline"))
        XCTAssertEqual(card(.weather)?.ctaTitle, text("Try again"))
        try weatherLoaded()
        XCTAssertEqual(card(.weather)?.status, .ready)
        XCTAssertEqual(card(.weather)?.scene, LifeScene.weather(.rain, temperatureC: 16), "The picture follows the weather code of the day")
    }

    // MARK: The server's feed

    private func serveFeed(_ object: [String: Any]) {
        api.result = { _ in .just(try! LifeFeedFixtures.dto(object)) }
    }

    func test_whenTheServerProvidesAFeedItReplacesTheExamplesAndIsUsedInItsOrder() throws {
        serveFeed(LifeFeedFixtures.typical)
        hub.refresh()
        XCTAssertEqual(api.calls, ["tokyo"])
        XCTAssertEqual(cards.map(\.topic), [.date, .weather, .nearby, .transit], "The unknown topic is ignored; the examples are gone")
        XCTAssertTrue(cards.allSatisfy { $0.provenance != .sample })
        XCTAssertEqual(card(.date)?.provenance, .live, "The server's date (it knows the holidays) replaces the one of the device")
        XCTAssertEqual(card(.date)?.headlineJapanese, "今日は祝日です")
        XCTAssertEqual(card(.weather)?.scene, LifeScene.weather(.rain, temperatureC: 16))
        XCTAssertEqual(card(.transit)?.lesson?.source.licenseStatus, .commercial)
        XCTAssertEqual(hub.lesson(forCard: "transit:1")?.vocabulary.first?.id, "holiday:shukujitsu")
    }

    func test_theServerCannotChooseWhereTheLearnerIs() throws {
        serveFeed(LifeFeedFixtures.feed(cards: [LifeFeedFixtures.card(id: "nearby:x", topic: "nearby", scene: ["kind": "place"])]))
        hub.refresh()
        XCTAssertEqual(card(.nearby)?.status, .needsLocation, "Near you is always the learner's own, worked out on the device")
        XCTAssertNil(cards.first { $0.id == "nearby:x" })
    }

    func test_aServerFeedWithoutAWeatherCardLeavesTheWeatherRoute() throws {
        serveFeed(LifeFeedFixtures.feed(cards: [LifeFeedFixtures.card(id: "date:2026-10-24", topic: "date")]))
        try weatherLoaded()
        hub.refresh()
        XCTAssertEqual(card(.weather)?.status, .ready, "The dedicated weather lesson still fills the weather card")
        XCTAssertEqual(cards.map(\.topic), [.date, .weather, .nearby])
    }

    func test_aServerWithoutAFeedKeepsTheExamplesAndIsNotAskedAgainForAnHour() throws {
        hub.refresh()
        XCTAssertEqual(api.calls.count, 1)
        XCTAssertEqual(cards.filter { $0.provenance == .sample }.count, 7)
        hub.refresh()
        hub.refresh()
        XCTAssertEqual(api.calls.count, 1, "404: not asked again at once")
        now = now.addingTimeInterval(3601)
        hub.refresh()
        XCTAssertEqual(api.calls.count, 2, "Asked again after the pause")
    }

    func test_aBrokenFeedFallsBackToTheExamplesAndIsRetriedSoon() throws {
        api.result = { _ in .error(LearnerAPIError.serviceUnavailable(nil)) }
        hub.refresh()
        XCTAssertEqual(cards.filter { $0.provenance == .sample }.count, 7)
        now = now.addingTimeInterval(61)
        serveFeed(LifeFeedFixtures.typical)
        hub.refresh()
        XCTAssertEqual(api.calls.count, 2)
        XCTAssertEqual(cards.filter { $0.provenance == .sample }.count, 0)
    }

    func test_aFeedForAnotherCityOrWithNothingUsableIsNotTrusted() throws {
        serveFeed(LifeFeedFixtures.feed(cityId: "osaka", cards: [LifeFeedFixtures.card(id: "date:x", topic: "date")]))
        hub.refresh()
        XCTAssertEqual(cards.filter { $0.provenance == .sample }.count, 7, "A feed for another city is ignored")
        XCTAssertNotEqual(card(.date)?.headlineJapanese, "今日は祝日です")
    }

    func test_theFeedIsReadAgainWhenTheCityChanges() throws {
        serveFeed(LifeFeedFixtures.typical)
        hub.refresh()
        let osaka = LifeFeedFixtures.feed(cityId: "osaka", cards: [LifeFeedFixtures.card(id: "date:2026-10-24", topic: "date")])
        serveFeed(osaka)
        hub.selectCity("osaka")
        XCTAssertEqual(weather.selected, ["osaka"])
        XCTAssertEqual(api.calls, ["tokyo", "osaka"])
        XCTAssertEqual(hub.section?.cityName, "Osaka")
    }

    func test_aServerFeedIsNotAskedAgainWhileItIsCurrent() throws {
        serveFeed(LifeFeedFixtures.typical)
        hub.refresh()
        hub.refresh()
        XCTAssertEqual(api.calls.count, 1)
        now = now.addingTimeInterval(24 * 3600)
        hub.refresh()
        XCTAssertEqual(api.calls.count, 2, "A new day asks again")
    }

    // MARK: Near you

    func test_theLocationIsNeverReadUntilTheLearnerAsks() {
        hub.refresh()
        XCTAssertEqual(card(.nearby)?.status, .needsLocation)
        XCTAssertEqual(places.calls, 0)
        places.authorization = .authorized
        hub.refresh()
        XCTAssertEqual(places.calls, 0, "Even when the system allows it, a first time is the learner's tap")
    }

    func test_theLearnersTapReadsThePlaceOnceAndTeachesIt() {
        hub.refresh()
        hub.requestLocation()
        XCTAssertEqual(card(.nearby)?.status, .locating)
        hub.requestLocation()
        XCTAssertEqual(places.calls, 1, "A second tap while locating asks nothing more")
        places.subject.onNext(place)
        places.subject.onCompleted()
        XCTAssertEqual(card(.nearby)?.status, .ready)
        XCTAssertEqual(card(.nearby)?.provenance, .onDevice)
        XCTAssertEqual(hub.lesson(forCard: card(.nearby)!.id)?.sentences.first?.japanese, "ここは東京都港区です。")
        XCTAssertEqual(prefs.opted["owner"], true)
    }

    func test_afterAnEarlierAskAndWithPermissionStillGivenThePlaceIsReadAgainWithoutAsking() {
        prefs.opted["owner"] = true
        places.authorization = .authorized
        hub.refresh()
        XCTAssertEqual(places.calls, 1)
        XCTAssertEqual(card(.nearby)?.status, .locating)
        places.authorization = .denied
        let other = TodayLifeHubLoader(weather: weather, remote: api, places: places, preferences: prefs, ownerKey: { "owner" }, now: { [unowned self] in now },
                                       calendar: LifeLessonFixtures.japanCalendar, language: { .vietnamese })
        other.refresh()
        XCTAssertEqual(places.calls, 1, "Permission taken away: nothing is read")
    }

    func test_refusalFailureAndNothingNearbyEachSayWhatHappened() {
        hub.refresh()
        hub.requestLocation()
        places.subject.onError(LifePlaceError.denied)
        XCTAssertEqual(card(.nearby)?.status, .locationDenied)
        XCTAssertEqual(card(.nearby)?.ctaTitle, text("Open Settings"))

        places.subject = PublishSubject<LifePlace>()
        hub.retry()   // a refusal is not retried by itself
        XCTAssertEqual(places.calls, 1)

        let fresh = TodayLifeHubLoader(weather: weather, remote: api, places: places, preferences: prefs, ownerKey: { "o2" }, now: { [unowned self] in now },
                                       calendar: LifeLessonFixtures.japanCalendar, language: { .vietnamese })
        fresh.refresh()
        fresh.requestLocation()
        places.subject.onError(LifePlaceError.outsideJapan)
        guard case .failed(let message)? = fresh.section?.cards.first(where: { $0.topic == .nearby })?.status else { return XCTFail("expected a failure") }
        XCTAssertEqual(message, LifePlaceError.outsideJapan.errorDescription)

        places.subject = PublishSubject<LifePlace>()
        fresh.retry()
        XCTAssertEqual(places.calls, 3, "A failure other than a refusal is retried")
        places.subject.onNext(LifePlace(adminArea: "東京都", locality: "港区", nearby: []))
        places.subject.onCompleted()
        XCTAssertEqual(fresh.section?.cards.first(where: { $0.topic == .nearby })?.status, .failed(message: LifePlaceError.nothingNearby.errorDescription ?? ""))
    }

    // MARK: Header and changes

    func test_theHeaderFollowsTheLearnersClock() {
        hub.refresh()
        XCTAssertEqual(hub.section?.header.greeting, "おはようございます")
        now = LifeLessonFixtures.japanCalendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 21))!
        hub.refresh()
        XCTAssertEqual(hub.section?.header.greeting, "こんばんは")
        XCTAssertEqual(hub.section?.header.symbol, "moon.stars.fill")
    }

    func test_everyChangeIsReportedSoTheScreenRedraws() throws {
        let before = changes
        hub.refresh()
        XCTAssertGreaterThan(changes, before)
        let mid = changes
        try weatherLoaded()
        XCTAssertGreaterThan(changes, mid)
    }
}

/// The server feed contract: what the app accepts, drops and refuses.
final class LifeFeedMapperTests: XCTestCase {
    func test_aTypicalFeedBecomesCardsInItsOrderAndUnknownTopicsAreIgnored() throws {
        let cards = try LifeFeedMapper.cards(from: LifeFeedFixtures.dto(LifeFeedFixtures.typical), requestedCityID: "tokyo", language: .english)
        XCTAssertEqual(cards.map(\.topic), [.date, .weather, .transit])
        let date = try XCTUnwrap(cards.first)
        XCTAssertEqual(date.status, .ready)
        XCTAssertEqual(date.headlineJapanese, "今日は祝日です")
        XCTAssertEqual(date.summary, "Today is a public holiday.", "The summary is the first sentence in the learner's language")
        XCTAssertEqual(date.chips.count, 2)
        XCTAssertEqual(date.chips.first?.symbol, "calendar")
        XCTAssertNil(date.chips.last?.symbol)
        XCTAssertEqual(date.lesson?.provenance, .live)
        XCTAssertEqual(date.lesson?.source.url?.absoluteString, "https://example.org/source")
        XCTAssertEqual(date.lesson?.source.attributionText, "Source: Cabinet Office")
        XCTAssertEqual(date.lesson?.cityID, "tokyo")
        XCTAssertEqual(date.scene, LifeScene.date(day: 24, weekday: "土"))
    }

    func test_feedChipsUseTheRequestedLanguage() throws {
        let dto = try LifeFeedFixtures.dto(LifeFeedFixtures.typical)
        let english = try LifeFeedMapper.cards(from: dto, requestedCityID: "tokyo", language: .english)
        let vietnamese = try LifeFeedMapper.cards(from: dto, requestedCityID: "tokyo", language: .vietnamese)

        XCTAssertEqual(english.first?.chips.first?.text, "Holiday")
        XCTAssertEqual(vietnamese.first?.chips.first?.text, "Ngày lễ")
    }

    func test_aSampleFromTheServerStaysASample() throws {
        let feed = LifeFeedFixtures.feed(cards: [LifeFeedFixtures.card(id: "a", topic: "food", provenance: "sample", scene: ["kind": "food"])])
        let cards = try LifeFeedMapper.cards(from: LifeFeedFixtures.dto(feed), requestedCityID: "tokyo", language: .vietnamese)
        XCTAssertEqual(cards.first?.provenance, .sample)
    }

    func test_cardsThatBreakTheContractAreLeftOutAndTheRestIsKept() throws {
        let feed = LifeFeedFixtures.feed(cards: [
            LifeFeedFixtures.card(id: "ok", topic: "date"),
            LifeFeedFixtures.card(id: "badProvenance", topic: "date", provenance: "onDevice"),
            LifeFeedFixtures.card(id: "noExercises", topic: "news", scene: ["kind": "news"], lesson: LifeFeedFixtures.lesson(id: "noExercises", exercisesValid: false)),
            LifeFeedFixtures.card(id: "httpLink", topic: "news", scene: ["kind": "news"], lesson: LifeFeedFixtures.lesson(id: "httpLink", url: "http://example.org")),
            LifeFeedFixtures.card(id: "badScene", topic: "news", scene: ["kind": "hologram"]),
            LifeFeedFixtures.card(id: "ok", topic: "food", scene: ["kind": "food"])
        ])
        let cards = try LifeFeedMapper.cards(from: LifeFeedFixtures.dto(feed), requestedCityID: "tokyo", language: .vietnamese)
        XCTAssertEqual(cards.map(\.id), ["ok"], "Only the first valid card of an id survives")
    }

    func test_aFeedThatCannotBeTrustedIsRefused() throws {
        for (name, object) in [("another schema", LifeFeedFixtures.feed(schemaVersion: 2, cards: [LifeFeedFixtures.card(id: "a", topic: "date")])),
                               ("another city", LifeFeedFixtures.feed(cityId: "osaka", cards: [LifeFeedFixtures.card(id: "a", topic: "date")])),
                               ("nothing usable", LifeFeedFixtures.feed(cards: [LifeFeedFixtures.card(id: "a", topic: "date", provenance: "magic")]))] {
            XCTAssertThrowsError(try LifeFeedMapper.cards(from: LifeFeedFixtures.dto(object), requestedCityID: "tokyo", language: .vietnamese), name) {
                XCTAssertEqual($0 as? LearnerAPIError, .invalidResponse, name)
            }
        }
        XCTAssertEqual(try LifeFeedMapper.cards(from: LifeFeedFixtures.dto(LifeFeedFixtures.feed(cards: [])), requestedCityID: "tokyo", language: .vietnamese), [],
                       "An empty feed is allowed: the hub then keeps the examples")
    }

    func test_aServerWeatherSceneUsesTheWeatherCode() throws {
        let feed = LifeFeedFixtures.feed(cards: [LifeFeedFixtures.card(id: "w", topic: "weather", scene: ["kind": "weather", "weatherCode": 71, "temperatureC": -2.4])])
        let cards = try LifeFeedMapper.cards(from: LifeFeedFixtures.dto(feed), requestedCityID: "tokyo", language: .vietnamese)
        XCTAssertEqual(cards.first?.scene, LifeScene.weather(.snow, temperatureC: -2))
        XCTAssertEqual(LifeWeatherKind(wmoCode: 45), .fog)
        XCTAssertEqual(LifeWeatherKind(wmoCode: 95), .thunderstorm)
        XCTAssertEqual(LifeWeatherKind(wmoCode: 999), .cloudy, "An unknown code is shown as plain cloud rather than a wrong sky")
    }
}
