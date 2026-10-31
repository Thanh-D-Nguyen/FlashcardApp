import RealmSwift
import RxSwift
import XCTest
@testable import FlashcardApp

private final class SignedOutTokens: AuthTokenManagerInterface {
    var accessToken: String? { nil }
    var userId: String? { nil }
    func save(accessToken: String, userId: String) throws {}
    func clear() throws {}
}

private final class UnusedNativeAuth: NativeAuthAPIInterface {
    func login(email: String, password: String) -> Single<NativeLoginResponse> { fatalError() }
    func loginWithGoogle(idToken: String) -> Single<NativeLoginResponse> { fatalError() }
    func me(token: @escaping () -> String?) -> Single<NativeProfile> { fatalError() }
    func logout(token: @escaping () -> String?) -> Single<Void> { fatalError() }
}

private final class FakeAccountAPI: BJTAccountDeckAPIInterface {
    private(set) var uploads: [Data] = []
    private(set) var created: [AccountDeckInput] = []
    var uploadOutcome: (Int) -> Single<String> = { _ in .just(UUID().uuidString.lowercased()) }
    var createOutcome: Single<BJTGeneratedDeckDTO> = .just(BJTGeneratedDeckDTO(id: "11111111-2222-4333-8444-555555555555", titleVi: "N5", cardCount: 2))

    func uploadPicture(data: Data, fileName: String, mimeType: String) -> Single<String> {
        uploads.append(data)
        return uploadOutcome(uploads.count)
    }

    func createDeck(_ deck: AccountDeckInput) -> Single<BJTGeneratedDeckDTO> {
        created.append(deck)
        return createOutcome
    }
}

final class DeckPublishInteractorTests: XCTestCase {
    private var api: FakeAccountAPI!
    private var repository: DeskManagement!
    private var store: CardImageStore!
    private var folder: URL!
    private var links: DeckAccountLinks!
    private var interactor: DeckPublishInteractor!
    private let accountDeck = "11111111-2222-4333-8444-555555555555"

    override func setUpWithError() throws {
        let configuration = Realm.Configuration(inMemoryIdentifier: "publish-\(UUID().uuidString)", objectTypes: RealmService.storedTypes)
        RealmService.shared.realm = try Realm(configuration: configuration)
        repository = DeskManagement()
        api = FakeAccountAPI()
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("publish-\(UUID().uuidString)")
        store = CardImageStore(directory: folder)
        let suite = "publish-links-\(UUID().uuidString)"
        links = DeckAccountLinks(defaults: UserDefaults(suiteName: suite)!, accountId: { "account-1" })
        interactor = DeckPublishInteractor(api: api, repository: repository, images: store, links: links,
                                           auth: AuthSession(tokens: SignedOutTokens(), api: UnusedNativeAuth()))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
        RealmService.shared.realm = nil
    }

    private func picture() throws -> String {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40))
        return try store.save(image: renderer.image { UIColor.systemTeal.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 40, height: 40)) })
    }

    private func addDeck(id: String = "device-deck", _ cards: [(front: String, back: String, image: String)]) throws {
        let desk = DeskEntity()
        desk.id = id
        desk.name = " N5 "
        desk.cards = cards.enumerated().map { index, item in
            let card = CardEntity()
            card.id = "\(id)-card-\(index)"
            card.frontText = item.front
            card.backText = item.back
            card.imageUrl = item.image
            if JapaneseText.containsJapanese(item.front) { card.frontExtraText = "よみ" }
            return card
        }
        try repository.add(desk)
    }

    private func publish(_ deckId: String = "device-deck") -> (updates: [DeckPublishUpdate], error: Error?) {
        var updates: [DeckPublishUpdate] = [], failure: Error?
        let done = expectation(description: "publish")
        let subscription = interactor.publish(deckId: deckId).subscribe(onNext: { updates.append($0) },
                                                                          onError: { failure = $0; done.fulfill() },
                                                                          onCompleted: { done.fulfill() })
        wait(for: [done], timeout: 10)
        subscription.dispose()
        return (updates, failure)
    }

    func test_pictureCardsAreUploadedOnceThenTheDeckIsCreatedWithTheirAssets() throws {
        let local = try picture()
        try addDeck([("犬", "chó", local), ("猫", "mèo", "")])
        let result = publish()
        XCTAssertNil(result.error)
        XCTAssertEqual(result.updates.first, .uploading(done: 1, total: 1))
        XCTAssertEqual(result.updates.dropFirst().first, .creating)
        XCTAssertEqual(result.updates.last, .finished(DeckPublishReport(accountDeckId: accountDeck, cardCount: 2, uploaded: 1, reused: 0, skipped: 0)))
        XCTAssertEqual(api.uploads.count, 1)
        let sent = try XCTUnwrap(api.created.first)
        XCTAssertEqual(sent.titleVi, "N5")
        XCTAssertEqual(sent.visibility, "private")
        XCTAssertEqual(sent.cards.map(\.frontText), ["犬", "猫"])
        XCTAssertEqual(sent.cards.first?.reading, "よみ")
        XCTAssertNotNil(sent.cards[0].primaryImageAssetId)
        XCTAssertNil(sent.cards[1].primaryImageAssetId)
        XCTAssertEqual(interactor.accountDeckId(forDevice: "device-deck"), accountDeck)
    }

    func test_aPictureFoundThroughThePictureSearchReusesItsAssetInsteadOfUploading() throws {
        let local = try picture()
        try store.saveAttribution(ImageAttribution(source: "unsplash", imageURL: "https://i.test/a.jpg", assetId: "asset-from-selection"), for: local)
        try addDeck([("犬", "chó", local)])
        let result = publish()
        XCTAssertTrue(api.uploads.isEmpty)
        XCTAssertEqual(api.created.first?.cards.first?.primaryImageAssetId, "asset-from-selection")
        guard case .finished(let report)? = result.updates.last else { return XCTFail("not finished") }
        XCTAssertEqual(report.reused, 1)
    }

    func test_picturesThatCannotBeSentAreLeftOutButTheCardsAreStillSaved() throws {
        try addDeck([("犬", "chó", "local-image:missing.jpg"), ("猫", "mèo", "https://example.com/a.jpg")])
        let result = publish()
        XCTAssertNil(result.error)
        guard case .finished(let report)? = result.updates.last else { return XCTFail("not finished") }
        XCTAssertEqual(report.skipped, 2)
        XCTAssertEqual(report.cardCount, 2)
        XCTAssertTrue(api.created.first?.cards.allSatisfy { $0.primaryImageAssetId == nil } ?? false)
    }

    func test_aPictureTheServerRefusesIsSkippedButARateLimitStopsEverything() throws {
        let first = try picture(), second = try picture()
        try addDeck([("犬", "chó", first), ("猫", "mèo", second)])
        api.uploadOutcome = { $0 == 1 ? .error(LearnerAPIError.server(413)) : .just("asset-2") }
        var result = publish()
        XCTAssertNil(result.error)
        guard case .finished(let report)? = result.updates.last else { return XCTFail("not finished") }
        XCTAssertEqual(report.skipped, 1)
        XCTAssertEqual(report.uploaded, 1)

        try addDeck(id: "other", [("犬", "chó", first)])
        api.uploadOutcome = { _ in .error(LearnerAPIError.rateLimited) }
        let createsBefore = api.created.count
        result = publish("other")
        XCTAssertEqual(result.error as? LearnerAPIError, .rateLimited)
        XCTAssertEqual(api.created.count, createsBefore, "The deck is not created when the pictures could not be sent")
        XCTAssertNil(interactor.accountDeckId(forDevice: "other"))
    }

    func test_aDeckIsNeverSavedTwice() throws {
        try addDeck([("犬", "chó", "")])
        XCTAssertNil(publish().error)
        let again = publish()
        XCTAssertEqual(again.error as? DeckPublishError, .alreadySaved)
        XCTAssertEqual(api.created.count, 1)
    }

    func test_aFailedCreateLeavesNoLinkSoTheLearnerCanTryAgain() throws {
        try addDeck([("犬", "chó", "")])
        api.createOutcome = .error(LearnerAPIError.interrupted)
        XCTAssertEqual(publish().error as? LearnerAPIError, .interrupted)
        XCTAssertNil(interactor.accountDeckId(forDevice: "device-deck"))
    }

    func test_decksThatCannotBeSavedAreRejectedBeforeAnyRequest() throws {
        XCTAssertEqual(publish("missing").error as? DeckPublishError, .notFound)
        try addDeck(id: "blank", [("", "", "")])
        XCTAssertEqual(publish("blank").error as? DeckPublishError, .noCards)
        XCTAssertTrue(api.uploads.isEmpty && api.created.isEmpty)
    }

    func test_theSavedDeckIsRecognisedAsTheDeviceCopyOfTheAccountDeck() throws {
        try addDeck([("犬", "chó", "")])
        XCTAssertNil(publish().error)
        let server = CardLibraryServerInteractor(api: FakeLibraryNoop(), repository: repository,
                                                 auth: AuthSession(tokens: SignedOutTokens(), api: UnusedNativeAuth()), links: links)
        XCTAssertTrue(server.hasDeviceCopy(deckId: accountDeck), "The account section must not list it again")
        XCTAssertFalse(server.hasDeviceCopy(deckId: "99999999-2222-4333-8444-555555555555"))
    }

    func test_aLargeNoisyPictureIsShrunkUnderTheLimit() throws {
        let side = 1600
        var generator = SystemRandomNumberGenerator()
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        for index in pixels.indices { pixels[index] = index % 4 == 3 ? 255 : UInt8.random(in: 0...255, using: &generator) }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let cgImage = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: provider, decode: nil,
                              shouldInterpolate: false, intent: .defaultIntent)!
        let reference = try store.save(image: UIImage(cgImage: cgImage))
        let stored = try Data(contentsOf: XCTUnwrap(store.fileURL(for: CardImageReference(reference))))
        XCTAssertGreaterThan(stored.count, DeckPublishInteractor.maximumPictureBytes, "The fixture must start above the limit")
        let sent = try XCTUnwrap(store.uploadData(for: CardImageReference(reference), maximumBytes: DeckPublishInteractor.maximumPictureBytes))
        XCTAssertLessThanOrEqual(sent.count, DeckPublishInteractor.maximumPictureBytes)
        XCTAssertNotNil(UIImage(data: sent), "The smaller rendition is still a picture")
    }

    func test_aStoredPictureIsSentAsItIsWhenSmallAndShrunkWhenLarge() throws {
        let local = try picture()
        let reference = CardImageReference(local)
        let original = try XCTUnwrap(store.uploadData(for: reference, maximumBytes: DeckPublishInteractor.maximumPictureBytes))
        XCTAssertEqual(original, try Data(contentsOf: XCTUnwrap(store.fileURL(for: reference))))
        XCTAssertNil(store.uploadData(for: reference, maximumBytes: 10), "Nothing that small can hold a picture")
        XCTAssertEqual(DeckPublishInteractor.maximumPictureBytes, 300_000)
        XCTAssertNil(store.uploadData(for: CardImageReference("local-image:nope.jpg"), maximumBytes: 1_000_000))
    }
}

private final class FakeLibraryNoop: BJTFlashcardLibraryAPIInterface {
    func libraryDecks(limit: Int) -> Single<[BJTDeckSummaryDTO]> { .just([]) }
    func deck(id: String) -> Single<BJTRemoteDeckDTO> { .error(LearnerAPIError.notFound) }
    func dueCards(limit: Int) -> Single<[BJTDueCardDTO]> { .just([]) }
    func submitReview(userFlashcardId: String, rating: ReviewRating, elapsedMs: Int?) -> Single<Void> { .just(()) }
    func archiveDeck(id: String) -> Single<Void> { .just(()) }
}

private final class FakePublisher: DeckPublishInteractorInterface {
    var isSignedIn = true
    var linked: [String: String] = [:]
    var pictures = 2
    let updates = PublishSubject<DeckPublishUpdate>()
    private(set) var published: [String] = []
    func accountDeckId(forDevice deckId: String) -> String? { linked[deckId] }
    func pictureCount(ofDeck deckId: String) -> Int { pictures }
    func publish(deckId: String) -> Observable<DeckPublishUpdate> { published.append(deckId); return updates }
}

final class CardPresenterUploadTests: XCTestCase {
    private var desks: FakeDeskInteractor!
    private var wireframe: FakeCardWireframe!
    private var publisher: FakePublisher!
    private var presenter: CardPresenter!

    override func setUp() {
        super.setUp()
        let suite = "card-upload-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        desks = FakeDeskInteractor()
        wireframe = FakeCardWireframe()
        publisher = FakePublisher()
        let desk = DeskEntity()
        desk.id = "d1"
        desk.name = "N5"
        desk.cards = [CardEntity(), CardEntity()]
        desks.decks = [desk]
        presenter = CardPresenter(interactor: CardInteractor(), deskInteractor: desks, wireframe: wireframe, defaults: defaults,
                                  server: FakeServerInteractor(), publisher: publisher)
        presenter.view = SpyCardView()
    }

    private func waitForMain() {
        let done = expectation(description: "main")
        DispatchQueue.main.async { DispatchQueue.main.async { done.fulfill() } }
        wait(for: [done], timeout: 2)
    }

    func test_nothingIsSentUntilTheLearnerConfirmsWithTheCountsShown() {
        presenter.uploadDeck(id: "d1")
        XCTAssertEqual(wireframe.uploadConfirmations.map(\.cards), [2])
        XCTAssertEqual(wireframe.uploadConfirmations.map(\.pictures), [2])
        XCTAssertTrue(publisher.published.isEmpty)
        wireframe.confirmTheUpload()
        XCTAssertEqual(publisher.published, ["d1"])
    }

    func test_signedOutLearnersAreAskedToSignInAndThenContinue() {
        publisher.isSignedIn = false
        presenter.uploadDeck(id: "d1")
        XCTAssertEqual(wireframe.signIns, 1)
        XCTAssertTrue(wireframe.uploadConfirmations.isEmpty)
        publisher.isSignedIn = true
        wireframe.finishSignIn()
        XCTAssertEqual(wireframe.uploadConfirmations.count, 1)
    }

    func test_aDeckAlreadyOnTheAccountIsNotSavedAgain() {
        publisher.linked = ["d1": "acc"]
        XCTAssertEqual(presenter.accountDeckId(forDeck: "d1"), "acc")
        presenter.uploadDeck(id: "d1")
        XCTAssertTrue(wireframe.uploadConfirmations.isEmpty)
        XCTAssertEqual(wireframe.alerts.count, 1)
    }

    func test_progressIsShownCancellableWhileUploadingAndNotOnceTheDeckIsBeingCreated() {
        presenter.uploadDeck(id: "d1")
        wireframe.confirmTheUpload()
        publisher.updates.onNext(.uploading(done: 1, total: 2))
        waitForMain()
        XCTAssertEqual(wireframe.progressCancellable.last, true)
        publisher.updates.onNext(.creating)
        waitForMain()
        XCTAssertEqual(wireframe.progressCancellable.last, false)
    }

    func test_finishingReportsWhatWasSavedAndAFailureReportsWhy() {
        presenter.uploadDeck(id: "d1")
        wireframe.confirmTheUpload()
        publisher.updates.onNext(.finished(DeckPublishReport(accountDeckId: "acc", cardCount: 2, uploaded: 1, reused: 0, skipped: 1)))
        waitForMain()
        XCTAssertEqual(wireframe.hidden, 1)
        XCTAssertEqual(wireframe.alerts.count, 1)

        let summary = CardPresenter.summary(of: DeckPublishReport(accountDeckId: "acc", cardCount: 2, uploaded: 1, reused: 0, skipped: 1))
        XCTAssertEqual(summary.components(separatedBy: "\n").count, 3, "Cards, pictures and left-out pictures each get a line")

        presenter.uploadDeck(id: "d1")
        wireframe.confirmTheUpload()
        publisher.updates.onError(LearnerAPIError.rateLimited)
        waitForMain()
        XCTAssertEqual(wireframe.hidden, 2)
        XCTAssertEqual(wireframe.alerts.count, 2)
    }
}
