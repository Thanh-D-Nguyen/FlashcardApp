import Alamofire
import RxSwift
import XCTest
@testable import FlashcardApp

private func sampleCards() throws -> [BJTRadarCardDTO] {
    try BJTDailyRadarAPI.decode(Data(DailyRadarFixtures.productionSample.utf8))
}

private func gregorian(_ zone: String = "Asia/Ho_Chi_Minh") -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    return calendar
}

private let noon = Date(timeIntervalSince1970: 1_794_373_200)   // 2026-11-11 12:00 in Hanoi (05:00 UTC)

final class DailyRadarDecodingTests: XCTestCase {
    func test_bothExpressionShapesOfTheProductionListDecode() throws {
        let cards = try sampleCards()
        XCTAssertEqual(cards.map(\.slug), ["client-follow-up-email-j2", "news-headline-patterns", "kentou-shimasu-real-meaning"])
        XCTAssertEqual(cards[0].metadata?.japaneseExpressions.first, .init(japanese: "進捗はいかがでしょうか"))
        let object = try XCTUnwrap(cards[1].metadata?.japaneseExpressions.first)
        XCTAssertEqual(object.japanese, "〜へ")
        XCTAssertEqual(object.reading, "〜へ")
        XCTAssertEqual(object.meaning, "→ (hướng đến, sắp xảy ra)")
        XCTAssertEqual(object.example, "日経平均、4万円台へ")
        XCTAssertEqual(cards[1].metadata?.seed, true)
    }

    func test_anOddFieldOrCardIsSkippedWithoutLosingTheList() throws {
        let json = #"""
        [{"id":"1","slug":"a","titleVi":"A","module":{"moduleKey":"workplace_mission","titleVi":"Công việc"},
          "metadata":{"seed":"yes","usageNote":42,"japaneseExpressions":[7,{"meaning":"no word"},"了解です"]}},
         {"id":"2","titleVi":"no slug","module":{"moduleKey":"x"}},
         {"id":"3","slug":"c","titleVi":"C","module":{"moduleKey":"life_hack"},"metadata":null}]
        """#
        let cards = try BJTDailyRadarAPI.decode(Data(json.utf8))
        XCTAssertEqual(cards.map(\.slug), ["a", "c"], "A card that cannot be read is skipped on its own")
        XCTAssertEqual(cards[0].metadata?.japaneseExpressions, [.init(japanese: "了解です")])
        XCTAssertNil(cards[0].metadata?.seed)
        XCTAssertNil(cards[0].metadata?.usageNote)
        XCTAssertThrowsError(try BJTDailyRadarAPI.decode(Data(#"{"cards":[]}"#.utf8)))
    }
}

final class DailyRadarPickerTests: XCTestCase {
    func test_seededNewsComingSoonAndCardsWithoutAnExpressionAreLeftOut() throws {
        let cards = try sampleCards()
        XCTAssertNotNil(DailyRadarPicker.item(from: cards[0], language: .vietnamese))
        XCTAssertNil(DailyRadarPicker.item(from: cards[1], language: .vietnamese), "A seeded news card is not today's news")
        let item = try XCTUnwrap(DailyRadarPicker.item(from: cards[2], language: .vietnamese))
        XCTAssertEqual(item.moduleTitle, cards[2].module.titleVi)
        XCTAssertEqual(item.title, cards[2].titleVi)
        XCTAssertEqual(item.expressions.map(\.japanese), ["検討します", "前向きに検討します"])

        let json = #"""
        [{"id":"1","slug":"soon","titleVi":"Soon","module":{"moduleKey":"life_hack"},"metadata":{"comingSoon":true,"japaneseExpressions":["a"]}},
         {"id":"2","slug":"bare","titleVi":"Bare","module":{"moduleKey":"life_hack"},"metadata":{"japaneseExpressions":[]}},
         {"id":"3","slug":"live","titleVi":"Live news","module":{"moduleKey":"news_bjt"},"metadata":{"seed":false,"japaneseExpressions":["速報"]}}]
        """#
        let other = try BJTDailyRadarAPI.decode(Data(json.utf8))
        XCTAssertNil(DailyRadarPicker.item(from: other[0], language: .vietnamese))
        XCTAssertNil(DailyRadarPicker.item(from: other[1], language: .vietnamese))
        XCTAssertNotNil(DailyRadarPicker.item(from: other[2], language: .vietnamese), "News the server marks as not seeded is current")
    }

    func test_theJapaneseTitlesAreUsedWhenTheAppIsInJapanese() throws {
        let card = try sampleCards()[0]
        let item = try XCTUnwrap(DailyRadarPicker.item(from: card, language: .japanese))
        XCTAssertEqual(item.moduleTitle, "今日の仕事シーン")
        XCTAssertEqual(item.title, card.titleVi, "No Japanese title on the server: the Vietnamese one stays")
    }

    func test_oneCardAllDayAndAnotherTheNextDay() throws {
        let cards = try sampleCards()
        let calendar = gregorian()
        let morning = DailyRadarPicker.pick(cards, on: noon.addingTimeInterval(-5 * 3600), calendar: calendar, language: .vietnamese)
        let evening = DailyRadarPicker.pick(cards, on: noon.addingTimeInterval(11 * 3600), calendar: calendar, language: .vietnamese)
        let tomorrow = DailyRadarPicker.pick(cards, on: noon.addingTimeInterval(24 * 3600), calendar: calendar, language: .vietnamese)
        XCTAssertNotNil(morning)
        XCTAssertEqual(morning, evening)
        XCTAssertNotEqual(morning?.slug, tomorrow?.slug, "Two usable cards alternate by day")
        XCTAssertNil(DailyRadarPicker.pick([cards[1]], on: noon, calendar: calendar, language: .vietnamese))
    }

    func test_radarItemMapsRealDeepLinksAndLifeSceneVisuals() throws {
        let cards = try sampleCards()
        let scenarioItem = try XCTUnwrap(DailyRadarPicker.item(from: cards[0], language: .vietnamese))
        XCTAssertEqual(scenarioItem.moduleKey, "workplace_mission")
        XCTAssertEqual(scenarioItem.deepLink, .scenarios)
        XCTAssertEqual(scenarioItem.visualScene(on: noon, calendar: gregorian()).topic, .transit)

        let nuanceItem = try XCTUnwrap(DailyRadarPicker.item(from: cards[2], language: .vietnamese))
        XCTAssertEqual(nuanceItem.moduleKey, "honne_tatemae")
        XCTAssertNil(nuanceItem.deepLink, "Website-only routes do not pretend to deep-link")
        XCTAssertEqual(nuanceItem.visualScene(on: noon, calendar: gregorian()).topic, .culture)
    }
}

private final class FakeRadarAPI: BJTDailyRadarAPIInterface {
    var result: Single<(cards: [BJTRadarCardDTO], data: Data)> = .error(LearnerAPIError.offline)
    private(set) var limits: [Int] = []
    func cards(limit: Int) -> Single<(cards: [BJTRadarCardDTO], data: Data)> { limits.append(limit); return result }
}

private final class MemoryRadarCache: DailyRadarCacheInterface {
    var stored: (data: Data, savedAt: Date)?
    var failSave = false
    func load() -> (data: Data, savedAt: Date)? { stored }
    func save(_ data: Data, at date: Date) throws {
        if failSave { throw CocoaError(.fileWriteNoPermission) }
        stored = (data, date)
    }
}

final class TodayRadarLoaderTests: XCTestCase {
    private var api: FakeRadarAPI!
    private var cache: MemoryRadarCache!
    private var now = noon
    private let sample = Data(DailyRadarFixtures.productionSample.utf8)

    override func setUp() {
        super.setUp()
        api = FakeRadarAPI()
        cache = MemoryRadarCache()
        now = noon
    }

    private func loader() -> TodayRadarLoader {
        TodayRadarLoader(api: api, cache: cache, now: { [unowned self] in now }, calendar: { gregorian() }, language: { .vietnamese })
    }

    private func settle() {
        let drained = expectation(description: "main queue")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 2)
    }

    func test_aSmallListIsAskedForOnceAndKeptForTheDay() throws {
        api.result = .just((try sampleCards(), sample))
        let loader = loader()
        var changes = 0
        loader.onChange = { changes += 1 }
        loader.refresh()
        settle()
        XCTAssertEqual(api.limits, [TodayRadarLoader.limit])
        XCTAssertEqual(TodayRadarLoader.limit, 20)
        XCTAssertNotNil(loader.item)
        XCTAssertEqual(changes, 1)
        XCTAssertEqual(cache.stored?.data, sample, "The server's bytes are kept unchanged")
        now = now.addingTimeInterval(3600)
        loader.refresh()
        settle()
        XCTAssertEqual(api.limits.count, 1, "A fresh copy is used without asking again")
    }

    func test_anOldCopyIsShownWhileTheServerIsAskedAndStaysWhenItFails() {
        cache.stored = (sample, noon.addingTimeInterval(-13 * 3600))
        api.result = .error(LearnerAPIError.offline)
        let loader = loader()
        loader.refresh()
        settle()
        XCTAssertEqual(api.limits.count, 1, "Older than 12 hours: asked again")
        XCTAssertNotNil(loader.item, "The day's card stays offline")
    }

    func test_withoutAUsableCopyAFailureShowsNothing() {
        cache.stored = (sample, noon.addingTimeInterval(-8 * 24 * 3600))
        let loader = loader()
        loader.refresh()
        settle()
        XCTAssertNil(loader.item, "A copy older than a week is not shown")
        cache.stored = nil
        loader.refresh()
        settle()
        XCTAssertNil(loader.item)
    }

    func test_aCopyThatCannotBeSavedIsStillShown() throws {
        api.result = .just((try sampleCards(), sample))
        cache.failSave = true
        let loader = loader()
        loader.refresh()
        settle()
        XCTAssertNotNil(loader.item)
    }
}

final class FileDailyRadarCacheTests: XCTestCase {
    func test_theCopySurvivesAndAnUnreadableFileIsIgnored() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = FileDailyRadarCache(directory: directory)
        XCTAssertNil(cache.load())
        try cache.save(Data("[]".utf8), at: noon)
        XCTAssertEqual(FileDailyRadarCache(directory: directory).load()?.data, Data("[]".utf8))
        XCTAssertEqual(FileDailyRadarCache(directory: directory).load()?.savedAt, noon)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("DailyRadar/cards.json"))
        XCTAssertNil(FileDailyRadarCache(directory: directory).load())
    }
}

final class BJTDailyRadarAPITests: XCTestCase {
    private var session: Session!
    private let bag = DisposeBag()

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LearnerURLProtocol.self]
        session = Session(configuration: config)
        LearnerURLProtocol.handler = nil
        LearnerURLProtocol.requests = []
    }

    override func tearDown() {
        session.session.invalidateAndCancel()
        LearnerURLProtocol.handler = nil
        super.tearDown()
    }

    func test_theListIsAskedAnonymouslyWithALimit() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: DailyRadarFixtures.productionSample) }
        let api = BJTDailyRadarAPI(session: session, baseURL: { "https://api.test/api" })
        var count: Int?
        let done = expectation(description: "answer")
        api.cards(limit: 20).subscribe(onSuccess: { count = $0.cards.count; done.fulfill() }, onFailure: { _ in done.fulfill() }).disposed(by: bag)
        wait(for: [done], timeout: 3)
        XCTAssertEqual(count, 3)
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.url.absoluteString, "https://api.test/api/daily-radar/cards?limit=20")
        XCTAssertNil(sent.headers["Authorization"])
        var rejected = false
        api.cards(limit: 0).subscribe(onFailure: { _ in rejected = true }).disposed(by: bag)
        XCTAssertTrue(rejected)
    }
}

private final class FakeRadarLoader: TodayRadarLoading {
    var item: DailyRadarItem?
    var onChange: (() -> Void)?
    private(set) var refreshes = 0
    func refresh() { refreshes += 1 }
}
