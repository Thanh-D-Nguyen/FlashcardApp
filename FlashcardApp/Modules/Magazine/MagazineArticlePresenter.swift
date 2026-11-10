import Foundation
import RxSwift

// MARK: View state

struct MagazineArticleState: Equatable {
    struct Header: Equatable {
        let kind: MagazineKind
        let eyebrow: String
        let dateText: String?
        let level: String?
        let titleJapanese: String
        let titleVietnamese: String
        let summaryJapanese: String?
        let summaryVietnamese: String?
    }

    struct VocabularyRow: Equatable {
        let id: String
        let japanese: String
        let reading: String
        let meaning: String
        let level: String?
        let example: String?
        let exampleMeaning: String?
        let isSelected: Bool
    }

    struct Vocabulary: Equatable {
        enum Status: Equatable {
            case idle
            /// The write has not finished: nothing is reported as saved.
            case saving
            case failed(message: String)
            case saved(message: String)
        }

        let title: String
        let rows: [VocabularyRow]
        let deckLabel: String
        let deckName: String
        let status: Status
        let primaryTitle: String
        let primaryEnabled: Bool
        /// After a save: study the cards of these words.
        let canReview: Bool
    }

    struct QuizOption: Equatable {
        enum Mark: Equatable { case neutral, correct, wrong, dimmed }
        let text: String
        let mark: Mark
    }

    struct QuizQuestion: Equatable {
        let progress: String
        let promptJapanese: String
        let prompt: String?
        let options: [QuizOption]
        /// Set once an option is picked.
        let feedbackTitle: String?
        let feedbackDetail: String?
        let feedbackIsCorrect: Bool?
        let primaryTitle: String?
    }

    struct QuizResult: Equatable {
        let score: String
        let message: String
        let actionTitle: String
    }

    enum Quiz: Equatable {
        case question(QuizQuestion)
        case result(QuizResult)
    }

    let header: Header
    let blocks: [MagazineArticle.Block]
    let vocabulary: Vocabulary?
    let quizTitle: String?
    let quiz: Quiz?
    /// Says what the text is when a reader could take it for something official (a forecast, a fortune).
    let note: String?
}

enum MagazineArticleViewState: Equatable {
    case loading(message: String)
    case failed(title: String, message: String)
    case article(MagazineArticleState)
}

protocol MagazineArticleViewInterface: AnyObject {
    func render(_ state: MagazineArticleViewState)
    /// A short spoken/visible announcement for feedback that appears without a navigation (right, not quite, saved).
    func announce(_ text: String)
}

protocol MagazineArticlePresenterInterface: AnyObject {
    func viewDidLoad()
    func retry()
    func toggleWord(id: String)
    func chooseDeck()
    /// Saves the chosen words, or opens their cards when they are already saved.
    func saveWords()
    func selectOption(_ index: Int)
    func nextQuestion()
    func restartQuiz()
}

// MARK: Presenter

/// One article: reading, saving its words, and its quiz. The quiz and the saving are independent. Nothing is stored until
/// the learner saves words, and "saved" is only shown after the write has finished.
final class MagazineArticlePresenter {
    private enum Phase: Equatable {
        case loading, failed(String), ready
    }

    private let slug: String
    /// The day the list gave the article. The article's own payload only says when it was published, which is not its day.
    private let day: MagazineDay?
    private let interactor: MagazineInteractorInterface
    private let wireframe: MagazineArticleWireframeInterface
    private let language: () -> AppLanguage
    private let scheduler: ImmediateSchedulerType
    weak var view: MagazineArticleViewInterface?

    private var article: MagazineArticle?
    private var phase: Phase = .loading
    private let loading = SerialDisposable()

    // Saving
    private var selectedWords: Set<String> = []
    private var target: MagazineSaveTarget = .newMagazineDeck
    private var saveStatus: MagazineArticleState.Vocabulary.Status = .idle
    private var saveOutcome: MagazineSaveOutcome?

    // Quiz: `order[question]` lists the options in the order they are shown.
    private var order: [[Int]] = []
    private var questionIndex = 0
    private var pickedOption: Int?
    private var correctCount = 0
    private var quizFinished = false

    init(slug: String, day: MagazineDay? = nil, interactor: MagazineInteractorInterface, wireframe: MagazineArticleWireframeInterface,
         language: @escaping () -> AppLanguage = { AppLanguage.current },
         scheduler: ImmediateSchedulerType = MainScheduler.instance) {
        self.scheduler = scheduler
        self.slug = slug
        self.day = day
        self.interactor = interactor
        self.wireframe = wireframe
        self.language = language
    }

    deinit { loading.dispose() }

    private static func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    private func publish() {
        view?.render(makeState())
    }

    // MARK: State building

    private func makeState() -> MagazineArticleViewState {
        switch phase {
        case .loading: return .loading(message: Self.text("Loading the article…"))
        case .failed(let message): return .failed(title: Self.text("Couldn't load the article"), message: message)
        case .ready: return article.map { .article(articleState($0)) } ?? .loading(message: Self.text("Loading the article…"))
        }
    }

    private func articleState(_ article: MagazineArticle) -> MagazineArticleState {
        let language = language()
        let header = MagazineArticleState.Header(
            kind: article.kind, eyebrow: article.kind.title, dateText: day?.formatted(.full, locale: language.locale),
            level: article.level, titleJapanese: article.titleJapanese, titleVietnamese: article.titleVietnamese,
            summaryJapanese: article.summaryJapanese, summaryVietnamese: article.summaryVietnamese)
        return MagazineArticleState(
            header: header, blocks: article.blocks, vocabulary: article.vocabulary.isEmpty ? nil : vocabularyState(article),
            quizTitle: article.questions.isEmpty ? nil : Self.text("Quick quiz"), quiz: article.questions.isEmpty ? nil : quizState(article),
            note: Self.note(for: article.kind))
    }

    static func note(for kind: MagazineKind) -> String? {
        switch kind {
        case .weather: return text("Study text for practising Japanese. It is not an official weather forecast.")
        case .horoscope: return text("For fun and for practising Japanese. It is not advice.")
        case .vocabulary, .businessPhrase: return nil
        }
    }

    private var targetName: String {
        let name = NSLocalizedString("Magazine", comment: "Name of the deck that collects words saved from magazine articles")
        switch target {
        case .newMagazineDeck: return interactor.deckChoices().first { $0.id == MagazineInteractor.magazineDeckID }?.name ?? name
        case .existing(let id): return interactor.deckChoices().first { $0.id == id }?.name ?? name
        }
    }

    private func vocabularyState(_ article: MagazineArticle) -> MagazineArticleState.Vocabulary {
        let rows = article.vocabulary.map {
            MagazineArticleState.VocabularyRow(id: $0.id, japanese: $0.japanese, reading: $0.reading, meaning: $0.meaning, level: $0.level,
                                               example: $0.example, exampleMeaning: $0.exampleMeaning, isSelected: selectedWords.contains($0.id))
        }
        let saved: Bool = { if case .saved = saveStatus { return true } else { return false } }()
        let saving = saveStatus == .saving
        let primary: String
        if saved {
            primary = Self.text("Study these cards")
        } else if case .failed = saveStatus {
            primary = Self.text("Try again")
        } else {
            primary = String.localizedStringWithFormat(Self.text("Save %lld words"), selectedWords.count)
        }
        return MagazineArticleState.Vocabulary(
            title: Self.text("Vocabulary"), rows: rows, deckLabel: Self.text("Deck"), deckName: targetName, status: saveStatus,
            primaryTitle: primary, primaryEnabled: !saving && (saved && !(saveOutcome?.cardIDs.isEmpty ?? true) || !saved && !selectedWords.isEmpty),
            canReview: saved)
    }

    private func quizState(_ article: MagazineArticle) -> MagazineArticleState.Quiz {
        let total = article.questions.count
        if quizFinished {
            let message: String
            if correctCount == total {
                message = Self.text("Perfect. Every answer was right.")
            } else if correctCount * 2 >= total {
                message = Self.text("Good work. Read the explanations once more to lock them in.")
            } else {
                message = Self.text("Keep going. Read the article again and try once more.")
            }
            return .result(MagazineArticleState.QuizResult(
                score: String(format: Self.text("%1$lld of %2$lld correct"), correctCount, total), message: message,
                actionTitle: Self.text("Try again")))
        }
        let question = article.questions[questionIndex]
        let shown = order[questionIndex]
        let options = shown.enumerated().map { position, original -> MagazineArticleState.QuizOption in
            let option = question.options[original]
            guard let picked = pickedOption else { return .init(text: option.text, mark: .neutral) }
            if option.isCorrect { return .init(text: option.text, mark: .correct) }
            return .init(text: option.text, mark: position == picked ? .wrong : .dimmed)
        }
        var title: String?, detail: String?, isCorrect: Bool?
        if let picked = pickedOption {
            let right = question.options[shown[picked]].isCorrect
            isCorrect = right
            title = right ? Self.text("Correct") : Self.text("Not quite")
            let explanation = [question.explanationJapanese, question.explanation].compactMap { $0 }.joined(separator: "\n")
            detail = explanation.isEmpty ? nil : explanation
        }
        let isLast = questionIndex == total - 1
        return .question(MagazineArticleState.QuizQuestion(
            progress: String(format: Self.text("Question %1$lld of %2$lld"), questionIndex + 1, total),
            promptJapanese: question.promptJapanese, prompt: question.prompt, options: options,
            feedbackTitle: title, feedbackDetail: detail, feedbackIsCorrect: isCorrect,
            primaryTitle: pickedOption == nil ? nil : (isLast ? Self.text("See results") : Self.text("Next question"))))
    }

    /// The options of each question in a fixed but mixed order. The server lists the right answer first; a hash of the
    /// article, the question and the option decides the order, so it is the same on every redraw and in every run.
    static func displayOrder(slug: String, questions: [MagazineArticle.Question]) -> [[Int]] {
        questions.enumerated().map { index, question in
            question.options.indices.sorted { lhs, rhs in
                let left = stableHash("\(slug)|\(index)|\(question.options[lhs].text)")
                let right = stableHash("\(slug)|\(index)|\(question.options[rhs].text)")
                return left == right ? lhs < rhs : left < right
            }
        }
    }

    /// FNV-1a: Swift's own `hashValue` changes between runs.
    static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 14695981039346656037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return hash
    }

    // MARK: Loading

    private func load() {
        phase = .loading
        publish()
        loading.disposable = interactor.loadArticle(slug: slug)
            .observe(on: scheduler)
            .subscribe(onSuccess: { [weak self] article in
                guard let self else { return }
                self.article = article
                self.selectedWords = Set(article.vocabulary.map(\.id))
                self.order = Self.displayOrder(slug: article.slug, questions: article.questions)
                self.resetQuiz()
                self.phase = .ready
                self.publish()
            }, onFailure: { [weak self] error in
                guard let self else { return }
                self.phase = .failed(MagazinePresenter.message(for: error))
                self.publish()
            })
    }

    private func resetQuiz() {
        questionIndex = 0
        pickedOption = nil
        correctCount = 0
        quizFinished = false
    }
}

// MARK: Interaction

extension MagazineArticlePresenter: MagazineArticlePresenterInterface {
    func viewDidLoad() { load() }

    func retry() { load() }

    func toggleWord(id: String) {
        guard let article, article.vocabulary.contains(where: { $0.id == id }), saveStatus != .saving else { return }
        if selectedWords.contains(id) { selectedWords.remove(id) } else { selectedWords.insert(id) }
        // A new choice is a new save: what was stored before stays stored, and repeating it adds nothing twice.
        saveStatus = .idle
        saveOutcome = nil
        publish()
    }

    func chooseDeck() {
        guard article != nil, saveStatus != .saving else { return }
        wireframe.showDeckChooser(interactor.deckChoices(), magazineDeckExists: interactor.magazineDeckExists(), selected: target) { [weak self] choice in
            guard let self else { return }
            self.target = choice
            self.saveStatus = .idle
            self.saveOutcome = nil
            self.publish()
        }
    }

    func saveWords() {
        guard let article else { return }
        if case .saved = saveStatus {
            if let outcome = saveOutcome, !outcome.cardIDs.isEmpty { wireframe.showStudy(deckId: outcome.deckID, cardIDs: outcome.cardIDs) }
            return
        }
        guard saveStatus != .saving else { return }
        let words = article.vocabulary.filter { selectedWords.contains($0.id) }
        guard !words.isEmpty else { return }
        saveStatus = .saving
        publish()
        do {
            let outcome = try interactor.saveVocabulary(words, target: target)
            saveOutcome = outcome
            let message: String
            if outcome.added.isEmpty {
                message = String(format: Self.text("These words were already in “%@”. Nothing was added twice."), outcome.deckName)
            } else {
                message = String.localizedStringWithFormat(Self.text("%lld new cards added."), outcome.added.count) + " "
                    + String(format: Self.text("In “%@”."), outcome.deckName)
            }
            saveStatus = .saved(message: message)
            publish()
            view?.announce(message)
        } catch {
            saveOutcome = nil
            let message = (error as? LocalizedError)?.errorDescription ?? Self.text("The words could not be stored on this device. No cards were added.")
            saveStatus = .failed(message: message)
            publish()
            view?.announce(message)
        }
    }

    func selectOption(_ index: Int) {
        guard let article, phase == .ready, !quizFinished, pickedOption == nil, order.indices.contains(questionIndex),
              order[questionIndex].indices.contains(index) else { return }
        pickedOption = index
        let right = article.questions[questionIndex].options[order[questionIndex][index]].isCorrect
        if right { correctCount += 1 }
        publish()
        view?.announce(right ? Self.text("Correct") : Self.text("Not quite"))
    }

    func nextQuestion() {
        guard let article, pickedOption != nil, !quizFinished else { return }
        if questionIndex == article.questions.count - 1 {
            quizFinished = true
        } else {
            questionIndex += 1
            pickedOption = nil
        }
        publish()
    }

    func restartQuiz() {
        guard article != nil else { return }
        resetQuiz()
        publish()
    }
}
