import RxSwift
import XCTest
@testable import FlashcardApp

final class CardStudyPresenterTests: XCTestCase {
    private var interactor: FakeStudyInteractor!
    private var wireframe: FakeStudyWireframe!
    private var preferences: FakeStudyPreferences!
    private var speech: FakeSpeech!
    private var examples: FakeExamples!
    private var view: SpyStudyView!
    private var presenter: CardStudyPresenter!

    override func setUp() {
        super.setUp()
        interactor = FakeStudyInteractor()
        wireframe = FakeStudyWireframe()
        preferences = FakeStudyPreferences()
        speech = FakeSpeech()
        examples = FakeExamples()
        view = SpyStudyView()
        interactor.deck = makeDeck(3)
    }

    private func makeDeck(_ count: Int, direction: LanguageSortingType = .normal) -> DeskEntity {
        let entity = DeskEntity()
        entity.id = "deck"
        entity.name = "Deck"
        entity.sortingLanguage = direction
        entity.cards = (1...count).map { index in
            let card = CardEntity()
            card.id = "c\(index)"
            card.frontText = "F\(index)"
            card.backText = "B\(index)"
            return card
        }
        return entity
    }

    private func start() {
        presenter = CardStudyPresenter(deckId: "deck", interactor: interactor, wireframe: wireframe, preferences: preferences,
                                       speech: speech, random: { $0.lowerBound }, examples: examples)
        presenter.view = view
        presenter.viewWillAppear()
    }

    private var state: CardStudyState { view.renders.last!.state }

    func test_opensOnTheFirstCardWithAShowAnswerButton() {
        start()
        XCTAssertEqual(state.card?.front, "F1")
        XCTAssertEqual(state.card?.isFlipped, false)
        XCTAssertEqual(state.primaryTitle, NSLocalizedString("Show answer", comment: ""))
        XCTAssertEqual(state.progress, 1.0 / 3.0, accuracy: 0.001)
    }

    func test_primaryButtonFlipsThenAdvancesThenFinishes() {
        start()
        presenter.primaryAction()
        XCTAssertEqual(state.card?.isFlipped, true)
        XCTAssertEqual(view.renders.last?.transition, .flip)
        XCTAssertEqual(state.primaryTitle, NSLocalizedString("Next card", comment: ""))
        presenter.primaryAction()
        XCTAssertEqual(state.card?.front, "F2")
        presenter.next(); presenter.flip()
        XCTAssertEqual(state.primaryTitle, NSLocalizedString("Finish", comment: ""))
        presenter.primaryAction()
        XCTAssertEqual(state.screen, .finished)
        XCTAssertEqual(state.summary.total, 3)
        XCTAssertEqual(state.primaryTitle, NSLocalizedString("Study again", comment: ""))
        presenter.primaryAction()
        XCTAssertEqual(state.screen, .card)
        XCTAssertEqual(state.card?.front, "F1")
    }

    func test_previousAndSkipMoveWithoutFlipping() {
        start()
        presenter.next()
        presenter.previous()
        XCTAssertEqual(state.card?.front, "F1")
        XCTAssertEqual(view.renders.last?.transition, .backward)
    }

    func test_quizNeedsAnAnswerBeforeMovingOn() {
        preferences.mode = .quiz
        start()
        XCTAssertEqual(state.mode, .quiz)
        XCTAssertEqual(state.primaryTitle, NSLocalizedString("Choose an answer", comment: ""))
        XCTAssertFalse(state.isPrimaryEnabled)
        presenter.next()
        XCTAssertEqual(state.card?.front, "F1", "An unanswered question cannot be skipped")
        presenter.select(option: "B1")
        XCTAssertEqual(state.quiz?.selected, "B1")
        XCTAssertTrue(state.isPrimaryEnabled)
        XCTAssertEqual(state.primaryTitle, NSLocalizedString("Next question", comment: ""))
        presenter.primaryAction()
        XCTAssertEqual(state.card?.front, "F2")
        XCTAssertEqual(state.summary.correct, 1)
    }

    func test_modeShuffleAndDisplayChoicesArePersisted() {
        start()
        presenter.setMode(.quiz)
        presenter.setShuffled(true)
        presenter.setReadingVisible(false)
        presenter.setImagesVisible(false)
        XCTAssertEqual(preferences.mode, .quiz)
        XCTAssertTrue(preferences.isShuffled)
        XCTAssertFalse(preferences.isReadingVisible)
        XCTAssertFalse(preferences.areImagesVisible)
        XCTAssertFalse(state.readingVisible)
        XCTAssertTrue(state.isShuffled)
    }

    func test_speakingReadsTheVisibleSideInItsLanguage() {
        start()
        presenter.speakCurrent()
        XCTAssertEqual(speech.spoken.last?.0, "F1")
        XCTAssertEqual(speech.spoken.last?.1, "ja-JP")
        presenter.flip()
        presenter.speakCurrent()
        XCTAssertEqual(speech.spoken.last?.0, "B1")
        XCTAssertEqual(speech.spoken.last?.1, "vi-VN")
    }

    func test_aCardWrittenInJapaneseOnOneSideIsSpokenAsJapaneseWhicheverWayTheDeckPoints() {
        // A generated deck can mix directions: the second card has Vietnamese on the front of a Japanese-first deck.
        let deck = makeDeck(2)
        deck.cards[0].frontText = "犬"; deck.cards[0].backText = "chó"
        deck.cards[1].frontText = "mèo"; deck.cards[1].backText = "猫"
        interactor.deck = deck
        start()
        presenter.speakCurrent()
        XCTAssertEqual(speech.spoken.last?.1, "ja-JP")
        presenter.next()
        presenter.speakCurrent()
        XCTAssertEqual(speech.spoken.last?.0, "mèo")
        XCTAssertEqual(speech.spoken.last?.1, "vi-VN", "The front of this card is Vietnamese even though the deck says Japanese first")
        presenter.flip()
        presenter.speakCurrent()
        XCTAssertEqual(speech.spoken.last?.0, "猫")
        XCTAssertEqual(speech.spoken.last?.1, "ja-JP")
    }

    func test_aReversedDeckSpeaksVietnameseOnTheFront() {
        interactor.deck = makeDeck(2, direction: .opposite)
        start()
        presenter.speakCurrent()
        XCTAssertEqual(speech.spoken.last?.1, "vi-VN")
        XCTAssertEqual(state.direction, .opposite)
    }

    func test_autoSpeakReadsEachNewCardAndStopsWhenDisabled() {
        preferences.autoSpeak = true
        start()
        presenter.next()
        XCTAssertEqual(speech.spoken.last?.0, "F2")
        presenter.setAutoSpeak(false)
        XCTAssertGreaterThan(speech.stopCount, 0)
        let spokenBefore = speech.spoken.count
        presenter.next()
        XCTAssertEqual(speech.spoken.count, spokenBefore)
    }

    func test_leavingStopsSpeech() {
        start()
        presenter.viewWillDisappear()
        XCTAssertEqual(speech.stopCount, 1)
    }

    func test_aDeckDeletedMeanwhileClosesTheScreen() {
        start()
        interactor.deck = nil
        presenter.viewWillAppear()
        XCTAssertEqual(wireframe.leaveCount, 1)
    }

    func test_returningFromTheEditorKeepsTheSessionWhenNothingChanged() {
        start()
        presenter.next()
        presenter.viewWillAppear()
        XCTAssertEqual(state.card?.front, "F2")
    }

    func test_returningFromTheEditorRestartsWhenTheCardsChanged() {
        start()
        presenter.next()
        interactor.deck = makeDeck(5)
        presenter.viewWillAppear()
        XCTAssertEqual(state.card?.front, "F1")
        XCTAssertEqual(state.progressText, String(format: NSLocalizedString("%1$lld of %2$lld", comment: ""), 1, 5))
    }

    func test_editOpensTheEditorForThisDeck() {
        start()
        presenter.edit()
        XCTAssertEqual(wireframe.editedDeckId, "deck")
    }

    // MARK: Example sentences

    private func japaneseDeck() {
        let deck = makeDeck(2)
        deck.cards[0].frontText = "犬"; deck.cards[0].frontExtraText = "いぬ"; deck.cards[0].backText = "chó"
        deck.cards[1].frontText = "猫"; deck.cards[1].backText = "mèo"
        interactor.deck = deck
    }

    private func sentence(_ id: String, _ japanese: String = "犬が好きです。") -> CardExample {
        CardExample(id: id, japanese: japanese, reading: "いぬがすきです。", translation: "Tôi thích chó.")
    }

    private func deliver(_ examples: [CardExample], request: Int = 0) {
        self.examples.subjects[request].onNext(examples)
        self.examples.subjects[request].onCompleted()
        waitForMain()
    }

    private func waitForMain() {
        let done = expectation(description: "main")
        DispatchQueue.main.async { DispatchQueue.main.async { done.fulfill() } }
        wait(for: [done], timeout: 2)
    }

    func test_theSentencesAreLookedUpWhenTheCardAppearsButShownOnlyAfterTheAnswer() {
        japaneseDeck()
        start()
        XCTAssertEqual(examples.requests.map(\.term), ["犬"], "Prefetched while the front is showing")
        XCTAssertEqual(examples.requests.first?.reading, "いぬ")
        XCTAssertEqual(state.examples, .hidden, "The front must not give the word's use away")
        deliver([sentence("1")])
        XCTAssertEqual(state.examples, .hidden)
        presenter.flip()
        XCTAssertEqual(state.examples, .results([sentence("1")]))
    }

    func test_theLookupIsVisibleAsLoadingUntilItAnswers() {
        japaneseDeck()
        start()
        presenter.flip()
        XCTAssertEqual(state.examples, .loading)
        deliver([])
        XCTAssertEqual(state.examples, .empty)
    }

    func test_aFailedLookupIsUnavailableAndRetryAsksAgain() {
        japaneseDeck()
        start()
        presenter.flip()
        examples.subjects[0].onError(LearnerAPIError.offline)
        waitForMain()
        XCTAssertEqual(state.examples, .unavailable)
        presenter.retryExamples()
        XCTAssertEqual(examples.requests.count, 2)
        XCTAssertEqual(state.examples, .loading)
        deliver([sentence("1")], request: 1)
        XCTAssertEqual(state.examples, .results([sentence("1")]))
    }

    func test_aLateAnswerForACardThatWasLeftIsDropped() {
        japaneseDeck()
        start()
        presenter.next()
        XCTAssertEqual(examples.requests.map(\.term), ["犬", "猫"])
        deliver([sentence("old")], request: 0)
        presenter.flip()
        XCTAssertEqual(state.card?.front, "猫")
        XCTAssertEqual(state.examples, .loading, "The sentence for the first card must not appear under the second")
        deliver([sentence("new", "猫がいます。")], request: 1)
        XCTAssertEqual(state.examples, .results([sentence("new", "猫がいます。")]))
    }

    func test_aCardWithoutAJapaneseWordHasNoSentencesAndNoRequest() {
        start()
        presenter.flip()
        XCTAssertTrue(examples.requests.isEmpty)
        XCTAssertEqual(state.examples, .hidden)
    }

    func test_aQuizShowsTheSentencesOnlyAfterAnAnswer() {
        japaneseDeck()
        preferences.mode = .quiz
        start()
        deliver([sentence("1")])
        XCTAssertEqual(state.examples, .hidden)
        presenter.select(option: "chó")
        XCTAssertEqual(state.examples, .results([sentence("1")]))
    }

    func test_theSentencesLeaveWhenTheDeckIsFinished() {
        japaneseDeck()
        start()
        deliver([sentence("1")])
        presenter.flip(); presenter.primaryAction(); presenter.flip(); presenter.primaryAction()
        XCTAssertEqual(state.screen, .finished)
        XCTAssertEqual(state.examples, .hidden)
    }

    func test_leavingTheScreenCancelsTheLookup() {
        japaneseDeck()
        start()
        presenter.viewWillDisappear()
        XCTAssertTrue(examples.disposed[0])
    }

    func test_collapsingTheSentencesIsRemembered() {
        japaneseDeck()
        start()
        presenter.setExamplesExpanded(false)
        XCTAssertFalse(preferences.areExamplesVisible)
        XCTAssertFalse(state.examplesExpanded)
    }

    func test_aSentenceIsReadAloudInJapanese() {
        japaneseDeck()
        start()
        deliver([sentence("1", "犬が好きです。")])
        presenter.flip()
        presenter.speakExample(id: "1")
        XCTAssertEqual(speech.spoken.last?.0, "犬が好きです。")
        XCTAssertEqual(speech.spoken.last?.1, "ja-JP")
        presenter.speakExample(id: "unknown")
        XCTAssertEqual(speech.spoken.count, 1)
    }

    // MARK: Card style

    func test_theCardUsesTheAppsOwnLookUntilAStyleIsChosen() {
        start()
        XCTAssertNil(state.style)
        preferences.cardStyleSlug = "sakura-bloom"
        presenter.setReadingVisible(true)
        XCTAssertEqual(state.style, .sakuraBloom)
    }

    func test_aStyleThisVersionDoesNotKnowFallsBackToTheDefaultCard() {
        preferences.cardStyleSlug = "removed-style"
        start()
        XCTAssertNil(state.style)
    }

    func test_choosingAStyleOpensThePickerAndRefreshesTheCardWhenItChanges() {
        preferences.cardStyleSlug = "warm-paper"
        start()
        presenter.chooseStyle()
        XCTAssertEqual(wireframe.styleRequests, ["warm-paper"])
        let rendersBefore = view.renders.count
        preferences.cardStyleSlug = "dark-focus"
        wireframe.styleChanged?()
        XCTAssertEqual(view.renders.count, rendersBefore + 1)
        XCTAssertEqual(state.style, .darkFocus)
    }
}

private final class SpyStudyView: CardStudyViewInterface {
    var renders: [(state: CardStudyState, transition: CardStudyTransition)] = []
    func render(_ state: CardStudyState, transition: CardStudyTransition) { renders.append((state, transition)) }
}

private final class FakeStudyInteractor: CardStudyInteractorInterface {
    var deck: DeskEntity?
    func deck(withId id: String) -> DeskEntity? { deck }
}

private final class FakeStudyWireframe: CardStudyWireframeInterface {
    var editedDeckId: String?
    var leaveCount = 0
    var styleRequests: [String?] = []
    var styleChanged: (() -> Void)?
    func showEditor(deckId: String, onFinish: @escaping () -> Void) { editedDeckId = deckId }
    func showStylePicker(selectedSlug: String?, onChange: @escaping () -> Void) {
        styleRequests.append(selectedSlug)
        styleChanged = onChange
    }
    func leave() { leaveCount += 1 }
}

private final class FakeStudyPreferences: StudyPreferencesInterface {
    var isReadingVisible = true
    var areImagesVisible = true
    var autoSpeak = false
    var isShuffled = false
    var mode: StudyMode = .flip
    var cardStyleSlug: String?
    var areExamplesVisible = true
}

private final class FakeSpeech: SpeechServiceInterface {
    var spoken: [(String, String)] = []
    var stopCount = 0
    func speak(_ text: String, languageCode: String) { spoken.append((text, languageCode)) }
    func stop() { stopCount += 1 }
}

private final class FakeExamples: CardExamplesInteractorInterface {
    var requests: [(term: String, reading: String)] = []
    var subjects: [PublishSubject<[CardExample]>] = []
    var disposed: [Bool] = []

    func examples(for term: String, cardReading: String) -> Single<[CardExample]> {
        requests.append((term, cardReading))
        let subject = PublishSubject<[CardExample]>()
        subjects.append(subject)
        disposed.append(false)
        let index = subjects.count - 1
        return subject.asSingle().do(onDispose: { [weak self] in self?.disposed[index] = true })
    }
}
