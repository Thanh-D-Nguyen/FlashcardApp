import RxSwift
import XCTest
@testable import FlashcardApp

final class FakeServerInteractor: CardLibraryServerInteractorInterface {
    var isSignedIn = true
    var accountId: String? = "account-1"
    var decksResult: Single<[ServerDeck]> = .just([])
    var detailResult: Single<ServerDeckDetail> = .error(LearnerAPIError.notFound)
    var dueResult: Single<[DueCard]> = .just([])
    /// Consumed in order, one per `submit`; an exhausted queue succeeds.
    var submitResults: [Single<Void>] = []
    var archiveResult: Single<Void> = .just(())
    /// Defaults to no distractors: the review falls back to flip-and-rate.
    var distractorResult: Single<[String]> = .just([])
    var distractorResultsByCard: [String: Single<[String]>] = [:]
    private(set) var distractorRequests: [(id: String, count: Int)] = []
    var reportResult: Single<Void> = .just(())
    var blockResult: Single<Void> = .just(())
    var deviceCopies = Set<String>()
    var saveOutcome: Result<DeckImportOutcome, Error> = .success(.imported(deckId: "x"))
    var copyResult: Single<Int> = .just(0)
    private(set) var pictureCopies: [ServerDeckDetail] = []

    private(set) var decksCalls = 0
    private(set) var dueLimits: [Int] = []
    private(set) var submissions: [(rating: ReviewRating, cardId: String, elapsed: TimeInterval)] = []
    private(set) var archived: [String] = []
    private(set) var reported: [(String, String)] = []
    private(set) var blocked: [String] = []
    private(set) var saved: [ServerDeckDetail] = []

    func decks() -> Single<[ServerDeck]> { decksCalls += 1; return decksResult }
    func detail(deckId: String) -> Single<ServerDeckDetail> { detailResult }
    func dueCards(limit: Int) -> Single<[DueCard]> { dueLimits.append(limit); return dueResult }
    func submit(_ rating: ReviewRating, for card: DueCard, elapsed: TimeInterval) -> Single<Void> {
        submissions.append((rating, card.id, elapsed))
        return submitResults.isEmpty ? .just(()) : submitResults.removeFirst()
    }
    func distractors(for card: DueCard, count: Int) -> Single<[String]> {
        distractorRequests.append((card.id, count))
        return distractorResultsByCard[card.id] ?? distractorResult
    }
    func archive(deckId: String) -> Single<Void> { archived.append(deckId); return archiveResult }
    func report(deckId: String, reason: String) -> Single<Void> { reported.append((deckId, reason)); return reportResult }
    func blockAuthor(deckId: String) -> Single<Void> { blocked.append(deckId); return blockResult }
    func hasDeviceCopy(deckId: String) -> Bool { deviceCopies.contains(deckId) }
    func saveToDevice(_ detail: ServerDeckDetail) throws -> DeckImportOutcome {
        saved.append(detail)
        return try saveOutcome.get()
    }
    func copyPictures(of detail: ServerDeckDetail) -> Single<Int> { pictureCopies.append(detail); return copyResult }
}

final class SpyReviewView: CardReviewViewInterface {
    var states: [CardReviewState] = []
    func render(_ state: CardReviewState) { states.append(state) }
    var last: CardReviewState { states.last ?? CardReviewState() }
}

final class FakeReviewWireframe: CardReviewWireframeInterface {
    private(set) var leaveCount = 0
    func leave() { leaveCount += 1 }
}

final class SpyReviewSpeech: SpeechServiceInterface {
    private(set) var spoken: [(String, String)] = []
    private(set) var stops = 0
    func speak(_ text: String, languageCode: String) { spoken.append((text, languageCode)) }
    func stop() { stops += 1 }
}

final class CardReviewPresenterTests: XCTestCase {
    private var interactor: FakeServerInteractor!
    private var wireframe: FakeReviewWireframe!
    private var view: SpyReviewView!
    private var speech: SpyReviewSpeech!
    private var clock: Date!
    private var presenter: CardReviewPresenter!

    private let ids = ["11111111-0000-4000-8000-000000000001", "11111111-0000-4000-8000-000000000002", "11111111-0000-4000-8000-000000000003"]

    override func setUp() {
        super.setUp()
        interactor = FakeServerInteractor()
        wireframe = FakeReviewWireframe()
        view = SpyReviewView()
        speech = SpyReviewSpeech()
        clock = Date(timeIntervalSince1970: 1_000_000)
    }

    private func card(_ index: Int, front: String? = nil, state: DueCard.State = .review, leech: Bool = false) -> DueCard {
        DueCard(id: ids[index], state: state, front: front ?? "語\(index)", back: "nghĩa \(index)", reading: "よみ\(index)", lapses: 0, isLeech: leech)
    }

    private func makePresenter(_ initial: [DueCard]?, shuffle: @escaping ([String]) -> [String] = { $0 }) {
        presenter = CardReviewPresenter(initialCards: initial, interactor: interactor, wireframe: wireframe, speech: speech, now: { [unowned self] in clock },
                                        shuffle: shuffle)
        presenter.view = view
        presenter.viewDidLoad()
    }

    private func advance(_ seconds: TimeInterval) { clock = clock.addingTimeInterval(seconds) }

    // MARK: Start

    func test_startsOnTheFirstCardUnflippedWithProgress() {
        makePresenter([card(0, state: .new), card(1), card(2)])
        XCTAssertEqual(view.last.screen, .card)
        XCTAssertEqual(view.last.card?.front, "語0")
        XCTAssertEqual(view.last.card?.isFlipped, false)
        XCTAssertEqual(view.last.card?.stateLabel, NSLocalizedString("New", comment: ""))
        XCTAssertEqual(view.last.progress, 0)
        XCTAssertTrue(interactor.dueLimits.isEmpty, "Cards the tab already loaded are not fetched again")
    }

    func test_withoutPreloadedCardsItFetchesABatchOf50() {
        interactor.dueResult = .just([card(0), card(1)])
        makePresenter(nil)
        XCTAssertEqual(interactor.dueLimits, [50])
        XCTAssertEqual(view.last.screen, .card)
    }

    func test_signedOutShowsAFailureWithoutAskingTheServer() {
        interactor.isSignedIn = false
        makePresenter(nil)
        guard case .failed(_, let canRetry) = view.last.screen else { return XCTFail("expected failure") }
        XCTAssertFalse(canRetry)
        XCTAssertTrue(interactor.dueLimits.isEmpty)
    }

    func test_aFailedLoadCanBeRetried() {
        interactor.dueResult = .error(LearnerAPIError.offline)
        makePresenter(nil)
        guard case .failed(_, let canRetry) = view.last.screen else { return XCTFail("expected failure") }
        XCTAssertTrue(canRetry)
        interactor.dueResult = .just([card(0)])
        presenter.reloadBatch()
        XCTAssertEqual(view.last.screen, .card)
    }

    func test_nothingDueFinishesWithAnEmptySummary() {
        interactor.dueResult = .just([])
        makePresenter(nil)
        XCTAssertEqual(view.last.screen, .finished)
        XCTAssertEqual(view.last.summary.total, 0)
        XCTAssertEqual(view.last.summary.accuracy, 0)
    }

    // MARK: Rating

    func test_aCardCannotBeRatedBeforeItsAnswerIsShown() {
        makePresenter([card(0)])
        presenter.rate(.good)
        XCTAssertTrue(interactor.submissions.isEmpty)
        presenter.flip()
        XCTAssertEqual(view.last.card?.isFlipped, true)
        presenter.flip()
        XCTAssertEqual(view.last.card?.isFlipped, false, "Flipping again shows the question")
    }

    func test_ratingSendsTheRatingAndTheTimeSpentThenMovesOn() {
        makePresenter([card(0), card(1)])
        advance(4.2)
        presenter.flip()
        presenter.rate(.good)
        XCTAssertEqual(interactor.submissions.count, 1)
        XCTAssertEqual(interactor.submissions[0].cardId, ids[0])
        XCTAssertEqual(interactor.submissions[0].rating, .good)
        XCTAssertEqual(interactor.submissions[0].elapsed, 4.2, accuracy: 0.001)
        XCTAssertEqual(view.last.card?.front, "語1")
        XCTAssertEqual(view.last.card?.isFlipped, false)
        XCTAssertEqual(view.last.progressText, String(format: NSLocalizedString("%1$lld of %2$lld", comment: ""), 2, 2))
        XCTAssertEqual(view.last.summary.total, 1)
    }

    func test_aSecondTapWhileTheRatingIsInFlightIsNotSentAgain() {
        let pending = PublishSubject<Void>()
        interactor.submitResults = [pending.asSingle()]
        makePresenter([card(0), card(1)])
        presenter.flip()
        presenter.rate(.easy)
        XCTAssertTrue(view.last.isSubmitting)
        presenter.rate(.easy)
        presenter.rate(.again)
        presenter.flip()
        XCTAssertEqual(interactor.submissions.count, 1, "A rating moves the schedule each time it arrives: it is sent once")
        pending.onNext(())
        pending.onCompleted()
        XCTAssertFalse(view.last.isSubmitting)
        XCTAssertEqual(view.last.card?.front, "語1")
    }

    func test_closingWhileARatingIsInFlightWaitsForTheAnswer() {
        let pending = PublishSubject<Void>()
        interactor.submitResults = [pending.asSingle()]
        makePresenter([card(0)])
        presenter.flip()
        presenter.rate(.good)
        presenter.close()
        XCTAssertEqual(wireframe.leaveCount, 0)
        pending.onNext(())
        pending.onCompleted()
        presenter.close()
        XCTAssertEqual(wireframe.leaveCount, 1)
    }

    // MARK: Failure

    func test_aFailedRatingKeepsTheCardAndRetryReusesTheSameRatingAndTime() {
        interactor.submitResults = [.error(LearnerAPIError.server(500)), .just(())]
        makePresenter([card(0), card(1)])
        advance(3)
        presenter.flip()
        presenter.rate(.hard)
        XCTAssertEqual(view.last.card?.front, "語0")
        XCTAssertNotNil(view.last.failure)
        XCTAssertEqual(view.last.failure?.outcomeUnknown, false)
        XCTAssertFalse(view.last.isSubmitting)
        XCTAssertEqual(view.last.summary.total, 0, "A rating the server did not confirm is not counted")
        advance(30)
        presenter.retryRating()
        XCTAssertEqual(interactor.submissions.map(\.rating), [.hard, .hard])
        XCTAssertEqual(interactor.submissions[1].elapsed, 3, accuracy: 0.001, "Time spent thinking is not inflated by the time spent on the error")
        XCTAssertNil(view.last.failure)
        XCTAssertEqual(view.last.card?.front, "語1")
        XCTAssertEqual(view.last.summary.hard, 1)
    }

    func test_aBrokenConnectionWarnsThatTheOutcomeIsUnknown() {
        interactor.submitResults = [.error(LearnerAPIError.interrupted)]
        makePresenter([card(0)])
        presenter.flip()
        presenter.rate(.good)
        XCTAssertEqual(view.last.failure?.outcomeUnknown, true)
    }

    func test_whileAFailureIsShownNothingElseCanBeRated() {
        interactor.submitResults = [.error(LearnerAPIError.offline)]
        makePresenter([card(0)])
        presenter.flip()
        presenter.rate(.good)
        presenter.rate(.easy)
        presenter.flip()
        XCTAssertEqual(interactor.submissions.count, 1)
    }

    func test_skippingAFailedCardLeavesItDueAndCountsItAsSkipped() {
        interactor.submitResults = [.error(LearnerAPIError.offline)]
        makePresenter([card(0), card(1)])
        presenter.flip()
        presenter.rate(.good)
        presenter.skipCard()
        XCTAssertEqual(view.last.card?.front, "語1")
        XCTAssertEqual(view.last.summary.skipped, 1)
        XCTAssertEqual(view.last.summary.total, 0)
    }

    func test_skipDoesNothingWhenThereIsNoFailure() {
        makePresenter([card(0), card(1)])
        presenter.skipCard()
        XCTAssertEqual(view.last.card?.front, "語0")
    }

    func test_aCardTheServerNoLongerKnowsIsSkippedWithoutAnError() {
        interactor.submitResults = [.error(LearnerAPIError.notFound)]
        makePresenter([card(0), card(1)])
        presenter.flip()
        presenter.rate(.good)
        XCTAssertNil(view.last.failure)
        XCTAssertEqual(view.last.card?.front, "語1")
        XCTAssertEqual(view.last.summary.skipped, 1)
    }

    func test_aSessionThatEndedOnTheServerSideStopsTheReview() {
        interactor.submitResults = [.error(LearnerAPIError.signInRequired)]
        makePresenter([card(0), card(1)])
        presenter.flip()
        presenter.rate(.good)
        guard case .failed(_, let canRetry) = view.last.screen else { return XCTFail("expected failure screen") }
        XCTAssertFalse(canRetry)
    }

    // MARK: Summary

    func test_theSummaryCountsConfirmedRatingsStreakAccuracyAndTime() {
        makePresenter([card(0), card(1), card(2)])
        advance(5)
        for rating in [ReviewRating.good, .easy, .again] {
            presenter.flip()
            presenter.rate(rating)
        }
        XCTAssertEqual(view.last.screen, .finished)
        let summary = view.last.summary
        XCTAssertEqual(summary.total, 3)
        XCTAssertEqual(summary.good, 1)
        XCTAssertEqual(summary.easy, 1)
        XCTAssertEqual(summary.again, 1)
        XCTAssertEqual(summary.longestStreak, 2)
        XCTAssertEqual(summary.accuracy, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(summary.duration, 5, accuracy: 0.001)
        XCTAssertFalse(summary.mayHaveMore, "Fewer than a full batch: nothing more is due")
    }

    func test_hardKeepsTheStreakWithoutExtendingIt() {
        makePresenter([card(0), card(1), card(2)])
        for rating in [ReviewRating.good, .hard, .good] {
            presenter.flip()
            presenter.rate(rating)
        }
        XCTAssertEqual(view.last.summary.longestStreak, 2)
    }

    func test_aFullBatchOffersToContinue() {
        let batch = (0..<50).map { DueCard(id: "11111111-0000-4000-8000-0000000000\(String(format: "%02d", $0))", state: .review, front: "語", back: "a", reading: "", lapses: 0, isLeech: false) }
        makePresenter(batch)
        XCTAssertTrue(view.last.summary.mayHaveMore)
    }

    // MARK: Speech

    func test_speakingReadsTheVisibleSideInItsOwnLanguage() {
        makePresenter([card(0, front: "食べる")])
        presenter.speakCurrent()
        XCTAssertEqual(speech.spoken.last?.0, "食べる")
        XCTAssertEqual(speech.spoken.last?.1, "ja-JP")
        presenter.flip()
        presenter.speakCurrent()
        XCTAssertEqual(speech.spoken.last?.0, "nghĩa 0")
        XCTAssertEqual(speech.spoken.last?.1, "vi-VN")
    }

    func test_leavingTheScreenStopsSpeech() {
        makePresenter([card(0)])
        presenter.viewWillDisappear()
        XCTAssertGreaterThan(speech.stops, 0)
    }
}

/// Multiple-choice questions on server-account review (K-07). A pick only reveals the card: the rating stays the learner's.
extension CardReviewPresenterTests {
    /// An empty question when none is offered, so a missing choice fails an assertion instead of crashing the run.
    private var choiceNow: ReviewChoiceState { view.last.choice ?? ReviewChoiceState(options: [], correctIndex: 0, selectedIndex: nil) }

    private func startWithChoices(_ distractors: [String] = ["sai A", "sai B", "sai C"], shuffle: @escaping ([String]) -> [String] = { $0 }) {
        interactor.distractorResult = .just(distractors)
        makePresenter([card(0), card(1)], shuffle: shuffle)
    }

    func test_choice_requestsThreeWrongAnswersForTheShownCard() {
        startWithChoices()
        XCTAssertEqual(interactor.distractorRequests.map(\.id), [ids[0]])
        XCTAssertEqual(interactor.distractorRequests.map(\.count), [3])
    }

    func test_choice_isOfferedWithTheCorrectAnswerAmongTheServersWrongOnes() {
        // Rotated, so the right answer is neither first nor last and `correctIndex` has to follow it.
        startWithChoices(shuffle: { Array($0.dropFirst()) + [$0[0]] })
        let choice = view.last.choice
        XCTAssertEqual(choice?.options, ["sai B", "sai C", "nghĩa 0", "sai A"])
        XCTAssertEqual(choice?.correctIndex, 2)
        XCTAssertNil(choice?.selectedIndex)
        XCTAssertEqual(view.last.card?.isFlipped, false, "The question comes first")
    }

    func test_choice_dropsEmptyRepeatedAndCorrectLookalikeAnswersAndNeedsTwoOthers() {
        startWithChoices(["", "  ", "nghĩa 0", "sai A", "sai A"])
        XCTAssertNil(view.last.choice, "Only one distinct wrong answer is left: not a fair question")
        startWithChoices(["nghĩa 0", "sai A", "sai B", "sai A"])
        XCTAssertEqual(view.last.choice?.options.sorted(), ["nghĩa 0", "sai A", "sai B"])
    }

    func test_choice_isNotOfferedWhenTheServerHasNoAnswersOrFails() {
        startWithChoices([])
        XCTAssertNil(view.last.choice)
        interactor.distractorResult = .error(LearnerAPIError.offline)
        makePresenter([card(0)])
        XCTAssertNil(view.last.choice)
        XCTAssertEqual(view.last.screen, .card)
        presenter.flip()
        XCTAssertEqual(view.last.card?.isFlipped, true, "Without a question the card is flipped as before")
        presenter.rate(.good)
        XCTAssertEqual(interactor.submissions.count, 1)
    }

    func test_choice_aRightPickRevealsTheCardButDoesNotRateIt() {
        startWithChoices()
        presenter.choose(optionAt: choiceNow.correctIndex)
        XCTAssertEqual(view.last.choice?.isCorrect, true)
        XCTAssertEqual(view.last.card?.isFlipped, true)
        XCTAssertTrue(interactor.submissions.isEmpty, "A right answer is not an automatic Good")
        XCTAssertEqual(view.last.summary.total, 0)
        XCTAssertEqual(view.last.card?.front, "語0", "The learner still has to rate this card")
    }

    func test_choice_aWrongPickRevealsTheCardAndDoesNotRateItEither() {
        startWithChoices()
        let wrong = (choiceNow.correctIndex + 1) % 4
        presenter.choose(optionAt: wrong)
        XCTAssertEqual(view.last.choice?.isCorrect, false)
        XCTAssertEqual(view.last.card?.isFlipped, true)
        XCTAssertTrue(interactor.submissions.isEmpty)
    }

    func test_choice_theLearnersOwnRatingIsWhatIsSentAfterAPick_exactlyOnce() {
        startWithChoices()
        presenter.choose(optionAt: choiceNow.correctIndex)
        presenter.rate(.hard)
        presenter.rate(.hard)
        XCTAssertEqual(interactor.submissions.map(\.rating), [.hard], "One confirmation, one POST, and it is the rating the learner chose")
        XCTAssertEqual(view.last.card?.front, "語1")
        XCTAssertNil(view.last.choice?.selectedIndex, "The next card is a fresh question, not the previous answer")
        XCTAssertTrue(view.last.choice?.options.contains("nghĩa 1") ?? false)
        XCTAssertEqual(interactor.distractorRequests.map(\.id), [ids[0], ids[1]])
    }

    func test_choice_aSecondPickIsIgnored() {
        startWithChoices()
        let right = choiceNow.correctIndex
        presenter.choose(optionAt: right)
        presenter.choose(optionAt: (right + 1) % 4)
        XCTAssertEqual(view.last.choice?.selectedIndex, right)
        XCTAssertEqual(view.last.choice?.isCorrect, true)
    }

    func test_choice_anOutOfRangePickIsIgnored() {
        startWithChoices()
        presenter.choose(optionAt: 9)
        presenter.choose(optionAt: -1)
        XCTAssertNil(view.last.choice?.selectedIndex)
        XCTAssertEqual(view.last.card?.isFlipped, false)
    }

    func test_choice_showingTheAnswerInsteadSkipsTheQuestionAndCountsNothing() {
        startWithChoices()
        presenter.flip()
        XCTAssertNil(view.last.choice, "The question is dropped; it never counts as reviewed")
        XCTAssertEqual(view.last.card?.isFlipped, true)
        XCTAssertTrue(interactor.submissions.isEmpty)
        XCTAssertEqual(view.last.summary.total, 0)
        presenter.rate(.good)
        XCTAssertEqual(interactor.submissions.count, 1)
    }

    func test_choice_anAnswerThatArrivesAfterTheLearnerMovedOnIsDiscarded() {
        let late = PublishSubject<[String]>()
        interactor.distractorResultsByCard = [ids[0]: late.asSingle()]
        interactor.distractorResult = .just([])
        makePresenter([card(0), card(1)])
        presenter.flip()
        presenter.rate(.good)
        XCTAssertEqual(view.last.card?.front, "語1")
        late.onNext(["sai A", "sai B", "sai C"])
        late.onCompleted()
        XCTAssertNil(view.last.choice, "Options of the previous card must not appear on this one")
    }

    func test_choice_aLateAnswerForTheShownCardOffersTheQuestionIfNotYetAnswered() {
        let late = PublishSubject<[String]>()
        interactor.distractorResultsByCard = [ids[0]: late.asSingle()]
        makePresenter([card(0)])
        XCTAssertNil(view.last.choice)
        late.onNext(["sai A", "sai B"])
        late.onCompleted()
        XCTAssertNotNil(view.last.choice)
        presenter.flip()
        XCTAssertNil(view.last.choice)
    }

    func test_choice_noPickIsPossibleOnceTheCardIsRevealedOrWhileSubmitting() {
        let pending = PublishSubject<Void>()
        interactor.submitResults = [pending.asSingle()]
        startWithChoices()
        presenter.choose(optionAt: choiceNow.correctIndex)
        presenter.rate(.good)
        presenter.choose(optionAt: 0)
        XCTAssertTrue(view.last.isSubmitting)
        XCTAssertEqual(interactor.submissions.count, 1)
        XCTAssertEqual(view.last.choice?.selectedIndex, view.last.choice?.correctIndex, "Nothing changes while the rating is on its way")
    }
}

private final class StubReviewPresenter: CardReviewPresenterInterface {
    private(set) var chosen: [Int] = []
    private(set) var flips = 0
    private(set) var ratings: [ReviewRating] = []
    func viewDidLoad() {}
    func viewWillDisappear() {}
    func flip() { flips += 1 }
    func choose(optionAt index: Int) { chosen.append(index) }
    func rate(_ rating: ReviewRating) { ratings.append(rating) }
    func retryRating() {}
    func skipCard() {}
    func speakCurrent() {}
    func reloadBatch() {}
    func close() {}
}

/// What the learner sees of the multiple-choice question (K-07): options before the answer, the four ratings after, and a tap that only
/// reaches `choose`.
final class CardReviewViewChoiceTests: XCTestCase {
    private var presenter: StubReviewPresenter!
    private var controller: CardReviewViewController!

    override func setUp() {
        super.setUp()
        presenter = StubReviewPresenter()
        controller = CardReviewViewController()
        controller.presenter = presenter
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
    }

    private func state(flipped: Bool, choice: ReviewChoiceState?) -> CardReviewState {
        var state = CardReviewState()
        state.screen = .card
        state.card = ReviewCardState(front: "犬", back: "chó", reading: "いぬ", isFlipped: flipped, stateLabel: "Review", isLeech: false)
        state.choice = choice
        return state
    }

    private func views(_ identifier: String) -> [UIView] {
        var found: [UIView] = []
        func walk(_ view: UIView) {
            if view.accessibilityIdentifier == identifier { found.append(view) }
            view.subviews.forEach(walk)
        }
        walk(controller.view)
        return found
    }

    private func isShown(_ identifier: String) -> Bool {
        views(identifier).contains { sequence(first: $0, next: \.superview).allSatisfy { !$0.isHidden } }
    }

    private let question = ReviewChoiceState(options: ["mèo", "chó", "chim"], correctIndex: 1, selectedIndex: nil)

    func test_theQuestionShowsItsOptionsAndTheShowAnswerWayOut_withoutRatings() {
        controller.render(state(flipped: false, choice: question))
        XCTAssertEqual((0..<3).filter { isShown("review_choice_\($0)") }, [0, 1, 2])
        XCTAssertTrue(isShown("review_show_answer"), "The learner can still give the question up and just flip the card")
        XCTAssertFalse(isShown("review_rate_good"))
    }

    func test_tappingAnOptionOnlyForwardsThePick() throws {
        controller.render(state(flipped: false, choice: question))
        let option = try XCTUnwrap(views("review_choice_2").first as? UIButton)
        option.sendActions(for: .primaryActionTriggered)
        XCTAssertEqual(presenter.chosen, [2])
        XCTAssertTrue(presenter.ratings.isEmpty, "Picking never rates")
        XCTAssertEqual(presenter.flips, 0)
    }

    func test_afterAPickTheOptionsGiveWayToFeedbackAndTheFourRatings() {
        var answered = question
        answered.selectedIndex = 1
        controller.render(state(flipped: true, choice: answered))
        XCTAssertFalse(isShown("review_choice_0"))
        XCTAssertTrue(isShown("review_choice_feedback"))
        XCTAssertTrue(["again", "hard", "good", "easy"].allSatisfy { isShown("review_rate_\($0)") })
    }

    func test_withoutAQuestionTheScreenIsTheFlipAndRateOneItWasBefore() {
        controller.render(state(flipped: false, choice: nil))
        XCTAssertFalse(isShown("review_choice_0"))
        XCTAssertTrue(isShown("review_show_answer"))
        controller.render(state(flipped: true, choice: nil))
        XCTAssertFalse(isShown("review_choice_feedback"))
        XCTAssertTrue(isShown("review_rate_easy"))
    }
}
