import Foundation
import RxSwift

/// One line of reading material. Which fields are set depends on the section: vocabulary has a headword, reading and meaning;
/// an example has a sentence, its translation and a note; a labelled fact has a label and a body.
struct ReaderEntry: Equatable {
    var label: String?
    var headline: String?
    var reading: String?
    var body: String?
    var note: String?
}

enum LessonReaderSectionKind: Equatable {
    case context, vocabulary, grammar, examples, remember, pitfalls
}

struct LessonReaderSection: Equatable {
    let kind: LessonReaderSectionKind
    let title: String
    let entries: [ReaderEntry]
}

enum LessonReaderState: Equatable {
    case idle, loading, loaded
    case failed(String)
}

protocol LessonReaderPresenterInterface: AnyObject {
    var state: LessonReaderState { get }
    var title: String { get }
    /// "25 min", only when the server sent a duration.
    var minutes: Int? { get }
    var sections: [LessonReaderSection] { get }
    var isFromCache: Bool { get }
    var practiceActivityCount: Int { get }
    var isPracticeAvailable: Bool { get }
    var practiceStatus: LessonPracticeStatus { get }
    var onChange: (() -> Void)? { get set }
    func viewDidLoad()
    func retry()
    func cancelLoading()
    func showPractice()
    /// Whether the loaded lesson has words the learner can save to a deck.
    var canSaveWords: Bool { get }
    /// Saves the word at this position of the vocabulary section to a deck the learner picks.
    func saveWord(at index: Int)
    func saveAllWords()
}

protocol LessonReaderWireframeInterface: AnyObject {
    func showPractice(lesson: BJTLessonDetailDTO)
    /// Asks which deck to save to; `completion` gets nil when the learner cancels.
    func chooseDeck(from choices: [TodayDeckChoice], completion: @escaping (DictionaryDeckTarget?) -> Void)
    func showMessage(title: String, message: String)
}

/// Where the learner stands in the lesson's activities on this device.
enum LessonPracticeStatus: Equatable {
    case notStarted
    case inProgress(answered: Int, total: Int)
    case completed
}

final class LessonReaderPresenter: LessonReaderPresenterInterface {
    private let slug: String
    private let interactor: LessonReaderInteractorInterface
    private let language: () -> AppLanguage
    private let request = SerialDisposable()
    private let progressStore: LessonProgressStoreInterface
    private let ownerKey: () -> String
    private let wordSaver: LessonWordSaverInterface
    private var lesson: BJTLessonDetailDTO?
    /// Held strongly: nothing else keeps the wireframe alive once its controller is pushed.
    var wireframe: LessonReaderWireframeInterface?

    private(set) var state: LessonReaderState = .idle
    private(set) var title: String
    private(set) var minutes: Int?
    private(set) var sections: [LessonReaderSection] = []
    private(set) var isFromCache = false
    private(set) var practiceActivityCount = 0
    private(set) var practiceStatus: LessonPracticeStatus = .notStarted
    var isPracticeAvailable: Bool { state == .loaded && practiceActivityCount > 0 }
    var onChange: (() -> Void)?

    /// `title` is the list row's, shown while the lesson loads.
    init(slug: String, title: String, interactor: LessonReaderInteractorInterface, language: @escaping () -> AppLanguage = { .current },
         progressStore: LessonProgressStoreInterface = RealmLessonProgressStore.shared,
         ownerKey: @escaping () -> String = { AuthSession.shared.currentUser?.id ?? "" },
         wordSaver: LessonWordSaverInterface = LessonWordSaver()) {
        self.wordSaver = wordSaver
        self.slug = slug
        self.title = title
        self.interactor = interactor
        self.language = language
        self.progressStore = progressStore
        self.ownerKey = ownerKey
    }

    deinit { request.dispose() }

    /// Called every time the screen appears: loads once, and again only after leaving cancelled the request.
    /// A failed load is repeated by `retry()` only.
    func viewDidLoad() {
        if state == .loaded {
            // Back from practice: the lesson is not fetched again, only the progress is read.
            refreshProgress()
            onChange?()
            return
        }
        guard state == .idle else { return }
        load()
    }

    var canSaveWords: Bool { state == .loaded && !(lesson?.lessonContent.vocabulary.isEmpty ?? true) }
    func saveWord(at index: Int) {
        guard let words = lesson?.lessonContent.vocabulary, words.indices.contains(index) else { return }
        save([LessonWord(words[index])])
    }

    func saveAllWords() {
        guard let words = lesson?.lessonContent.vocabulary, !words.isEmpty else { return }
        save(words.map(LessonWord.init))
    }

    /// The learner picks the deck first; cancelling writes nothing.
    private func save(_ words: [LessonWord]) {
        guard let wireframe else { return }
        wireframe.chooseDeck(from: wordSaver.choices()) { [weak self] target in
            guard let self, let target else { return }
            do {
                let outcome = try self.wordSaver.save(words, fromLesson: self.slug, to: target)
                wireframe.showMessage(title: NSLocalizedString("Words saved", comment: "Lesson reader"), message: Self.message(for: outcome))
            } catch {
                wireframe.showMessage(title: NSLocalizedString("Couldn't save the words", comment: "Lesson reader"),
                                      message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }

    private static func message(for outcome: LessonWordSaveOutcome) -> String {
        var parts = [String(format: NSLocalizedString("Added %lld to “%@”.", comment: "Lesson reader: words added to a deck"), outcome.added, outcome.deckName)]
        if outcome.alreadyThere > 0 {
            parts.append(String(format: NSLocalizedString("%lld were already in the deck.", comment: "Lesson reader"), outcome.alreadyThere))
        }
        if outcome.skipped > 0 {
            parts.append(String(format: NSLocalizedString("%lld had no meaning and were skipped.", comment: "Lesson reader"), outcome.skipped))
        }
        return parts.joined(separator: " ")
    }

    func showPractice() {
        guard isPracticeAvailable, let lesson else { return }
        wireframe?.showPractice(lesson: lesson)
    }

    private func refreshProgress() {
        guard let lesson else { practiceStatus = .notStarted; return }
        let ids = Set(lesson.lessonContent.activities.map(\.id))
        let progress = progressStore.progress(slug: slug, ownerKey: ownerKey())
        if progress?.isCompletedLocally == true {
            practiceStatus = .completed
        } else if let progress, !progress.answers.isEmpty {
            practiceStatus = .inProgress(answered: progress.answers.filter { ids.contains($0.activityId) }.count, total: ids.count)
        } else {
            practiceStatus = .notStarted
        }
    }

    func retry() {
        guard state != .loading else { return }
        load()
    }

    func cancelLoading() {
        guard state == .loading else { return }
        request.disposable = Disposables.create()
        state = .idle
    }

    private func load() {
        state = .loading
        onChange?()
        request.disposable = interactor.lesson(slug: slug)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] result in
                guard let self else { return }
                let lesson = result.lesson
                self.title = Self.text(self.language() == .japanese ? lesson.titleJa : lesson.titleVi, lesson.titleVi, lesson.titleJa) ?? self.title
                self.minutes = lesson.estimatedDurationMin.flatMap { $0 > 0 ? $0 : nil }
                self.sections = Self.sections(for: lesson.lessonContent)
                self.isFromCache = result.isFromCache
                self.practiceActivityCount = lesson.lessonContent.activities.count
                self.lesson = lesson
                self.state = .loaded
                self.refreshProgress()
                self.onChange?()
            }, onFailure: { [weak self] error in
                guard let self else { return }
                self.sections = []
                self.state = .failed((error as? LocalizedError)?.errorDescription
                                     ?? NSLocalizedString("Couldn't load data. Check your connection and try again.", comment: ""))
                self.onChange?()
            })
    }

    // MARK: Sections

    /// Reading order: situation, words, grammar, examples, things to remember, common mistakes. A section the server left
    /// empty is not shown; nothing is filled in for it.
    static func sections(for content: BJTLessonContentDTO) -> [LessonReaderSection] {
        var sections: [LessonReaderSection] = []
        func add(_ kind: LessonReaderSectionKind, _ title: String, _ entries: [ReaderEntry]) {
            if !entries.isEmpty { sections.append(LessonReaderSection(kind: kind, title: title, entries: entries)) }
        }
        add(.context, NSLocalizedString("Situation", comment: "Lesson reader section"), contextEntries(content))
        add(.vocabulary, NSLocalizedString("Vocabulary", comment: ""), content.vocabulary.compactMap { word in
            guard let headline = clean(word.japanese) else { return nil }
            return ReaderEntry(headline: headline, reading: clean(word.reading), body: clean(word.meaningVi))
        })
        add(.grammar, NSLocalizedString("Grammar", comment: ""), content.grammar.compactMap { point in
            guard let headline = clean(point.pattern) else { return nil }
            return ReaderEntry(headline: headline, body: clean(point.explanationVi))
        })
        add(.examples, NSLocalizedString("Examples", comment: "Lesson reader section"), content.examples.compactMap { example in
            guard let headline = clean(example.japanese) else { return nil }
            return ReaderEntry(headline: headline, body: clean(example.vietnamese), note: clean(example.noteVi))
        })
        add(.remember, NSLocalizedString("Key points", comment: "Lesson reader section"), rememberEntries(content))
        add(.pitfalls, NSLocalizedString("Common mistakes", comment: "Lesson reader section: mistakes Vietnamese learners often make"),
            content.vietnameseLearnerPitfalls.compactMap { clean($0) }.map { ReaderEntry(body: $0) })
        return sections
    }

    private static func contextEntries(_ content: BJTLessonContentDTO) -> [ReaderEntry] {
        var entries: [ReaderEntry] = []
        if let scenario = content.workplaceScenario {
            let ja = clean(scenario.contextJa), vi = clean(scenario.contextVi)
            if ja != nil || vi != nil { entries.append(ReaderEntry(headline: ja, body: vi)) }
            let facts: [(String, String?)] = [
                (NSLocalizedString("Goal", comment: "Lesson reader label"), scenario.goalVi),
                (NSLocalizedString("Challenge", comment: "Lesson reader label"), scenario.problemVi),
                (NSLocalizedString("Desired outcome", comment: "Lesson reader label"), scenario.desiredOutcomeVi)]
            for (label, text) in facts {
                if let text = clean(text) { entries.append(ReaderEntry(label: label, body: text)) }
            }
        }
        let objectiveLabel = NSLocalizedString("You will learn", comment: "Lesson reader label")
        entries += content.learningObjectives.compactMap { clean($0) }.map { ReaderEntry(label: objectiveLabel, body: $0) }
        return entries
    }

    private static func rememberEntries(_ content: BJTLessonContentDTO) -> [ReaderEntry] {
        var entries = (content.summaryVi + content.knowledgePoints + content.nuanceNotesVi).compactMap { clean($0) }.map { ReaderEntry(body: $0) }
        if let usage = clean(content.businessUsageVi) {
            entries.append(ReaderEntry(label: NSLocalizedString("Use at work", comment: "Lesson reader label"), body: usage))
        }
        if let politeness = clean(content.politenessHierarchyVi) {
            entries.append(ReaderEntry(label: NSLocalizedString("Politeness", comment: "Lesson reader label"), body: politeness))
        }
        return entries
    }

    /// The text, or nil when it is missing or blank.
    private static func clean(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    /// The first non-blank of the candidates, so a missing translation never leaves an empty title.
    private static func text(_ candidates: String?...) -> String? {
        candidates.lazy.compactMap { clean($0) }.first
    }
}
