//
//  CardReviewPresenter.swift
//  FlashcardApp
//
//  The spaced-repetition review of the cards the account says are due. The learner flips a card and rates it
//  (again / hard / good / easy); each rating is sent to the server straight away and moves the card's schedule.
//
//  A rating changes the schedule every time the server receives it, so it is sent once: when that fails the
//  learner stays on the card and chooses between trying again and skipping it (the card stays due). Only
//  ratings the server confirmed are counted in the summary.
//

import Foundation
import RxSwift

struct ReviewCardState: Equatable {
    let front: String
    let back: String
    let reading: String
    let isFlipped: Bool
    /// "New", "Relearning" …: where the card is in its schedule. Words, not only a colour.
    let stateLabel: String
    let isLeech: Bool
}

struct ReviewSummary: Equatable {
    var total = 0
    var again = 0
    var hard = 0
    var good = 0
    var easy = 0
    var skipped = 0
    var longestStreak = 0
    var duration: TimeInterval = 0
    /// A full batch was reviewed, so more cards may be due.
    var mayHaveMore = false

    /// Share of the rated cards that were remembered (good or easy), 0 when nothing was rated.
    var accuracy: Double { total == 0 ? 0 : Double(good + easy) / Double(total) }
}

struct CardReviewState: Equatable {
    enum Screen: Equatable {
        case loading
        case card
        case finished
        /// Loading the batch failed (or the learner is signed out).
        case failed(message: String, canRetry: Bool)
    }

    /// A rating the server did not confirm. The card stays on screen until the learner decides.
    struct Failure: Equatable {
        let message: String
        /// The connection broke after the request left: the server may have applied the rating.
        let outcomeUnknown: Bool
    }

    var screen: Screen = .loading
    var progressText = ""
    var progress: Float = 0
    var card: ReviewCardState?
    var isSubmitting = false
    var failure: Failure?
    var summary = ReviewSummary()
}

protocol CardReviewViewInterface: AnyObject {
    func render(_ state: CardReviewState)
}

protocol CardReviewPresenterInterface: AnyObject {
    func viewDidLoad()
    func viewWillDisappear()
    func flip()
    func rate(_ rating: ReviewRating)
    /// Sends the rating that failed, again, because the learner asked.
    func retryRating()
    /// Leaves the card that could not be rated; it stays due.
    func skipCard()
    func speakCurrent()
    func reloadBatch()
    func close()
}

final class CardReviewPresenter {
    static let batchSize = 50

    private let interactor: CardLibraryServerInteractorInterface
    private let wireframe: CardReviewWireframeInterface
    private let speech: SpeechServiceInterface
    private let now: () -> Date
    weak var view: CardReviewViewInterface?

    private var state = CardReviewState()
    private var cards: [DueCard] = []
    private var position = 0
    private var isFlipped = false
    private var cardShownAt = Date()
    private var sessionStartedAt = Date()
    private var streak = 0
    private var pendingRating: ReviewRating?
    private var pendingElapsed: TimeInterval = 0
    private let request = SerialDisposable()

    /// `initialCards` skips the first load when the Cards tab already has them.
    init(initialCards: [DueCard]?,
         interactor: CardLibraryServerInteractorInterface,
         wireframe: CardReviewWireframeInterface,
         speech: SpeechServiceInterface = SystemSpeechService.shared,
         now: @escaping () -> Date = Date.init) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.speech = speech
        self.now = now
        self.initialCards = initialCards
    }

    private var initialCards: [DueCard]?

    deinit { request.dispose() }

    // MARK: Loading

    private func start(with batch: [DueCard]) {
        cards = batch
        position = 0
        streak = 0
        state.summary = ReviewSummary(mayHaveMore: batch.count >= Self.batchSize)
        sessionStartedAt = now()
        showCurrentCard()
    }

    private func loadBatch() {
        guard interactor.isSignedIn else {
            state.screen = .failed(message: NSLocalizedString("Sign in to review your cards.", comment: ""), canRetry: false)
            return publish()
        }
        state.screen = .loading
        publish()
        request.disposable = interactor.dueCards(limit: Self.batchSize)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] batch in self?.start(with: batch) },
                       onFailure: { [weak self] error in
                guard let self else { return }
                let signInRequired: Bool
                if case LearnerAPIError.signInRequired = error { signInRequired = true } else { signInRequired = false }
                self.state.screen = .failed(message: Self.message(for: error), canRetry: !signInRequired)
                self.publish()
            })
    }

    // MARK: State

    private func showCurrentCard() {
        guard position < cards.count else { return finish() }
        isFlipped = false
        cardShownAt = now()
        state.screen = .card
        state.failure = nil
        state.isSubmitting = false
        pendingRating = nil
        publish()
    }

    private func finish() {
        speech.stop()
        state.summary.duration = now().timeIntervalSince(sessionStartedAt)
        state.screen = .finished
        state.card = nil
        state.progress = 1
        state.failure = nil
        state.isSubmitting = false
        publish()
    }

    private func publish() {
        if state.screen == .card, position < cards.count {
            let card = cards[position]
            state.card = ReviewCardState(front: card.front, back: card.back, reading: card.reading, isFlipped: isFlipped,
                                         stateLabel: Self.label(for: card.state), isLeech: card.isLeech)
            state.progressText = String(format: NSLocalizedString("%1$lld of %2$lld", comment: "Study progress: position of total"),
                                        position + 1, cards.count)
            state.progress = cards.isEmpty ? 0 : Float(position) / Float(cards.count)
        }
        view?.render(state)
    }

    static func label(for state: DueCard.State) -> String {
        switch state {
        case .new: return NSLocalizedString("New", comment: "Schedule state of a card")
        case .learning: return NSLocalizedString("Learning", comment: "Schedule state of a card")
        case .review: return NSLocalizedString("Review", comment: "Schedule state of a card")
        case .lapsed: return NSLocalizedString("Relearning", comment: "Schedule state of a card the learner forgot")
        }
    }

    static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func record(_ rating: ReviewRating) {
        state.summary.total += 1
        switch rating {
        case .again: state.summary.again += 1
        case .hard: state.summary.hard += 1
        case .good: state.summary.good += 1
        case .easy: state.summary.easy += 1
        }
        switch rating {
        case .good, .easy:
            streak += 1
            state.summary.longestStreak = max(state.summary.longestStreak, streak)
        case .again: streak = 0
        case .hard: break
        }
    }

    private func submit(_ rating: ReviewRating, elapsed: TimeInterval) {
        guard position < cards.count else { return }
        let card = cards[position]
        pendingRating = rating
        pendingElapsed = elapsed
        state.isSubmitting = true
        state.failure = nil
        publish()
        request.disposable = interactor.submit(rating, for: card, elapsed: elapsed)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                guard let self else { return }
                self.record(rating)
                self.position += 1
                self.showCurrentCard()
            }, onFailure: { [weak self] error in
                guard let self else { return }
                self.state.isSubmitting = false
                if case LearnerAPIError.signInRequired = error {
                    self.state.screen = .failed(message: Self.message(for: error), canRetry: false)
                    self.state.failure = nil
                } else if case LearnerAPIError.staleSession = error {
                    self.state.screen = .failed(message: Self.message(for: error), canRetry: false)
                    self.state.failure = nil
                } else if case LearnerAPIError.notFound = error {
                    // The card is no longer in the learner's schedule (for example its deck was archived): nothing to rate.
                    self.state.summary.skipped += 1
                    self.position += 1
                    return self.showCurrentCard()
                } else {
                    self.state.failure = .init(message: Self.message(for: error), outcomeUnknown: (error as? LearnerAPIError) == .interrupted)
                }
                self.publish()
            })
    }

    private func languageCode(for text: String) -> String {
        JapaneseText.containsJapanese(text) ? "ja-JP" : "vi-VN"
    }
}

extension CardReviewPresenter: CardReviewPresenterInterface {
    func viewDidLoad() {
        if let batch = initialCards {
            initialCards = nil
            if batch.isEmpty { loadBatch() } else { start(with: batch) }
        } else {
            loadBatch()
        }
    }

    func viewWillDisappear() { speech.stop() }

    func flip() {
        guard state.screen == .card, !state.isSubmitting, state.failure == nil, position < cards.count else { return }
        isFlipped.toggle()
        publish()
    }

    func rate(_ rating: ReviewRating) {
        // Rating needs the answer: it is a judgement of the recall the learner just checked.
        guard state.screen == .card, isFlipped, !state.isSubmitting, state.failure == nil else { return }
        submit(rating, elapsed: now().timeIntervalSince(cardShownAt))
    }

    func retryRating() {
        guard state.failure != nil, !state.isSubmitting, let rating = pendingRating else { return }
        submit(rating, elapsed: pendingElapsed)
    }

    func skipCard() {
        guard state.failure != nil, !state.isSubmitting else { return }
        state.summary.skipped += 1
        position += 1
        showCurrentCard()
    }

    func speakCurrent() {
        guard state.screen == .card, position < cards.count else { return }
        let card = cards[position]
        let text = isFlipped ? card.back : card.front
        speech.speak(text, languageCode: languageCode(for: text))
    }

    func reloadBatch() {
        guard !state.isSubmitting else { return }
        loadBatch()
    }

    func close() {
        // A rating in flight is sent whether or not the screen is open; wait for its answer so the result is not lost.
        guard !state.isSubmitting else { return }
        speech.stop()
        wireframe.leave()
    }
}
