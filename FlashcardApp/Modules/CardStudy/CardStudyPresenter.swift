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
}

struct StudyQuizState: Equatable {
    let options: [String]
    let selected: String?
    let correct: String
}

struct StudySummary: Equatable {
    let total: Int
    let answered: Int
    let correct: Int
    let mode: StudyMode
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
    /// Example sentences for the current card; `.hidden` until its answer is shown.
    var examples: ExamplesState
    var examplesExpanded: Bool
    var quiz: StudyQuizState?
    var canGoBack: Bool
    var primaryTitle: String
    var isPrimaryEnabled: Bool
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
    func setMode(_ mode: StudyMode)
    func setShuffled(_ shuffled: Bool)
    func setReadingVisible(_ visible: Bool)
    func setImagesVisible(_ visible: Bool)
    func setAutoSpeak(_ enabled: Bool)
    func speakCurrent()
    func speakExample(id: String)
    func setExamplesExpanded(_ expanded: Bool)
    func retryExamples()
    func chooseStyle()
    func restart()
    func edit()
}

final class CardStudyPresenter {
    private let deckId: String
    private let interactor: CardStudyInteractorInterface
    private let wireframe: CardStudyWireframeInterface
    private let preferences: StudyPreferencesInterface
    private let speech: SpeechServiceInterface
    private let random: StudyRandomSource
    private let examplesInteractor: CardExamplesInteractorInterface
    weak var view: CardStudyViewInterface?

    private var deck: DeskEntity?
    private var session = StudySession(cards: [])
    /// The sentence lookup for the card on screen. Prefetched when the card appears, shown once its answer is.
    private var lookup: (cardId: String, term: String, state: ExamplesState)?
    private let lookupRequest = SerialDisposable()

    init(deckId: String,
         interactor: CardStudyInteractorInterface,
         wireframe: CardStudyWireframeInterface,
         preferences: StudyPreferencesInterface = UserDefaultsStudyPreferences.shared,
         speech: SpeechServiceInterface = SystemSpeechService.shared,
         random: @escaping StudyRandomSource = { Int.random(in: $0) },
         examples: CardExamplesInteractorInterface = CardExamplesInteractor()) {
        self.deckId = deckId
        self.interactor = interactor
        self.wireframe = wireframe
        self.preferences = preferences
        self.speech = speech
        self.random = random
        self.examplesInteractor = examples
    }

    // MARK: Loading

    /// Loads the deck. A session in progress is kept when the deck did not change (e.g. returning from the editor).
    private func load() {
        guard let entity = interactor.deck(withId: deckId) else {
            speech.stop()
            wireframe.leave()
            return
        }
        let cards = entity.cards.map(StudyCard.init(entity:))
        let changed = deck == nil || session.cards != cards
        deck = entity
        if changed {
            session = StudySession(cards: cards, mode: preferences.mode, shuffled: preferences.isShuffled, random: random)
        }
        publish(.none)
    }

    // MARK: State

    private func publish(_ transition: CardStudyTransition) {
        guard let deck else { return }
        syncExamples(deck: deck)
        view?.render(makeState(deck: deck), transition: transition)
        if transition != .none, !session.isFinished, session.current != nil { autoSpeakIfNeeded() }
    }

    private func makeState(deck: DeskEntity) -> CardStudyState {
        let current = session.current
        let finished = session.isFinished || current == nil
        let progressText = String(format: NSLocalizedString("%1$lld of %2$lld", comment: "Study progress: position of total"),
                                  min(session.position + 1, max(session.count, 1)), session.count)
        let card = current.map {
            StudyCardState(front: $0.front, back: $0.back, reading: $0.reading, note: $0.note,
                           imageReference: $0.imageReference, isFlipped: session.isFlipped)
        }
        var quiz: StudyQuizState?
        if session.mode == .quiz, let current { quiz = StudyQuizState(options: session.options, selected: session.selectedOption, correct: current.back) }
        let (title, enabled) = primary(finished: finished)
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
            progress: Float(session.progress),
            card: card,
            style: CardStyle.style(forSlug: preferences.cardStyleSlug),
            examples: finished ? .hidden : examplesState(),
            examplesExpanded: preferences.areExamplesVisible,
            quiz: quiz,
            canGoBack: session.canGoBack,
            primaryTitle: title,
            isPrimaryEnabled: enabled,
            summary: StudySummary(total: session.count, answered: session.answeredCount, correct: session.correctCount, mode: session.mode))
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

    private func examplesState() -> ExamplesState {
        guard answerIsShown, let lookup, lookup.cardId == session.current?.id else { return .hidden }
        return lookup.state
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
                self?.finishLookup(cardId: cardId, term: term, state: examples.isEmpty ? .empty : .results(examples))
            }, onFailure: { [weak self] _ in
                self?.finishLookup(cardId: cardId, term: term, state: .unavailable)
            })
    }

    private func finishLookup(cardId: String, term: String, state: ExamplesState) {
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
        guard session.mode == .flip else { return }
        session.flip()
        publish(.flip)
    }

    func primaryAction() {
        if session.isFinished || session.current == nil { return restart() }
        if session.mode == .flip, !session.isFlipped { return flip() }
        next()
    }

    func previous() {
        guard session.canGoBack else { return }
        session.goBack()
        publish(.backward)
    }

    func next() {
        // Quiz answers are final: the learner must answer before moving on.
        if session.mode == .quiz, session.selectedOption == nil { return }
        session.advance()
        publish(.forward)
    }

    func select(option: String) {
        session.select(option: option)
        publish(.none)
    }

    func setMode(_ mode: StudyMode) {
        preferences.mode = mode
        session.setMode(mode)
        publish(.forward)
    }

    func setShuffled(_ shuffled: Bool) {
        preferences.isShuffled = shuffled
        session.setShuffled(shuffled)
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
        speech.speak(text, languageCode: languageCode(for: card, front: !showingBack))
    }

    func speakExample(id: String) {
        guard case .results(let examples)? = lookup?.state, let example = examples.first(where: { $0.id == id }) else { return }
        speech.speak(example.japanese, languageCode: "ja-JP")
    }

    func setExamplesExpanded(_ expanded: Bool) {
        preferences.areExamplesVisible = expanded
        publish(.none)
    }

    func retryExamples() {
        guard let lookup, lookup.state == .unavailable, let card = session.current else { return }
        startLookup(cardId: lookup.cardId, term: lookup.term, reading: card.reading)
        publish(.none)
    }

    func chooseStyle() {
        wireframe.showStylePicker(selectedSlug: preferences.cardStyleSlug) { [weak self] in self?.publish(.none) }
    }

    func restart() {
        session.restart()
        publish(.forward)
    }

    func edit() {
        wireframe.showEditor(deckId: deckId) { [weak self] in self?.load() }
    }
}
