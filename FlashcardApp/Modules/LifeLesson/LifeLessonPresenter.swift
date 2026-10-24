import Foundation
import RxSwift

// MARK: View state

struct LifeSentenceRow: Equatable {
    let japanese: String
    let reading: String
    let translation: String
    let explanation: String
    /// A rule of the lesson template, shown with a "tip" label: not something the data source reported.
    let isAdvice: Bool
}

struct LifeStoryState: Equatable {
    let eyebrow: String
    let title: String
    let titleReading: String
    let topic: LifeTopic
    let scene: LifeScene
    /// "Not the latest" and "Development source": shown as tags next to the facts, never hidden.
    let tags: [String]
    let factsHeader: String
    let factChips: [LifeChip]
    let sourceLine: String
    let attribution: String
    let sentencesHeader: String
    let sentences: [LifeSentenceRow]
    let ctaTitle: String
}

struct LifeFeedback: Equatable {
    let isCorrect: Bool
    let title: String
    let detail: String
    /// For a choice exercise: the row the learner picked and the right row, to mark both.
    let selectedChoice: Int?
    let correctChoice: Int?
}

struct LifePracticeState: Equatable {
    enum Input: Equatable {
        case typed(placeholder: String)
        case choices(texts: [String], selected: Int?)
    }

    let progress: String
    let skill: String
    let promptJapanese: String
    let prompt: String
    let input: Input
    let feedback: LifeFeedback?
    let primaryTitle: String
    /// A choice exercise needs a pick before it can be checked.
    let primaryEnabled: Bool
}

struct LifeSaveRow: Equatable {
    let id: String
    let japanese: String
    let reading: String
    let meaning: String
    let isSelected: Bool
}

struct LifeSaveState: Equatable {
    enum Status: Equatable {
        case idle
        /// The write has not finished: nothing is reported as saved.
        case saving
        case failed(message: String)
        case saved(message: String)
    }

    let header: String
    let rows: [LifeSaveRow]
    let deckLabel: String
    let deckName: String
    let status: Status
    let primaryTitle: String
    let primaryEnabled: Bool
    let secondaryTitle: String?
}

struct LifeDoneState: Equatable {
    enum SaveResult: Equatable { case saved, notSaved }

    let title: String
    let exerciseTitle: String
    let exerciseDetail: String
    let saveTitle: String
    let saveDetail: String
    let saveResult: SaveResult
    let canReviewCards: Bool
}

enum LifeLessonViewState: Equatable {
    case loading(message: String)
    case failed(title: String, message: String)
    case story(LifeStoryState)
    case practice(LifePracticeState)
    case save(LifeSaveState)
    case done(LifeDoneState)
}

protocol LifeLessonViewInterface: AnyObject {
    func render(_ state: LifeLessonViewState)
    /// A short spoken/visible announcement for feedback that appears without a navigation (correct, not quite).
    func announce(_ text: String)
}

protocol LifeLessonPresenterInterface: AnyObject {
    func viewDidLoad()
    func retry()
    func startPractice()
    func selectChoice(_ index: Int)
    /// Checks the answer, or moves on when the answer was already checked. `answer` is the typed text (recall exercises).
    func primaryTapped(answer: String)
    func toggleWord(id: String)
    func chooseDeck()
    func saveWords()
    func skipSaving()
    func continueToDone()
    func reviewSavedCards()
    func practiceAgain()
    func openSource()
    func finish()
}

// MARK: Presenter

/// The whole journey of one lesson, as one state machine: story → practice → save → done. Nothing is stored before the
/// learner saves words, and "done" says separately whether the exercises were finished and whether the words were stored.
final class LifeLessonPresenter {
    private enum Phase: Equatable {
        case loading, failed(String), story, practice, save, done
    }

    private let cityID: String
    private let interactor: LifeLessonInteractorInterface
    private let wireframe: LifeLessonWireframeInterface
    private let language: () -> AppLanguage
    private let now: () -> Date
    weak var view: LifeLessonViewInterface?

    private var lesson: LifeLesson?
    private var phase: Phase = .loading
    private let loading = SerialDisposable()

    // Practice
    private var exerciseIndex = 0
    private var checked: LifeFeedback?
    private var selectedChoice: Int?
    private var results: [Bool] = []

    // Saving
    private var selectedWords: Set<String> = []
    private var target: LifeSaveTarget = .newLifeDeck
    private var saveStatus: LifeSaveState.Status = .idle
    private var saveOutcome: LifeSaveOutcome?

    init(cityID: String, lesson: LifeLesson?, interactor: LifeLessonInteractorInterface, wireframe: LifeLessonWireframeInterface,
         language: @escaping () -> AppLanguage = { AppLanguage.current }, now: @escaping () -> Date = Date.init) {
        self.cityID = cityID
        self.lesson = lesson
        self.interactor = interactor
        self.wireframe = wireframe
        self.language = language
        self.now = now
        self.phase = lesson == nil ? .loading : .story
        self.selectedWords = Set(lesson?.vocabulary.map(\.id) ?? [])
    }

    deinit { loading.dispose() }

    private static func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    private func publish() {
        guard let view else { return }
        view.render(makeState())
    }

    // MARK: State building

    private func makeState() -> LifeLessonViewState {
        switch phase {
        case .loading: return .loading(message: Self.text("Loading today's lesson…"))
        case .failed(let message): return .failed(title: Self.text("Couldn't load the lesson"), message: message)
        case .story: return lesson.map { .story(storyState($0)) } ?? .loading(message: Self.text("Loading today's lesson…"))
        case .practice: return lesson.map { .practice(practiceState($0)) } ?? .loading(message: Self.text("Loading today's lesson…"))
        case .save: return lesson.map { .save(saveState($0)) } ?? .loading(message: Self.text("Loading today's lesson…"))
        case .done: return lesson.map { .done(doneState($0)) } ?? .loading(message: Self.text("Loading today's lesson…"))
        }
    }

    static func timeText(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// The picture of a lesson: the weather's own kind for weather, the topic's scene for the rest.
    static func scene(for lesson: LifeLesson) -> LifeScene {
        if let scene = lesson.scene { return scene }
        switch lesson.topic {
        case .weather: return .weather(LifeWeatherKind(wmoCode: lesson.facts?.weatherCode ?? 3), temperatureC: lesson.facts?.temperatureMaxC)
        case .date: return .date(day: 1, weekday: "")
        case .nearby: return .place
        case .transit: return .transit
        case .shopping: return .shopping
        case .news: return .news
        case .food: return .food
        case .culture: return .culture
        case .money: return .money
        case .lottery: return .lottery
        }
    }

    private func storyState(_ lesson: LifeLesson) -> LifeStoryState {
        let language = language()
        let city = LifeCity.city(id: lesson.cityID)?.displayName(language) ?? lesson.cityName.resolved(language)
        var tags: [String] = []
        if lesson.source.freshness == .stale { tags.append(Self.text("Not the latest")) }
        if lesson.source.licenseStatus == .nonCommercialDevOnly { tags.append(Self.text("Development source")) }
        if lesson.provenance == .sample { tags.append(Self.text("Sample content")) }
        let time = Self.timeText(lesson.source.observedAt, language: language)
        let eyebrow = lesson.topic == .weather ? String(format: Self.text("%@ · TODAY'S WEATHER"), city.uppercased()) : lesson.topic.title.uppercased()
        let sourceLine: String
        switch lesson.provenance {
        case .live: sourceLine = String(format: Self.text("%1$@ · observed %2$@ (Japan time)"), lesson.source.providerName, time)
        case .onDevice: sourceLine = String(format: Self.text("%@ · worked out on this device"), lesson.source.providerName)
        case .sample: sourceLine = Self.text("Example content · not live data yet")
        }
        return LifeStoryState(
            eyebrow: eyebrow,
            title: lesson.titleJapanese, titleReading: lesson.titleReading,
            topic: lesson.topic, scene: Self.scene(for: lesson), tags: tags,
            factsHeader: lesson.provenance == .live ? Self.text("FROM THE DATA SOURCE") : Self.text("FACTS"), factChips: lesson.chips,
            sourceLine: sourceLine,
            attribution: lesson.source.attributionText ?? "",
            sentencesHeader: Self.text("SENTENCES TO LEARN"),
            sentences: lesson.sentences.map {
                LifeSentenceRow(japanese: $0.japanese, reading: $0.reading, translation: $0.translation.resolved(language),
                                explanation: $0.explanation.resolved(language), isAdvice: $0.isAdvice)
            },
            ctaTitle: Self.text("Practise recalling"))
    }

    private func practiceState(_ lesson: LifeLesson) -> LifePracticeState {
        let language = language()
        let exercise = lesson.exercises[exerciseIndex]
        let progress = String(format: Self.text("Exercise %1$lld of %2$lld"), exerciseIndex + 1, lesson.exercises.count)
        let isLast = exerciseIndex == lesson.exercises.count - 1
        let primary: String
        if checked == nil { primary = Self.text("Check") } else { primary = isLast ? Self.text("See results") : Self.text("Next") }
        switch exercise {
        case .recall(_, let promptJapanese, let prompt, _, _):
            return LifePracticeState(progress: progress, skill: Self.text("Recall: type the answer"), promptJapanese: promptJapanese,
                                     prompt: prompt.resolved(language), input: .typed(placeholder: Self.text("Your answer")),
                                     feedback: checked, primaryTitle: primary, primaryEnabled: true)
        case .choice(_, let promptJapanese, let prompt, let choices, _, _):
            return LifePracticeState(progress: progress, skill: Self.text("Recognition: pick the answer"), promptJapanese: promptJapanese,
                                     prompt: prompt.resolved(language), input: .choices(texts: choices.map(\.text), selected: selectedChoice),
                                     feedback: checked, primaryTitle: primary, primaryEnabled: checked != nil || selectedChoice != nil)
        }
    }

    private var targetName: String {
        switch target {
        case .newLifeDeck:
            return interactor.deckChoices().first { $0.id == LifeLessonInteractor.lifeDeckID }?.name ?? Self.text("Learn from Life")
        case .existing(let id):
            return interactor.deckChoices().first { $0.id == id }?.name ?? Self.text("Learn from Life")
        }
    }

    private func saveState(_ lesson: LifeLesson) -> LifeSaveState {
        let language = language()
        let rows = lesson.vocabulary.map {
            LifeSaveRow(id: $0.id, japanese: $0.japanese, reading: $0.reading, meaning: $0.meaning.resolved(language), isSelected: selectedWords.contains($0.id))
        }
        let saved: Bool = { if case .saved = saveStatus { return true } else { return false } }()
        let saving = saveStatus == .saving
        let primary: String
        if saved { primary = Self.text("Continue") } else if case .failed = saveStatus { primary = Self.text("Try again") } else {
            primary = String.localizedStringWithFormat(Self.text("Save %lld words"), selectedWords.count)
        }
        return LifeSaveState(header: Self.text("SAVE WORDS TO A DECK"), rows: rows, deckLabel: Self.text("Deck"), deckName: targetName,
                             status: saveStatus, primaryTitle: primary,
                             primaryEnabled: !saving && (saved || !selectedWords.isEmpty),
                             secondaryTitle: saved ? nil : Self.text("Not now"))
    }

    private func doneState(_ lesson: LifeLesson) -> LifeDoneState {
        let correct = results.filter { $0 }.count
        let exerciseDetail = String(format: Self.text("%1$lld of %2$lld correct"), correct, lesson.exercises.count)
        if let outcome = saveOutcome {
            let detail: String
            if outcome.added.isEmpty {
                detail = String(format: Self.text("These words were already in “%@”. Nothing was added twice."), outcome.deckName)
            } else {
                detail = String.localizedStringWithFormat(Self.text("%lld new cards added."), outcome.added.count) + " "
                    + String(format: Self.text("In “%@”. Studying them is what starts their review schedule."), outcome.deckName)
            }
            return LifeDoneState(title: Self.text("Today's lesson is done"), exerciseTitle: Self.text("Exercises finished"), exerciseDetail: exerciseDetail,
                                 saveTitle: Self.text("Words saved"), saveDetail: detail, saveResult: .saved, canReviewCards: !outcome.cardIDs.isEmpty)
        }
        let detail: String
        if case .failed = saveStatus { detail = Self.text("The words could not be stored on this device. No cards were added.") } else {
            detail = Self.text("You chose not to save them. No cards were added.")
        }
        return LifeDoneState(title: Self.text("Today's lesson is done"), exerciseTitle: Self.text("Exercises finished"), exerciseDetail: exerciseDetail,
                             saveTitle: Self.text("Words not saved"), saveDetail: detail, saveResult: .notSaved, canReviewCards: false)
    }
}

// MARK: Interaction

extension LifeLessonPresenter: LifeLessonPresenterInterface {
    func viewDidLoad() {
        if lesson == nil { load() } else { publish() }
    }

    func retry() { load() }

    private func load() {
        phase = .loading
        publish()
        loading.disposable = interactor.loadWeather(cityID: cityID)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] lesson in
                guard let self else { return }
                self.lesson = lesson
                self.selectedWords = Set(lesson.vocabulary.map(\.id))
                self.phase = .story
                self.publish()
            }, onFailure: { [weak self] error in
                guard let self else { return }
                self.phase = .failed(Self.message(for: error))
                self.publish()
            })
    }

    static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    func startPractice() {
        guard lesson != nil, phase == .story else { return }
        exerciseIndex = 0
        checked = nil
        selectedChoice = nil
        results = []
        phase = .practice
        publish()
    }

    func selectChoice(_ index: Int) {
        guard phase == .practice, checked == nil, let lesson, case .choice(_, _, _, let choices, _, _) = lesson.exercises[exerciseIndex],
              choices.indices.contains(index) else { return }
        selectedChoice = index
        publish()
    }

    func primaryTapped(answer: String) {
        guard phase == .practice, let lesson else { return }
        if checked != nil {
            // Already answered: move on.
            if exerciseIndex + 1 < lesson.exercises.count {
                exerciseIndex += 1
                checked = nil
                selectedChoice = nil
            } else {
                phase = .save
            }
            publish()
            return
        }
        let language = language()
        let feedback: LifeFeedback
        switch lesson.exercises[exerciseIndex] {
        case .recall(_, _, _, let accepted, let explanation):
            let correct = LifeAnswerChecker.isCorrect(answer, accepted: accepted)
            feedback = LifeFeedback(isCorrect: correct, title: correct ? Self.text("Correct") : Self.text("Not quite"),
                                    detail: explanation.resolved(language), selectedChoice: nil, correctChoice: nil)
        case .choice(_, _, _, let choices, let correctID, let explanation):
            guard let picked = selectedChoice else { return }
            let correctIndex = choices.firstIndex { $0.id == correctID }
            let correct = choices[picked].id == correctID
            feedback = LifeFeedback(isCorrect: correct, title: correct ? Self.text("Correct") : Self.text("Not quite"),
                                    detail: explanation.resolved(language), selectedChoice: picked, correctChoice: correctIndex)
        }
        results.append(feedback.isCorrect)
        checked = feedback
        publish()
        view?.announce(feedback.title + ". " + feedback.detail)
    }

    func toggleWord(id: String) {
        guard phase == .save, saveStatus != .saving, saveOutcome == nil, lesson?.vocabulary.contains(where: { $0.id == id }) == true else { return }
        if selectedWords.contains(id) { selectedWords.remove(id) } else { selectedWords.insert(id) }
        if case .failed = saveStatus { saveStatus = .idle }
        publish()
    }

    func chooseDeck() {
        guard phase == .save, saveStatus != .saving, saveOutcome == nil else { return }
        wireframe.showDeckChooser(interactor.deckChoices(), lifeDeckExists: interactor.lifeDeckExists(), selected: target) { [weak self] chosen in
            guard let self else { return }
            self.target = chosen
            if case .failed = self.saveStatus { self.saveStatus = .idle }
            self.publish()
        }
    }

    func saveWords() {
        guard phase == .save, let lesson else { return }
        // Already stored: the button only moves on, and a second tap can never write again.
        if saveOutcome != nil { return continueToDone() }
        guard saveStatus != .saving, !selectedWords.isEmpty else { return }
        saveStatus = .saving
        publish()
        let words = lesson.vocabulary.filter { selectedWords.contains($0.id) }
        do {
            let outcome = try interactor.saveVocabulary(words, target: target, language: language())
            saveOutcome = outcome
            saveStatus = .saved(message: Self.savedMessage(outcome))
            publish()
            view?.announce(Self.savedMessage(outcome))
        } catch {
            logger.error("Saving lesson words failed: \(error.localizedDescription)")
            let message = Self.text("The words could not be stored on this device. No cards were added.")
            saveStatus = .failed(message: message)
            publish()
            view?.announce(message)
        }
    }

    private static func savedMessage(_ outcome: LifeSaveOutcome) -> String {
        if outcome.added.isEmpty {
            return String(format: text("Already in “%@”. Nothing was added twice."), outcome.deckName)
        }
        let added = String.localizedStringWithFormat(text("Saved %lld new words to “%@”."), outcome.added.count, outcome.deckName)
        return outcome.alreadyPresent.isEmpty ? added
            : added + " " + String.localizedStringWithFormat(text("%lld were already there."), outcome.alreadyPresent.count)
    }

    func skipSaving() {
        guard phase == .save, saveOutcome == nil, saveStatus != .saving else { return }
        phase = .done
        publish()
    }

    func continueToDone() {
        guard phase == .save, saveOutcome != nil else { return }
        phase = .done
        publish()
    }

    func reviewSavedCards() {
        guard phase == .done, let outcome = saveOutcome, !outcome.cardIDs.isEmpty else { return }
        wireframe.showStudy(deckId: outcome.deckID, cardIDs: outcome.cardIDs)
    }

    func practiceAgain() {
        guard phase == .done || phase == .save else { return }
        phase = .story
        publish()
        startPractice()
    }

    func openSource() {
        guard let url = lesson?.source.url else { return }
        wireframe.openSource(url)
    }

    func finish() { wireframe.finish() }
}
