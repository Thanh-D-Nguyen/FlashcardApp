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
    var deviceCopies = Set<String>()
    var saveOutcome: Result<DeckImportOutcome, Error> = .success(.imported(deckId: "x"))
    var copyResult: Single<Int> = .just(0)
    private(set) var pictureCopies: [ServerDeckDetail] = []

    private(set) var decksCalls = 0
    private(set) var dueLimits: [Int] = []
    private(set) var submissions: [(rating: ReviewRating, cardId: String, elapsed: TimeInterval)] = []
    private(set) var archived: [String] = []
    private(set) var saved: [ServerDeckDetail] = []

    func decks() -> Single<[ServerDeck]> { decksCalls += 1; return decksResult }
    func detail(deckId: String) -> Single<ServerDeckDetail> { detailResult }
    func dueCards(limit: Int) -> Single<[DueCard]> { dueLimits.append(limit); return dueResult }
    func submit(_ rating: ReviewRating, for card: DueCard, elapsed: TimeInterval) -> Single<Void> {
        submissions.append((rating, card.id, elapsed))
        return submitResults.isEmpty ? .just(()) : submitResults.removeFirst()
    }
    func archive(deckId: String) -> Single<Void> { archived.append(deckId); return archiveResult }
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

    private func makePresenter(_ initial: [DueCard]?) {
        presenter = CardReviewPresenter(initialCards: initial, interactor: interactor, wireframe: wireframe, speech: speech, now: { [unowned self] in clock })
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
