import RxSwift
import XCTest
@testable import FlashcardApp

final class SpyRemoteDeckView: RemoteDeckViewInterface {
    var states: [RemoteDeckState] = []
    func render(_ state: RemoteDeckState) { states.append(state) }
    var last: RemoteDeckState { states.last ?? RemoteDeckState() }
}

final class FakeRemoteDeckWireframe: RemoteDeckWireframeInterface {
    private(set) var studied: [String] = []
    private(set) var archiveRequests: [String] = []
    private(set) var signIns = 0
    private(set) var leaveCount = 0
    private var confirmation: (() -> Void)?
    private var signInFinish: (() -> Void)?
    func showStudy(deckId: String) { studied.append(deckId) }
    func showSignIn(onFinish: @escaping () -> Void) { signIns += 1; signInFinish = onFinish }
    func confirmArchive(deckName: String, onConfirm: @escaping () -> Void) { archiveRequests.append(deckName); confirmation = onConfirm }
    func leave() { leaveCount += 1 }
    func confirm() { confirmation?() }
    func finishSignIn() { signInFinish?() }
}

final class RemoteDeckPresenterTests: XCTestCase {
    private var server: FakeServerInteractor!
    private var wireframe: FakeRemoteDeckWireframe!
    private var view: SpyRemoteDeckView!
    private var presenter: RemoteDeckPresenter!
    private let deckId = "11111111-2222-4333-8444-555555555555"

    override func setUp() {
        super.setUp()
        server = FakeServerInteractor()
        wireframe = FakeRemoteDeckWireframe()
        view = SpyRemoteDeckView()
        server.detailResult = .just(detail())
    }

    private func detail(owned: Bool = false, cards: Int = 2) -> ServerDeckDetail {
        ServerDeckDetail(deck: ServerDeck(id: deckId, title: "N5 words", details: "Basics", visibility: .public, isOwned: owned, cardCount: cards),
                         cards: (0..<cards).map { ServerDeckCard(id: "aaaaaaaa-0000-4000-8000-00000000000\($0)", front: "語\($0)", back: "a", reading: "") })
    }

    private func makePresenter() {
        presenter = RemoteDeckPresenter(deckId: deckId, interactor: server, wireframe: wireframe)
        presenter.view = view
        presenter.viewDidLoad()
    }

    func test_loadsTheDeckAndOffersToStudyIt() {
        makePresenter()
        XCTAssertEqual(view.last.phase, .loaded)
        XCTAssertEqual(view.last.title, "N5 words")
        XCTAssertEqual(view.last.cards.count, 2)
        XCTAssertTrue(view.last.canStudy)
        XCTAssertFalse(view.last.isOnDevice)
    }

    func test_signedOutAsksToSignInAndLoadsAfterwards() {
        server.isSignedIn = false
        makePresenter()
        XCTAssertEqual(view.last.phase, .signInRequired)
        presenter.signIn()
        server.isSignedIn = true
        wireframe.finishSignIn()
        XCTAssertEqual(view.last.phase, .loaded)
    }

    func test_aFailedLoadCanBeRetried() {
        server.detailResult = .error(LearnerAPIError.offline)
        makePresenter()
        guard case .failed = view.last.phase else { return XCTFail("expected failure") }
        server.detailResult = .just(detail())
        presenter.retry()
        XCTAssertEqual(view.last.phase, .loaded)
    }

    func test_aDeckWithoutUsableCardsCannotBeStudied() {
        server.detailResult = .just(detail(cards: 0))
        makePresenter()
        XCTAssertFalse(view.last.canStudy)
        presenter.study()
        XCTAssertTrue(wireframe.studied.isEmpty)
    }

    func test_studyingSavesACopyFirstThenOpensTheStudyScreen() {
        makePresenter()
        presenter.study()
        XCTAssertEqual(server.saved.count, 1)
        XCTAssertEqual(wireframe.studied, [deckId])
        XCTAssertTrue(view.last.isOnDevice)
    }

    func test_ifTheCopyCannotBeSavedItStaysOnTheDeckAndSaysWhy() {
        server.saveOutcome = .failure(AppError.databaseWriteFailed("disk full"))
        makePresenter()
        presenter.study()
        XCTAssertTrue(wireframe.studied.isEmpty)
        XCTAssertNotNil(view.last.notice)
        XCTAssertFalse(view.last.isOnDevice)
    }

    func test_savingToTheDeviceDoesNotStudyAndHidesTheSaveAction() {
        makePresenter()
        presenter.saveToDevice()
        XCTAssertEqual(server.saved.count, 1)
        XCTAssertTrue(wireframe.studied.isEmpty)
        XCTAssertTrue(view.last.isOnDevice)
        presenter.saveToDevice()
        XCTAssertEqual(server.saved.count, 1, "Already on the device: nothing more to save")
    }

    func test_comingBackAfterTheCopyWasDeletedOffersToSaveAgain() {
        makePresenter()
        presenter.saveToDevice()
        server.deviceCopies = []
        presenter.viewWillAppear()
        XCTAssertFalse(view.last.isOnDevice)
    }

    func test_onlyTheOwnerCanArchiveAndItAsksFirst() {
        makePresenter()
        presenter.archive()
        XCTAssertTrue(wireframe.archiveRequests.isEmpty, "Not the learner's deck")
        server.detailResult = .just(detail(owned: true))
        presenter.retry()
        presenter.archive()
        XCTAssertEqual(wireframe.archiveRequests, ["N5 words"])
        XCTAssertTrue(server.archived.isEmpty, "Nothing is archived before the learner confirms")
        wireframe.confirm()
        XCTAssertEqual(server.archived, [deckId])
        XCTAssertEqual(wireframe.leaveCount, 1)
    }

    func test_aFailedArchiveStaysOnTheDeckWithTheReason() {
        server.detailResult = .just(detail(owned: true))
        server.archiveResult = .error(LearnerAPIError.forbidden("not owner"))
        makePresenter()
        presenter.archive()
        wireframe.confirm()
        XCTAssertEqual(wireframe.leaveCount, 0)
        XCTAssertNotNil(view.last.notice)
        XCTAssertNil(view.last.busy)
    }
}
