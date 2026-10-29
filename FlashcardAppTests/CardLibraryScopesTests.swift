import RxSwift
import XCTest
@testable import FlashcardApp

/// The sections of the Cards tab that come from the account: what each shows, when it loads, and what a failure does.
final class CardLibraryScopesTests: XCTestCase {
    private var server: FakeServerInteractor!
    private var desks: FakeDeskInteractor!
    private var wireframe: FakeCardWireframe!
    private var view: SpyCardView!
    private var presenter: CardPresenter!
    private var clock = Date(timeIntervalSince1970: 2_000_000)
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        let suite = "card-scopes-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        server = FakeServerInteractor()
        desks = FakeDeskInteractor()
        wireframe = FakeCardWireframe()
        view = SpyCardView()
        presenter = CardPresenter(interactor: CardInteractor(), deskInteractor: desks, wireframe: wireframe, defaults: defaults,
                                  server: server, now: { [unowned self] in clock })
        presenter.view = view
    }

    private func deck(_ id: String, _ title: String, owned: Bool = false, visibility: ServerDeckVisibility = .public, cards: Int = 10,
                      age: TimeInterval = 0, details: String = "") -> ServerDeck {
        ServerDeck(id: id, title: title, details: details, visibility: visibility, isOwned: owned, cardCount: cards,
                   updatedAt: clock.addingTimeInterval(-age))
    }

    private func due(_ count: Int) -> [DueCard] {
        (0..<count).map { DueCard(id: "11111111-0000-4000-8000-\(String(format: "%012d", $0))", state: .review, front: "語\($0)", back: "a", reading: "", lapses: 0, isLeech: false) }
    }

    private var last: CardLibraryState { view.states.last ?? CardLibraryState(content: .empty, sort: .recent, deckCount: 0) }

    private var remoteRows: [RemoteDeckRowModel] {
        if case .remote(.decks(let rows)) = last.content { return rows }
        return []
    }

    // MARK: Sections

    func test_theLibraryOnTheDeviceIsTheDefaultSectionAndNeedsNoAccount() {
        server.isSignedIn = false
        presenter.viewWillAppear()
        XCTAssertEqual(presenter.scope, .mine)
        XCTAssertEqual(last.content, .empty)
        XCTAssertNil(last.accountDecks, "Signed out: the account section is simply absent")
        XCTAssertEqual(server.decksCalls, 0)
        XCTAssertTrue(server.dueLimits.isEmpty)
    }

    func test_signedOutSectionsAskToSignInWithoutCallingTheServer() {
        server.isSignedIn = false
        presenter.viewWillAppear()
        for scope in [CardLibraryScope.publicDecks, .recent] {
            presenter.selectScope(scope)
            XCTAssertEqual(last.content, .remote(.signInRequired), "\(scope)")
        }
        presenter.selectScope(.review)
        XCTAssertEqual(last.content, .review(ReviewEntryModel(phase: .signInRequired)))
        XCTAssertEqual(server.decksCalls, 0)
        XCTAssertTrue(server.dueLimits.isEmpty)
    }

    func test_publicShowsOnlyOthersPublicDecksNewestFirst() {
        server.decksResult = .just([
            deck("mine-public", "Mine public", owned: true, age: 1),
            deck("old", "Old", age: 500),
            deck("private", "Private", owned: true, visibility: .private, age: 2),
            deck("new", "New", age: 5)
        ])
        presenter.viewWillAppear()
        presenter.selectScope(.publicDecks)
        XCTAssertEqual(remoteRows.map(\.id), ["new", "old"])
        XCTAssertEqual(remoteRows.first?.monogram, "N")
    }

    func test_recentMixesOwnAndPublicDecksNewestFirstAndStopsAt24() {
        var decks = (0..<30).map { deck("d\($0)", "Deck \($0)", owned: $0 % 2 == 0, age: Double($0 + 1) * 10) }
        decks.append(deck("fresh", "Fresh", owned: true, visibility: .private, age: 1))
        server.decksResult = .just(decks)
        presenter.viewWillAppear()
        presenter.selectScope(.recent)
        XCTAssertEqual(remoteRows.count, 24)
        XCTAssertEqual(remoteRows.first?.id, "fresh")
        XCTAssertEqual(remoteRows[1].id, "d0")
    }

    func test_searchFiltersTheRemoteListByTitleAndDescription() {
        server.decksResult = .just([deck("a", "Office words", details: "meetings"), deck("b", "Animals")])
        presenter.viewWillAppear()
        presenter.selectScope(.publicDecks)
        presenter.updateQuery("meet")
        XCTAssertEqual(remoteRows.map(\.id), ["a"])
        presenter.updateQuery("zzz")
        XCTAssertEqual(last.content, .remote(.noMatches(query: "zzz")))
        presenter.updateQuery("")
        XCTAssertEqual(remoteRows.count, 2)
    }

    func test_anEmptySectionSaysSoInsteadOfSayingNothingMatches() {
        server.decksResult = .just([deck("mine", "Mine", owned: true)])
        presenter.viewWillAppear()
        presenter.selectScope(.publicDecks)
        XCTAssertEqual(last.content, .remote(.empty))
    }

    func test_theReviewSearchDoesNotFollowTheLearnerToAnotherSection() {
        server.decksResult = .just([deck("a", "Alpha")])
        presenter.viewWillAppear()
        presenter.selectScope(.publicDecks)
        presenter.updateQuery("alp")
        presenter.selectScope(.review)
        presenter.selectScope(.publicDecks)
        XCTAssertEqual(remoteRows.map(\.id), ["a"], "Review clears the search, so coming back shows the whole list")
    }

    // MARK: My decks: the account section

    func test_myDecksListsTheAccountsOwnDecksThatAreNotOnTheDevice() {
        server.decksResult = .just([deck("on-device", "Saved", owned: true), deck("remote-only", "Remote", owned: true, visibility: .private), deck("public", "Public")])
        server.deviceCopies = ["on-device"]
        presenter.viewWillAppear()
        guard case .decks(let rows)? = last.accountDecks else { return XCTFail("expected the account section") }
        XCTAssertEqual(rows.map(\.id), ["remote-only"])
        XCTAssertEqual(rows.first?.isOnDevice, false)
        XCTAssertEqual(rows.first?.visibility, .private)
    }

    func test_theAccountSectionIsHiddenWhenThereIsNothingToAdd() {
        server.decksResult = .just([deck("public", "Public"), deck("saved", "Saved", owned: true)])
        server.deviceCopies = ["saved"]
        presenter.viewWillAppear()
        XCTAssertNil(last.accountDecks)
    }

    func test_aFailureToLoadTheAccountSectionIsShownNotHidden() {
        server.decksResult = .error(LearnerAPIError.offline)
        presenter.viewWillAppear()
        guard case .failed? = last.accountDecks else { return XCTFail("expected a visible failure") }
    }

    // MARK: Review

    func test_reviewShowsTheDueCountAndTheBadge() {
        server.dueResult = .just(due(12))
        presenter.viewWillAppear()
        XCTAssertEqual(last.reviewDueCount, 12)
        presenter.selectScope(.review)
        XCTAssertEqual(last.content, .review(ReviewEntryModel(phase: .ready(due: 12, capped: false))))
        XCTAssertEqual(server.dueLimits, [50])
    }

    func test_aFullBatchIsShownAsAtLeast() {
        server.dueResult = .just(due(50))
        presenter.viewWillAppear()
        presenter.selectScope(.review)
        XCTAssertEqual(last.content, .review(ReviewEntryModel(phase: .ready(due: 50, capped: true))))
    }

    func test_startingAReviewHandsOverTheLoadedCards() {
        server.dueResult = .just(due(3))
        presenter.viewWillAppear()
        presenter.selectScope(.review)
        presenter.startReview()
        XCTAssertEqual(wireframe.reviews.first?.count, 3)
    }

    func test_nothingDueDoesNotOpenAReview() {
        server.dueResult = .just([])
        presenter.viewWillAppear()
        presenter.selectScope(.review)
        presenter.startReview()
        XCTAssertTrue(wireframe.reviews.isEmpty)
        XCTAssertEqual(last.content, .review(ReviewEntryModel(phase: .ready(due: 0, capped: false))))
    }

    func test_afterAReviewTheDueCountIsLoadedAgainEvenIfFresh() {
        server.dueResult = .just(due(3))
        presenter.viewWillAppear()
        presenter.selectScope(.review)
        presenter.startReview()
        server.dueResult = .just(due(1))
        presenter.viewWillAppear()
        XCTAssertEqual(last.reviewDueCount, 1)
        XCTAssertEqual(server.dueLimits.count, 2)
    }

    func test_aFailedDueLoadOffersARetryThatLoadsAgain() {
        server.dueResult = .error(LearnerAPIError.offline)
        presenter.viewWillAppear()
        presenter.selectScope(.review)
        guard case .review(let entry) = last.content, case .failed = entry.phase else { return XCTFail("expected failure") }
        server.dueResult = .just(due(2))
        presenter.refresh()
        XCTAssertEqual(last.content, .review(ReviewEntryModel(phase: .ready(due: 2, capped: false))))
    }

    // MARK: Freshness

    func test_dataYoungerThanAMinuteIsNotFetchedAgainButOlderDataIs() {
        server.decksResult = .just([deck("a", "A")])
        presenter.viewWillAppear()
        presenter.selectScope(.publicDecks)
        presenter.viewWillAppear()
        XCTAssertEqual(server.decksCalls, 1)
        clock = clock.addingTimeInterval(CardPresenter.staleAfter + 1)
        presenter.viewWillAppear()
        XCTAssertEqual(server.decksCalls, 2)
    }

    func test_pullToRefreshAlwaysFetchesAgain() {
        server.decksResult = .just([deck("a", "A")])
        presenter.viewWillAppear()
        presenter.selectScope(.publicDecks)
        presenter.refresh()
        XCTAssertEqual(server.decksCalls, 2)
    }

    func test_aFailedRefreshKeepsTheListAndTellsTheLearner() {
        server.decksResult = .just([deck("a", "A")])
        presenter.viewWillAppear()
        presenter.selectScope(.publicDecks)
        server.decksResult = .error(LearnerAPIError.offline)
        presenter.refresh()
        XCTAssertEqual(remoteRows.map(\.id), ["a"])
        XCTAssertEqual(wireframe.alerts.count, 1)
    }

    func test_aDifferentAccountNeverSeesThePreviousAccountsDecks() {
        server.decksResult = .just([deck("a", "A")])
        presenter.viewWillAppear()
        presenter.selectScope(.publicDecks)
        XCTAssertEqual(remoteRows.count, 1)
        server.accountId = "account-2"
        server.decksResult = .just([deck("b", "B")])
        presenter.viewWillAppear()
        XCTAssertEqual(remoteRows.map(\.id), ["b"])
        XCTAssertEqual(server.decksCalls, 2, "A new account reloads even though the old data was fresh")
    }

    func test_signingOutDropsTheCachedSections() {
        server.decksResult = .just([deck("a", "A")])
        presenter.viewWillAppear()
        presenter.selectScope(.publicDecks)
        server.isSignedIn = false
        server.accountId = nil
        presenter.viewWillAppear()
        XCTAssertEqual(last.content, .remote(.signInRequired))
    }

    // MARK: Navigation

    func test_openingAnAccountDeckGoesThroughTheWireframeAndRefreshesOnReturn() {
        server.decksResult = .just([deck("a", "A", owned: true, visibility: .private)])
        presenter.viewWillAppear()
        presenter.openAccountDeck(id: "a")
        XCTAssertEqual(wireframe.remoteDecks, ["a"])
        presenter.viewWillAppear()
        XCTAssertEqual(server.decksCalls, 2, "Saving or archiving there changes what this list shows")
    }

    func test_signInLoadsTheSectionsAfterItFinishes() {
        server.isSignedIn = false
        server.accountId = nil
        presenter.viewWillAppear()
        presenter.selectScope(.publicDecks)
        presenter.signIn()
        XCTAssertEqual(wireframe.signIns, 1)
        server.isSignedIn = true
        server.accountId = "account-1"
        server.decksResult = .just([deck("a", "A")])
        wireframe.finishSignIn()
        XCTAssertEqual(remoteRows.map(\.id), ["a"])
    }
}
