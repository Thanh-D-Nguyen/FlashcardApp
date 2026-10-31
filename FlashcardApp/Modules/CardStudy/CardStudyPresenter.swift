import Foundation
import RxSwift

/// How the card area should change when new state arrives; the view animates accordingly.
enum CardStudyTransition {
    case none
    case flip
    case forward
    case backward
}

struct StudyCardState: Equatable {
    let front: String
    let back: String
    let reading: String
    let note: String
    let imageReference: String
    let isFlipped: Bool
    /// "Photo by …" for a picture chosen from a provider; empty when there is none to show.
    var imageCredit: String = ""
}

struct StudyQuizState: Equatable {
    let options: [String]
    let selected: String?
    let correct: String
}

/// A card the learner got wrong or rated "needs review", for the end-of-session list.
struct StudyReviewedCard: Equatable {
    let front: String
    let back: String
    let result: ReviewResult
}

/// What the session covered. Only attempts confirmed saved are counted: an attempt that could not be saved is not progress.
struct StudySummary: Equatable {
    let total: Int
    /// Saved quiz answers, and how many of them were right.
    let answered: Int
    let correct: Int
    let mode: StudyMode
    var saved = 0
    var incorrect = 0
    /// Saved self-ratings; they are never added to the quiz score.
    var selfRated = 0
    var toReview: [StudyReviewedCard] = []
}

/// Saving of the question on screen and of the session so far.
struct StudyReviewState: Equatable {
    enum Save: Equatable {
        /// Nothing to save yet: not answered, or only looked at.
        case none
        case saved
        /// The attempt could not be saved. The learner stays on the question and can retry or leave.
        case failed
    }

    var savedCount = 0
    var total = 0
    /// Flip mode, answer shown, nothing recorded yet: the learner can rate themselves.
    var canRate = false
    var save = Save.none
    /// The reading was in view before the answer, so the result is recorded as helped.
    var usedReadingHint = false
}

struct CardStudyState: Equatable {
    enum Screen: Equatable {
        case card
        case finished
    }

    var screen: Screen
    var deckName: String
    var direction: LanguageSortingType
    var mode: StudyMode
    var canQuiz: Bool
    var isShuffled: Bool
    var readingVisible: Bool
    var imagesVisible: Bool
    var autoSpeak: Bool
    var deckHasImages: Bool
    var progressText: String
    var progress: Float
    var card: StudyCardState?
    /// The chosen card style; `nil` is the app's own adaptive card.
    var style: CardStyle?
    /// Example sentences for the current card; hidden until its answer is shown.
    var examples: ExamplesPanelState
    var examplesExpanded: Bool
    var quiz: StudyQuizState?
    var canGoBack: Bool
    var primaryTitle: String
    var isPrimaryEnabled: Bool
    var review: StudyReviewState
    var summary: StudySummary
}

protocol CardStudyViewInterface: AnyObject {
    func render(_ state: CardStudyState, transition: CardStudyTransition)
}

protocol CardStudyPresenterInterface: AnyObject {
    func viewWillAppear()
    func viewWillDisappear()
    func flip()
    func primaryAction()
    func previous()
    func next()
    func select(option: String)
    /// Self-rating of a flipped card; the attempt is saved at once.
    func rate(_ rating: SelfRating)
    /// Saves the attempt that failed to save, again with the same id.
    func retrySave()
    /// Leaves the session, asking first when an attempt is still unsaved.
    func leaveSession()
    func setMode(_ mode: StudyMode)
    func setShuffled(_ shuffled: Bool)
    func setReadingVisible(_ visible: Bool)
    func setImagesVisible(_ visible: Bool)
    func setAutoSpeak(_ enabled: Bool)
    func speakCurrent()
    func speakExample(id: String)
    func setExamplesExpanded(_ expanded: Bool)
    func retryExamples()
    func addExample()
    func editExample(id: String)
    func removeExample(id: String)
    func restoreOriginalExample(id: String)
    func restoreRemovedExamples()
    func chooseStyle()
    func restart()
    func edit()
}

final class CardStudyPresenter {
    private let deckId: String
    /// Study only these cards, in this order (a session planned on Today); nil studies the whole deck.
    private let cardIDs: [String]?
    private let interactor: CardStudyInteractorInterface
    private let wireframe: CardStudyWireframeInterface
    private let preferences: StudyPreferencesInterface
    private let speech: SpeechServiceInterface
    private let random: StudyRandomSource
    private let examplesInteractor: CardExamplesInteractorInterface
    private let exampleStore: CardExampleStoreInterface
    private let reviewHistory: ReviewHistoryStoreInterface
    /// Whose sentences these are: the signed-in account's id, or "" with nobody signed in.
    private let ownerKey: () -> String
    weak var view: CardStudyViewInterface?

    private var creditCache: [String: String] = [:]
    private var deck: DeskEntity?
    private var session = StudySession(cards: [])
    /// Whose results this session saves, fixed when it starts: a different account never receives them.
    private var sessionOwner = ""
    /// Attempts of this run that are confirmed saved.
    private var savedAttemptIds = Set<String>()
    /// The attempt that could not be saved; the session waits for a retry or for the learner to leave.
    private var unsavedAttempt: ReviewAttempt?
    /// Set once the account changed: the learner has been told, and no further answer is saved.
    private var sessionEnded = false
    private enum ServerSentences: Equatable {
        case loading
        case loaded([CardExample])
        case unavailable
    }

    /// The server's sentences for the card on screen. Prefetched when the card appears, shown once its answer is.
    private var lookup: (cardId: String, term: String, state: ServerSentences)?
    private let lookupRequest = SerialDisposable()

    init(deckId: String,
         cardIDs: [String]? = nil,
         interactor: CardStudyInteractorInterface,
         wireframe: CardStudyWireframeInterface,
         preferences: StudyPreferencesInterface = UserDefaultsStudyPreferences.shared,
         speech: SpeechServiceInterface = SystemSpeechService.shared,
         random: @escaping StudyRandomSource = { Int.random(in: $0) },
         examples: CardExamplesInteractorInterface = CardExamplesInteractor(),
         exampleStore: CardExampleStoreInterface = RealmCardExampleStore(),
         reviewHistory: ReviewHistoryStoreInterface = RealmReviewHistoryStore(),
         ownerKey: @escaping () -> String = { AuthSession.shared.currentUser?.id ?? "" }) {
        self.deckId = deckId
        self.cardIDs = cardIDs
        self.interactor = interactor
        self.wireframe = wireframe
        self.preferences = preferences
        self.speech = speech
        self.random = random
        self.examplesInteractor = examples
        self.exampleStore = exampleStore
        self.reviewHistory = reviewHistory
        self.ownerKey = ownerKey
    }

    // MARK: Loading

    /// Loads the deck. A session in progress is kept when the deck did not change (e.g. returning from the editor).
    private func load() {
        guard let entity = interactor.deck(withId: deckId) else {
            speech.stop()
            wireframe.leave()
            return
        }
        let wholeDeck = entity.cards.map(StudyCard.init(entity:))
        let cards: [StudyCard]
        if let cardIDs {
            // A planned session: its cards in its order. Cards deleted since it was planned are skipped; with none left there is
            // nothing to study.
            var byID: [String: StudyCard] = [:]
            for card in wholeDeck where byID[card.id] == nil { byID[card.id] = card }
            cards = cardIDs.compactMap { byID[$0] }
            if cards.isEmpty {
                speech.stop()
                wireframe.leave()
                return
            }
        } else {
            cards = wholeDeck
        }
        let changed = deck == nil || session.cards != cards
        if !changed, sessionEnded || ownerKey() != sessionOwner { return endSessionForAccountChange() }
        deck = entity
        if changed {
            // A planned session keeps the order it was planned in (oldest due first).
            // The quiz of a planned session draws its wrong answers from the whole deck, so it is a quiz even for one due card.
            session = StudySession(cards: cards, quizPool: cardIDs == nil ? nil : wholeDeck, mode: preferences.mode,
                                   shuffled: cardIDs == nil && preferences.isShuffled, random: random)
            startRun()
        }
        publish(.none)
    }

    /// Starts counting a new run: the owner is fixed and nothing is saved or pending yet.
    private func startRun() {
        sessionOwner = ownerKey()
        savedAttemptIds = []
        unsavedAttempt = nil
        sessionEnded = false
    }

    // MARK: Saving

    private func persistCurrentAttempt() {
        guard let attempt = session.currentAttempt, !savedAttemptIds.contains(attempt.id) else { return }
        save(attempt)
    }

    /// Saves an attempt for the learner who started the session, in one step before anything else happens. A failure is
    /// kept, not hidden: the session waits on this attempt until it is saved or the learner leaves.
    private func save(_ attempt: ReviewAttempt) {
        guard ownerKey() == sessionOwner else { return endSessionForAccountChange() }
        do {
            _ = try reviewHistory.save(attempt, ownerKey: sessionOwner)
            savedAttemptIds.insert(attempt.id)
            if unsavedAttempt?.id == attempt.id { unsavedAttempt = nil }
        } catch {
            logger.error("Saving a study attempt failed: \(error.localizedDescription)")
            unsavedAttempt = attempt
        }
    }

    /// The account is no longer the one that started the session. The session is frozen and the learner is told; coming back to
    /// the screen asks again, so a message that could not be presented is not lost.
    private func endSessionForAccountChange() {
        sessionEnded = true
        speech.stop()
        wireframe.endSession(message: NSLocalizedString("The account changed, so this session ended. Your saved results are kept.", comment: ""))
    }

    /// False while an attempt waits to be saved or after the session ended: nothing may change the session then.
    private var canChange: Bool { unsavedAttempt == nil && !sessionEnded }

    private var saveStatus: StudyReviewState.Save {
        guard let attempt = session.currentAttempt else { return .none }
        if unsavedAttempt?.id == attempt.id { return .failed }
        return savedAttemptIds.contains(attempt.id) ? .saved : .none
    }

    private func makeSummary() -> StudySummary {
        let saved = session.attempts.filter { savedAttemptIds.contains($0.id) }
        let quiz = saved.filter { $0.skill == .recognition }
        let toReview = saved.compactMap { attempt -> StudyReviewedCard? in
            guard attempt.result == .incorrect || attempt.result == .needsReview,
                  let card = session.cards.first(where: { $0.id == attempt.cardID }) else { return nil }
            return StudyReviewedCard(front: card.front, back: card.back, result: attempt.result)
        }
        return StudySummary(total: session.count, answered: quiz.count, correct: quiz.filter { $0.result == .correct }.count,
                            mode: session.mode, saved: saved.count, incorrect: quiz.filter { $0.result == .incorrect }.count,
                            selfRated: saved.filter { $0.skill == .selfRecall }.count, toReview: toReview)
    }

    // MARK: State

    private func publish(_ transition: CardStudyTransition) {
        guard let deck else { return }
        // The reading in view before the answer is help; the result is recorded as such.
        if preferences.isReadingVisible, let card = session.current, !card.reading.isEmpty { session.noteHint(.reading) }
        syncExamples(deck: deck)
        view?.render(makeState(deck: deck), transition: transition)
        if transition != .none, !session.isFinished, session.current != nil { autoSpeakIfNeeded() }
    }

    /// The credit stored next to a picture found through the picture search; read once per picture.
    private func credit(for reference: String) -> String {
        guard !reference.isEmpty else { return "" }
        if let known = creditCache[reference] { return known }
        let line = CardImageStore.shared.attribution(for: reference)?.creditLine ?? ""
        creditCache[reference] = line
        return line
    }

    private func makeState(deck: DeskEntity) -> CardStudyState {
        let current = session.current
        let finished = session.isFinished || current == nil
        let progressText = String(format: NSLocalizedString("%1$lld of %2$lld", comment: "Study progress: position of total"),
                                  min(session.position + 1, max(session.count, 1)), session.count)
        let card = current.map {
            StudyCardState(front: $0.front, back: $0.back, reading: $0.reading, note: $0.note,
                           imageReference: $0.imageReference, isFlipped: session.isFlipped, imageCredit: credit(for: $0.imageReference))
        }
        var quiz: StudyQuizState?
        if session.mode == .quiz, let current { quiz = StudyQuizState(options: session.options, selected: session.selectedOption, correct: current.back) }
        let (title, enabled) = primary(finished: finished)
        let review = StudyReviewState(
            savedCount: savedAttemptIds.count, total: session.count,
            canRate: !finished && session.mode == .flip && session.isFlipped && session.currentAttempt == nil && unsavedAttempt == nil,
            save: saveStatus, usedReadingHint: !session.currentHints.isDisjoint(with: [.reading]))
        return CardStudyState(
            screen: finished ? .finished : .card,
            deckName: deck.name,
            direction: deck.sortingLanguage,
            mode: session.mode,
            canQuiz: session.canQuiz,
            isShuffled: session.isShuffled,
            readingVisible: preferences.isReadingVisible,
            imagesVisible: preferences.areImagesVisible,
            autoSpeak: preferences.autoSpeak,
            deckHasImages: session.cards.contains { !$0.imageReference.isEmpty },
            progressText: progressText,
            progress: session.count == 0 ? 0 : Float(savedAttemptIds.count) / Float(session.count),
            card: card,
            style: CardStyle.style(forSlug: preferences.cardStyleSlug),
            examples: finished ? .hidden : examplesPanel(),
            examplesExpanded: preferences.areExamplesVisible,
            quiz: quiz,
            canGoBack: session.canGoBack,
            primaryTitle: title,
            isPrimaryEnabled: enabled,
            review: review,
            summary: makeSummary())
    }

    private func primary(finished: Bool) -> (String, Bool) {
        if finished { return (NSLocalizedString("Study again", comment: ""), true) }
        if session.mode == .quiz {
            guard session.selectedOption != nil else { return (NSLocalizedString("Choose an answer", comment: ""), false) }
            return (session.isLastCard ? NSLocalizedString("See results", comment: "") : NSLocalizedString("Next question", comment: ""), true)
        }
        if !session.isFlipped { return (NSLocalizedString("Show answer", comment: ""), true) }
        return (session.isLastCard ? NSLocalizedString("Finish", comment: "") : NSLocalizedString("Next card", comment: ""), true)
    }

    // MARK: Examples

    /// Whether the learner may see the sentences yet: after the flip, or after answering a quiz question. Showing them
    /// on the front would give the word's use away before the learner has tried to recall it.
    private var answerIsShown: Bool {
        session.mode == .flip ? session.isFlipped : session.selectedOption != nil
    }

    /// The sentences panel: the server's sentences with the learner's changes applied, then the learner's own. The learner's
    /// part is read from the device on every render, so a change shows at once and an offline card still has its own sentences.
    private func examplesPanel() -> ExamplesPanelState {
        guard answerIsShown, let card = session.current else { return .hidden }
        let overlay = exampleStore.overlay(cardId: card.id, ownerKey: ownerKey())
        var server: [CardExample] = []
        var status = ExamplesPanelState.Server.notApplicable
        if let lookup, lookup.cardId == card.id {
            switch lookup.state {
            case .loading: status = .loading
            case .unavailable: status = .unavailable
            case .loaded(let found): server = found; status = .loaded
            }
        }
        return ExamplesPanelState(isVisible: true, items: ExampleMerge.items(server: server, overlay: overlay), server: status,
                                  removedCount: ExampleMerge.removedCount(server: server, overlay: overlay))
    }

    /// Starts the lookup for the current card when it changed. Only the answer of the lookup that is still current is
    /// kept: a late answer for a card the learner already left is dropped.
    private func syncExamples(deck: DeskEntity) {
        guard !session.isFinished, let card = session.current,
              let term = CardExampleLookup.term(front: card.front, back: card.back, deckHasJapaneseOnFront: deck.sortingLanguage != .opposite) else {
            lookupRequest.disposable = Disposables.create()
            lookup = nil
            return
        }
        guard lookup?.cardId != card.id || lookup?.term != term else { return }
        startLookup(cardId: card.id, term: term, reading: card.reading)
    }

    private func startLookup(cardId: String, term: String, reading: String) {
        lookup = (cardId, term, .loading)
        lookupRequest.disposable = examplesInteractor.examples(for: term, cardReading: reading)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] examples in
                self?.finishLookup(cardId: cardId, term: term, state: .loaded(examples))
            }, onFailure: { [weak self] _ in
                self?.finishLookup(cardId: cardId, term: term, state: .unavailable)
            })
    }

    private func finishLookup(cardId: String, term: String, state: ServerSentences) {
        guard let current = lookup, current.cardId == cardId, current.term == term else { return }
        lookup = (cardId, term, state)
        publish(.none)
    }

    // MARK: Speech

    /// The language a side of a card is written in. When exactly one side holds kana or kanji that side is Japanese,
    /// whatever the deck's direction says (a generated deck can mix directions card by card); otherwise the deck's
    /// direction setting decides.
    private func languageCode(for card: StudyCard, front: Bool) -> String {
        let japaneseOnFront = JapaneseText.japaneseIsOnFront(front: card.front, back: card.back, deckHasJapaneseOnFront: deck?.sortingLanguage != .opposite)
        return (front == japaneseOnFront) ? "ja-JP" : "vi-VN"
    }

    private func autoSpeakIfNeeded() {
        guard preferences.autoSpeak else { return }
        speakCurrent()
    }
}

extension CardStudyPresenter: CardStudyPresenterInterface {
    func viewWillAppear() { load() }

    func viewWillDisappear() {
        speech.stop()
        // Leaving the screen cancels a lookup in flight; coming back asks again.
        lookupRequest.disposable = Disposables.create()
        lookup = nil
    }

    func flip() {
        guard session.mode == .flip, canChange else { return }
        session.flip()
        publish(.flip)
    }

    func primaryAction() {
        if session.isFinished || session.current == nil { return restart() }
        if session.mode == .flip, !session.isFlipped { return flip() }
        next()
    }

    func previous() {
        guard session.canGoBack, canChange else { return }
        session.goBack()
        publish(.backward)
    }

    func next() {
        // An unsaved answer is not left behind, and quiz answers are final: the learner must answer before moving on.
        guard canChange else { return }
        if session.mode == .quiz, session.selectedOption == nil { return }
        session.advance()
        publish(.forward)
    }

    func select(option: String) {
        guard !sessionEnded else { return }
        session.select(option: option)
        persistCurrentAttempt()
        publish(.none)
    }

    func rate(_ rating: SelfRating) {
        guard canChange else { return }
        session.rate(rating)
        persistCurrentAttempt()
        publish(.none)
    }

    func retrySave() {
        guard let attempt = unsavedAttempt, !sessionEnded else { return }
        save(attempt)
        publish(.none)
    }

    func leaveSession() {
        guard unsavedAttempt != nil else {
            speech.stop()
            return wireframe.leave()
        }
        wireframe.confirmLeaveUnsaved { [weak self] in
            self?.speech.stop()
            self?.wireframe.leave()
        }
    }

    func setMode(_ mode: StudyMode) {
        guard canChange else { return }
        preferences.mode = mode
        session.setMode(mode)
        startRun()
        publish(.forward)
    }

    func setShuffled(_ shuffled: Bool) {
        guard canChange else { return }
        preferences.isShuffled = shuffled
        session.setShuffled(shuffled)
        startRun()
        publish(.forward)
    }

    func setReadingVisible(_ visible: Bool) {
        preferences.isReadingVisible = visible
        publish(.none)
    }

    func setImagesVisible(_ visible: Bool) {
        preferences.areImagesVisible = visible
        publish(.none)
    }

    func setAutoSpeak(_ enabled: Bool) {
        preferences.autoSpeak = enabled
        if enabled { speakCurrent() } else { speech.stop() }
        publish(.none)
    }

    /// Reads the side of the card that is on screen, in that side's language.
    func speakCurrent() {
        guard let card = session.current else { return }
        let showingBack = session.mode == .flip && session.isFlipped
        let text = showingBack ? card.back : card.front
        if !showingBack { session.noteHint(.audio) }
        speech.speak(text, languageCode: languageCode(for: card, front: !showingBack))
    }

    func speakExample(id: String) {
        guard let item = currentExampleItems().first(where: { $0.id == id }) else { return }
        speech.speak(item.example.japanese, languageCode: "ja-JP")
    }

    func setExamplesExpanded(_ expanded: Bool) {
        preferences.areExamplesVisible = expanded
        publish(.none)
    }

    func retryExamples() {
        guard let lookup, case .unavailable = lookup.state, let card = session.current else { return }
        startLookup(cardId: lookup.cardId, term: lookup.term, reading: card.reading)
        publish(.none)
    }

    // MARK: Editing the learner's sentences

    private func currentExampleItems() -> [ExampleItem] { examplesPanel().items }

    /// Rejects a sentence that is already on the card, so adding or editing cannot create a visible duplicate.
    private func ensureNotDuplicate(_ draft: CardExampleDraft, excluding id: String?) throws {
        let japanese = draft.japanese.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentExampleItems().contains(where: { $0.id != id && $0.example.japanese == japanese }) { throw CardExampleError.duplicate }
    }

    func addExample() {
        guard let card = session.current, answerIsShown else { return }
        let cardId = card.id, owner = ownerKey()
        wireframe.showExampleEditor(isNew: true, draft: CardExampleDraft()) { [weak self] draft in
            guard let self else { return }
            let valid = try draft.validated()
            try self.ensureNotDuplicate(valid, excluding: nil)
            try self.exampleStore.addCustom(valid, cardId: cardId, ownerKey: owner)
            self.publish(.none)
        }
    }

    func editExample(id: String) {
        guard let card = session.current, let item = currentExampleItems().first(where: { $0.id == id }) else { return }
        let cardId = card.id, owner = ownerKey()
        wireframe.showExampleEditor(isNew: false, draft: CardExampleDraft(item.example)) { [weak self] draft in
            guard let self else { return }
            let valid = try draft.validated()
            try self.ensureNotDuplicate(valid, excluding: item.id)
            try self.exampleStore.update(item, with: valid, cardId: cardId, ownerKey: owner)
            self.publish(.none)
        }
    }

    func removeExample(id: String) {
        guard let card = session.current, let item = currentExampleItems().first(where: { $0.id == id }) else { return }
        let cardId = card.id, owner = ownerKey()
        wireframe.confirmRemoveExample(origin: item.origin) { [weak self] in
            self?.perform { try $0.exampleStore.remove(item, cardId: cardId, ownerKey: owner) }
        }
    }

    func restoreOriginalExample(id: String) {
        guard let card = session.current, let item = currentExampleItems().first(where: { $0.id == id }), item.origin == .edited else { return }
        let cardId = card.id, owner = ownerKey()
        perform { try $0.exampleStore.restoreOriginal(of: item, cardId: cardId, ownerKey: owner) }
    }

    func restoreRemovedExamples() {
        guard let card = session.current else { return }
        let cardId = card.id, owner = ownerKey()
        perform { try $0.exampleStore.restoreRemoved(cardId: cardId, ownerKey: owner) }
    }

    /// Runs a change to the learner's sentences, shows it, or tells the learner it could not be saved. Nothing is retried.
    private func perform(_ change: (CardStudyPresenter) throws -> Void) {
        do {
            try change(self)
            publish(.none)
        } catch {
            wireframe.showError(String(format: NSLocalizedString("Couldn't save your change to the example sentences: %@", comment: ""), error.localizedDescription))
            publish(.none)
        }
    }

    func chooseStyle() {
        wireframe.showStylePicker(selectedSlug: preferences.cardStyleSlug) { [weak self] in self?.publish(.none) }
    }

    func restart() {
        guard canChange else { return }
        session.restart()
        startRun()
        publish(.forward)
    }

    func edit() {
        guard canChange else { return }
        wireframe.showEditor(deckId: deckId) { [weak self] in self?.load() }
    }
}
