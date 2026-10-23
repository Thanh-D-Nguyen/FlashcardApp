import RxSwift
import XCTest
@testable import FlashcardApp

/// How the server's dictionary answers become the suggestion list.
final class DictionarySuggestionTests: XCTestCase {
    private var online: StubOnline!
    private var interactor: DictionarySuggestionInteractor!
    private var bag: DisposeBag!

    override func setUp() {
        super.setUp()
        online = StubOnline()
        interactor = DictionarySuggestionInteractor(online: online)
        bag = DisposeBag()
    }

    private func dto(_ title: String, _ reading: String?, _ meaning: String?, kind: String = "lexeme", level: String? = nil) -> BJTSearchResultDTO {
        BJTSearchResultDTO(id: UUID().uuidString, kind: kind, title: title, description: meaning, reading: reading, jlptLevel: level)
    }

    private func collect(_ query: SuggestionQuery) -> [SuggestionsState] {
        var states: [SuggestionsState] = []
        interactor.suggestions(for: query).subscribe(onNext: { states.append($0) }).disposed(by: bag)
        return states
    }

    private let japanese = SuggestionQuery("食べ")!

    // MARK: Query shaping

    func test_onlyWorthwhileTextBecomesAQuery() {
        XCTAssertNotNil(SuggestionQuery("犬"))
        XCTAssertNotNil(SuggestionQuery("  ăn "))
        XCTAssertNil(SuggestionQuery(""))
        XCTAssertNil(SuggestionQuery("   "))
        XCTAssertNil(SuggestionQuery("a"))
        XCTAssertNil(SuggestionQuery(String(repeating: "日", count: SuggestionQuery.maximumLength + 1)))
        XCTAssertEqual(SuggestionQuery(" 食べ ")?.text, "食べ")
    }

    func test_scriptDetection() {
        XCTAssertTrue(JapaneseText.containsJapanese("たべる"))
        XCTAssertTrue(JapaneseText.containsJapanese("コーヒー"))
        XCTAssertTrue(JapaneseText.containsJapanese("ăn 食"))
        XCTAssertFalse(JapaneseText.containsJapanese("ăn cơm"))
        XCTAssertFalse(JapaneseText.containsJapanese("hello"))
        XCTAssertEqual(JapaneseText.folded("Đã Ăn"), "da an")
        XCTAssertEqual(JapaneseText.firstGloss(of: "ăn; dùng bữa, ăn uống"), "ăn")
        XCTAssertEqual(JapaneseText.firstGloss(of: "  "), "")
    }

    // MARK: Ranking

    func test_searchingIsAnnouncedFirstThenTheRankedResult() {
        online.result = .just([dto("食べ物", "たべもの", "thức ăn", level: "N5"), dto("食べる", "たべる", "ăn", level: "N5")])
        let states = collect(japanese)
        XCTAssertEqual(states.count, 2)
        XCTAssertEqual(states[0], .searching)
        guard case .results(let ranked) = states[1] else { return XCTFail("\(states[1])") }
        XCTAssertEqual(ranked.map(\.japanese), ["食べ物", "食べる"], "Equal ranks keep the server's order")
        XCTAssertEqual(ranked[0].jlptLevel, "N5")
    }

    func test_theSameWordIsListedOnce() {
        online.result = .just([dto("食べる", "たべる", "ăn"), dto("食べる", "たべる", "dùng bữa")])
        guard case .results(let ranked) = collect(japanese).last else { return XCTFail() }
        XCTAssertEqual(ranked.map(\.vietnamese), ["ăn"])
    }

    func test_typoToleranceNoiseFromTheServerIsDropped() {
        online.result = .just([dto("イベント駆動", "イベントくどう", "hướng sự kiện"), dto("食べ滓", "たべかす", "thức ăn thừa")])
        let states = collect(japanese)
        guard case .results(let merged) = states.last else { return XCTFail("\(String(describing: states.last))") }
        XCTAssertEqual(merged.map(\.japanese), ["食べ滓"])
    }

    func test_vietnameseQueriesMatchTheMeaningIgnoringToneMarks() {
        online.result = .just([dto("食べる", "たべる", "ăn; dùng bữa"), dto("庭", "にわ", "vườn")])
        let states = collect(SuggestionQuery("an")!)
        guard case .results(let merged) = states.last else { return XCTFail() }
        XCTAssertEqual(merged.map(\.japanese), ["食べる"])
        XCTAssertFalse(merged[0].typedJapanese)
    }

    func test_entriesWithoutAMeaningOrOfAnotherKindAreSkipped() {
        online.result = .just([dto("食べる", "たべる", nil), dto("食べる", "たべる", "  "), dto("食", "しょく", "ăn", kind: "kanji"), dto("食べる", "たべる", "ăn")])
        let states = collect(japanese)
        guard case .results(let merged) = states.last else { return XCTFail() }
        XCTAssertEqual(merged.count, 1)
    }

    func test_exactMatchesRankAboveLongerWords() {
        let query = SuggestionQuery("食")!
        online.result = .just([dto("食堂", "しょくどう", "nhà ăn"), dto("食", "しょく", "ăn"), dto("朝食", "ちょうしょく", "bữa sáng")])
        guard case .results(let merged) = collect(query).last else { return XCTFail() }
        XCTAssertEqual(merged.map(\.japanese), ["食", "食堂", "朝食"])
    }

    func test_theListIsCapped() {
        online.result = .just((0..<40).map { dto("食べ\($0)", "たべ", "ăn \($0)") })
        guard case .results(let merged) = collect(japanese).last else { return XCTFail() }
        XCTAssertEqual(merged.count, DictionarySuggestionInteractor.limit)
    }

    // MARK: Failure and emptiness

    func test_noMatchAnywhereIsEmptyNotAnError() {
        online.result = .just([])
        XCTAssertEqual(collect(japanese).last, .empty)
    }

    func test_noConnectionIsReportedAsUnavailableNotAsNoMatch() {
        online.result = .error(LearnerAPIError.offline)
        XCTAssertEqual(collect(japanese), [.searching, .unavailable])
    }

    func test_aServerFailureIsReportedAsUnavailable() {
        online.result = .error(AppError.invalidInput("x"))
        XCTAssertEqual(collect(japanese).last, .unavailable)
    }

    func test_disposingTheSubscriptionCancelsTheOnlineLookup() {
        let subject = PublishSubject<[BJTSearchResultDTO]>()
        var cancelled = false
        online.result = subject.asSingle().do(onDispose: { cancelled = true })
        let subscription = interactor.suggestions(for: japanese).subscribe()
        subscription.dispose()
        XCTAssertTrue(cancelled)
    }

    func test_theOnlineLookupAsksForAFewMoreEntriesThanItShows() {
        online.result = .just([])
        _ = collect(japanese)
        XCTAssertEqual(online.lookups.map(\.text), ["食べ"])
        XCTAssertEqual(online.lookups.first?.limit, 20)
    }
}

private final class StubOnline: OnlineDictionaryInterface {
    var result: Single<[BJTSearchResultDTO]> = .just([])
    var lookups: [(text: String, limit: Int)] = []
    func lookup(_ text: String, limit: Int) -> Single<[BJTSearchResultDTO]> {
        lookups.append((text, limit))
        return result
    }
}
