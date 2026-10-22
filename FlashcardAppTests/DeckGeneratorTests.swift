import RealmSwift
import RxSwift
import XCTest
@testable import FlashcardApp

final class DeckGeneratorPresenterTests: XCTestCase {
    private var interactor: FakeGenerator!
    private var wireframe: FakeGeneratorWireframe!
    private var view: SpyGeneratorView!

    override func setUp() {
        super.setUp()
        interactor = FakeGenerator()
        wireframe = FakeGeneratorWireframe()
        view = SpyGeneratorView()
    }

    private func makePresenter() -> DeckGeneratorPresenter {
        let presenter = DeckGeneratorPresenter(interactor: interactor, wireframe: wireframe, previewDelay: .milliseconds(30))
        presenter.view = view
        presenter.viewDidLoad()
        return presenter
    }

    private func settle(_ seconds: TimeInterval = 0.2) {
        let done = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
        wait(for: [done], timeout: seconds + 2)
    }

    private func readyPresenter(available: Int = 500) -> DeckGeneratorPresenter {
        let presenter = makePresenter()
        settle()
        interactor.previews.last?.subject.onNext(available)
        waitForMain()
        return presenter
    }

    private let receipt = GeneratedDeckReceipt(id: "11111111-2222-4333-8444-555555555555", name: "N5 · Vocabulary", cardCount: 20, direction: .japaneseToVietnamese)

    private func generatedDeck() -> GeneratedDeck {
        GeneratedDeck(id: receipt.id, name: receipt.name, direction: .japaneseToVietnamese,
                      cards: [.init(id: "a1", front: "犬", back: "chó", reading: "いぬ"), .init(id: "a2", front: "猫", back: "mèo", reading: "ねこ")])
    }

    // MARK: Preview

    func test_openingPreviewsTheDefaultChoices() {
        let presenter = readyPresenter(available: 1240)
        XCTAssertEqual(interactor.previews.map(\.level), [.n5])
        XCTAssertEqual(interactor.previews.map(\.types), [[.vocabulary]])
        XCTAssertEqual(presenter.state.preview, .ready(available: 1240))
        XCTAssertEqual(presenter.state.expectedCount, 20)
        XCTAssertTrue(presenter.state.canGenerate)
        XCTAssertEqual(presenter.state.request.name, "N5 · \(GenerationContentType.vocabulary.title)")
    }

    func test_aBurstOfChoicesAsksTheServerOnce() {
        let presenter = makePresenter()
        presenter.setLevel(.n4)
        presenter.setLevel(.n3)
        presenter.toggle(.kanji)
        settle()
        XCTAssertEqual(interactor.previews.count, 1)
        XCTAssertEqual(interactor.previews[0].level, .n3)
        XCTAssertEqual(interactor.previews[0].types, [.kanji, .vocabulary])
    }

    func test_aNewChoiceCancelsThePreviewStillRunningAndIgnoresItsAnswer() {
        let presenter = makePresenter()
        settle()
        presenter.setLevel(.n2)
        settle()
        XCTAssertEqual(interactor.previews.count, 2)
        XCTAssertEqual(interactor.previews[0].disposed, true, "The older count request is cancelled")
        interactor.previews[0].subject.onNext(999)
        interactor.previews[1].subject.onNext(42)
        XCTAssertEqual(presenter.state.preview, .ready(available: 42))
    }

    func test_aFailedPreviewCanBeRetriedAndBlocksGenerating() {
        let presenter = makePresenter()
        settle()
        interactor.previews[0].subject.onError(LearnerAPIError.offline)
        guard case .failed = presenter.state.preview else { return XCTFail("\(presenter.state.preview)") }
        XCTAssertFalse(presenter.state.canGenerate)
        presenter.retryPreview()
        settle()
        XCTAssertEqual(interactor.previews.count, 2)
    }

    func test_signedOutShowsSignInAndNeverCallsTheServer() {
        interactor.signedIn = false
        let presenter = makePresenter()
        settle()
        XCTAssertTrue(interactor.previews.isEmpty)
        XCTAssertEqual(presenter.state.preview, .signInRequired)
        XCTAssertFalse(presenter.state.canGenerate)
        presenter.signIn()
        interactor.signedIn = true
        wireframe.finishSignIn?()
        settle()
        XCTAssertEqual(interactor.previews.count, 1, "After signing in the count is requested")
    }

    func test_tooFewCardsBlockGenerating() {
        let presenter = readyPresenter(available: 1)
        XCTAssertFalse(presenter.state.canGenerate)
        XCTAssertEqual(readyPresenter(available: 2).state.canGenerate, true)
    }

    func test_fewerCardsThanRequestedShrinkTheExpectedCount() {
        let presenter = readyPresenter(available: 8)
        XCTAssertEqual(presenter.state.expectedCount, 8)
    }

    // MARK: Choices

    func test_atLeastOneKindOfContentStaysSelected() {
        let presenter = makePresenter()
        presenter.toggle(.vocabulary)
        XCTAssertEqual(presenter.state.request.contentTypes, [.vocabulary])
        presenter.toggle(.grammar)
        presenter.toggle(.vocabulary)
        XCTAssertEqual(presenter.state.request.contentTypes, [.grammar])
    }

    func test_theSuggestedNameFollowsTheChoicesUntilTheLearnerEditsIt() {
        let presenter = makePresenter()
        presenter.setLevel(.n3)
        XCTAssertEqual(presenter.state.request.name, "N3 · \(GenerationContentType.vocabulary.title)")
        presenter.setName("My deck")
        presenter.setLevel(.n2)
        XCTAssertEqual(presenter.state.request.name, "My deck")
    }

    func test_countSnapsToFivesWithinTheAllowedRange() {
        let presenter = makePresenter()
        for (input, expected) in [(23, 25), (22, 20), (0, 5), (500, 100), (100, 100)] {
            presenter.setCount(input)
            XCTAssertEqual(presenter.state.request.count, expected, "\(input)")
        }
    }

    func test_aBlankNameBlocksGenerating() {
        let presenter = readyPresenter()
        presenter.setName("   ")
        XCTAssertFalse(presenter.state.canGenerate)
        XCTAssertEqual(presenter.state.request.issues, [.nameEmpty])
        presenter.generate()
        XCTAssertEqual(interactor.generateCalls, 0)
    }

    // MARK: Generating

    func test_generatingCreatesTheDeckOnceDownloadsItAndOpensTheImportedDeck() {
        let presenter = readyPresenter()
        presenter.generate()
        XCTAssertEqual(presenter.state.phase, .generating)
        XCTAssertFalse(presenter.state.canGenerate)
        presenter.generate()
        presenter.generate()
        XCTAssertEqual(interactor.generateCalls, 1, "Repeated taps never create a second deck")
        interactor.generation.onNext(receipt)
        waitForMain()
        XCTAssertEqual(presenter.state.phase, .downloading)
        XCTAssertEqual(interactor.downloads, [receipt])
        interactor.download.onNext(generatedDeck())
        waitForMain()
        XCTAssertEqual(interactor.imported.map(\.id), [receipt.id])
        XCTAssertEqual(wireframe.shown, [receipt.id])
    }

    func test_theRequestSentIsExactlyWhatWasChosen() {
        let presenter = readyPresenter()
        presenter.setLevel(.n2)
        presenter.toggle(.grammar)
        presenter.setDirection(.vietnameseToJapanese)
        presenter.setCount(40)
        presenter.setName(" Mine ")
        settle()
        interactor.previews.last?.subject.onNext(300)
        presenter.generate()
        let sent = interactor.requests.first
        XCTAssertEqual(sent?.level, .n2)
        XCTAssertEqual(sent?.sourceTypes, ["lexeme", "grammar"])
        XCTAssertEqual(sent?.direction, .vietnameseToJapanese)
        XCTAssertEqual(sent?.count, 40)
        XCTAssertEqual(sent?.trimmedName, "Mine")
    }

    func test_choicesAreLockedWhileTheServerWorks() {
        let presenter = readyPresenter()
        presenter.generate()
        presenter.setLevel(.n1)
        presenter.setCount(50)
        presenter.toggle(.kanji)
        XCTAssertEqual(presenter.state.request.level, .n5)
        XCTAssertEqual(presenter.state.request.count, 20)
        presenter.close()
        XCTAssertEqual(wireframe.closes, 0, "Closing would cancel a deck creation whose outcome is then unknown")
    }

    func test_aBrokenConnectionWarnsAboutADuplicateAndNeverRetriesByItself() {
        let presenter = readyPresenter()
        presenter.generate()
        interactor.generation.onError(LearnerAPIError.interrupted)
        waitForMain()
        XCTAssertEqual(presenter.state.phase, .editing)
        XCTAssertTrue(presenter.state.notice?.contains(NSLocalizedString("The deck may already have been created in your account on the website. Check there before generating again, or you may get a second copy.", comment: "")) == true)
        settle()
        XCTAssertEqual(interactor.generateCalls, 1)
        XCTAssertNil(presenter.state.pendingDownload, "Nothing is known to exist on the server")
        presenter.generate()
        XCTAssertEqual(interactor.generateCalls, 2, "Only the learner's own tap starts another attempt")
    }

    func test_everyOutcomeThatMayFollowAServerCommitWarnsAboutADuplicate() {
        let warning = NSLocalizedString("The deck may already have been created in your account on the website. Check there before generating again, or you may get a second copy.", comment: "")
        for error: LearnerAPIError in [.interrupted, .staleSession, .serviceUnavailable(nil), .server(504), .server(500), .invalidResponse] {
            XCTAssertTrue(DeckGeneratorPresenter.notice(forGenerationError: error).contains(warning), "\(error)")
        }
        for error: LearnerAPIError in [.invalidRequest(nil), .rateLimited, .originRejected, .forbidden(nil), .signInRequired] {
            XCTAssertFalse(DeckGeneratorPresenter.notice(forGenerationError: error).contains(warning), "\(error) was refused before anything was created")
        }
    }

    func test_aFailureBeforeAnythingWasSentSaysNothingWasCreated() {
        let presenter = readyPresenter()
        presenter.generate()
        interactor.generation.onError(LearnerAPIError.offline)
        waitForMain()
        XCTAssertTrue(presenter.state.notice?.contains(NSLocalizedString("Nothing was created.", comment: "")) == true)
    }

    func test_aRejectedSessionAsksToSignInAgain() {
        let presenter = readyPresenter()
        presenter.generate()
        interactor.generation.onError(LearnerAPIError.signInRequired)
        waitForMain()
        XCTAssertEqual(presenter.state.preview, .signInRequired)
        XCTAssertFalse(presenter.state.canGenerate)
    }

    func test_aFailedDownloadRetriesOnlyTheReadNeverTheCreation() {
        let presenter = readyPresenter()
        presenter.generate()
        interactor.generation.onNext(receipt)
        waitForMain()
        interactor.download.onError(LearnerAPIError.interrupted)
        waitForMain()
        XCTAssertEqual(presenter.state.phase, .editing)
        XCTAssertEqual(presenter.state.pendingDownload, receipt)
        XCTAssertNotNil(presenter.state.notice)
        XCTAssertTrue(presenter.state.canGenerate, "The primary action now downloads")
        interactor.download = PublishSubject<GeneratedDeck>()
        presenter.generate()
        XCTAssertEqual(interactor.generateCalls, 1, "The deck already exists on the server")
        XCTAssertEqual(interactor.downloads, [receipt, receipt])
        interactor.download.onNext(generatedDeck())
        waitForMain()
        XCTAssertEqual(wireframe.shown, [receipt.id])
    }

    func test_aLocalSaveFailureKeepsTheDownloadForARetry() {
        let presenter = readyPresenter()
        presenter.generate()
        interactor.generation.onNext(receipt)
        waitForMain()
        interactor.importError = AppError.databaseWriteFailed("disk full")
        interactor.download.onNext(generatedDeck())
        waitForMain()
        XCTAssertTrue(wireframe.shown.isEmpty)
        XCTAssertEqual(presenter.state.phase, .editing)
        XCTAssertNotNil(presenter.state.notice)
        XCTAssertEqual(presenter.state.pendingDownload, receipt)
    }

    func test_aDeckThatIsAlreadyOnTheDeviceIsOpenedNotDuplicated() {
        let presenter = readyPresenter()
        interactor.outcome = { .alreadyPresent(deckId: $0.id) }
        presenter.generate()
        interactor.generation.onNext(receipt)
        waitForMain()
        interactor.download.onNext(generatedDeck())
        waitForMain()
        XCTAssertEqual(wireframe.shown, [receipt.id])
    }

    func test_closingWhenIdleDismissesTheGenerator() {
        let presenter = makePresenter()
        presenter.close()
        XCTAssertEqual(wireframe.closes, 1)
    }

    /// `observe(on: MainScheduler)` hops once; let it run.
    private func waitForMain() {
        let done = expectation(description: "main")
        DispatchQueue.main.async { DispatchQueue.main.async { done.fulfill() } }
        wait(for: [done], timeout: 2)
    }
}

// MARK: - Mapping and local identity

final class DeckGeneratorInteractorTests: XCTestCase {
    private var repository: DeskManagement!
    private var interactor: DeckGeneratorInteractor!
    private let deckId = "11111111-2222-4333-8444-555555555555"

    override func setUpWithError() throws {
        let configuration = Realm.Configuration(inMemoryIdentifier: "generator-\(UUID().uuidString)", objectTypes: [RDesk.self, RCard.self])
        RealmService.shared.realm = try Realm(configuration: configuration)
        repository = DeskManagement()
        interactor = DeckGeneratorInteractor(api: UnusedAPI(), repository: repository, auth: AuthSession(tokens: NoTokens(), api: NoAuth()))
    }

    override func tearDownWithError() throws {
        RealmService.shared.realm = nil
    }

    private func remote(cardIds: [String] = ["aaaaaaaa-0000-4000-8000-000000000001", "aaaaaaaa-0000-4000-8000-000000000002"]) -> BJTRemoteDeckDTO {
        func entry(_ id: String, _ position: Int, _ front: String, _ back: String, _ reading: String?) -> BJTRemoteDeckDTO.Entry {
            .init(id: id, position: position, card: .init(id: "variant-\(position)", frontText: front, backText: back, reading: reading, sourceId: "s", sourceType: "lexeme"))
        }
        return BJTRemoteDeckDTO(id: deckId, titleVi: "N5", cards: [entry(cardIds[1], 1, "猫", "mèo", "ねこ"), entry(cardIds[0], 0, "犬", "chó", " いぬ ")])
    }

    func test_cardsKeepTheServersOrderAndIds() throws {
        let deck = try DeckGeneratorInteractor.deck(from: remote(), direction: .japaneseToVietnamese)
        XCTAssertEqual(deck.id, deckId)
        XCTAssertEqual(deck.cards.map(\.front), ["犬", "猫"])
        XCTAssertEqual(deck.cards.map(\.id), ["aaaaaaaa-0000-4000-8000-000000000001", "aaaaaaaa-0000-4000-8000-000000000002"])
        XCTAssertEqual(deck.cards[0].reading, "いぬ")
    }

    func test_aMalformedIdFromTheServerIsRefusedNotInvented() {
        XCTAssertThrowsError(try DeckGeneratorInteractor.deck(from: remote(cardIds: ["not-a-uuid", "aaaaaaaa-0000-4000-8000-000000000002"]), direction: .both)) {
            XCTAssertEqual($0 as? LearnerAPIError, .invalidResponse)
        }
    }

    func test_theReadingBelongsToTheJapaneseSideWhicheverSideThatIs() {
        let deck = GeneratedDeck(id: deckId, name: "N5", direction: .both, cards: [
            .init(id: "c1", front: "犬", back: "chó", reading: "いぬ"),
            .init(id: "c2", front: "mèo", back: "猫", reading: "ねこ"),
            .init(id: "c3", front: "ăn", back: "ăn", reading: "x")
        ])
        let entity = DeckGeneratorInteractor.entity(from: deck)
        XCTAssertEqual(entity.id, deckId)
        XCTAssertEqual(entity.sortingLanguage, .normal)
        XCTAssertEqual(entity.cards[0].frontExtraText, "いぬ")
        XCTAssertEqual(entity.cards[0].backExtraText, "")
        XCTAssertEqual(entity.cards[1].frontExtraText, "")
        XCTAssertEqual(entity.cards[1].backExtraText, "ねこ")
        XCTAssertEqual(entity.cards[2].frontExtraText + entity.cards[2].backExtraText, "", "A reading is never attached to text that is not Japanese")
    }

    func test_theDirectionDecidesTheLocalDeckDirection() {
        XCTAssertEqual(GenerationDirection.japaneseToVietnamese.localDirection, .normal)
        XCTAssertEqual(GenerationDirection.vietnameseToJapanese.localDirection, .opposite)
        XCTAssertEqual(GenerationDirection.both.localDirection, .normal)
    }

    func test_importingStoresTheDeckUnderTheServersIds() throws {
        let deck = try DeckGeneratorInteractor.deck(from: remote(), direction: .japaneseToVietnamese)
        XCTAssertEqual(try interactor.importDeck(deck), .imported(deckId: deckId))
        let stored = try XCTUnwrap(repository.desk(withId: deckId))
        XCTAssertEqual(stored.name, "N5")
        XCTAssertEqual(stored.cards.map(\.id), deck.cards.map(\.id))
        XCTAssertEqual(stored.cards[0].frontExtraText, "いぬ")
    }

    func test_importingTheSameServerDeckTwiceNeverDuplicatesIt() throws {
        let deck = try DeckGeneratorInteractor.deck(from: remote(), direction: .japaneseToVietnamese)
        _ = try interactor.importDeck(deck)
        XCTAssertEqual(try interactor.importDeck(deck), .alreadyPresent(deckId: deckId))
        XCTAssertEqual(repository.getAll().count, 1)
    }

    func test_twoGeneratedDecksMayShareTheSameFlashcardVariants() throws {
        // The server draws random variants, so the same variant can be in two decks; each membership has its own id.
        var second = remote(cardIds: ["cccccccc-0000-4000-8000-000000000001", "cccccccc-0000-4000-8000-000000000002"])
        second = BJTRemoteDeckDTO(id: "99999999-2222-4333-8444-555555555555", titleVi: "N5 again", cards: second.cards)
        _ = try interactor.importDeck(DeckGeneratorInteractor.deck(from: remote(), direction: .japaneseToVietnamese))
        _ = try interactor.importDeck(DeckGeneratorInteractor.deck(from: second, direction: .japaneseToVietnamese))
        XCTAssertEqual(repository.getAll().count, 2)
        XCTAssertEqual(repository.getAll().flatMap(\.cards).count, 4)
    }

    func test_anImportedDeckIsAnOrdinaryEditableDeck() throws {
        _ = try interactor.importDeck(DeckGeneratorInteractor.deck(from: remote(), direction: .japaneseToVietnamese))
        let editor = CreateDeskInteractor(repository: repository, drafts: DeckDraftStore(defaults: UserDefaults(suiteName: "gen-\(UUID().uuidString)")!),
                                          images: CardImageStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("gen-\(UUID().uuidString)")))
        var draft = DeckDraft(entity: try XCTUnwrap(repository.desk(withId: deckId)))
        draft.cards[0].back = "con chó"
        try editor.save(draft)
        XCTAssertEqual(repository.desk(withId: deckId)?.cards[0].backText, "con chó")
        XCTAssertEqual(repository.desk(withId: deckId)?.cards[0].id, "aaaaaaaa-0000-4000-8000-000000000001", "Editing keeps the card ids")
    }
}

// MARK: - Doubles

private final class UnusedAPI: BJTLearnerAPIInterface {
    func previewGeneration(level: GenerationLevel, contentTypes: [GenerationContentType]) -> Single<Int> { fatalError() }
    func generateDeck(_ request: DeckGenerationRequest) -> Single<BJTGeneratedDeckDTO> { fatalError() }
    func deck(id: String) -> Single<BJTRemoteDeckDTO> { fatalError() }
    func searchImages(query: String, limit: Int) -> Single<[BJTImageResultDTO]> { fatalError() }
}

private final class NoTokens: AuthTokenManagerInterface {
    var accessToken: String? { nil }
    var userId: String? { nil }
    func save(accessToken: String, userId: String) throws {}
    func clear() throws {}
}

private final class NoAuth: NativeAuthAPIInterface {
    func login(email: String, password: String) -> Single<NativeLoginResponse> { fatalError() }
    func me(token: @escaping () -> String?) -> Single<NativeProfile> { fatalError() }
    func logout(token: @escaping () -> String?) -> Single<Void> { fatalError() }
}

private final class FakeGenerator: DeckGeneratorInteractorInterface {
    final class Preview {
        let level: GenerationLevel
        let types: [GenerationContentType]
        let subject = PublishSubject<Int>()
        var disposed = false
        init(level: GenerationLevel, types: [GenerationContentType]) { self.level = level; self.types = types }
    }

    var signedIn = true
    var previews: [Preview] = []
    var requests: [DeckGenerationRequest] = []
    var generation = PublishSubject<GeneratedDeckReceipt>()
    var download = PublishSubject<GeneratedDeck>()
    var downloads: [GeneratedDeckReceipt] = []
    var imported: [GeneratedDeck] = []
    var importError: Error?
    var outcome: (GeneratedDeck) -> DeckImportOutcome = { .imported(deckId: $0.id) }
    var generateCalls: Int { requests.count }
    var isSignedIn: Bool { signedIn }

    func preview(level: GenerationLevel, contentTypes: [GenerationContentType]) -> Single<Int> {
        let preview = Preview(level: level, types: contentTypes)
        previews.append(preview)
        return preview.subject.take(1).asSingle().do(onDispose: { preview.disposed = true })
    }

    func generate(_ request: DeckGenerationRequest) -> Single<GeneratedDeckReceipt> {
        requests.append(request)
        generation = PublishSubject<GeneratedDeckReceipt>()
        return generation.take(1).asSingle()
    }

    func download(_ receipt: GeneratedDeckReceipt) -> Single<GeneratedDeck> {
        downloads.append(receipt)
        return download.take(1).asSingle()
    }

    func importDeck(_ deck: GeneratedDeck) throws -> DeckImportOutcome {
        if let importError { throw importError }
        imported.append(deck)
        return outcome(deck)
    }
}

private final class FakeGeneratorWireframe: DeckGeneratorWireframeInterface {
    var shown: [String] = []
    var closes = 0
    var finishSignIn: (() -> Void)?
    func showDeck(withId id: String) { shown.append(id) }
    func showSignIn(onFinish: @escaping () -> Void) { finishSignIn = onFinish }
    func close() { closes += 1 }
    func showAlert(with title: String?, message: String?) {}
}

private final class SpyGeneratorView: DeckGeneratorViewInterface {
    var states: [DeckGeneratorState] = []
    func render(_ state: DeckGeneratorState) { states.append(state) }
}
