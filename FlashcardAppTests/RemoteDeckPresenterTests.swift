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
    private(set) var reportRequests = 0
    private(set) var blockRequests = 0
    private(set) var signIns = 0
    private(set) var leaveCount = 0
    private var confirmation: (() -> Void)?
    private var reportSelection: ((String) -> Void)?
    private var blockConfirmation: (() -> Void)?
    private var signInFinish: (() -> Void)?
    func showStudy(deckId: String) { studied.append(deckId) }
    func showSignIn(onFinish: @escaping () -> Void) { signIns += 1; signInFinish = onFinish }
    func confirmArchive(deckName: String, onConfirm: @escaping () -> Void) { archiveRequests.append(deckName); confirmation = onConfirm }
    func chooseReportReason(onSelect: @escaping (String) -> Void) { reportRequests += 1; reportSelection = onSelect }
    func confirmBlockAuthor(onConfirm: @escaping () -> Void) { blockRequests += 1; blockConfirmation = onConfirm }
    func leave() { leaveCount += 1 }
    func confirm() { confirmation?() }
    func selectReportReason(_ reason: String) { reportSelection?(reason) }
    func confirmBlock() { blockConfirmation?() }
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

    private func detailWithPicture() -> ServerDeckDetail {
        let picture = CardPicture(url: URL(string: "https://images.unsplash.com/a.jpg")!, attribution: nil)
        return ServerDeckDetail(deck: ServerDeck(id: deckId, title: "N5 words", isOwned: false, cardCount: 1),
                                cards: [ServerDeckCard(id: "aaaaaaaa-0000-4000-8000-000000000000", front: "犬", back: "chó", reading: "", picture: picture)])
    }

    func test_studyingACopyWithPicturesWaitsForThePicturesBeforeOpeningTheDeck() {
        server.detailResult = .just(detailWithPicture())
        let stored = PublishSubject<Int>()
        server.copyResult = stored.take(1).asSingle()
        makePresenter()
        presenter.study()
        XCTAssertEqual(view.last.busy, .saving)
        XCTAssertTrue(wireframe.studied.isEmpty, "The deck opens once its pictures are stored")
        stored.onNext(1)
        waitForMain()
        XCTAssertNil(view.last.busy)
        XCTAssertEqual(wireframe.studied, [deckId])
    }

    func test_aPictureThatCannotBeCopiedNeverBlocksStudying() {
        server.detailResult = .just(detailWithPicture())
        server.copyResult = .error(RemoteImageError.offline)
        makePresenter()
        presenter.study()
        waitForMain()
        XCTAssertEqual(wireframe.studied, [deckId])
        XCTAssertNil(view.last.notice)
    }

    func test_aCopyThatAlreadyExistsDoesNotCopyPicturesAgain() {
        server.detailResult = .just(detailWithPicture())
        server.saveOutcome = .success(.alreadyPresent(deckId: deckId))
        makePresenter()
        presenter.study()
        XCTAssertTrue(server.pictureCopies.isEmpty)
        XCTAssertEqual(wireframe.studied, [deckId])
    }

    func test_aDeckWithoutPicturesDoesNotLookForAny() {
        makePresenter()
        presenter.study()
        XCTAssertTrue(server.pictureCopies.isEmpty)
    }

    private func waitForMain() {
        let done = expectation(description: "main")
        DispatchQueue.main.async { DispatchQueue.main.async { done.fulfill() } }
        wait(for: [done], timeout: 2)
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

    func test_reportRequiresForeignPublicDeckAndReasonSelection() {
        makePresenter()
        presenter.report()
        XCTAssertEqual(wireframe.reportRequests, 1)
        XCTAssertTrue(server.reported.isEmpty)
        wireframe.selectReportReason("spam")
        XCTAssertEqual(server.reported.map { $0.1 }, ["spam"])
        XCTAssertNil(view.last.busy)
        XCTAssertNotNil(view.last.notice)

        server.detailResult = .just(detail(owned: true))
        presenter.retry()
        presenter.report()
        XCTAssertEqual(wireframe.reportRequests, 1)
    }

    func test_blockRequiresConfirmationAndLeavesOnlyOnSuccess() {
        makePresenter()
        presenter.blockAuthor()
        XCTAssertEqual(wireframe.blockRequests, 1)
        XCTAssertTrue(server.blocked.isEmpty)
        wireframe.confirmBlock()
        XCTAssertEqual(server.blocked, [deckId])
        XCTAssertEqual(wireframe.leaveCount, 1)
    }

    func test_failedBlockDoesNotCloseDeck() {
        server.blockResult = .error(LearnerAPIError.offline)
        makePresenter()
        presenter.blockAuthor()
        wireframe.confirmBlock()
        XCTAssertEqual(wireframe.leaveCount, 0)
        XCTAssertNil(view.last.busy)
        XCTAssertNotNil(view.last.notice)
    }
}
