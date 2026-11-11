import RealmSwift
import RxSwift
import XCTest
@testable import FlashcardApp

final class CardStudyPresenterTests: XCTestCase {
    private var interactor: FakeStudyInteractor!
    private var wireframe: FakeStudyWireframe!
    private var preferences: FakeStudyPreferences!
    private var speech: FakeSpeech!
    private var examples: FakeExamples!
    private var realm: Realm!
    private var owner = "11111111-1111-1111-1111-111111111111"
    private var view: SpyStudyView!
    private var presenter: CardStudyPresenter!
    private var exampleStore: CardExampleStoreInterface?
    private var history: FakeReviewHistory!

    override func setUp() {
        super.setUp()
        interactor = FakeStudyInteractor()
        wireframe = FakeStudyWireframe()
        preferences = FakeStudyPreferences()
        speech = FakeSpeech()
        examples = FakeExamples()
        history = FakeReviewHistory()
        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "study-\(UUID().uuidString)", objectTypes: RealmService.storedTypes))
        RealmService.shared.realm = realm
        owner = "11111111-1111-1111-1111-111111111111"
        view = SpyStudyView()
        interactor.deck = makeDeck(3)
    }

    override func tearDown() {
        presenter = nil
        realm = nil
        RealmService.shared.realm = nil
        super.tearDown()
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
                                       speech: speech, random: { $0.lowerBound }, examples: examples,
                                       exampleStore: exampleStore ?? RealmCardExampleStore(), reviewHistory: history, ownerKey: { [unowned self] in owner })
        presenter.view = view
        presenter.viewWillAppear()
    }

    private var state: CardStudyState { view.renders.last!.state }

    func test_opensOnTheFirstCardWithAShowAnswerButton() {
        start()
        XCTAssertEqual(state.card?.front, "F1")
        XCTAssertEqual(state.card?.isFlipped, false)
        XCTAssertEqual(state.primaryTitle, NSLocalizedString("Show answer", comment: ""))
        XCTAssertEqual(state.progress, 0, accuracy: 0.001, "Progress counts saved attempts, not the card on screen")
        XCTAssertEqual(state.progressText, String(format: NSLocalizedString("%1$lld of %2$lld", comment: ""), 1, 3))
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

    func test_theQuizButtonStaysDisabledOnScreenUntilAnAnswerIsChosen() throws {
        preferences.mode = .quiz
        start()
        let controller = CardStudyViewController()
        controller.presenter = presenter
        controller.loadViewIfNeeded()
        controller.render(state, transition: .none)
        func find(_ view: UIView) -> UIButton? {
            if let button = view as? UIButton, button.accessibilityIdentifier == "study_primary" { return button }
            return view.subviews.lazy.compactMap(find).first
        }
        let button = try XCTUnwrap(find(controller.view))
        XCTAssertFalse(button.isEnabled, "'Choose an answer' does nothing, so it must not look or read as enabled")
        presenter.select(option: "B1")
        controller.render(state, transition: .none)
        XCTAssertTrue(button.isEnabled)
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

    // MARK: Saving the learner's answers (L03)

    private func startQuiz() {
        preferences.mode = .quiz
        start()
    }

    // MARK: A session planned on Today (L05)

    private func startPlanned(_ ids: [String]) {
        presenter = CardStudyPresenter(deckId: "deck", cardIDs: ids, interactor: interactor, wireframe: wireframe, preferences: preferences,
                                       speech: speech, random: { $0.lowerBound }, examples: examples,
                                       exampleStore: exampleStore ?? RealmCardExampleStore(), reviewHistory: history, ownerKey: { [unowned self] in owner })
        presenter.view = view
        presenter.viewWillAppear()
    }

    func test_aPlannedSessionStudiesOnlyItsCardsInItsOrderEvenWhenShuffleIsOn() {
        interactor.deck = makeDeck(5)
        preferences.isShuffled = true
        startPlanned(["c4", "c2"])
        XCTAssertEqual(state.card?.front, "F4")
        XCTAssertEqual(state.review.total, 2)
        XCTAssertEqual(state.progressText, String(format: NSLocalizedString("%1$lld of %2$lld", comment: ""), 1, 2))
        presenter.next()
        XCTAssertEqual(state.card?.front, "F2")
        presenter.next()
        XCTAssertEqual(state.screen, .finished)
        XCTAssertEqual(state.summary.total, 2)
    }

    func test_aPlannedSessionSkipsCardsThatNoLongerExistAndLeavesWhenNoneRemain() {
        interactor.deck = makeDeck(3)
        startPlanned(["gone", "c3", "also-gone"])
        XCTAssertEqual(state.review.total, 1)
        XCTAssertEqual(state.card?.front, "F3")

        interactor.deck = makeDeck(3)
        let leaves = wireframe.leaveCount
        startPlanned(["gone", "also-gone"])
        XCTAssertEqual(wireframe.leaveCount, leaves + 1)
    }

    func test_startingOverAPlannedSessionKeepsItsCards() {
        interactor.deck = makeDeck(5)
        startPlanned(["c5", "c1"])
        presenter.next(); presenter.next()
        presenter.restart()
        XCTAssertEqual(state.review.total, 2)
        XCTAssertEqual(state.card?.front, "F5")
    }

    func test_aPlannedSessionOfOneCardIsStillAQuizSoItsAnswerGradesTheRecognitionSchedule() {
        interactor.deck = makeDeck(5)
        preferences.mode = .quiz
        startPlanned(["c3"])
        XCTAssertEqual(state.mode, .quiz, "One due card must not turn the session into a flip")
        XCTAssertGreaterThan(state.quiz?.options.count ?? 0, 2, "The wrong answers come from the whole deck")
        presenter.select(option: "B3")
        XCTAssertEqual(history.saves.map(\.0.result), [.correct])
        XCTAssertEqual(history.saves.first?.0.skill, .recognition)
    }

    func test_aPlannedSessionOfCardsWithTheSameMeaningStillQuizzesWhenTheDeckCan() {
        let deck = makeDeck(5)
        deck.cards[0].backText = "same"
        deck.cards[1].backText = "same"
        interactor.deck = deck
        preferences.mode = .quiz
        startPlanned(["c1", "c2"])
        XCTAssertEqual(state.mode, .quiz)
        XCTAssertTrue(state.quiz!.options.contains("B3") || state.quiz!.options.contains("B4") || state.quiz!.options.contains("B5"))
    }

    func test_aPlannedCardSavedWhileAnsweredCarriesItsOwnId() throws {
        interactor.deck = makeDeck(5)
        preferences.mode = .quiz
        startPlanned(["c3", "c1"])
        presenter.select(option: "B3")
        XCTAssertEqual(history.saves.first?.0.cardID, "c3")
    }

    func test_aQuizAnswerIsSavedForTheLearnerWithTheCardAndWhatWasAsked() throws {
        startQuiz()
        presenter.select(option: "B1")

        XCTAssertEqual(history.saves.count, 1)
        let (attempt, savedFor) = try XCTUnwrap(history.saves.first)
        XCTAssertEqual(savedFor, owner)
        XCTAssertEqual(attempt.cardID, "c1")
        XCTAssertEqual(attempt.result, .correct)
        XCTAssertEqual(attempt.contentVersion, StudyCard(id: "c1", front: "F1", back: "B1").contentVersion)
        XCTAssertEqual(state.review.save, .saved)
        XCTAssertEqual(state.review.savedCount, 1)
        XCTAssertEqual(state.progress, 1.0 / 3.0, accuracy: 0.001)
    }

    func test_aWrongQuizAnswerIsSavedAsIncorrect() {
        startQuiz()
        presenter.select(option: state.quiz!.options.first { $0 != "B1" }!)
        XCTAssertEqual(history.saves.map(\.0.result), [.incorrect])
    }

    func test_choosingAnOptionTwiceSavesOnce() {
        startQuiz()
        presenter.select(option: "B1")
        presenter.select(option: "B1")
        presenter.select(option: state.quiz!.options.first { $0 != "B1" }!)
        XCTAssertEqual(history.saves.count, 1)
        XCTAssertEqual(state.review.savedCount, 1)
    }

    func test_lookingAtACardNeverSavesAnything() {
        start()
        presenter.flip()
        presenter.next()
        presenter.previous()
        presenter.flip()
        presenter.primaryAction()
        XCTAssertTrue(history.saves.isEmpty)
        XCTAssertEqual(state.review.savedCount, 0)
        XCTAssertEqual(state.review.save, .none)
    }

    func test_aFlippedCardCanBeRatedAndTheRatingIsSavedAsASelfAssessment() throws {
        start()
        XCTAssertFalse(state.review.canRate, "The answer is not shown yet")
        presenter.flip()
        XCTAssertTrue(state.review.canRate)
        presenter.rate(.needsReview)

        let attempt = try XCTUnwrap(history.saves.first?.0)
        XCTAssertEqual(attempt.result, .needsReview)
        XCTAssertEqual(attempt.skill, .selfRecall)
        XCTAssertEqual(attempt.cardID, "c1")
        XCTAssertFalse(state.review.canRate, "A question is rated once")
        XCTAssertEqual(state.review.save, .saved)
        XCTAssertEqual(state.summary.answered, 0, "A self-rating is not a quiz answer")
        XCTAssertEqual(state.summary.selfRated, 1)
    }

    func test_ratingBeforeTheAnswerIsShownOrInAQuizSavesNothing() {
        start()
        presenter.rate(.remembered)
        XCTAssertTrue(history.saves.isEmpty)
        presenter.setMode(.quiz)
        presenter.rate(.remembered)
        XCTAssertTrue(history.saves.isEmpty)
    }

    func test_ratingTheSameCardTwiceSavesOnce() {
        start()
        presenter.flip()
        presenter.rate(.remembered)
        presenter.rate(.needsReview)
        XCTAssertEqual(history.saves.map(\.0.result), [.remembered])
    }

    func test_theReadingInViewBeforeTheAnswerIsRecordedAsAHint() {
        let deck = makeDeck(3)
        deck.cards[0].frontExtraText = "えふいち"
        interactor.deck = deck
        start()
        XCTAssertTrue(state.review.usedReadingHint)
        presenter.flip()
        presenter.rate(.remembered)
        XCTAssertEqual(history.saves.first?.0.hints, [.reading])
        XCTAssertTrue(state.review.usedReadingHint)
    }

    func test_noReadingOrAHiddenReadingIsNoHint() {
        let deck = makeDeck(3)
        deck.cards[0].frontExtraText = "えふいち"
        interactor.deck = deck
        preferences.isReadingVisible = false
        start()
        XCTAssertFalse(state.review.usedReadingHint)
        presenter.flip()
        presenter.rate(.remembered)
        presenter.next()
        presenter.flip()
        presenter.rate(.remembered)
        XCTAssertEqual(history.saves.map(\.0.hints), [[], []], "Card 2 has no reading to show")
    }

    func test_listeningBeforeTheAnswerIsAHintAndListeningAfterIsNot() {
        start()
        presenter.speakCurrent()
        presenter.flip()
        presenter.speakCurrent()
        presenter.rate(.remembered)
        XCTAssertEqual(history.saves.first?.0.hints, [.audio])

        presenter.next()
        presenter.flip()
        presenter.speakCurrent()
        presenter.rate(.remembered)
        XCTAssertEqual(history.saves.last?.0.hints, [], "Hearing the answer after seeing it helped nothing")
    }

    func test_answersSavedBeforeTheSummaryAreStillThereAfterTheAppIsClosedAndOpenedAgain() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let configuration = RealmService.makeConfiguration(fileURL: folder.appendingPathComponent("flash_card.realm"))
        try autoreleasepool {
            RealmService.shared.realm = try Realm(configuration: configuration)
            preferences.mode = .quiz
            presenter = CardStudyPresenter(deckId: "deck", interactor: interactor, wireframe: wireframe, preferences: preferences, speech: speech,
                                           random: { $0.lowerBound }, examples: examples, exampleStore: RealmCardExampleStore(),
                                           reviewHistory: RealmReviewHistoryStore(), ownerKey: { [unowned self] in owner })
            presenter.view = view
            presenter.viewWillAppear()
            presenter.select(option: "B1")
            presenter.next()
            presenter.select(option: state.quiz!.options.first { $0 != "B2" }!)
            // The app is closed here, before the summary was ever shown.
            presenter = nil
            RealmService.shared.realm = nil
        }

        RealmService.shared.realm = try Realm(configuration: configuration)
        let saved = RealmReviewHistoryStore().attempts(ownerKey: owner, cardId: nil)
        XCTAssertEqual(saved.map(\.cardID), ["c1", "c2"])
        XCTAssertEqual(saved.map(\.result), [.correct, .incorrect])
    }

    // MARK: When saving fails

    private func startWithFailingSave() {
        history.failuresRemaining = 1
        startQuiz()
        presenter.select(option: "B1")
    }

    func test_aFailedSaveIsShownAsFailedAndIsNotCountedAsProgress() {
        startWithFailingSave()
        XCTAssertEqual(state.review.save, .failed)
        XCTAssertEqual(state.review.savedCount, 0)
        XCTAssertEqual(state.progress, 0)
        XCTAssertEqual(state.summary.saved, 0)
        XCTAssertEqual(state.quiz?.selected, "B1", "The answer stays on screen")
    }

    func test_whileAnAttemptIsUnsavedTheLearnerCannotMoveOnOrChangeTheSession() {
        startWithFailingSave()
        presenter.next()
        presenter.primaryAction()
        presenter.previous()
        presenter.restart()
        presenter.setMode(.flip)
        presenter.setShuffled(true)
        XCTAssertEqual(state.card?.front, "F1")
        XCTAssertEqual(state.mode, .quiz)
        XCTAssertFalse(state.isShuffled)
        XCTAssertEqual(state.review.save, .failed)
    }

    func test_retryingSavesTheSameAttemptOnceAndUnblocksTheSession() throws {
        startWithFailingSave()
        presenter.retrySave()
        presenter.retrySave()

        XCTAssertEqual(history.attempted.count, 2, "One failed try and one successful retry; the second retry has nothing to save")
        XCTAssertEqual(history.attempted[0].0.id, history.attempted[1].0.id, "A retry sends the same attempt, never a new one")
        XCTAssertEqual(history.saves.count, 1)
        XCTAssertEqual(state.review.save, .saved)
        XCTAssertEqual(state.review.savedCount, 1)
        presenter.next()
        XCTAssertEqual(state.card?.front, "F2")
    }

    func test_aRetryThatFailsAgainKeepsWaiting() {
        history.failuresRemaining = 2
        startQuiz()
        presenter.select(option: "B1")
        presenter.retrySave()
        XCTAssertEqual(state.review.save, .failed)
        presenter.retrySave()
        XCTAssertEqual(state.review.save, .saved)
    }

    func test_aFailedRatingStaysRatedAndCanBeRetried() {
        history.failuresRemaining = 1
        start()
        presenter.flip()
        presenter.rate(.remembered)
        XCTAssertEqual(state.review.save, .failed)
        XCTAssertFalse(state.review.canRate, "The rating was given; only saving remains")
        presenter.rate(.needsReview)
        presenter.retrySave()
        XCTAssertEqual(history.saves.map(\.0.result), [.remembered])
    }

    func test_leavingWithAnUnsavedAttemptAsksFirst() {
        startWithFailingSave()
        presenter.leaveSession()
        XCTAssertEqual(wireframe.leaveCount, 0)
        XCTAssertEqual(wireframe.unsavedLeavePrompts.count, 1)
        wireframe.unsavedLeavePrompts[0]()
        XCTAssertEqual(wireframe.leaveCount, 1)
        XCTAssertTrue(history.saves.isEmpty, "Nothing was saved, and the learner was told")
    }

    func test_leavingWhenEverythingIsSavedDoesNotAsk() {
        startQuiz()
        presenter.select(option: "B1")
        presenter.leaveSession()
        XCTAssertTrue(wireframe.unsavedLeavePrompts.isEmpty)
        XCTAssertEqual(wireframe.leaveCount, 1)
    }

    // MARK: Whose results they are

    func test_anAccountChangeDuringTheSessionEndsItAndNothingIsSavedForTheNewAccount() {
        startQuiz()
        presenter.select(option: "B1")
        presenter.next()
        owner = "22222222-2222-2222-2222-222222222222"
        presenter.select(option: "B2")

        XCTAssertEqual(history.saves.map(\.1), ["11111111-1111-1111-1111-111111111111"], "Only the first answer, for the first account")
        XCTAssertEqual(wireframe.endedSessions.count, 1)
    }

    func test_signingOutDuringTheSessionEndsItToo() {
        startQuiz()
        owner = ""
        presenter.select(option: "B1")
        XCTAssertTrue(history.saves.isEmpty)
        XCTAssertEqual(wireframe.endedSessions.count, 1)
    }

    func test_comingBackAfterTheAccountChangedEndsTheSession() {
        start()
        presenter.flip()
        owner = "22222222-2222-2222-2222-222222222222"
        presenter.viewWillAppear()
        XCTAssertEqual(wireframe.endedSessions.count, 1)
    }

    func test_theSignedOutLearnerSavesUnderAnEmptyKey() {
        owner = ""
        startQuiz()
        presenter.select(option: "B1")
        XCTAssertEqual(history.saves.map(\.1), [""])
    }

    // MARK: A run and its summary

    func test_startingOverBeginsANewRunWithNewAttemptIdsAndKeepsWhatWasSaved() {
        startQuiz()
        presenter.select(option: "B1")
        presenter.restart()
        XCTAssertEqual(state.review.savedCount, 0)
        presenter.select(option: "B1")
        XCTAssertEqual(history.saves.count, 2)
        XCTAssertNotEqual(history.saves[0].0.id, history.saves[1].0.id)
    }

    func test_changingTheModeOrShufflingBeginsANewRunWhoseCountStartsAtZero() {
        startQuiz()
        presenter.select(option: "B1")
        XCTAssertEqual(state.review.savedCount, 1)

        presenter.setShuffled(true)
        XCTAssertEqual(state.review.savedCount, 0, "Nothing is saved in the new run yet")
        XCTAssertEqual(state.progress, 0)
        presenter.select(option: state.quiz!.options.first { $0 == state.card!.back }!)
        XCTAssertEqual(state.review.savedCount, 1)

        presenter.setMode(.flip)
        XCTAssertEqual(state.review.savedCount, 0)
        presenter.flip()
        presenter.rate(.remembered)
        presenter.next()
        presenter.flip()
        presenter.rate(.remembered)
        XCTAssertEqual(state.review.savedCount, 2)
        XCTAssertLessThanOrEqual(state.review.savedCount, state.review.total)
        XCTAssertEqual(state.summary.saved, 2, "The header and the summary agree")
        XCTAssertEqual(history.saves.count, 4, "Every earlier attempt is still stored")
    }

    func test_anUnsavedAttemptAlsoBlocksEditingTheDeck() {
        startWithFailingSave()
        presenter.edit()
        XCTAssertNil(wireframe.editedDeckId)
        presenter.retrySave()
        presenter.edit()
        XCTAssertEqual(wireframe.editedDeckId, "deck")
    }

    func test_onceTheSessionEndedForAnAccountChangeNothingMoreIsAnsweredOrSaved() {
        startQuiz()
        owner = "22222222-2222-2222-2222-222222222222"
        presenter.select(option: "B1")
        XCTAssertEqual(wireframe.endedSessions.count, 1)

        presenter.next()
        presenter.select(option: "B1")
        presenter.setMode(.flip)
        presenter.setShuffled(true)
        presenter.restart()
        XCTAssertTrue(history.saves.isEmpty)
        XCTAssertEqual(state.card?.front, "F1", "The session is frozen")
        XCTAssertEqual(state.mode, .quiz)
        presenter.viewWillAppear()
        XCTAssertEqual(wireframe.endedSessions.count, 2, "Coming back asks again, in case the first message was never shown")
    }

    func test_theSummaryCountsOnlySavedAttemptsAndListsTheCardsToReview() throws {
        startQuiz()
        presenter.select(option: "B1")
        presenter.next()
        presenter.select(option: state.quiz!.options.first { $0 != "B2" }!)
        presenter.next()
        presenter.next()   // the third question is skipped: unanswered quiz questions cannot be left
        presenter.select(option: "B3")
        presenter.next()

        XCTAssertEqual(state.screen, .finished)
        XCTAssertEqual(state.summary.saved, 3)
        XCTAssertEqual(state.summary.answered, 3)
        XCTAssertEqual(state.summary.correct, 2)
        XCTAssertEqual(state.summary.incorrect, 1)
        XCTAssertEqual(state.summary.selfRated, 0)
        XCTAssertEqual(state.summary.toReview, [StudyReviewedCard(front: "F2", back: "B2", result: .incorrect)])
    }

    func test_theSummaryKeepsSelfRatingsApartFromTheQuizScore() {
        start()
        presenter.flip(); presenter.rate(.remembered); presenter.next()
        presenter.flip(); presenter.rate(.needsReview); presenter.next()
        presenter.next()   // skipped
        XCTAssertEqual(state.screen, .finished)
        XCTAssertEqual(state.summary.saved, 2)
        XCTAssertEqual(state.summary.selfRated, 2)
        XCTAssertEqual(state.summary.answered, 0)
        XCTAssertEqual(state.summary.toReview.map(\.front), ["F2"])
    }

    func test_aSessionWithNothingSavedSaysSo() {
        start()
        presenter.next(); presenter.next(); presenter.next()
        XCTAssertEqual(state.screen, .finished)
        XCTAssertEqual(state.summary.saved, 0)
        XCTAssertTrue(state.summary.toReview.isEmpty)
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

    private var panel: ExamplesPanelState { state.examples }

    func test_theSentencesAreLookedUpWhenTheCardAppearsButShownOnlyAfterTheAnswer() {
        japaneseDeck()
        start()
        XCTAssertEqual(examples.requests.map(\.term), ["犬"], "Prefetched while the front is showing")
        XCTAssertEqual(examples.requests.first?.reading, "いぬ")
        XCTAssertFalse(panel.isVisible, "The front must not give the word's use away")
        deliver([sentence("1")])
        XCTAssertFalse(panel.isVisible)
        presenter.flip()
        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(panel.items, [ExampleItem(example: sentence("1"), origin: .server)])
        XCTAssertEqual(panel.server, .loaded)
    }

    func test_theServersPartIsLoadingUntilItAnswersAndAnEmptyAnswerIsNotAnError() {
        japaneseDeck()
        start()
        presenter.flip()
        XCTAssertEqual(panel.server, .loading)
        XCTAssertTrue(panel.items.isEmpty)
        deliver([])
        XCTAssertEqual(panel.server, .loaded)
        XCTAssertTrue(panel.items.isEmpty)
    }

    func test_aFailedLookupIsUnavailableAndRetryAsksAgain() {
        japaneseDeck()
        start()
        presenter.flip()
        examples.subjects[0].onError(LearnerAPIError.offline)
        waitForMain()
        XCTAssertEqual(panel.server, .unavailable)
        presenter.retryExamples()
        XCTAssertEqual(examples.requests.count, 2)
        XCTAssertEqual(panel.server, .loading)
        deliver([sentence("1")], request: 1)
        XCTAssertEqual(panel.items.map(\.id), ["1"])
    }

    func test_aLateAnswerForACardThatWasLeftIsDropped() {
        japaneseDeck()
        start()
        presenter.next()
        XCTAssertEqual(examples.requests.map(\.term), ["犬", "猫"])
        deliver([sentence("old")], request: 0)
        presenter.flip()
        XCTAssertEqual(state.card?.front, "猫")
        XCTAssertEqual(panel.server, .loading, "The sentence for the first card must not appear under the second")
        XCTAssertTrue(panel.items.isEmpty)
        deliver([sentence("new", "猫がいます。")], request: 1)
        XCTAssertEqual(panel.items.map(\.id), ["new"])
    }

    func test_aCardWithoutAJapaneseWordHasNoLookupButStillTakesTheLearnersOwnSentences() {
        start()
        presenter.flip()
        XCTAssertTrue(examples.requests.isEmpty)
        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(panel.server, .notApplicable)
        presenter.addExample()
        XCTAssertEqual(wireframe.editors.count, 1)
    }

    func test_aQuizShowsTheSentencesOnlyAfterAnAnswer() {
        japaneseDeck()
        preferences.mode = .quiz
        start()
        deliver([sentence("1")])
        XCTAssertFalse(panel.isVisible)
        presenter.select(option: "chó")
        XCTAssertEqual(panel.items.map(\.id), ["1"])
    }

    func test_theSentencesLeaveWhenTheDeckIsFinished() {
        japaneseDeck()
        start()
        deliver([sentence("1")])
        presenter.flip(); presenter.primaryAction(); presenter.flip(); presenter.primaryAction()
        XCTAssertEqual(state.screen, .finished)
        XCTAssertFalse(panel.isVisible)
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

    // MARK: The learner's own changes to the sentences

    private func openJapaneseCard(serving found: [CardExample]) {
        japaneseDeck()
        start()
        deliver(found)
        presenter.flip()
    }

    func test_theLearnersOwnSentencesShowAtOnceAndWithoutAConnection() throws {
        japaneseDeck()
        start()
        presenter.flip()
        presenter.addExample()
        try wireframe.editors[0].save(CardExampleDraft(japanese: "私の文。"))
        XCTAssertEqual(panel.server, .loading, "The server is still being asked")
        XCTAssertEqual(panel.items.map(\.origin), [.custom])
        examples.subjects[0].onError(LearnerAPIError.offline)
        waitForMain()
        XCTAssertEqual(panel.server, .unavailable)
        XCTAssertEqual(panel.items.map(\.example.japanese), ["私の文。"], "Offline the learner still has their own sentences")
    }

    func test_addingASentenceOpensTheFormAndStoresItOnSave() throws {
        openJapaneseCard(serving: [sentence("1")])
        presenter.addExample()
        XCTAssertTrue(wireframe.editors[0].isNew)
        XCTAssertEqual(wireframe.editors[0].draft, CardExampleDraft())
        try wireframe.editors[0].save(CardExampleDraft(japanese: " 犬と散歩する。 ", translation: "Đi dạo với chó."))
        XCTAssertEqual(panel.items.map(\.example.japanese), ["犬が好きです。", "犬と散歩する。"], "The server's first, then the learner's own")
        XCTAssertEqual(panel.items.map(\.origin), [.server, .custom])
        XCTAssertEqual(panel.items.last?.example.translation, "Đi dạo với chó.")
    }

    func test_aSentenceAlreadyOnTheCardIsRefusedWhetherServersOrTheLearners() throws {
        openJapaneseCard(serving: [sentence("1", "犬が好きです。")])
        presenter.addExample()
        XCTAssertThrowsError(try wireframe.editors[0].save(CardExampleDraft(japanese: "犬が好きです。"))) { XCTAssertEqual($0 as? CardExampleError, .duplicate) }
        try wireframe.editors[0].save(CardExampleDraft(japanese: "新しい文。"))
        presenter.addExample()
        XCTAssertThrowsError(try wireframe.editors[1].save(CardExampleDraft(japanese: " 新しい文。 "))) { XCTAssertEqual($0 as? CardExampleError, .duplicate) }
        XCTAssertEqual(panel.items.count, 2)
    }

    func test_aBlankSentenceIsRefusedByTheStoreRules() {
        openJapaneseCard(serving: [])
        presenter.addExample()
        XCTAssertThrowsError(try wireframe.editors[0].save(CardExampleDraft(japanese: "  "))) { XCTAssertEqual($0 as? CardExampleError, .sentenceMissing) }
        XCTAssertTrue(panel.items.isEmpty)
    }

    func test_editingAServerSentenceShowsTheLearnersVersionAndCanGoBackToTheOriginal() throws {
        openJapaneseCard(serving: [sentence("1", "犬が好きです。"), sentence("2", "犬を飼っています。")])
        presenter.editExample(id: "1")
        XCTAssertFalse(wireframe.editors[0].isNew)
        XCTAssertEqual(wireframe.editors[0].draft.japanese, "犬が好きです。", "The form starts from the sentence")
        try wireframe.editors[0].save(CardExampleDraft(japanese: "犬が大好きです。", translation: "Tôi rất thích chó."))
        XCTAssertEqual(panel.items.map(\.origin), [.edited, .server], "The edit stays where the sentence was")
        XCTAssertEqual(panel.items.first?.example.japanese, "犬が大好きです。")
        XCTAssertEqual(panel.items.first?.id, "1")
        presenter.restoreOriginalExample(id: "1")
        XCTAssertEqual(panel.items.map(\.origin), [.server, .server])
        XCTAssertEqual(panel.items.first?.example.japanese, "犬が好きです。")
    }

    func test_editingTheLearnersOwnSentenceKeepsItTheirs() throws {
        openJapaneseCard(serving: [])
        presenter.addExample()
        try wireframe.editors[0].save(CardExampleDraft(japanese: "旧"))
        let id = panel.items[0].id
        presenter.editExample(id: id)
        try wireframe.editors[1].save(CardExampleDraft(japanese: "新"))
        XCTAssertEqual(panel.items.map(\.example.japanese), ["新"])
        XCTAssertEqual(panel.items.map(\.origin), [.custom])
        XCTAssertEqual(panel.items.first?.id, id)
    }

    func test_editingAnUnchangedSentenceToItself_isNotADuplicateOfItself() throws {
        openJapaneseCard(serving: [sentence("1", "犬が好きです。")])
        presenter.editExample(id: "1")
        XCTAssertNoThrow(try wireframe.editors[0].save(CardExampleDraft(japanese: "犬が好きです。", translation: "Thích chó.")))
        XCTAssertEqual(panel.items.first?.example.translation, "Thích chó.")
    }

    func test_removingAServerSentenceAsksFirstThenHidesItAndCanBeRestored() {
        openJapaneseCard(serving: [sentence("1"), sentence("2", "犬を飼っています。")])
        presenter.removeExample(id: "1")
        XCTAssertEqual(wireframe.removalPrompts.map(\.origin), [.server])
        XCTAssertEqual(panel.items.count, 2, "Nothing changes until the learner confirms")
        wireframe.removalPrompts[0].confirm()
        XCTAssertEqual(panel.items.map(\.id), ["2"])
        XCTAssertEqual(panel.removedCount, 1)
        presenter.restoreRemovedExamples()
        XCTAssertEqual(panel.items.map(\.id), ["1", "2"])
        XCTAssertEqual(panel.removedCount, 0)
    }

    func test_decliningTheConfirmationChangesNothing() {
        openJapaneseCard(serving: [sentence("1")])
        presenter.removeExample(id: "1")
        XCTAssertEqual(panel.items.count, 1)
        XCTAssertEqual(panel.removedCount, 0)
    }

    func test_deletingTheLearnersOwnSentenceIsFinalAndIsNotCountedAsRemoved() throws {
        openJapaneseCard(serving: [])
        presenter.addExample()
        try wireframe.editors[0].save(CardExampleDraft(japanese: "消える"))
        presenter.removeExample(id: panel.items[0].id)
        XCTAssertEqual(wireframe.removalPrompts.last?.origin, .custom)
        wireframe.removalPrompts[0].confirm()
        XCTAssertTrue(panel.items.isEmpty)
        XCTAssertEqual(panel.removedCount, 0, "There is nothing to restore")
    }

    func test_aRemovedSentenceStaysRemovedWhenTheCardIsVisitedAgain() {
        openJapaneseCard(serving: [sentence("1")])
        presenter.removeExample(id: "1")
        wireframe.removalPrompts[0].confirm()
        presenter.next()
        presenter.previous()
        deliver([sentence("1")], request: 2)   // the card is asked about again; the answer comes back with the sentence
        presenter.flip()
        XCTAssertTrue(panel.items.isEmpty, "The learner's removal is remembered")
        XCTAssertEqual(panel.removedCount, 1)
    }

    func test_eachAccountSeesItsOwnSentencesAndItsOwnRemovals() throws {
        openJapaneseCard(serving: [sentence("1")])
        presenter.removeExample(id: "1")
        wireframe.removalPrompts[0].confirm()
        presenter.addExample()
        try wireframe.editors[0].save(CardExampleDraft(japanese: "A さんの文"))
        XCTAssertEqual(panel.items.map(\.example.japanese), ["A さんの文"])

        owner = "22222222-2222-2222-2222-222222222222"   // another account signs in on this device
        presenter.setReadingVisible(true)
        XCTAssertEqual(panel.items.map(\.id), ["1"], "The server's sentence is still there for them")
        XCTAssertEqual(panel.removedCount, 0)

        owner = ""   // and nobody signed in
        presenter.setReadingVisible(true)
        XCTAssertEqual(panel.items.map(\.id), ["1"])
    }

    func test_aFailureToSaveIsReportedAndNothingIsRetried() throws {
        japaneseDeck()
        exampleStore = FailingExampleStore()
        start()
        deliver([sentence("1")])
        presenter.flip()
        presenter.removeExample(id: "1")
        wireframe.removalPrompts[0].confirm()
        XCTAssertEqual(wireframe.errors.count, 1)
        XCTAssertTrue(wireframe.errors[0].contains("disk is full"))
        XCTAssertEqual(panel.items.map(\.id), ["1"], "The sentence is still shown")
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
    var kanjiWritingCards: [[StudyCard]] = []
    func showKanjiWriting(cards: [StudyCard]) { kanjiWritingCards.append(cards) }
    var editedDeckId: String?
    var leaveCount = 0
    var styleRequests: [String?] = []
    var styleChanged: (() -> Void)?
    var editors: [(isNew: Bool, draft: CardExampleDraft, save: (CardExampleDraft) throws -> Void)] = []
    var removalPrompts: [(origin: ExampleOrigin, confirm: () -> Void)] = []
    var errors: [String] = []
    var unsavedLeavePrompts: [() -> Void] = []
    var endedSessions: [String] = []
    func confirmLeaveUnsaved(onLeave: @escaping () -> Void) { unsavedLeavePrompts.append(onLeave) }
    func endSession(message: String) { endedSessions.append(message) }
    func showExampleEditor(isNew: Bool, draft: CardExampleDraft, save: @escaping (CardExampleDraft) throws -> Void) {
        editors.append((isNew, draft, save))
    }
    func confirmRemoveExample(origin: ExampleOrigin, onConfirm: @escaping () -> Void) { removalPrompts.append((origin, onConfirm)) }
    func showError(_ message: String) { errors.append(message) }
    func showEditor(deckId: String, onFinish: @escaping () -> Void) { editedDeckId = deckId }
    func showStylePicker(selectedSlug: String?, onChange: @escaping () -> Void) {
        styleRequests.append(selectedSlug)
        styleChanged = onChange
    }
    func leave() { leaveCount += 1 }
}

private final class FakeReviewHistory: ReviewHistoryStoreInterface {
    struct DiskFull: LocalizedError { var errorDescription: String? { "The disk is full." } }
    /// Every save the presenter attempted, including the ones that failed.
    var attempted: [(ReviewAttempt, String)] = []
    /// What was stored: one entry per attempt id and owner.
    var saves: [(ReviewAttempt, String)] = []
    var failuresRemaining = 0

    func save(_ attempt: ReviewAttempt, ownerKey: String) throws -> Bool {
        attempted.append((attempt, ownerKey))
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw DiskFull()
        }
        if saves.contains(where: { $0.0.id == attempt.id && $0.1 == ownerKey }) { return false }
        saves.append((attempt, ownerKey))
        return true
    }

    func attempts(ownerKey: String, cardId: String?) -> [ReviewAttempt] {
        saves.filter { $0.1 == ownerKey && (cardId == nil || $0.0.cardID == cardId) }.map(\.0)
    }
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

private final class FailingExampleStore: CardExampleStoreInterface {
    struct DiskFull: LocalizedError { var errorDescription: String? { "The disk is full." } }
    func overlay(cardId: String, ownerKey: String) -> ExampleOverlay { .empty }
    func addCustom(_ draft: CardExampleDraft, cardId: String, ownerKey: String) throws { throw DiskFull() }
    func update(_ item: ExampleItem, with draft: CardExampleDraft, cardId: String, ownerKey: String) throws { throw DiskFull() }
    func remove(_ item: ExampleItem, cardId: String, ownerKey: String) throws { throw DiskFull() }
    func restoreOriginal(of item: ExampleItem, cardId: String, ownerKey: String) throws { throw DiskFull() }
    func restoreRemoved(cardId: String, ownerKey: String) throws { throw DiskFull() }
}

/// K-09: typing the reading of a card in kana.
extension CardStudyPresenterTests {
    private func startTyping(readings: [String] = ["いち", "に", "さん"]) {
        let deck = makeDeck(readings.count)
        for (index, card) in deck.cards.enumerated() {
            card.frontText = "漢\(index + 1)"
            card.frontExtraText = readings[index]
        }
        interactor.deck = deck
        preferences.mode = .type
        start()
    }

    func test_typingAsksTheFrontAndNeverShowsItsReadingOnTheFront() {
        preferences.isReadingVisible = true
        startTyping()
        XCTAssertEqual(state.mode, .type)
        XCTAssertTrue(state.canType)
        XCTAssertEqual(state.card?.front, "漢1")
        XCTAssertFalse(state.readingVisible, "The reading is the answer")
        XCTAssertEqual(state.typing, StudyTypingState(typed: nil, expected: "いち", isCorrect: nil))
        XCTAssertEqual(state.primaryTitle, NSLocalizedString("Check answer", comment: ""))
        XCTAssertTrue(state.review.usedReadingHint == false, "Reading visibility is not a hint here")
    }

    func test_aRightReadingIsSavedAsTypedCorrectForTheLearnerAndShowsFeedback() throws {
        startTyping()
        presenter.submit(typed: "イチ")
        XCTAssertEqual(state.typing?.isCorrect, true)
        XCTAssertEqual(state.typing?.typed, "イチ")
        XCTAssertEqual(state.primaryTitle, NSLocalizedString("Next question", comment: ""))
        let (attempt, savedFor) = try XCTUnwrap(history.saves.first)
        XCTAssertEqual(savedFor, owner)
        XCTAssertEqual(attempt.result, .typedCorrect)
        XCTAssertEqual(attempt.skill, .typedRecall)
        XCTAssertEqual(state.review.save, .saved)
        XCTAssertEqual(state.summary.correct, 1)
    }

    func test_aWrongReadingIsSavedAsTypedIncorrectAndListedForReview() {
        startTyping()
        presenter.submit(typed: "にち")
        XCTAssertEqual(state.typing?.isCorrect, false)
        XCTAssertEqual(history.saves.first?.0.result, .typedIncorrect)
        XCTAssertEqual(state.summary.incorrect, 1)
        XCTAssertEqual(state.summary.toReview.map(\.result), [.typedIncorrect])
    }

    func test_aBlankAnswerSavesNothingAndTheQuestionCannotBeSkipped() {
        startTyping()
        presenter.submit(typed: "  ")
        XCTAssertTrue(history.attempted.isEmpty)
        presenter.primaryAction()
        presenter.next()
        XCTAssertEqual(state.card?.front, "漢1")
    }

    func test_anAnsweredQuestionIsFinalAndTheNextOneStartsEmpty() {
        startTyping()
        presenter.submit(typed: "いち")
        presenter.submit(typed: "ちがう")
        XCTAssertEqual(history.attempted.count, 1)
        presenter.primaryAction()
        XCTAssertEqual(state.card?.front, "漢2")
        XCTAssertEqual(state.typing, StudyTypingState(typed: nil, expected: "に", isCorrect: nil))
    }

    func test_theSessionFinishesWithTypedAnswersCounted() {
        startTyping()
        for typed in ["いち", "ちがう", "さん"] {
            presenter.submit(typed: typed)
            presenter.primaryAction()
        }
        XCTAssertEqual(state.screen, .finished)
        XCTAssertEqual(state.summary.answered, 3)
        XCTAssertEqual(state.summary.correct, 2)
        XCTAssertEqual(state.summary.incorrect, 1)
        XCTAssertEqual(state.summary.selfRated, 0)
    }

    func test_aDeckWithACardThatCannotBeTypedFallsBackToFlipping() {
        startTyping(readings: ["いち", "", "さん"])
        XCTAssertEqual(state.mode, .flip)
        XCTAssertFalse(state.canType)
        XCTAssertNil(state.typing)
    }

    func test_anAccountChangeStopsSavingTypedAnswersToo() {
        startTyping()
        owner = "22222222-2222-2222-2222-222222222222"
        presenter.submit(typed: "いち")
        XCTAssertTrue(history.saves.isEmpty, "A different account never receives this session's results")
    }

    func test_aFailedSaveKeepsTheTypedQuestionUntilRetried() {
        history.failuresRemaining = 1
        startTyping()
        presenter.submit(typed: "いち")
        XCTAssertEqual(state.review.save, .failed)
        presenter.next()
        XCTAssertEqual(state.card?.front, "漢1", "An unsaved answer is not left behind")
        presenter.retrySave()
        XCTAssertEqual(state.review.save, .saved)
        XCTAssertEqual(history.saves.count, 1)
    }
}
