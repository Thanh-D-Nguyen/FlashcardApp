import RxRelay
import RxSwift
import XCTest
@testable import FlashcardApp

final class DictionaryPresenterTests: XCTestCase {
    private var interactor: SearchInteractorStub!
    private var wireframe: SearchWireframeStub!
    private var presenter: DictionaryPresenter!

    override func setUp() {
        super.setUp()
        interactor = SearchInteractorStub()
        wireframe = SearchWireframeStub()
        presenter = DictionaryPresenter(interactor: interactor, wireframe: wireframe, debounce: .milliseconds(1))
    }

    private func waitForRequest(count: Int = 1, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(3)
        while interactor.calls.count < count, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
        XCTAssertGreaterThanOrEqual(interactor.calls.count, count, "the request was never made", file: file, line: line)
    }

    private func row(_ id: String, _ title: String, kind: String = "lexeme") -> BJTSearchResultDTO {
        BJTSearchResultDTO(id: id, kind: kind, title: title, description: "ăn", reading: "たべる", jlptLevel: "N5")
    }

    // MARK: Query handling

    func testEmptyTextReturnsToTheHomeAndCancelsTheRequest() {
        presenter.searchText("日本", withType: 0)
        waitForRequest()
        XCTAssertEqual(presenter.state.value, .loading)
        presenter.searchText("", withType: 0)
        XCTAssertTrue(interactor.cancelled)
        interactor.complete?(.success([row("a", "日本")]))
        XCTAssertEqual(presenter.state.value, .idle)
    }

    func testALateResultOfAnOlderQueryNeverReplacesTheNewerOne() {
        presenter.searchText("古い", withType: 0)
        waitForRequest()
        let stale = interactor.complete
        presenter.searchText("新しい", withType: 0)
        waitForRequest(count: 2)
        stale?(.success([row("old", "古い")]))
        XCTAssertEqual(presenter.state.value, .loading, "The answer to the old query is ignored")
        interactor.complete?(.success([row("new", "新しい")]))
        guard case .results(let results) = presenter.state.value else { return XCTFail("expected results") }
        XCTAssertEqual(results.items.map(\.id), ["new"])
    }

    func testTheLatestQueryAndScopeReachTheInteractorOnce() {
        presenter.searchText("古い", withType: 0)
        presenter.searchText(" 日本 ", withType: 1)
        waitForRequest()
        XCTAssertEqual(interactor.calls.count, 1)
        XCTAssertEqual(interactor.calls.first?.query, "日本")
        XCTAssertEqual(interactor.calls.first?.type, .kanji)
        XCTAssertEqual(interactor.calls.first?.offset, 0)
    }

    func testTheSameQueryAndScopeIsNotRequestedAgain() {
        presenter.searchText("日本", withType: 0)
        waitForRequest()
        interactor.complete?(.success([row("a", "日本")]))
        presenter.searchText("日本", withType: 0)
        presenter.searchText("  日本 ", withType: 0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(interactor.calls.count, 1, "UISearchController repeats the same text when it gains focus")
    }

    func testChangingTheScopeSearchesAgainWithoutWaiting() {
        presenter.searchText("日本", withType: 0)
        waitForRequest()
        interactor.complete?(.success([]))
        presenter.searchText("日本", withType: 2)
        waitForRequest(count: 2)
        XCTAssertEqual(interactor.calls.last?.type, .grammar)
    }

    func testASingleLatinLetterAsksForMoreTextWithoutARequest() {
        presenter.searchText("a", withType: 0)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(presenter.state.value, .tooShort)
        XCTAssertTrue(interactor.calls.isEmpty)
    }

    func testSpacesAroundAndInsideTheQueryAreNormalisedBeforeSending() {
        presenter.searchText("  ăn \n cơm ", withType: 0)
        waitForRequest()
        XCTAssertEqual(interactor.calls.first?.query, "ăn cơm")
    }

    // MARK: Results

    func testResultsKeepTheServerOrderAndDropKindsTheAppHasNoScreenFor() {
        presenter.searchText("食べる", withType: 0)
        waitForRequest()
        interactor.complete?(.success([row("2", "食べる"), row("lesson", "Bài", kind: "lesson"), row("1", "食べ物")]))
        guard case .results(let results) = presenter.state.value else { return XCTFail("expected results") }
        XCTAssertEqual(results.items.map(\.id), ["2", "1"], "No client-side re-ranking")
    }

    func testNoRowsIsAnEmptyAnswerNotAnError() {
        presenter.searchText("zzzz", withType: 0)
        waitForRequest()
        interactor.complete?(.success([]))
        XCTAssertEqual(presenter.state.value, .empty("zzzz"))
    }

    func testAFailureShowsItsMessageAndRetryAsksAgainWithTheSameQuery() {
        presenter.searchText("日本", withType: 0)
        waitForRequest()
        interactor.complete?(.failure(LearnerAPIError.offline))
        guard case .error(let message) = presenter.state.value else { return XCTFail("error must be visible") }
        XCTAssertEqual(message, LearnerAPIError.offline.errorDescription)
        presenter.retry()
        waitForRequest(count: 2)
        XCTAssertEqual(presenter.state.value, .loading)
        interactor.complete?(.success([row("a", "日本")]))
        guard case .results = presenter.state.value else { return XCTFail("recovered") }
    }

    func testTypingTheSameTextAgainAfterAFailureRetries() {
        presenter.searchText("日本", withType: 0)
        waitForRequest()
        interactor.complete?(.failure(LearnerAPIError.offline))
        presenter.searchText("日本", withType: 0)
        waitForRequest(count: 2)
    }

    func testRomajiQueriesOfferTheKanaReadingWithoutChangingTheSearch() {
        presenter.searchText("taberu", withType: 0)
        waitForRequest()
        XCTAssertEqual(interactor.calls.first?.query, "taberu")
        interactor.complete?(.success([row("a", "Tabernaemontana属")]))
        guard case .results(let results) = presenter.state.value else { return XCTFail("expected results") }
        XCTAssertEqual(results.kanaCandidate, "たべる")
    }

    // MARK: Paging

    func testScrollingToTheEndLoadsTheNextPageAfterTheRowsAlreadyShown() {
        presenter.searchText("食べる", withType: 0)
        waitForRequest()
        let page = (0..<DictionaryPresenter.pageSize).map { row("id\($0)", "食べる\($0)") }
        interactor.complete?(.success(page))
        guard case .results(let first) = presenter.state.value else { return XCTFail() }
        XCTAssertTrue(first.hasMore)

        presenter.loadMore()
        waitForRequest(count: 2)
        XCTAssertEqual(interactor.calls.last?.offset, DictionaryPresenter.pageSize)
        guard case .results(let loading) = presenter.state.value else { return XCTFail() }
        XCTAssertTrue(loading.isLoadingMore)
        interactor.complete?(.success([row("last", "食べ終わる")]))
        guard case .results(let all) = presenter.state.value else { return XCTFail() }
        XCTAssertEqual(all.items.count, DictionaryPresenter.pageSize + 1)
        XCTAssertFalse(all.hasMore, "A short page is the end")
        XCTAssertFalse(all.isLoadingMore)
    }

    func testLoadMoreIsIgnoredWhileOneIsRunningOrWhenThereIsNothingMore() {
        presenter.searchText("食べる", withType: 0)
        waitForRequest()
        interactor.complete?(.success([row("only", "食べる")]))
        presenter.loadMore()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(interactor.calls.count, 1, "A short first page has no next page")
    }

    func testANewQueryDropsAPageStillLoadingForTheOldOne() {
        presenter.searchText("食べる", withType: 0)
        waitForRequest()
        interactor.complete?(.success((0..<DictionaryPresenter.pageSize).map { row("id\($0)", "食べる\($0)") }))
        presenter.loadMore()
        waitForRequest(count: 2)
        let latePage = interactor.complete
        presenter.searchText("飲む", withType: 0)
        waitForRequest(count: 3)
        latePage?(.success([row("late", "遅い")]))
        XCTAssertEqual(presenter.state.value, .loading)
    }

    func testAFailedNextPageKeepsTheRowsAndCanBeRetried() {
        presenter.searchText("食べる", withType: 0)
        waitForRequest()
        interactor.complete?(.success((0..<DictionaryPresenter.pageSize).map { row("id\($0)", "食べる\($0)") }))
        presenter.loadMore()
        waitForRequest(count: 2)
        interactor.complete?(.failure(LearnerAPIError.offline))
        guard case .results(let results) = presenter.state.value else { return XCTFail("rows must stay") }
        XCTAssertEqual(results.items.count, DictionaryPresenter.pageSize)
        XCTAssertTrue(results.loadMoreFailed)
        presenter.loadMore()
        waitForRequest(count: 3)
    }

    func testRetryAndPagingWorkAfterASearchStartedByAProgrammaticTextAndScope() {
        // Recent-search taps, scans, voice and "look up" set the text and call the scope path directly.
        presenter.searchText("食べる", scopeChangedTo: 0)
        waitForRequest()
        interactor.complete?(.failure(LearnerAPIError.offline))
        presenter.retry()
        waitForRequest(count: 2)
        XCTAssertEqual(interactor.calls.last?.query, "食べる", "Retry must repeat the search that failed")
        interactor.complete?(.success((0..<DictionaryPresenter.pageSize).map { row("id\($0)", "食べる\($0)") }))
        presenter.loadMore()
        waitForRequest(count: 3)
        XCTAssertEqual(interactor.calls.last?.offset, DictionaryPresenter.pageSize, "…and the next page can be asked for")
    }

    // MARK: History and navigation

    func testOpeningAResultRemembersTheQueryAndRoutesThroughTheWireframe() {
        presenter.searchText("食べる", withType: 0)
        waitForRequest()
        let item = DictionaryItem(kind: .vocabulary, id: "u", title: "食べる")
        interactor.complete?(.success([row("u", "食べる")]))
        presenter.select(item)
        XCTAssertEqual(wireframe.shown, [item])
        XCTAssertEqual(interactor.recordedQueries, ["食べる"])
    }

    func testKeyboardSearchRemembersTheQuery() {
        presenter.searchText("日本語", withType: 0)
        presenter.commit("日本語")
        XCTAssertEqual(interactor.recordedQueries, ["日本語"])
    }

    func testHomeListsHistoryAndDeletingOneItemRefreshesIt() {
        interactor.queries = ["a1", "b2"]
        interactor.items = [DictionaryItem(kind: .vocabulary, id: "u", title: "猫")]
        presenter.refreshHome()
        XCTAssertEqual(presenter.home.value.queries, ["a1", "b2"])
        XCTAssertEqual(presenter.home.value.items.map(\.title), ["猫"])
        presenter.deleteRecentQuery("a1")
        XCTAssertEqual(presenter.home.value.queries, ["b2"])
        presenter.clearRecentQueries()
        XCTAssertTrue(presenter.home.value.queries.isEmpty)
        presenter.clearViewedItems()
        XCTAssertTrue(presenter.home.value.items.isEmpty)
    }

    func testBeginSearchAsksTheScreenToShowTheTextAndSearches() {
        var requested: [String] = []
        let bag = DisposeBag()
        presenter.requestedQuery.subscribe(onNext: { requested.append($0) }).disposed(by: bag)
        presenter.beginSearch("  食べる ")
        XCTAssertEqual(requested, ["食べる"])
    }
}

private final class SearchInteractorStub: DictionaryInteractorInterface {
    struct Call { let query: String; let type: DictionarySearchType; let offset: Int }
    var calls: [Call] = []
    var complete: ((SingleEvent<[BJTSearchResultDTO]>) -> Void)?
    var cancelled = false
    var queries: [String] = []
    var items: [DictionaryItem] = []
    var recordedQueries: [String] = []

    func search(_ query: String, type: DictionarySearchType, offset: Int) -> Single<[BJTSearchResultDTO]> {
        calls.append(Call(query: query, type: type, offset: offset))
        return Single.create { observer in
            self.complete = observer
            return Disposables.create { self.cancelled = true }
        }
    }

    var recentQueries: [String] { queries }
    var recentItems: [DictionaryItem] { items }
    func recordQuery(_ query: String) { recordedQueries.append(query) }
    func removeQuery(_ query: String) { queries.removeAll { $0 == query } }
    func clearQueries() { queries = [] }
    func removeItem(_ item: DictionaryItem) { items.removeAll { $0 == item } }
    func clearItems() { items = [] }
}

private final class SearchWireframeStub: DictionaryWireframeInterface {
    var shown: [DictionaryItem] = []
    func showEntry(_ item: DictionaryItem) { shown.append(item) }
    func showSaved() {}
    func showScanner() {}
    func showVoice() {}
    func showHandwriting() {}
}
