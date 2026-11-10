import RealmSwift
import RxSwift
import XCTest
@testable import FlashcardApp

/// Turning the API's payloads into what the app shows, and saving article words into the learner's decks.
final class MagazineInteractorTests: XCTestCase {

    // MARK: Day

    func test_aDayReadsFromADateOrAnInstantAndRejectsJunk() {
        XCTAssertEqual(MagazineDay(key: "2026-10-26"), MagazineDay(key: "2026-10-26T00:00:00Z"))
        XCTAssertNil(MagazineDay(key: "2026-13-01"))
        XCTAssertNil(MagazineDay(key: "yesterday"))
        XCTAssertNil(MagazineDay(key: "2026-1-5"))
        XCTAssertTrue(MagazineDay(key: "2026-10-25")! < MagazineDay(key: "2026-10-26")!)
    }

    func test_todayIsTheDayInJapanNotOnTheDevice() {
        // 16:00 UTC on the 25th is already 01:00 on the 26th in Tokyo, where the magazine is dated.
        let instant = ISO8601DateFormatter().date(from: "2026-10-25T16:00:00Z")!
        XCTAssertEqual(MagazineDay.today(now: instant), MagazineDay(key: "2026-10-26"))
    }

    func test_aDayIsWrittenInTheLanguageOfTheApp() {
        let day = MagazineDay(key: "2026-10-26")!
        XCTAssertEqual(day.formatted(.short, locale: Locale(identifier: "en")), "Oct 26")
        XCTAssertEqual(day.formatted(.short, locale: Locale(identifier: "ja")), "10月26日")
        XCTAssertTrue(day.formatted(.full, locale: Locale(identifier: "en")).contains("Monday"), "2026-10-26 is a Monday")
    }

    // MARK: Pages

    private func dto(_ items: [String], page: Int = 1, limit: Int = 20, total: Int) throws -> BJTMagazineListDTO {
        try JSONDecoder().decode(BJTMagazineListDTO.self, from: Data(MagazineFixtures.list(items, page: page, limit: limit, total: total).utf8))
    }

    func test_aPageKeepsTheKindsTheAppHasAndDropsLotteryAndUnknownOnes() throws {
        let page = MagazineInteractor.page(from: try dto([
            MagazineFixtures.listItem(slug: "v", kind: "magazine_vocab"),
            MagazineFixtures.listItem(slug: "l6", kind: "magazine_loto6"),
            MagazineFixtures.listItem(slug: "l7", kind: "magazine_loto7"),
            MagazineFixtures.listItem(slug: "l", kind: "magazine_loto"),
            MagazineFixtures.listItem(slug: "n", kind: "magazine_new_thing"),
            MagazineFixtures.listItem(slug: "w", kind: "magazine_weather"),
            MagazineFixtures.listItem(slug: "h", kind: "magazine_horoscope"),
            MagazineFixtures.listItem(slug: "b", kind: "magazine_bjt_phrase")
        ], total: 8), requestedPage: 1)
        XCTAssertEqual(page.items.map(\.slug), ["v", "w", "h", "b"])
        XCTAssertEqual(page.items.map(\.kind), [.vocabulary, .weather, .horoscope, .businessPhrase])
    }

    func test_morePagesFollowFromTheTotal() throws {
        XCTAssertTrue(MagazineInteractor.page(from: try dto([MagazineFixtures.listItem(slug: "a")], page: 1, limit: 20, total: 41), requestedPage: 1).hasMore)
        XCTAssertTrue(MagazineInteractor.page(from: try dto([MagazineFixtures.listItem(slug: "a")], page: 2, limit: 20, total: 41), requestedPage: 2).hasMore)
        XCTAssertFalse(MagazineInteractor.page(from: try dto([MagazineFixtures.listItem(slug: "a")], page: 3, limit: 20, total: 41), requestedPage: 3).hasMore)
        XCTAssertFalse(MagazineInteractor.page(from: try dto([MagazineFixtures.listItem(slug: "a")], page: 1, limit: 20, total: 20), requestedPage: 1).hasMore)
    }

    func test_aPageBeyondTheEndIsEmptyEvenThoughTheServerRepeatsTheLastPage() throws {
        // The server clamps page 99 to the last page; showing it again would repeat articles.
        let clamped = try dto([MagazineFixtures.listItem(slug: "last")], page: 3, limit: 20, total: 41)
        let page = MagazineInteractor.page(from: clamped, requestedPage: 4)
        XCTAssertTrue(page.items.isEmpty)
        XCTAssertFalse(page.hasMore)
    }

    func test_aRepeatedSlugAppearsOnce() throws {
        let page = MagazineInteractor.page(from: try dto([MagazineFixtures.listItem(slug: "a"), MagazineFixtures.listItem(slug: "a")], total: 2), requestedPage: 1)
        XCTAssertEqual(page.items.count, 1)
    }

    func test_aSummaryCarriesWhatTheRowShows() throws {
        let item = try XCTUnwrap(MagazineInteractor.page(from: try dto([MagazineFixtures.listItem(slug: "a", day: "2026-10-26", level: "N3", words: ["会議", "資料"])], total: 1), requestedPage: 1).items.first)
        XCTAssertEqual(item.titleJapanese, "題 a")
        XCTAssertEqual(item.titleVietnamese, "Tiêu đề a")
        XCTAssertEqual(item.level, "N3")
        XCTAssertEqual(item.day, MagazineDay(key: "2026-10-26"))
        XCTAssertEqual(item.words, ["会議", "資料"])
    }

    // MARK: Articles

    func test_aVocabularyArticleHasItsIntroductionWordsAndQuiz() throws {
        let article = try MagazineFixtures.article()
        XCTAssertEqual(article.kind, .vocabulary)
        XCTAssertEqual(article.blocks, [.passage(japanese: "6月から7月にかけて、日本は梅雨の季節を迎えます。", meaning: "Từ tháng 6 đến tháng 7, Nhật Bản bước vào mùa mưa.")])
        XCTAssertEqual(article.vocabulary.map(\.japanese), ["梅雨", "傘"])
        XCTAssertEqual(article.vocabulary.first?.reading, "つゆ")
        XCTAssertEqual(article.vocabulary.first?.example, "今年の梅雨は長引きそうです。")
        XCTAssertEqual(article.questions.count, 2)
    }

    func test_aPhraseArticleReadsInOrderPhraseDialogueUsageSituations() throws {
        let article = try MagazineFixtures.article(MagazineFixtures.phraseArticle)
        XCTAssertEqual(article.blocks.count, 4)
        XCTAssertEqual(article.blocks[0], .phrase(japanese: "お疲れ様です", reading: "おつかれさまです", literalMeaning: "Bạn đã vất vả rồi", formality: .polite))
        XCTAssertEqual(article.blocks[1], .dialogue([
            MagazineArticle.DialogueLine(speaker: "田中", japanese: "お疲れ様です。", meaning: "Chào anh."),
            MagazineArticle.DialogueLine(speaker: "山田", japanese: "お疲れ様です。はい。", meaning: nil)]))
        XCTAssertEqual(article.blocks[2], .usage(japanese: "万能な挨拶表現。", meaning: "Lời chào đa năng."))
        XCTAssertEqual(article.blocks[3], .situations([
            MagazineArticle.Situation(japanese: "会議の終わりに", meaning: "Cuối buổi họp"),
            MagazineArticle.Situation(japanese: "メールの冒頭", meaning: nil)]), "A missing translation stays missing instead of shifting the others")
    }

    func test_aWeatherArticleRoundsItsNumbersAndPicksASymbol() throws {
        let article = try MagazineFixtures.article(MagazineFixtures.weatherArticle)
        guard case .weather(let weather)? = article.blocks.first else { return XCTFail("no weather block") }
        XCTAssertEqual(weather.city, "東京")
        XCTAssertEqual(weather.descriptionJapanese, "曇り時々雨")
        XCTAssertEqual(weather.highC, 28)
        XCTAssertEqual(weather.lowC, 22, "21.6 rounds to 22")
        XCTAssertEqual(weather.humidityPercent, 85)
        XCTAssertEqual(weather.uvIndex, 3)
        XCTAssertEqual(weather.symbol, "cloud.drizzle.fill")
        XCTAssertEqual(weather.adviceJapanese, "傘を持って出かけましょう。")
    }

    func test_aHoroscopeSkipsAnEntryWithoutASignAndReadsTheGeneratorsKeys() throws {
        let article = try MagazineFixtures.article(MagazineFixtures.horoscopeArticle)
        guard case .horoscope(let fortunes)? = article.blocks.first else { return XCTFail("no horoscope block") }
        XCTAssertEqual(fortunes.count, 1)
        XCTAssertEqual(fortunes[0].sign, "牡羊座")
        XCTAssertEqual(fortunes[0].fortune, "大吉")
        XCTAssertEqual(fortunes[0].fortuneMeaning, "Đại cát")
        XCTAssertEqual(fortunes[0].luckyNumber, 7)
    }

    func test_paragraphsAreReadAsPairsWithTheirTranslations() throws {
        let json = #"{"id":"a","slug":"s","widgetKind":"magazine_vocab","titleJp":"題","titleVi":"v","contentJson":{"paragraphsJp":["一つ目。","二つ目。"],"paragraphsVi":["Một."]}}"#
        let blocks = try MagazineFixtures.article(json).blocks
        XCTAssertEqual(blocks, [.passage(japanese: "一つ目。", meaning: "Một."), .passage(japanese: "二つ目。", meaning: nil)])
    }

    func test_aQuestionNeedsTwoChoicesAndExactlyOneRightAnswer() throws {
        let json = #"""
        {"id":"a","slug":"s","widgetKind":"magazine_vocab","titleJp":"題","titleVi":"v","quizzes":[
         {"questionJp":"二つ正解","options":[{"label":"a","isCorrect":true},{"label":"b","isCorrect":true}]},
         {"questionJp":"正解なし","options":[{"label":"a","isCorrect":false},{"label":"b","isCorrect":false}]},
         {"questionJp":"一つだけ","options":[{"label":"a","isCorrect":true}]},
         {"questionJp":"良い","options":[{"label":"a","isCorrect":false},{"label":" ","isCorrect":true},{"label":"c","isCorrect":true}]}]}
        """#
        XCTAssertEqual(try MagazineFixtures.article(json).questions.map(\.promptJapanese), ["良い"], "A blank option is not a choice")
    }

    func test_anArticleOfAKindTheAppDoesNotHaveIsRejected() throws {
        let json = #"{"id":"a","slug":"s","widgetKind":"magazine_loto6","titleJp":"題","titleVi":"v"}"#
        XCTAssertThrowsError(try MagazineFixtures.article(json)) { XCTAssertEqual($0 as? LearnerAPIError, .invalidResponse) }
        let blank = #"{"id":"a","slug":"s","widgetKind":"magazine_vocab","titleJp":"  ","titleVi":"v"}"#
        XCTAssertThrowsError(try MagazineFixtures.article(blank))
    }

    func test_aWordWithoutAnIdGetsAStableOneFromItsArticleAndPosition() throws {
        let json = #"{"id":"a","slug":"my-slug","widgetKind":"magazine_vocab","titleJp":"題","titleVi":"v","vocabItems":[{"wordJp":"傘","meaningVi":"ô"},{"wordJp":"雨","meaningVi":"mưa"}]}"#
        XCTAssertEqual(try MagazineFixtures.article(json).vocabulary.map(\.id), ["my-slug-0", "my-slug-1"])
    }

    func test_theWeatherSymbolFollowsTheGeneratorsIconName() {
        let expected = ["sunny": "sun.max.fill", "clear": "sun.max.fill", "cloudy": "cloud.fill", "partly_cloudy": "cloud.sun.fill", "rain": "cloud.rain.fill",
                        "cloudy_rain": "cloud.drizzle.fill", "snow": "cloud.snow.fill", "thunderstorm": "cloud.bolt.rain.fill", "fog": "cloud.fog.fill",
                        "windy": "wind", "something_new": "cloud.sun.fill"]
        for (icon, symbol) in expected { XCTAssertEqual(MagazineInteractor.weatherSymbol(icon), symbol, icon) }
        XCTAssertEqual(MagazineInteractor.weatherSymbol(nil), "cloud.sun.fill")
    }

    func test_anImplausibleTemperatureIsLeftOutInsteadOfTrapping() throws {
        let json = #"{"id":"a","slug":"s","widgetKind":"magazine_weather","titleJp":"題","titleVi":"v","contentJson":{"description":"晴れ","highTemp":1e300,"lowTemp":-5}}"#
        guard case .weather(let weather)? = try MagazineFixtures.article(json).blocks.first else { return XCTFail("no weather block") }
        XCTAssertNil(weather.highC)
        XCTAssertEqual(weather.lowC, -5)
    }

    // MARK: Loading through the API

    func test_loadingAPageAsksForTheKindAndMapsIt() throws {
        let api = FakeMagazineAPI()
        api.listResult = { _, _ in .just(try! JSONDecoder().decode(BJTMagazineListDTO.self, from: Data(MagazineFixtures.list([MagazineFixtures.listItem(slug: "a")], total: 1).utf8))) }
        let interactor = MagazineInteractor(api: api)
        var loaded: MagazinePage?
        _ = interactor.loadPage(kind: .weather, page: 1).subscribe(onSuccess: { loaded = $0 })
        let page = try XCTUnwrap(loaded)
        XCTAssertEqual(page.items.map(\.slug), ["a"])
        XCTAssertEqual(api.listCalls.first?.kind, .weather)
        XCTAssertEqual(api.listCalls.first?.limit, MagazineInteractor.pageSize)
    }

    // MARK: Saving words

    private var realm: Realm!
    private var decks: DeskManagement!
    private var interactor: MagazineInteractor!

    private func prepareRealm() throws {
        realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: "magazine-\(UUID().uuidString)", objectTypes: RealmService.storedTypes))
        RealmService.shared.realm = realm
        decks = DeskManagement()
        interactor = MagazineInteractor(api: FakeMagazineAPI(), decks: decks, cards: CardManagement.shared)
    }

    override func tearDownWithError() throws {
        RealmService.shared.realm = nil
        realm = nil
    }

    private func words(_ ids: String...) throws -> [MagazineArticle.Vocabulary] {
        try MagazineFixtures.article().vocabulary.filter { ids.contains($0.id) }
    }

    func test_theFirstSaveCreatesTheMagazineDeckWithTheWordsAsCards() throws {
        try prepareRealm()
        let outcome = try interactor.saveVocabulary(try words("v1", "v2"), target: .newMagazineDeck)

        XCTAssertEqual(outcome.deckID, "magazine")
        XCTAssertEqual(outcome.added, ["v1", "v2"])
        let deck = try XCTUnwrap(decks.desk(withId: "magazine"))
        XCTAssertEqual(deck.name, NSLocalizedString("Magazine", comment: ""))
        XCTAssertEqual(deck.cards.map(\.id), ["magazine:magazine:v1", "magazine:magazine:v2"])
        let first = try XCTUnwrap(deck.cards.first)
        XCTAssertEqual(first.frontText, "梅雨")
        XCTAssertEqual(first.frontExtraText, "つゆ")
        XCTAssertEqual(first.backText, "Mùa mưa")
        XCTAssertEqual(first.backExtraText, "今年の梅雨は長引きそうです。")
    }

    func test_savingTheSameWordsAgainWritesNothing() throws {
        try prepareRealm()
        let first = try interactor.saveVocabulary(try words("v1", "v2"), target: .newMagazineDeck)
        let second = try interactor.saveVocabulary(try words("v1", "v2"), target: .newMagazineDeck)

        XCTAssertTrue(second.added.isEmpty)
        XCTAssertEqual(second.alreadyPresent, ["v1", "v2"])
        XCTAssertEqual(second.cardIDs, first.cardIDs)
        XCTAssertEqual(realm.objects(RCard.self).count, 2)
    }

    func test_aWordAlreadyOnACardOfTheDeckIsNotAddedUnderAnotherId() throws {
        try prepareRealm()
        let deck = DeskEntity()
        deck.id = "mine"
        deck.name = "My words"
        let card = CardEntity()
        card.id = "own-card"
        card.frontText = "傘"
        card.backText = "ô"
        deck.cards = [card]
        try decks.add(deck)

        let outcome = try interactor.saveVocabulary(try words("v1", "v2"), target: .existing(deckID: "mine"))

        XCTAssertEqual(outcome.added, ["v1"])
        XCTAssertEqual(outcome.alreadyPresent, ["v2"])
        XCTAssertEqual(outcome.cardIDs, ["magazine:mine:v1", "own-card"])
        XCTAssertEqual(decks.desk(withId: "mine")?.cards.count, 2)
    }

    func test_theSameWordTwiceInOneSaveIsOneCard() throws {
        try prepareRealm()
        let outcome = try interactor.saveVocabulary(try words("v1") + words("v1"), target: .newMagazineDeck)
        XCTAssertEqual(outcome.added, ["v1"])
        XCTAssertEqual(realm.objects(RCard.self).count, 1)
    }

    func test_savingIntoADeckThatIsGoneStoresNothingAndSaysSo() throws {
        try prepareRealm()
        XCTAssertThrowsError(try interactor.saveVocabulary(try words("v1"), target: .existing(deckID: "missing"))) { error in
            guard let appError = error as? FlashcardApp.AppError, case .entityNotFound = appError else { return XCTFail("unexpected \(error)") }
        }
        XCTAssertEqual(realm.objects(RCard.self).count, 0)
        XCTAssertNil(decks.desk(withId: "magazine"))
    }

    func test_theChooserKnowsWhetherTheMagazineDeckExists() throws {
        try prepareRealm()
        XCTAssertFalse(interactor.magazineDeckExists())
        _ = try interactor.saveVocabulary(try words("v1"), target: .newMagazineDeck)
        XCTAssertTrue(interactor.magazineDeckExists())
        XCTAssertEqual(interactor.deckChoices().map(\.id), ["magazine"])
        XCTAssertEqual(interactor.deckChoices().first?.cardCount, 1)
    }
}
