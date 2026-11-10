import RxRelay
import RxSwift
import XCTest
@testable import FlashcardApp

final class DictionaryEntryPresenterTests: XCTestCase {
    private var interactor: FakeEntryInteractor!
    private var wireframe: FakeEntryWireframe!
    private var speech: FakeSpeech!
    private var preferences: FakePreferences!
    private var copied: [String] = []
    private var voiceAvailable = true
    private var notices: [EntryNotice] = []
    private var bag = DisposeBag()

    private let vocabItem = DictionaryItem(kind: .vocabulary, id: "9adc769d-2d6f-48a1-a9ca-5fe729033518", title: "食べる", reading: "たべる", meaning: "ăn", level: "N5")

    override func setUp() {
        super.setUp()
        interactor = FakeEntryInteractor()
        wireframe = FakeEntryWireframe()
        speech = FakeSpeech()
        preferences = FakePreferences()
        copied = []
        notices = []
        voiceAvailable = true
        bag = DisposeBag()
    }

    private func makePresenter(_ item: DictionaryItem? = nil) -> DictionaryEntryPresenter {
        let presenter = DictionaryEntryPresenter(item: item ?? vocabItem, interactor: interactor, wireframe: wireframe, speech: speech, preferences: preferences,
                                                 japaneseVoiceAvailable: { [unowned self] in voiceAvailable }, pasteboard: { [unowned self] in copied.append($0) })
        presenter.notices.subscribe(onNext: { [unowned self] in notices.append($0) }).disposed(by: bag)
        return presenter
    }

    private func vocabulary(_ id: String = "9adc769d-2d6f-48a1-a9ca-5fe729033518") -> EntryDetail {
        .vocabulary(VocabularyDetail(id: id, headword: "食べる", reading: "たべる", hanViet: "THỰC", level: "N5", meanings: [.init(text: "ăn", partOfSpeech: nil, note: nil)], pitch: []))
    }

    private func pump() { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }

    // MARK: Loading

    func testItShowsTheSearchRowAtOnceThenTheLoadedDetailWithItsRelatedParts() {
        interactor.detailResult = .just(vocabulary())
        interactor.kanjiResult = .just([KanjiReference(id: "k", character: "食", meaning: "THỰC")])
        interactor.examplesResult = .just([CardExample(id: "e", japanese: "食べるな。", reading: "たべるな。", translation: "Cấm ăn.")])
        let presenter = makePresenter()
        XCTAssertEqual(presenter.state.value.detail, .loading)
        XCTAssertEqual(presenter.state.value.item, vocabItem)
        presenter.viewDidLoad()
        pump()
        XCTAssertEqual(presenter.state.value.detail, .loaded(vocabulary()))
        XCTAssertEqual(presenter.state.value.kanji.value?.map(\.character), ["食"])
        XCTAssertEqual(presenter.state.value.examples.value?.count, 1)
        XCTAssertEqual(interactor.examplesCalls.first?.term, "食べる")
        XCTAssertEqual(interactor.examplesCalls.first?.reading, "たべる")
        XCTAssertEqual(interactor.viewed, [vocabItem], "Opening an entry puts it in the recently viewed list")
    }

    func testAFailedDetailShowsTheErrorAndRetryLoadsAgain() {
        interactor.detailResult = .error(LearnerAPIError.offline)
        let presenter = makePresenter()
        presenter.viewDidLoad()
        pump()
        XCTAssertEqual(presenter.state.value.detail, .failed(LearnerAPIError.offline.errorDescription!))
        interactor.detailResult = .just(vocabulary())
        presenter.retry()
        pump()
        XCTAssertEqual(presenter.state.value.detail, .loaded(vocabulary()))
        XCTAssertEqual(interactor.detailCalls, 2)
    }

    func testExamplesFailingDoesNotHideTheEntryAndCanBeRetriedOnTheirOwn() {
        interactor.detailResult = .just(vocabulary())
        interactor.examplesResult = .error(LearnerAPIError.rateLimited)
        let presenter = makePresenter()
        presenter.viewDidLoad()
        pump()
        XCTAssertEqual(presenter.state.value.detail, .loaded(vocabulary()))
        XCTAssertEqual(presenter.state.value.examples, .failed(LearnerAPIError.rateLimited.errorDescription!))
        interactor.examplesResult = .just([])
        presenter.retryExamples()
        pump()
        XCTAssertEqual(presenter.state.value.examples, .loaded([]))
        XCTAssertEqual(interactor.detailCalls, 1, "Only the sentences are asked for again")
    }

    func testKanjiLoadsItsStrokesWithTheHashTheApiPublished() throws {
        let kanji = KanjiDetail(id: "k1", character: "食", meaning: "THỰC", onyomi: [], kunyomi: [], strokeCount: 9, level: "N5", frequency: nil, explanation: [],
                                mnemonic: [], words: [], components: [], strokeHash: "abc")
        interactor.detailResult = .just(.kanji(kanji))
        interactor.strokeResult = .just(try KanjiStrokeDrawing(svg: KanjiStrokeDrawingTests.twoStrokes))
        let presenter = makePresenter(DictionaryItem(kind: .kanji, id: "k1", title: "食"))
        presenter.viewDidLoad()
        pump()
        XCTAssertEqual(interactor.strokeCalls.first?.hash, "abc")
        XCTAssertEqual(presenter.state.value.stroke.value?.strokes.count, 2)
    }

    func testAStrokeFileThatFailsVerificationShowsItsReasonAndNoDrawing() {
        let kanji = KanjiDetail(id: "k1", character: "食", meaning: nil, onyomi: [], kunyomi: [], strokeCount: nil, level: nil, frequency: nil, explanation: [],
                                mnemonic: [], words: [], components: [], strokeHash: "abc")
        interactor.detailResult = .just(.kanji(kanji))
        interactor.strokeResult = .error(DictionaryEntryError.strokeIntegrity)
        let presenter = makePresenter(DictionaryItem(kind: .kanji, id: "k1", title: "食"))
        presenter.viewDidLoad()
        pump()
        XCTAssertEqual(presenter.state.value.stroke, .failed(DictionaryEntryError.strokeIntegrity.errorDescription!))
    }

    func testGrammarLooksSentencesUpByItsCleanedPatternAndSentencesLookUpKanji() {
        let grammar = GrammarDetail(id: "g", pattern: "〜ても", meaning: "Dù...cũng...", level: "N4", category: nil, sections: [])
        interactor.detailResult = .just(.grammar(grammar))
        let presenter = makePresenter(DictionaryItem(kind: .grammar, id: "g", title: "〜ても"))
        presenter.viewDidLoad()
        pump()
        XCTAssertEqual(interactor.examplesCalls.first?.term, "ても")

        let sentence = DictionaryItem(kind: .sentence, id: "s", title: "食べるな。", reading: "たべるな。", meaning: "Cấm ăn.")
        interactor.detailResult = .just(.sentence(DictionaryEntryMapper.sentence(sentence)))
        let second = makePresenter(sentence)
        second.viewDidLoad()
        pump()
        XCTAssertEqual(interactor.kanjiTextCalls, ["食べるな。"])
        XCTAssertEqual(second.state.value.favorite, .unavailable)
    }

    // MARK: Favourite

    func testAGuestSeesSignedOutAndTappingAsksToSignInThenChecksTheState() {
        interactor.signedIn = false
        interactor.detailResult = .just(vocabulary())
        let presenter = makePresenter()
        presenter.viewDidLoad()
        pump()
        XCTAssertEqual(presenter.state.value.favorite, .signedOut)
        presenter.toggleFavorite()
        XCTAssertEqual(wireframe.signInRequests, 1)
        XCTAssertTrue(interactor.toggleCalls.isEmpty, "Nothing is written before the learner has signed in")
        interactor.signedIn = true
        interactor.favoriteCheck = .just(true)
        wireframe.finishSignIn?()
        pump()
        XCTAssertEqual(presenter.state.value.favorite, .on)
    }

    func testTogglingAddsAndRemovesAndTellsTheServerStateOnce() {
        interactor.detailResult = .just(vocabulary())
        interactor.favoriteCheck = .just(false)
        let presenter = makePresenter()
        presenter.viewDidLoad()
        pump()
        XCTAssertEqual(presenter.state.value.favorite, .off)
        interactor.toggleResult = .just(true)
        presenter.toggleFavorite()
        pump()
        XCTAssertEqual(presenter.state.value.favorite, .on)
        XCTAssertEqual(notices.last, .favoriteAdded)
        interactor.toggleResult = .just(false)
        presenter.toggleFavorite()
        pump()
        XCTAssertEqual(presenter.state.value.favorite, .off)
        XCTAssertEqual(notices.last, .favoriteRemoved)
        XCTAssertEqual(interactor.toggleCalls.count, 2)
    }

    func testADoubleTapSendsOneToggle() {
        interactor.detailResult = .just(vocabulary())
        interactor.favoriteCheck = .just(false)
        let presenter = makePresenter()
        presenter.viewDidLoad()
        pump()
        let pending = PublishSubject<Bool>()
        interactor.toggleResult = pending.asSingle()
        presenter.toggleFavorite()
        presenter.toggleFavorite()
        XCTAssertEqual(interactor.toggleCalls.count, 1, "A toggle is not idempotent: the second tap must not reach the server")
        XCTAssertEqual(presenter.state.value.favorite, .updating(true))
        pending.onNext(true)
        pending.onCompleted()
        pump()
        XCTAssertEqual(presenter.state.value.favorite, .on)
    }

    func testAFailedToggleRestoresTheStateAndANetworkBreakRechecksInsteadOfGuessing() {
        interactor.detailResult = .just(vocabulary())
        interactor.favoriteCheck = .just(false)
        let presenter = makePresenter()
        presenter.viewDidLoad()
        pump()
        interactor.toggleResult = .error(LearnerAPIError.server(500))
        presenter.toggleFavorite()
        pump()
        XCTAssertEqual(presenter.state.value.favorite, .off)
        guard case .failure? = notices.last else { return XCTFail("the failure is shown") }

        interactor.toggleResult = .error(LearnerAPIError.interrupted)
        interactor.favoriteCheck = .just(true)
        presenter.toggleFavorite()
        pump()
        XCTAssertEqual(presenter.state.value.favorite, .on, "The server may have applied the toggle; its own answer decides")
        XCTAssertEqual(interactor.checkCalls, 2)
    }

    func testAnExpiredSessionDuringToggleAsksToSignInAgain() {
        interactor.detailResult = .just(vocabulary())
        interactor.favoriteCheck = .just(false)
        let presenter = makePresenter()
        presenter.viewDidLoad()
        pump()
        interactor.toggleResult = .error(LearnerAPIError.signInRequired)
        presenter.toggleFavorite()
        pump()
        XCTAssertEqual(presenter.state.value.favorite, .signedOut)
        XCTAssertEqual(wireframe.signInRequests, 1)
    }

    func testWhenTheServerCannotBeAskedTheStateIsUnknownAndATapAsksAgainInsteadOfToggling() {
        interactor.detailResult = .just(vocabulary())
        interactor.favoriteCheck = .error(LearnerAPIError.offline)
        let presenter = makePresenter()
        presenter.viewDidLoad()
        pump()
        XCTAssertEqual(presenter.state.value.favorite, .unknown, "Neither saved nor unsaved may be claimed")
        interactor.favoriteCheck = .just(true)
        presenter.toggleFavorite()
        pump()
        XCTAssertTrue(interactor.toggleCalls.isEmpty, "The tap re-reads the state; it never writes while unsure")
        XCTAssertEqual(presenter.state.value.favorite, .on)
    }

    func testChangingAccountWhileTheEntryIsOpenRereadsTheSavedState() {
        interactor.detailResult = .just(vocabulary())
        interactor.favoriteCheck = .just(true)
        let presenter = makePresenter()
        presenter.viewDidLoad()
        pump()
        XCTAssertEqual(presenter.state.value.favorite, .on)
        presenter.viewWillAppear()
        XCTAssertEqual(interactor.checkCalls, 1, "Nothing changed: no extra request")
        interactor.signedIn = false
        presenter.viewWillAppear()
        XCTAssertEqual(presenter.state.value.favorite, .signedOut, "A logout must not leave the old account's Saved on screen")
    }

    // MARK: Actions

    func testSpeakingUsesAJapaneseVoiceAndExplainsWhenThereIsNone() {
        let presenter = makePresenter()
        presenter.speak("たべる")
        XCTAssertEqual(speech.spoken.first?.text, "たべる")
        XCTAssertEqual(speech.spoken.first?.language, "ja-JP")
        voiceAvailable = false
        presenter.speak("たべる")
        XCTAssertEqual(speech.spoken.count, 1)
        XCTAssertEqual(notices.last, .voiceUnavailable)
    }

    func testCopyWritesToThePasteboardAndConfirms() {
        let presenter = makePresenter()
        presenter.copy("食べる", what: "Word")
        XCTAssertEqual(copied, ["食べる"])
        XCTAssertEqual(notices.last, .copied(what: "Word"))
    }

    func testAddToDeckAsksWhichDeckAndSavesOnlyAfterTheChoice() {
        interactor.detailResult = .just(vocabulary())
        interactor.deckChoicesResult = [TodayDeckChoice(id: "d1", name: "My words", cardCount: 3)]
        let presenter = makePresenter()
        presenter.viewDidLoad()
        pump()
        presenter.addToDeck()
        XCTAssertEqual(wireframe.deckChooserCalls.first?.choices.map(\.id), ["d1"])
        XCTAssertTrue(interactor.saveCalls.isEmpty, "Never saves into a deck the learner has not chosen")
        interactor.saveResult = .success(DictionarySaveOutcome(deckID: "d1", deckName: "My words", wasAlreadyThere: false))
        wireframe.onDeckSelected?(.existing(deckID: "d1"))
        XCTAssertEqual(interactor.saveCalls.first?.card.front, "食べる")
        XCTAssertEqual(interactor.saveCalls.first?.target, .existing(deckID: "d1"))
        XCTAssertEqual(notices.last, .savedToDeck(name: "My words"))
    }

    func testAddToDeckReportsARepeatAndAFailure() {
        interactor.detailResult = .just(vocabulary())
        let presenter = makePresenter()
        presenter.viewDidLoad()
        pump()
        presenter.addToDeck()
        interactor.saveResult = .success(DictionarySaveOutcome(deckID: "d1", deckName: "My words", wasAlreadyThere: true))
        wireframe.onDeckSelected?(.existing(deckID: "d1"))
        XCTAssertEqual(notices.last, .alreadyInDeck(name: "My words"))
        interactor.saveResult = .failure(AppError.databaseWriteFailed("disk"))
        wireframe.onDeckSelected?(.existing(deckID: "d1"))
        guard case .failure? = notices.last else { return XCTFail("the failure is shown") }
    }

    func testAddToDeckBeforeTheEntryLoadedSaysThereIsNothingToSave() {
        interactor.detailResult = .never()
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.addToDeck()
        XCTAssertEqual(notices.last, .nothingToSave)
        XCTAssertTrue(wireframe.deckChooserCalls.isEmpty)
    }

    func testTheReadingsPreferenceIsRememberedAndShown() {
        let presenter = makePresenter()
        XCTAssertTrue(presenter.state.value.showReadings)
        presenter.setShowReadings(false)
        XCTAssertFalse(preferences.showReadings)
        XCTAssertFalse(presenter.state.value.showReadings)
    }

    // MARK: Navigation

    func testTappedRelatedItemsOpenTheirOwnEntries() {
        let presenter = makePresenter()
        presenter.openKanji(KanjiReference(id: "k", character: "食", meaning: "THỰC"))
        XCTAssertEqual(wireframe.shown.last, DictionaryItem(kind: .kanji, id: "k", title: "食", meaning: "THỰC"))

        interactor.wordResult = .just(DictionaryItem(kind: .vocabulary, id: "w", title: "食う"))
        presenter.openWord("食う", reading: "くう")
        pump()
        XCTAssertEqual(wireframe.shown.last?.id, "w")
        XCTAssertEqual(interactor.wordCalls.last?.reading, "くう")

        interactor.wordResult = .just(nil)
        presenter.openWord("謎語", reading: nil)
        pump()
        XCTAssertEqual(notices.last, .notFound(text: "謎語"))

        interactor.kanjiLookupResult = .just(DictionaryItem(kind: .kanji, id: "k2", title: "良"))
        presenter.openKanji(character: "良")
        pump()
        XCTAssertEqual(wireframe.shown.last?.id, "k2")

        presenter.open(example: CardExample(id: "s", japanese: "食べるな。", reading: "", translation: "Cấm ăn."))
        XCTAssertEqual(wireframe.shown.last, DictionaryItem(kind: .sentence, id: "s", title: "食べるな。", reading: nil, meaning: "Cấm ăn."))
    }

    func testSelectedTextIsLookedUpInTheDictionarySearch() {
        let presenter = makePresenter()
        presenter.lookUp("  食べる ")
        XCTAssertEqual(wireframe.lookedUp, ["食べる"])
        presenter.lookUp("   ")
        XCTAssertEqual(wireframe.lookedUp.count, 1)
    }
}

// MARK: Doubles

private final class FakeEntryInteractor: DictionaryEntryInteractorInterface {
    var signedIn = true
    var detailResult: Single<EntryDetail> = .never()
    var kanjiResult: Single<[KanjiReference]> = .just([])
    var examplesResult: Single<[CardExample]> = .just([])
    var strokeResult: Single<KanjiStrokeDrawing> = .never()
    var wordResult: Single<DictionaryItem?> = .just(nil)
    var kanjiLookupResult: Single<DictionaryItem?> = .just(nil)
    var favoriteCheck: Single<Bool> = .just(false)
    var toggleResult: Single<Bool> = .just(true)
    var deckChoicesResult: [TodayDeckChoice] = []
    var saveResult: Result<DictionarySaveOutcome, Error> = .success(DictionarySaveOutcome(deckID: "d", deckName: "d", wasAlreadyThere: false))

    var detailCalls = 0
    var viewed: [DictionaryItem] = []
    var examplesCalls: [(term: String, reading: String)] = []
    var strokeCalls: [(id: String, hash: String?)] = []
    var kanjiTextCalls: [String] = []
    var toggleCalls: [DictionaryItem] = []
    var checkCalls = 0
    var wordCalls: [(text: String, reading: String?)] = []
    var saveCalls: [(card: DictionaryCard, target: DictionaryDeckTarget)] = []

    var isSignedIn: Bool { signedIn }
    func detail(for item: DictionaryItem) -> Single<EntryDetail> { detailCalls += 1; return detailResult }
    func kanjiInWord(id: String) -> Single<[KanjiReference]> { kanjiResult }
    func kanjiInText(_ text: String) -> Single<[KanjiReference]> { kanjiTextCalls.append(text); return kanjiResult }
    func examples(term: String, reading: String) -> Single<[CardExample]> { examplesCalls.append((term, reading)); return examplesResult }
    func strokes(kanjiID: String, expectedHash: String?) -> Single<KanjiStrokeDrawing> { strokeCalls.append((kanjiID, expectedHash)); return strokeResult }
    func resolveWord(_ text: String, reading: String?) -> Single<DictionaryItem?> { wordCalls.append((text, reading)); return wordResult }
    func resolveKanji(_ character: String) -> Single<DictionaryItem?> { kanjiLookupResult }
    func isFavorite(_ item: DictionaryItem) -> Single<Bool> { checkCalls += 1; return favoriteCheck }
    func toggleFavorite(_ item: DictionaryItem) -> Single<Bool> { toggleCalls.append(item); return toggleResult }
    func recordViewed(_ item: DictionaryItem) { viewed.append(item) }
    func deckChoices() -> [TodayDeckChoice] { deckChoicesResult }
    func dictionaryDeckExists() -> Bool { false }
    func save(_ card: DictionaryCard, to target: DictionaryDeckTarget) throws -> DictionarySaveOutcome {
        saveCalls.append((card, target))
        return try saveResult.get()
    }
}

private final class FakeEntryWireframe: DictionaryEntryWireframeInterface {
    var shown: [DictionaryItem] = []
    var signInRequests = 0
    var finishSignIn: (() -> Void)?
    var deckChooserCalls: [(choices: [TodayDeckChoice], exists: Bool)] = []
    var onDeckSelected: ((DictionaryDeckTarget) -> Void)?
    var lookedUp: [String] = []
    var shared: [String] = []

    func showEntry(_ item: DictionaryItem) { shown.append(item) }
    func showDeckChooser(_ choices: [TodayDeckChoice], dictionaryDeckExists: Bool, onSelect: @escaping (DictionaryDeckTarget) -> Void) {
        deckChooserCalls.append((choices, dictionaryDeckExists))
        onDeckSelected = onSelect
    }
    func showSignIn(onFinish: @escaping () -> Void) { signInRequests += 1; finishSignIn = onFinish }
    func share(_ text: String) { shared.append(text) }
    func showSearch(for text: String) { lookedUp.append(text) }
    func openSystemSettings() {}
}

private final class FakeSpeech: SpeechServiceInterface {
    var spoken: [(text: String, language: String)] = []
    func speak(_ text: String, languageCode: String) { spoken.append((text, languageCode)) }
    func stop() {}
}

private final class FakePreferences: DictionaryPreferencesInterface {
    var showReadings = true
}
