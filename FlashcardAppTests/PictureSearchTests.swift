import RxSwift
import XCTest
@testable import FlashcardApp

final class PictureSearchPresenterTests: XCTestCase {
    private var interactor: FakePictureSearch!
    private var wireframe: FakePictureWireframe!
    private var view: SpyPictureView!
    private var picked: [PictureSuggestion] = []
    /// The presenter owns the running search; it must outlive `makePresenter`.
    private var retained: PictureSearchPresenter?

    override func setUp() {
        super.setUp()
        interactor = FakePictureSearch()
        wireframe = FakePictureWireframe()
        view = SpyPictureView()
        picked = []
    }

    private func makePresenter(term: String = "chó") -> PictureSearchPresenter {
        let presenter = PictureSearchPresenter(term: term, interactor: interactor, wireframe: wireframe, onPick: { [unowned self] in picked.append($0) })
        presenter.view = view
        retained = presenter
        presenter.viewDidLoad()
        return presenter
    }

    private func picture(_ id: String) -> PictureSuggestion {
        PictureSuggestion(BJTImageResultDTO(id: id, thumbUrl: "https://i.test/\(id)-t.jpg", fullUrl: "https://i.test/\(id).jpg", source: "unsplash"))!
    }

    /// `observe(on: MainScheduler)` hops once; let it run.
    private func waitForMain() {
        let done = expectation(description: "main")
        DispatchQueue.main.async { DispatchQueue.main.async { done.fulfill() } }
        wait(for: [done], timeout: 2)
    }

    func test_openingSearchesTheSuggestedTermAndShowsTheResults() {
        _ = makePresenter()
        XCTAssertEqual(view.states.first, .loading)
        XCTAssertEqual(interactor.terms, ["chó"])
        interactor.result.onNext([picture("1"), picture("2")])
        waitForMain()
        XCTAssertEqual(view.states.last, .results([picture("1"), picture("2")]))
    }

    func test_noResultsIsAnEmptyStateNotAnError() {
        _ = makePresenter()
        interactor.result.onNext([])
        waitForMain()
        XCTAssertEqual(view.states.last, .empty)
    }

    func test_signedOutExplainsAndDoesNotCallTheServer() {
        interactor.signedIn = false
        let presenter = makePresenter()
        XCTAssertEqual(view.states.last, .signInRequired)
        XCTAssertTrue(interactor.terms.isEmpty)
        presenter.signIn()
        interactor.signedIn = true
        wireframe.finishSignIn?()
        XCTAssertEqual(interactor.terms, ["chó"], "After signing in the search runs again")
    }

    func test_anUnconfiguredProviderIsAnExpectedStateWithAWayForward() {
        _ = makePresenter()
        interactor.result.onError(LearnerAPIError.serviceUnavailable("image search unavailable"))
        waitForMain()
        XCTAssertEqual(view.states.last, .unavailable)
    }

    func test_authenticationRateLimitAndNetworkFailuresEachGetTheirOwnState() {
        let cases: [(Error, PictureSearchState)] = [
            (LearnerAPIError.signInRequired, .signInRequired),
            (LearnerAPIError.rateLimited, .failed(LearnerAPIError.rateLimited.errorDescription!)),
            (LearnerAPIError.offline, .failed(LearnerAPIError.offline.errorDescription!)),
            (LearnerAPIError.originRejected, .failed(LearnerAPIError.originRejected.errorDescription!))
        ]
        for (error, expected) in cases {
            interactor = FakePictureSearch()
            view = SpyPictureView()
            _ = makePresenter()
            interactor.result.onError(error)
            waitForMain()
            XCTAssertEqual(view.states.last, expected)
        }
    }

    func test_aShortTermAsksForAWordInsteadOfSearching() {
        let presenter = makePresenter(term: "")
        XCTAssertEqual(view.states.last, .needsTerm)
        presenter.search("a")
        XCTAssertEqual(view.states.last, .needsTerm)
        XCTAssertTrue(interactor.terms.isEmpty)
    }

    func test_aNewSearchCancelsTheOneStillRunning() {
        let presenter = makePresenter()
        presenter.search("mèo")
        XCTAssertEqual(interactor.terms, ["chó", "mèo"])
        XCTAssertEqual(interactor.disposed, 1)
    }

    func test_choosingAPictureClosesTheSheetThenHandsItOver() {
        let presenter = makePresenter()
        interactor.result.onNext([picture("1")])
        presenter.select(picture("1"))
        XCTAssertTrue(picked.isEmpty, "Nothing is saved before the sheet has closed")
        wireframe.completeClose()
        XCTAssertEqual(picked, [picture("1")])
    }

    func test_closingWithoutChoosingSavesNothing() {
        let presenter = makePresenter()
        presenter.close()
        wireframe.completeClose()
        XCTAssertTrue(picked.isEmpty)
    }
}

final class CardImageAttributionTests: XCTestCase {
    private var folder: URL!
    private var store: CardImageStore!

    override func setUp() {
        super.setUp()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("attribution-\(UUID().uuidString)")
        store = CardImageStore(directory: folder)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
        super.tearDown()
    }

    private func reference() throws -> String {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20))
        return try store.save(image: renderer.image { UIColor.systemTeal.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 20, height: 20)) })
    }

    private let attribution = ImageAttribution(source: "unsplash", sourceID: "p1", imageURL: "https://i.test/p1.jpg")

    func test_theSourceIsKeptWithThePicture() throws {
        let reference = try reference()
        try store.saveAttribution(attribution, for: reference)
        XCTAssertEqual(store.attribution(for: reference), attribution)
        XCTAssertNil(store.attribution(for: "https://example.com/a.jpg"))
    }

    func test_theRecordLeavesWithItsPictureAndStaysWhileItIsUsed() throws {
        let kept = try reference(), dropped = try reference()
        try store.saveAttribution(attribution, for: kept)
        try store.saveAttribution(attribution, for: dropped)
        let removed = store.removeUnreferenced(keeping: [kept])
        XCTAssertEqual(Set(removed.map { $0.replacingOccurrences(of: CardImageStore.attributionSuffix, with: "") }), [CardImageReference(dropped).fileName!])
        XCTAssertEqual(store.attribution(for: kept), attribution)
        XCTAssertNil(store.attribution(for: dropped))
        XCTAssertTrue(store.exists(CardImageReference(kept)))
    }
}

private extension CardImageReference {
    var fileName: String? {
        if case .local(let name) = self { return name }
        return nil
    }
}

private final class FakePictureSearch: PictureSearchInteractorInterface {
    var signedIn = true
    var terms: [String] = []
    var disposed = 0
    var result = PublishSubject<[PictureSuggestion]>()
    var isSignedIn: Bool { signedIn }
    func search(_ term: String) -> Single<[PictureSuggestion]> {
        terms.append(term)
        result = PublishSubject<[PictureSuggestion]>()
        return result.take(1).asSingle().do(onDispose: { [weak self] in self?.disposed += 1 })
    }
}

private final class FakePictureWireframe: PictureSearchWireframeInterface {
    var finishSignIn: (() -> Void)?
    private var closing: (() -> Void)?
    func close(then: (() -> Void)?) { closing = then }
    func completeClose() { closing?() }
    func showSignIn(onFinish: @escaping () -> Void) { finishSignIn = onFinish }
}

private final class SpyPictureView: PictureSearchViewInterface {
    var states: [PictureSearchState] = []
    func render(_ state: PictureSearchState) { states.append(state) }
}
