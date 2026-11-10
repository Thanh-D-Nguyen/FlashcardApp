import RxSwift
import XCTest
@testable import FlashcardApp

/// Loto: choosing the next draw, mapping the number sets, the countdown and the presenter's states.
final class LotoTests: XCTestCase {
    // MARK: Fixtures

    private func article(_ numbers: String = "[10,15,18,20,22,23,35]", game: String = "magazine_loto7", extra: String = "") -> BJTLotoArticleDTO {
        let json = """
        {"id":"a","slug":"s","widgetKind":"\(game)","contentJson":{"game":"loto7","drawTime":"18:45 JST","drawNumber":702,"drawNumberEstimated":false,
        "targetDrawDate":"2026-11-06","scheduleVi":"Thứ 6","algorithmWeights":{"frequencyHot":0.24,"overdue":0.2,"weatherBias":0,"randomEntropy":0.1},
        "riskDisclaimer":{"en":"Same chance.","vi":"Như nhau.","ja":"同じ。"},
        "source":{"officialVerificationUrl":"https://www.mizuhobank.co.jp/takarakuji/check/loto/index.html"},
        "sets":[{"rank":1,"score":0.4,"mainNumbers":\(numbers),"bonusNumbers":[],"explanation":{"shape":{"odd":3,"even":4,"low":3,"high":4,"sum":143,"consecutivePairs":1},
        "numbers":[{"number":15,"count":155,"gap":2,"tags":["hot","recent","unknown"]}],"signals":{"hotNumbers":[15],"coldNumbers":[],"overdueNumbers":[18]},"historyDraws":701}}]\(extra)}}
        """
        return try! JSONDecoder().decode(BJTLotoArticleDTO.self, from: Data(json.utf8))
    }

    private func item(_ game: LotoGame = .loto7, _ day: String = "2026-11-06") -> LotoListItem {
        LotoListItem(slug: "s", game: game, day: MagazineDay(key: day)!)
    }

    // MARK: Games

    func test_theChanceOfTheTopPrizeIsOneInTheNumberOfCombinations() {
        XCTAssertEqual(LotoGame.loto6.combinations, 6_096_454)
        XCTAssertEqual(LotoGame.loto7.combinations, 10_295_472)
    }

    func test_gamesAreRecognisedFromTheWidgetKind() {
        XCTAssertEqual(LotoGame(widgetKind: "magazine_loto6"), .loto6)
        XCTAssertEqual(LotoGame(widgetKind: "magazine_loto7"), .loto7)
        XCTAssertNil(LotoGame(widgetKind: "magazine_loto"), "The old combined article is not a draw")
        XCTAssertNil(LotoGame(widgetKind: "magazine_vocab"))
    }

    // MARK: Next draw

    func test_theNextDrawIsTheFirstOneNotYetPast_andTodayCounts() {
        let items = [item(.loto7, "2026-10-30"), item(.loto7, "2026-11-06"), item(.loto6, "2026-11-02")]
        let today = MagazineDay(key: "2026-10-30")!
        XCTAssertEqual(LotoInteractor.nextItem(of: .loto7, in: items, today: today)?.day, MagazineDay(key: "2026-10-30"))
        XCTAssertEqual(LotoInteractor.nextItem(of: .loto7, in: items, today: MagazineDay(key: "2026-10-31")!)?.day, MagazineDay(key: "2026-11-06"))
    }

    func test_whenEveryDrawIsPastTheLatestIsShown_andAGameWithoutArticlesHasNone() {
        let items = [item(.loto7, "2026-10-23"), item(.loto7, "2026-10-30")]
        XCTAssertEqual(LotoInteractor.nextItem(of: .loto7, in: items, today: MagazineDay(key: "2026-12-01")!)?.day, MagazineDay(key: "2026-10-30"))
        XCTAssertNil(LotoInteractor.nextItem(of: .loto6, in: items, today: MagazineDay(key: "2026-10-01")!))
    }

    func test_theListKeepsOnlyLotoGames() {
        let json = MagazineFixtures.list([MagazineFixtures.listItem(slug: "a", kind: "magazine_loto6", day: "2026-11-02"),
                                          MagazineFixtures.listItem(slug: "b", kind: "magazine_loto", day: "2026-10-07"),
                                          MagazineFixtures.listItem(slug: "c", kind: "magazine_vocab", day: "2026-10-07")])
        let list = try! JSONDecoder().decode(BJTMagazineListDTO.self, from: Data(json.utf8))
        XCTAssertEqual(LotoInteractor.items(from: list).map(\.slug), ["a"])
    }

    // MARK: Mapping

    func test_aCompleteSetIsMapped_withTagsShapeSignalsAndWeights() throws {
        let draw = try XCTUnwrap(LotoInteractor.draw(from: article(), item: item(), language: .vietnamese))
        XCTAssertEqual(draw.sets.first?.main, [10, 15, 18, 20, 22, 23, 35])
        XCTAssertEqual(draw.sets.first?.numbers.first?.tags, [.hot, .recent], "An unknown tag is dropped")
        XCTAssertEqual(draw.sets.first?.shape?.sum, 143)
        XCTAssertEqual(draw.signals.overdue, [18])
        XCTAssertEqual(draw.weights.map(\.kind), [.frequencyHot, .overdue, .randomEntropy], "Weights of zero are not listed")
        XCTAssertEqual(draw.historyDraws, 701)
        XCTAssertEqual(draw.disclaimer, "Như nhau.")
        XCTAssertEqual(draw.drawNumber, 702)
        XCTAssertNotNil(draw.officialURL)
    }

    func test_aSetThatIsNotAWholeTicketIsNotShown() {
        XCTAssertNil(LotoInteractor.draw(from: article("[10,15,18]"), item: item()), "Too few numbers")
        XCTAssertNil(LotoInteractor.draw(from: article("[10,15,18,20,22,23,23]"), item: item()), "A repeated number")
        XCTAssertNil(LotoInteractor.draw(from: article("[10,15,18,20,22,23,38]"), item: item()), "Outside 1…37")
    }

    func test_theDisclaimerFollowsTheLanguage_andNeverDisappears() {
        let all = BJTLotoArticleDTO.Disclaimer(en: "E", ja: "J", vi: "V")
        XCTAssertEqual(LotoInteractor.disclaimer(all, language: .japanese), "J")
        XCTAssertEqual(LotoInteractor.disclaimer(all, language: .english), "E")
        XCTAssertEqual(LotoInteractor.disclaimer(BJTLotoArticleDTO.Disclaimer(en: nil, ja: nil, vi: "V"), language: .english), "V")
        XCTAssertFalse(LotoInteractor.disclaimer(nil, language: .english).isEmpty, "The numbers are never shown without the statement")
        XCTAssertFalse(LotoInteractor.disclaimer(BJTLotoArticleDTO.Disclaimer(en: "  ", ja: nil, vi: nil), language: .english).trimmingCharacters(in: .whitespaces).isEmpty)
    }

    func test_onlyTheLotteryOperatorsHttpsSiteIsOpened() {
        XCTAssertNotNil(LotoInteractor.officialURL("https://www.mizuhobank.co.jp/takarakuji/check/loto/index.html"))
        XCTAssertNil(LotoInteractor.officialURL("http://www.mizuhobank.co.jp/x"))
        XCTAssertNil(LotoInteractor.officialURL("https://mizuhobank.co.jp.evil.example/x"))
        XCTAssertNil(LotoInteractor.officialURL("https://example.com/"))
        XCTAssertNil(LotoInteractor.officialURL(nil))
    }

    func test_theDrawInstantIsTheJapanTime() throws {
        let instant = try XCTUnwrap(LotoInteractor.drawInstant(day: MagazineDay(key: "2026-11-06")!, time: "18:45 JST"))
        XCTAssertEqual(instant.timeIntervalSince1970, ISO8601DateFormatter().date(from: "2026-11-06T09:45:00Z")?.timeIntervalSince1970)
        XCTAssertNil(LotoInteractor.drawInstant(day: MagazineDay(key: "2026-11-06")!, time: "evening"))
        XCTAssertNil(LotoInteractor.drawInstant(day: MagazineDay(key: "2026-11-06")!, time: nil))
    }

    // MARK: Countdown

    func test_theCountdownIsSplitIntoDaysHoursMinutesSeconds_andEndsAtTheDrawTime() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let target = now.addingTimeInterval(2 * 86_400 + 3 * 3_600 + 4 * 60 + 5)
        XCTAssertEqual(LotoCountdown.until(target, now: now), LotoCountdown(days: 2, hours: 3, minutes: 4, seconds: 5))
        XCTAssertNil(LotoCountdown.until(now, now: now))
        XCTAssertNil(LotoCountdown.until(now.addingTimeInterval(-5), now: now))
    }

    // MARK: Presenter

    private final class FakeInteractor: LotoInteractorInterface {
        var result: Single<LotoOverview>
        init(_ result: Single<LotoOverview>) { self.result = result }
        func load() -> Single<LotoOverview> { result }
    }

    private final class FakeView: LotoViewInterface {
        var states: [LotoViewState] = []
        var endedRefreshing = 0
        func render(_ state: LotoViewState) { states.append(state) }
        func endRefreshing() { endedRefreshing += 1 }
    }

    private final class FakeWireframe: LotoWireframeInterface {
        var opened: [URL] = []
        func showOfficialSite(_ url: URL) { opened.append(url) }
    }

    private func draw(_ game: LotoGame) throws -> LotoDraw {
        let json = article(game == .loto7 ? "[10,15,18,20,22,23,35]" : "[1,2,3,4,5,6]")
        return try XCTUnwrap(LotoInteractor.draw(from: json, item: item(game), language: .english))
    }

    private final class FakeEnvironment: LotoEnvironmentInteractorInterface {
        var factors: [LotoChaosFactor] = []
        func weatherFactors() -> Single<[LotoChaosFactor]> { .just(factors) }
    }

    private func makePresenter(_ result: Single<LotoOverview>) -> (LotoPresenter, FakeView, FakeWireframe) {
        let view = FakeView(), wireframe = FakeWireframe()
        let presenter = LotoPresenter(interactor: FakeInteractor(result), wireframe: wireframe, scheduler: CurrentThreadScheduler.instance,
                                   environment: FakeEnvironment())
        presenter.view = view
        return (presenter, view, wireframe)
    }

    func test_loadingShowsTheFirstGame_andSwitchingShowsTheOther() throws {
        let overview = LotoOverview(draws: [try draw(.loto7), try draw(.loto6)])
        let (presenter, view, _) = makePresenter(.just(overview))
        presenter.viewDidLoad()
        XCTAssertEqual(view.states.first?.phase, .loading)
        XCTAssertEqual(view.states.last?.phase, .ready)
        XCTAssertEqual(view.states.last?.games, [.loto7, .loto6])
        XCTAssertEqual(view.states.last?.draw?.game, .loto7)
        presenter.select(.loto6)
        XCTAssertEqual(view.states.last?.draw?.game, .loto6)
    }

    func test_noArticlesIsAnEmptyState_andAFailureOffersARetry() {
        let (empty, emptyView, _) = makePresenter(.just(LotoOverview(draws: [])))
        empty.viewDidLoad()
        XCTAssertEqual(emptyView.states.last?.phase, .empty)

        let (failing, failedView, _) = makePresenter(.error(LearnerAPIError.invalidResponse))
        failing.viewDidLoad()
        if case .failed = failedView.states.last?.phase {} else { XCTFail("Expected a failed state") }
    }

    func test_aFailedRefreshKeepsTheDrawsOnScreen() throws {
        let interactor = FakeInteractor(.just(LotoOverview(draws: [try draw(.loto7)])))
        let view = FakeView()
        let presenter = LotoPresenter(interactor: interactor, wireframe: FakeWireframe(), scheduler: CurrentThreadScheduler.instance,
                                   environment: FakeEnvironment())
        presenter.view = view
        presenter.viewDidLoad()
        let rendered = view.states.count
        interactor.result = .error(LearnerAPIError.invalidResponse)
        presenter.refresh()
        XCTAssertEqual(view.states.count, rendered, "Nothing is re-rendered, so the numbers stay")
        XCTAssertEqual(view.endedRefreshing, 2)
    }

    func test_theCopiedTextListsTheNumbersWithTheGame() throws {
        let (presenter, _, _) = makePresenter(.just(LotoOverview(draws: [try draw(.loto7)])))
        presenter.viewDidLoad()
        let set = try draw(.loto7).sets[0]
        let text = try XCTUnwrap(presenter.copyText(for: set))
        XCTAssertTrue(text.hasPrefix(LotoGame.loto7.title))
        XCTAssertTrue(text.hasSuffix("10 15 18 20 22 23 35"))
    }

    func test_theOfficialSiteOpensOnlyWhenTheDrawHasOne() throws {
        let (presenter, _, wireframe) = makePresenter(.just(LotoOverview(draws: [try draw(.loto7)])))
        presenter.viewDidLoad()
        presenter.openOfficialSite()
        XCTAssertEqual(wireframe.opened.count, 1)
    }

    // MARK: Randomness lab

    private let signals = LotoSignals(hot: [1, 2, 3], cold: [4], overdue: [5, 6])

    private func seeded(_ seed: UInt64 = 7) -> LotoRandomSource {
        var state = seed
        // splitmix64: repeatable and well spread.
        return LotoRandomSource {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    func test_fullRandomnessWeighsEveryNumberTheSame() {
        for game in LotoGame.allCases {
            let weights = LotoRandomizer.weights(game: game, signals: signals, randomness: 1)
            XCTAssertEqual(weights.count, game.poolSize)
            XCTAssertTrue(LotoRandomizer.isUniform(weights))
        }
    }

    func test_lowerRandomnessFavoursMarkedNumbersButKeepsEveryNumberPossible() {
        let weights = LotoRandomizer.weights(game: .loto6, signals: signals, randomness: 0)
        XCTAssertFalse(LotoRandomizer.isUniform(weights))
        XCTAssertEqual(weights[0], 1)
        XCTAssertEqual(weights[20], LotoRandomizer.unmarkedShare)
        XCTAssertTrue(weights.allSatisfy { $0 > 0 })
    }

    func test_withoutSignalsTheWeightsAreFlatAtAnyRandomness() {
        let empty = LotoSignals(hot: [], cold: [], overdue: [])
        XCTAssertTrue(LotoRandomizer.isUniform(LotoRandomizer.weights(game: .loto7, signals: empty, randomness: 0)))
    }

    func test_randomnessOutsideTheRangeOrNotANumberIsClamped() {
        XCTAssertEqual(LotoRandomizer.clamped(-3), 0)
        XCTAssertEqual(LotoRandomizer.clamped(4), 1)
        XCTAssertEqual(LotoRandomizer.clamped(.nan), 1)
    }

    func test_aTicketHasTheRightNumberOfDifferentSortedNumbersInRange() {
        var generator = seeded()
        for game in LotoGame.allCases {
            for randomness in [0.0, 0.5, 1.0] {
                let ticket = LotoRandomizer.ticket(game: game, signals: signals, randomness: randomness, using: &generator)
                XCTAssertEqual(ticket.count, game.pickCount)
                XCTAssertEqual(Set(ticket).count, game.pickCount)
                XCTAssertEqual(ticket, ticket.sorted())
                XCTAssertTrue(ticket.allSatisfy { (1...game.poolSize).contains($0) })
            }
        }
    }

    func test_aSpinGivesDistinctTickets() {
        var generator = seeded()
        let tickets = LotoRandomizer.tickets(game: .loto6, signals: signals, randomness: 0.3, using: &generator)
        XCTAssertEqual(tickets.count, LotoRandomizer.setsPerSpin)
        XCTAssertEqual(Set(tickets).count, tickets.count)
    }

    func test_fullRandomnessPicksEveryNumberAboutEquallyOften() {
        var generator = seeded(11)
        var counts = [Int](repeating: 0, count: LotoGame.loto6.poolSize)
        let spins = 20_000
        for _ in 0..<spins {
            LotoRandomizer.ticket(game: .loto6, signals: signals, randomness: 1, using: &generator).forEach { counts[$0 - 1] += 1 }
        }
        let expected = Double(spins * LotoGame.loto6.pickCount) / Double(LotoGame.loto6.poolSize)
        for count in counts { XCTAssertEqual(Double(count), expected, accuracy: expected * 0.1) }
    }

    func test_noRandomnessPicksMarkedNumbersMoreOftenThanOthers() {
        var generator = seeded(5)
        var marked = 0, other = 0
        for _ in 0..<2_000 {
            for number in LotoRandomizer.ticket(game: .loto6, signals: signals, randomness: 0, using: &generator) {
                if (1...6).contains(number) { marked += 1 } else { other += 1 }
            }
        }
        // Six marked numbers of 43 would be 14% of the picks with equal weights.
        XCTAssertGreaterThan(Double(marked) / Double(marked + other), 0.4)
    }

    func test_theSameSourceGivesTheSameTickets() {
        var first = seeded(), second = seeded()
        XCTAssertEqual(LotoRandomizer.tickets(game: .loto7, signals: signals, randomness: 0.6, using: &first),
                       LotoRandomizer.tickets(game: .loto7, signals: signals, randomness: 0.6, using: &second))
    }

    // MARK: Chaos system

    private func factors(_ temperature: String = "17.6") -> [LotoChaosFactor] {
        [LotoChaosFactor(kind: .moment, key: "moment", value: "epochMs=1"),
         LotoChaosFactor(kind: .weather, key: "weather.tokyo", value: "code=2;temperatureC=\(temperature)", subject: "tokyo"),
         LotoChaosFactor(kind: .draw, key: "draw", value: "game=loto6;number=2151")]
    }

    func test_theFingerprintIgnoresTheOrderButNotAnyValue() {
        let list = factors()
        XCTAssertEqual(LotoChaosEngine.fingerprint(of: list), LotoChaosEngine.fingerprint(of: list.reversed()))
        XCTAssertNotEqual(LotoChaosEngine.fingerprint(of: list), LotoChaosEngine.fingerprint(of: factors("17.7")))
    }

    func test_theSameFactorsGiveTheSameSystemAndTickets() {
        let a = LotoChaosEngine.run(factors: factors(), game: .loto6, signals: signals, randomness: 1)
        let b = LotoChaosEngine.run(factors: factors(), game: .loto6, signals: signals, randomness: 1)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.tickets.count, LotoRandomizer.setsPerSpin)
    }

    func test_aTenthOfADegreeChangesTheWholeOutcome() {
        let a = LotoChaosEngine.run(factors: factors(), game: .loto6, signals: signals, randomness: 1)
        let b = LotoChaosEngine.run(factors: factors("17.7"), game: .loto6, signals: signals, randomness: 1)
        XCTAssertNotEqual(a.fingerprint, b.fingerprint)
        XCTAssertNotEqual(a.tickets, b.tickets)
        XCTAssertNotEqual(a.original.last, b.original.last)
    }

    func test_aMillionthOfDifferenceAtTheStartBecomesAWholeAttractorApart() {
        // The butterfly effect itself: for every start the two copies end up far apart.
        for seed in 0..<12 {
            let result = LotoChaosEngine.run(factors: [LotoChaosFactor(kind: .moment, key: "moment", value: "seed=\(seed)")],
                                             game: .loto7, signals: signals, randomness: 1)
            XCTAssertNotNil(result.divergenceIndex, "seed \(seed)")
            XCTAssertGreaterThan(result.finalDistance, 1, "seed \(seed)")
            XCTAssertEqual(result.original.count, LotoChaosEngine.sampleCount)
        }
    }

    func test_theTwoPathsStartPracticallyTogether() {
        let result = LotoChaosEngine.run(factors: factors(), game: .loto6, signals: signals, randomness: 1)
        XCTAssertLessThan(result.original[0].distance(to: result.perturbed[0]), 0.001)
    }

    func test_chaosTicketsAreValidAtEveryRandomness() {
        for randomness in [0.0, 0.5, 1.0] {
            let result = LotoChaosEngine.run(factors: factors(), game: .loto7, signals: signals, randomness: randomness)
            for ticket in result.tickets {
                XCTAssertEqual(Set(ticket).count, LotoGame.loto7.pickCount)
                XCTAssertTrue(ticket.allSatisfy { (1...LotoGame.loto7.poolSize).contains($0) })
            }
        }
    }

    func test_chaosNumbersAtFullRandomnessAreSpreadEvenly() {
        var counts = [Int](repeating: 0, count: LotoGame.loto6.poolSize)
        let spins = 3_000
        for index in 0..<spins {
            let result = LotoChaosEngine.run(factors: [LotoChaosFactor(kind: .moment, key: "moment", value: "n=\(index)")], game: .loto6,
                                             signals: signals, randomness: 1, ticketCount: 1)
            result.tickets[0].forEach { counts[$0 - 1] += 1 }
        }
        let expected = Double(spins * LotoGame.loto6.pickCount) / Double(LotoGame.loto6.poolSize)
        for count in counts { XCTAssertEqual(Double(count), expected, accuracy: expected * 0.2) }
    }

    func test_aSpinNeedsADraw_andCarriesTheDrawAndTheLocalFactors() throws {
        let (empty, _, _) = makePresenter(.just(LotoOverview(draws: [])))
        empty.viewDidLoad()
        XCTAssertNil(empty.spin(randomness: 1, local: []))

        let (presenter, _, _) = makePresenter(.just(LotoOverview(draws: [try draw(.loto7)])))
        presenter.viewDidLoad()
        let local = [LotoChaosFactor(kind: .moment, key: "moment", value: "epochMs=1")]
        let result = try XCTUnwrap(presenter.spin(randomness: 1, local: local))
        XCTAssertEqual(Set(result.factors.map(\.kind)), [.moment, .draw])
        XCTAssertEqual(result.tickets.count, LotoRandomizer.setsPerSpin)
        XCTAssertTrue(result.tickets.allSatisfy { $0.count == LotoGame.loto7.pickCount })
    }

    func test_theWeatherFactorComesFromTheWeatherCardOfTheFeed() throws {
        let json = """
        {"schemaVersion":1,"generatedAt":"x","cityId":"tokyo","cards":[
        {"id":"w","topic":"weather","provenance":"live","summary":{"vi":"a","en":"b"},
        "scene":{"kind":"weather","weatherCode":2,"temperatureC":17.64},
        "lesson":{"id":"w","level":"N5","title":{"japanese":"a","reading":"a","vi":"a","en":"a"},
        "source":{"providerName":"p","observedAt":"x","fetchedAt":"x","expiresAt":"x","freshness":"live"},
        "chips":[],"sentences":[],"vocabulary":[],"exercises":[],"estimatedMinutes":1}}]}
        """
        let feed = try JSONDecoder().decode(BJTLifeFeedDTO.self, from: Data(json.utf8))
        let factor = try XCTUnwrap(LotoEnvironmentInteractor.factor(city: LifeCity.all[0], feed: feed))
        XCTAssertEqual(factor.key, "weather.tokyo")
        XCTAssertEqual(factor.value, "code=2;temperatureC=17.6")
        XCTAssertNil(LotoEnvironmentInteractor.factor(city: LifeCity.all[0], feed: BJTLifeFeedDTO(schemaVersion: 1, generatedAt: "x", cityId: "tokyo", cards: [])))
    }
}
