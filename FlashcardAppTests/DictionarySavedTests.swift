import RxRelay
import RxSwift
import XCTest
@testable import FlashcardApp

final class DictionarySavedInteractorTests: XCTestCase {
    private let a = "11111111-1111-4111-8111-111111111111"
    private let b = "22222222-2222-4222-8222-222222222222"
    private let c = "33333333-3333-4333-8333-333333333333"
    private var bookmarks: FakeBookmarkAPI!
    private var api: FakeDictionaryAPI!
    private var interactor: DictionarySavedInteractor!
    private var bag = DisposeBag()

    override func setUp() {
        super.setUp()
        bookmarks = FakeBookmarkAPI()
        api = FakeDictionaryAPI()
        interactor = DictionarySavedInteractor(bookmarks: bookmarks, api: api, signedIn: { true })
        bag = DisposeBag()
    }

    private func value<T>(_ single: Single<T>) throws -> T {
        var outcome: Result<T, Error>?
        single.subscribe(onSuccess: { outcome = .success($0) }, onFailure: { outcome = .failure($0) }).disposed(by: bag)
        let deadline = Date().addingTimeInterval(3)
        while outcome == nil, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
        return try XCTUnwrap(outcome).get()
    }

    func testIdsComeNewestFirstWithoutDuplicates() throws {
        bookmarks.rows = [a, b, a].map { BJTBookmarkDTO(id: "x\($0)", targetId: $0, type: "lexeme", createdAt: nil) }
        XCTAssertEqual(try value(interactor.savedIDs(.vocabulary)), [a, b])
        XCTAssertEqual(bookmarks.listLimits, [100])
    }

    func testIdsAreResolvedToEntriesInTheServersOrderAndMissingOnesAreCounted() throws {
        api.lexemes = [a: BJTLexemeDetailDTO(id: a, headword: "猫", reading: "ねこ", jlptLevel: "N5", shortMeaningVi: "mèo"),
                       c: BJTLexemeDetailDTO(id: c, headword: "犬", reading: "いぬ", shortMeaningVi: "chó")]
        let page = try value(interactor.resolve([a, b, c], kind: .vocabulary))
        XCTAssertEqual(page.items.map(\.title), ["猫", "犬"])
        XCTAssertEqual(page.items.map(\.id), [a, c], "Backend ids are kept")
        XCTAssertEqual(page.missing, 1, "b is no longer in the dictionary")
    }

    func testARealFailureFailsThePageInsteadOfLookingLikeFewerSavedWords() {
        api.lexemeError = LearnerAPIError.offline
        XCTAssertThrowsError(try value(interactor.resolve([a], kind: .vocabulary))) {
            XCTAssertEqual($0 as? LearnerAPIError, .offline)
        }
    }

    func testRemovingReadsTheStateFirstSoAnAlreadyRemovedEntryIsNotAddedBack() throws {
        let item = DictionaryItem(kind: .vocabulary, id: a, title: "猫")
        bookmarks.checkResult = false
        _ = try value(interactor.remove(item))
        XCTAssertTrue(bookmarks.toggled.isEmpty, "A toggle now would bookmark it again")
        bookmarks.checkResult = true
        _ = try value(interactor.remove(item))
        XCTAssertEqual(bookmarks.toggled.count, 1)
    }
}

final class DictionarySavedPresenterTests: XCTestCase {
    private var interactor: FakeSavedInteractor!
    private var wireframe: FakeSavedWireframe!
    private var presenter: DictionarySavedPresenter!

    override func setUp() {
        super.setUp()
        interactor = FakeSavedInteractor()
        wireframe = FakeSavedWireframe()
        presenter = DictionarySavedPresenter(interactor: interactor, wireframe: wireframe)
    }

    private func pump() { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
    private func item(_ n: Int, kind: DictionaryItemKind = .vocabulary) -> DictionaryItem { DictionaryItem(kind: kind, id: "id\(n)", title: "語\(n)") }

    func testAGuestIsAskedToSignInAndNothingIsRequested() {
        interactor.signedIn = false
        presenter.viewWillAppear()
        XCTAssertEqual(presenter.state.value, .signedOut)
        XCTAssertTrue(interactor.idCalls.isEmpty)
        presenter.signIn()
        XCTAssertEqual(wireframe.signIns, 1)
    }

    func testTheFirstPageIsResolvedAndTheRestWaits() {
        interactor.ids = (0..<45).map { "id\($0)" }
        presenter.viewWillAppear()
        pump()
        guard case .loaded(let list) = presenter.state.value else { return XCTFail("expected a list") }
        XCTAssertEqual(list.items.count, DictionarySavedPresenter.pageSize)
        XCTAssertEqual(list.pendingIDs.count, 15)
        presenter.loadMore()
        pump()
        guard case .loaded(let all) = presenter.state.value else { return XCTFail() }
        XCTAssertEqual(all.items.count, 45)
        XCTAssertTrue(all.pendingIDs.isEmpty)
        XCTAssertEqual(interactor.resolveCalls.map(\.count), [30, 15])
    }

    func testNothingSavedIsAnEmptyStateAndChangingTheCategoryAsksForThatKind() {
        presenter.viewWillAppear()
        pump()
        XCTAssertEqual(presenter.state.value, .empty)
        presenter.selectKind(1)
        pump()
        XCTAssertEqual(interactor.idCalls.last, .kanji)
        XCTAssertEqual(presenter.kind, .kanji)
        presenter.selectKind(1)
        XCTAssertEqual(interactor.idCalls.count, 2, "The category that is already shown is not reloaded")
    }

    func testAFailureCanBeRetriedAndARefreshFailureKeepsTheRowsShown() {
        interactor.idsError = LearnerAPIError.offline
        presenter.viewWillAppear()
        pump()
        XCTAssertEqual(presenter.state.value, .error(LearnerAPIError.offline.errorDescription!))
        interactor.idsError = nil
        interactor.ids = ["id1"]
        presenter.retry()
        pump()
        guard case .loaded = presenter.state.value else { return XCTFail("recovered") }
        interactor.idsError = LearnerAPIError.offline
        presenter.viewWillAppear()
        pump()
        guard case .loaded = presenter.state.value else { return XCTFail("a quiet refresh failure must not blank the list") }
    }

    func testAnExpiredSessionBecomesSignedOut() {
        interactor.idsError = LearnerAPIError.signInRequired
        presenter.viewWillAppear()
        pump()
        XCTAssertEqual(presenter.state.value, .signedOut)
    }

    func testRemovingTakesTheRowOutAndTheLastRowMakesItEmpty() {
        interactor.ids = ["id1", "id2"]
        presenter.viewWillAppear()
        pump()
        presenter.remove(item(1))
        pump()
        guard case .loaded(let list) = presenter.state.value else { return XCTFail() }
        XCTAssertEqual(list.items.map(\.id), ["id2"])
        presenter.remove(item(2))
        pump()
        XCTAssertEqual(presenter.state.value, .empty)
        XCTAssertEqual(interactor.removed.map(\.id), ["id1", "id2"])
    }

    func testASecondRemoveOfTheSameRowWhileTheFirstRunsIsIgnored() {
        interactor.ids = ["id1"]
        presenter.viewWillAppear()
        pump()
        let pending = PublishSubject<Void>()
        interactor.removeResult = pending.asSingle()
        presenter.remove(item(1))
        presenter.remove(item(1))
        XCTAssertEqual(interactor.removed.count, 1, "A second toggle would add the bookmark back")
        pending.onNext(())
        pending.onCompleted()
        pump()
        XCTAssertEqual(presenter.state.value, .empty)
    }

    func testTheListIsNotReloadedWhenTheScreenReappearsUnlessAnEntryWasOpened() {
        interactor.ids = ["id1"]
        presenter.viewWillAppear()
        pump()
        presenter.viewWillAppear()
        pump()
        XCTAssertEqual(interactor.idCalls.count, 1, "A list the learner scrolled is not collapsed by merely reappearing")
        presenter.select(item(1))
        presenter.viewWillAppear()
        pump()
        XCTAssertEqual(interactor.idCalls.count, 2, "After an entry was opened its bookmark may have changed")
    }

    func testAFailedQuietRefreshDoesNotLeaveAPageSpinningForever() {
        interactor.ids = (0..<45).map { "id\($0)" }
        presenter.viewWillAppear()
        pump()
        presenter.select(item(1))
        interactor.resolveGate = PublishSubject<SavedPage>().asSingle()   // the next page never answers
        presenter.loadMore()
        interactor.idsError = LearnerAPIError.offline
        presenter.viewWillAppear()
        pump()
        guard case .loaded(let list) = presenter.state.value else { return XCTFail("the rows stay") }
        XCTAssertFalse(list.isLoadingMore)
    }

    func testSelectingOpensTheEntry() {
        presenter.select(item(7))
        XCTAssertEqual(wireframe.shown.map(\.id), ["id7"])
    }
}

// MARK: Doubles

final class FakeBookmarkAPI: BJTBookmarkAPIInterface {
    var rows: [BJTBookmarkDTO] = []
    var listLimits: [Int] = []
    var checkResult = false
    var toggled: [String] = []
    func check(_ kind: DictionaryItemKind, id: String) -> Single<Bool> { .just(checkResult) }
    func toggle(_ kind: DictionaryItemKind, id: String) -> Single<Bool> { toggled.append(id); return .just(!checkResult) }
    func list(_ kind: DictionaryItemKind, limit: Int) -> Single<[BJTBookmarkDTO]> { listLimits.append(limit); return .just(rows) }
}

final class FakeDictionaryAPI: BJTDictionaryAPIInterface {
    var lexemes: [String: BJTLexemeDetailDTO] = [:]
    var lexemeError: Error?
    func lexeme(id: String) -> Single<BJTLexemeDetailDTO> {
        if let lexemeError { return .error(lexemeError) }
        return lexemes[id].map { .just($0) } ?? .error(LearnerAPIError.notFound)
    }
    func grammar(id: String) -> Single<BJTGrammarDetailDTO> { .error(LearnerAPIError.notFound) }
    func kanji(id: String) -> Single<BJTKanjiDetailDTO> { .error(LearnerAPIError.notFound) }
    func kanji(character: String) -> Single<BJTKanjiSummaryDTO?> { .just(nil) }
    func kanjiWords(kanjiID: String) -> Single<[BJTKanjiWordDTO]> { .just([]) }
    func kanjiForWord(lexemeID: String) -> Single<[BJTKanjiReferenceDTO]> { .just([]) }
    func strokeSVG(kanjiID: String) -> Single<String> { .error(LearnerAPIError.notFound) }
}

private final class FakeSavedInteractor: DictionarySavedInteractorInterface {
    var signedIn = true
    var ids: [String] = []
    var idsError: Error?
    var idCalls: [DictionaryItemKind] = []
    var resolveCalls: [[String]] = []
    var removed: [DictionaryItem] = []
    var removeResult: Single<Void> = .just(())
    var resolveGate: Single<SavedPage>?
    var isSignedIn: Bool { signedIn }

    func savedIDs(_ kind: DictionaryItemKind) -> Single<[String]> {
        idCalls.append(kind)
        if let idsError { return .error(idsError) }
        return .just(ids)
    }

    func resolve(_ ids: [String], kind: DictionaryItemKind) -> Single<SavedPage> {
        resolveCalls.append(ids)
        if let gate = resolveGate, resolveCalls.count > 1 { return gate }
        return .just(SavedPage(items: ids.map { DictionaryItem(kind: kind, id: $0, title: "語\($0)") }, missing: 0))
    }

    func remove(_ item: DictionaryItem) -> Single<Void> { removed.append(item); return removeResult }
}

private final class FakeSavedWireframe: DictionarySavedWireframeInterface {
    var shown: [DictionaryItem] = []
    var signIns = 0
    func showEntry(_ item: DictionaryItem) { shown.append(item) }
    func showSignIn(onFinish: @escaping () -> Void) { signIns += 1 }
}
