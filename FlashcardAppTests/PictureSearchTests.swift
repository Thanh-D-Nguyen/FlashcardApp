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
        PictureSuggestion(Self.dto(id))!
    }

    static func dto(_ id: String, url: String? = nil, author: String = "Ana Lee") -> BJTImageResultDTO {
        BJTImageResultDTO(handle: id, provider: "unsplash", url: url ?? "https://i.test/\(id).jpg", sourceUrl: "https://unsplash.com/photos/\(id)",
                          author: author, authorUrl: "https://unsplash.com/@ana", license: "Unsplash License", licenseUrl: nil)
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

    func test_choosingAPictureRegistersItThenClosesTheSheetThenHandsItOver() {
        let presenter = makePresenter()
        interactor.result.onNext([picture("1")])
        presenter.select(picture("1"))
        XCTAssertEqual(interactor.selected, [picture("1")])
        XCTAssertEqual(view.selecting, [true])
        XCTAssertNil(wireframe.pendingClose, "The sheet stays open until the server accepted the choice")
        interactor.selection.onNext("asset-1")
        waitForMain()
        XCTAssertEqual(view.selecting, [true, false])
        XCTAssertTrue(picked.isEmpty, "Nothing is saved before the sheet has closed")
        wireframe.completeClose()
        XCTAssertEqual(picked, [picture("1").registered(assetId: "asset-1")])
        XCTAssertEqual(picked.first?.attribution.assetId, "asset-1", "The asset id travels with the picture")
    }

    func test_aRejectedChoiceKeepsTheSheetOpenAndSavesNothing() {
        let presenter = makePresenter()
        presenter.select(picture("1"))
        interactor.selection.onError(LearnerAPIError.rateLimited)
        waitForMain()
        XCTAssertEqual(view.selecting, [true, false])
        XCTAssertEqual(view.failures, [LearnerAPIError.rateLimited.errorDescription])
        XCTAssertNil(wireframe.pendingClose)
        XCTAssertTrue(picked.isEmpty)
    }

    func test_anExpiredHandleAsksForANewSearch() {
        XCTAssertEqual(PictureSearchPresenter.selectionMessage(for: LearnerAPIError.invalidRequest(nil)),
                       NSLocalizedString("This result has expired. Search again and choose it once more.", comment: ""))
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

    private let attribution = ImageAttribution(source: "unsplash", imageURL: "https://i.test/p1.jpg", sourceURL: "https://unsplash.com/photos/p1",
                                               author: "Ana Lee", authorURL: "https://unsplash.com/@ana", license: "Unsplash License", licenseURL: nil)

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
    var selected: [PictureSuggestion] = []
    var selection = PublishSubject<String>()
    var isSignedIn: Bool { signedIn }
    func search(_ term: String) -> Single<[PictureSuggestion]> {
        terms.append(term)
        result = PublishSubject<[PictureSuggestion]>()
        return result.take(1).asSingle().do(onDispose: { [weak self] in self?.disposed += 1 })
    }
    func select(_ picture: PictureSuggestion) -> Single<String> {
        selected.append(picture)
        selection = PublishSubject<String>()
        return selection.take(1).asSingle()
    }
}

private final class FakePictureWireframe: PictureSearchWireframeInterface {
    var finishSignIn: (() -> Void)?
    private(set) var pendingClose: (() -> Void)?
    func close(then: (() -> Void)?) { pendingClose = then }
    func completeClose() { pendingClose?() }
    func showSignIn(onFinish: @escaping () -> Void) { finishSignIn = onFinish }
}

private final class SpyPictureView: PictureSearchViewInterface {
    var states: [PictureSearchState] = []
    var selecting: [Bool] = []
    var failures: [String] = []
    func render(_ state: PictureSearchState) { states.append(state) }
    func setSelecting(_ selecting: Bool) { self.selecting.append(selecting) }
    func showSelectionFailure(_ message: String) { failures.append(message) }
}

final class PictureSuggestionTests: XCTestCase {
    func test_aResultKeepsTheCreditItsLicenceAsksFor() throws {
        let picture = try XCTUnwrap(PictureSuggestion(PictureSearchPresenterTests.dto("p1")))
        XCTAssertEqual(picture.handle, "p1")
        XCTAssertEqual(picture.attribution.creditLine, "Photo by Ana Lee · unsplash · Unsplash License")
        XCTAssertEqual(picture.attribution.creditURL, URL(string: "https://unsplash.com/@ana"))
    }

    func test_onlySecureAddressesAreAccepted() {
        XCTAssertNil(PictureSuggestion(PictureSearchPresenterTests.dto("p", url: "http://i.test/f.jpg")))
        XCTAssertNil(PictureSuggestion(PictureSearchPresenterTests.dto("p", url: "file:///etc/passwd")))
    }

    func test_aResultWithoutHandleOrAuthorIsDropped() {
        XCTAssertNil(PictureSuggestion(PictureSearchPresenterTests.dto("")))
        XCTAssertNil(PictureSuggestion(PictureSearchPresenterTests.dto("p", author: "  ")))
    }

    func test_aRecordWrittenBeforeTheCreditFieldsExistedStillDecodes() throws {
        let old = #"{"source":"unsplash","sourceID":"p1","imageURL":"https://i.test/p1.jpg"}"#
        let attribution = try JSONDecoder().decode(ImageAttribution.self, from: Data(old.utf8))
        XCTAssertEqual(attribution.source, "unsplash")
        XCTAssertNil(attribution.author)
        XCTAssertEqual(attribution.creditLine, "unsplash")
        XCTAssertNil(attribution.creditURL)
    }
}

final class CardPictureTests: XCTestCase {
    private let api = "https://api.example.test/api"

    private func dto(readUrl: String?, provider: String? = "unsplash", author: String? = "Ana Lee") -> BJTCardImageDTO {
        BJTCardImageDTO(assetId: "a", mimeType: "image/jpeg", readUrl: readUrl, provider: provider,
                        sourceUrl: "https://unsplash.com/photos/a", author: author, authorUrl: "http://insecure.test/ana",
                        license: "Unsplash License", licenseUrl: nil)
    }

    func test_aProviderAddressIsKeptWithItsCredit() throws {
        let picture = try XCTUnwrap(CardPicture.make(dto(readUrl: "https://images.unsplash.com/a.jpg"), apiBase: api))
        XCTAssertEqual(picture.reference, "https://images.unsplash.com/a.jpg")
        XCTAssertEqual(picture.credit, "Photo by Ana Lee · unsplash · Unsplash License")
        XCTAssertNil(picture.attribution?.authorURL, "A link that is not https is not kept")
        XCTAssertEqual(picture.attribution?.creditURL, URL(string: "https://unsplash.com/photos/a"))
    }

    func test_anAPIMediaPathResolvesAgainstTheConfiguredAPIAddress() throws {
        let preview = try XCTUnwrap(CardPicture.make(dto(readUrl: "/api/media/1/private-preview", provider: nil, author: nil), apiBase: api))
        XCTAssertEqual(preview.reference, "https://api.example.test/api/media/1/private-preview")
        XCTAssertNil(preview.attribution, "An own upload has no credit")
        XCTAssertEqual(preview.credit, "")
    }

    func test_addressesTheAppWillNotLoadAreDropped() {
        for raw in [nil, "", "http://images.test/a.jpg", "file:///etc/passwd", "/other/path.jpg", "//evil.test/api/media/1"] {
            XCTAssertNil(CardPicture.make(dto(readUrl: raw), apiBase: api), String(describing: raw))
        }
        XCTAssertNil(CardPicture.make(nil, apiBase: api))
    }

    func test_theSessionIsOnlyEverSentToTheAPIsOwnMediaPaths() {
        let own = URL(string: "https://api.example.test/api/media/1/private-preview")!
        XCTAssertEqual(APIImageAuthorization.header(for: own, token: "tok", apiBase: api), "Bearer tok")
        XCTAssertNil(APIImageAuthorization.header(for: own, token: nil, apiBase: api))
        XCTAssertNil(APIImageAuthorization.header(for: URL(string: "https://images.unsplash.com/a.jpg")!, token: "tok", apiBase: api))
        XCTAssertNil(APIImageAuthorization.header(for: URL(string: "https://api.example.test.evil.test/api/media/1")!, token: "tok", apiBase: api))
        XCTAssertNil(APIImageAuthorization.header(for: URL(string: "http://api.example.test/api/media/1")!, token: "tok", apiBase: api))
        XCTAssertNil(APIImageAuthorization.header(for: URL(string: "https://api.example.test/api/flashcards/decks")!, token: "tok", apiBase: api))
    }

    func test_theDeckAndReviewPayloadsCarryThePicture() throws {
        let deck = #"{"id":"d","titleVi":"t","cards":[{"id":"i","position":0,"card":{"id":"c","frontText":"犬","backText":"chó","reading":null,"sourceId":"s","sourceType":"t","primaryImage":{"assetId":"a","mimeType":"image/jpeg","readUrl":"/api/media/a/stream"}}}]}"#
        let decoded = try JSONDecoder().decode(BJTRemoteDeckDTO.self, from: Data(deck.utf8))
        XCTAssertEqual(decoded.cards[0].card.primaryImage?.readUrl, "/api/media/a/stream")
        let due = #"{"id":"i","cardId":"c","state":"new","intervalDays":0,"lapses":0,"leeched":false,"card":{"id":"c","frontText":"犬","backText":"chó","reading":null},"primaryImage":null}"#
        XCTAssertNil(try JSONDecoder().decode(BJTDueCardDTO.self, from: Data(due.utf8)).primaryImage)
    }

    func test_theMappersPassThePictureOn() throws {
        let image = #","primaryImage":{"assetId":"a","mimeType":"image/jpeg","readUrl":"https://images.unsplash.com/a.jpg"}"#
        let due = #"{"id":"11111111-0000-4000-8000-000000000001","cardId":"c","state":"new","intervalDays":0,"lapses":0,"leeched":false,"card":{"id":"c","frontText":"犬","backText":"chó","reading":null}"# + image + "}"
        let dueCard = try XCTUnwrap(ServerDeckMapper.dueCard(from: JSONDecoder().decode(BJTDueCardDTO.self, from: Data(due.utf8))))
        XCTAssertEqual(dueCard.picture?.reference, "https://images.unsplash.com/a.jpg")
        let deck = #"{"id":"d","titleVi":"t","cards":[{"id":"i","position":0,"card":{"id":"c","frontText":"犬","backText":"chó","reading":null,"sourceId":"s","sourceType":"t""# + image + "}}]}"
        let detail = ServerDeckMapper.detail(from: try JSONDecoder().decode(BJTRemoteDeckDTO.self, from: Data(deck.utf8)))
        XCTAssertEqual(detail.cards.first?.picture?.reference, "https://images.unsplash.com/a.jpg")
    }
}
