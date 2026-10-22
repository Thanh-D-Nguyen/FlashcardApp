import Foundation

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
    weak var view: CardStudyViewInterface?

    private var deck: DeskEntity?
    private var session = StudySession(cards: [])

    init(deckId: String,
         interactor: CardStudyInteractorInterface,
         wireframe: CardStudyWireframeInterface,
         preferences: StudyPreferencesInterface = UserDefaultsStudyPreferences.shared,
         speech: SpeechServiceInterface = SystemSpeechService.shared,
         random: @escaping StudyRandomSource = { Int.random(in: $0) }) {
        self.deckId = deckId
        self.interactor = interactor
        self.wireframe = wireframe
        self.preferences = preferences
        self.speech = speech
        self.random = random
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

    func viewWillDisappear() { speech.stop() }

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

    func restart() {
        session.restart()
        publish(.forward)
    }

    func edit() {
        wireframe.showEditor(deckId: deckId) { [weak self] in self?.load() }
    }
}
