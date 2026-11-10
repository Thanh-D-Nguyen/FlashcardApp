import RxSwift
import XCTest
@testable import FlashcardApp

/// One article: loading, choosing and saving words, and the quiz.
final class MagazineArticlePresenterTests: XCTestCase {
    private var interactor: FakeMagazineInteractor!
    private var wireframe: FakeMagazineArticleWireframe!
    private var view: SpyMagazineArticleView!
    private var presenter: MagazineArticlePresenter!
    private var article: MagazineArticle!

    override func setUpWithError() throws {
        article = try MagazineFixtures.article()
        interactor = FakeMagazineInteractor()
        interactor.articleResult = { [unowned self] _ in .just(article) }
        wireframe = FakeMagazineArticleWireframe()
        view = SpyMagazineArticleView()
        make(article)
    }

    private func make(_ article: MagazineArticle, day: MagazineDay? = MagazineDay(key: "2026-10-26")) {
        interactor.articleResult = { _ in .just(article) }
        presenter = MagazineArticlePresenter(slug: article.slug, day: day, interactor: interactor, wireframe: wireframe, language: { .english }, scheduler: CurrentThreadScheduler.instance)
        presenter.view = view
        self.article = article
    }

    private var state: MagazineArticleState { view.article! }

    // MARK: Loading

    func test_theArticleLoadsAndShowsItsHeaderWithTheDayTheListGave() throws {
        let reply = PublishSubject<MagazineArticle>()
        interactor.articleResult = { _ in reply.take(1).asSingle() }
        presenter.viewDidLoad()
        XCTAssertEqual(view.last, .loading(message: "Loading the article…"))

        reply.onNext(article)
        XCTAssertEqual(state.header.titleJapanese, "梅雨の季節の言葉")
        XCTAssertEqual(state.header.eyebrow, "Vocabulary")
        XCTAssertEqual(state.header.level, "N4")
        XCTAssertTrue(try XCTUnwrap(state.header.dateText).contains("Monday"))
        XCTAssertEqual(interactor.articleCalls, ["2026-10-26-vocab-vi"])
    }

    func test_withoutADayTheHeaderShowsNoDate() {
        make(article, day: nil)
        presenter.viewDidLoad()
        XCTAssertNil(state.header.dateText)
    }

    func test_aFailureShowsItsReasonAndRetryLoadsAgain() {
        interactor.articleResult = { _ in .error(LearnerAPIError.notFound) }
        presenter.viewDidLoad()
        XCTAssertEqual(view.last, .failed(title: "Couldn't load the article", message: LearnerAPIError.notFound.errorDescription ?? ""))
        interactor.articleResult = { [unowned self] _ in .just(article) }
        presenter.retry()
        XCTAssertNotNil(view.article)
    }

    func test_onlyWeatherAndHoroscopeCarryANoteThatTheyAreNotOfficial() {
        XCTAssertNotNil(MagazineArticlePresenter.note(for: .weather))
        XCTAssertNotNil(MagazineArticlePresenter.note(for: .horoscope))
        XCTAssertNil(MagazineArticlePresenter.note(for: .vocabulary))
        XCTAssertNil(MagazineArticlePresenter.note(for: .businessPhrase))
    }

    func test_anArticleWithoutWordsOrQuestionsHasNoSuchSections() throws {
        make(try MagazineFixtures.article(MagazineFixtures.phraseArticle))
        presenter.viewDidLoad()
        XCTAssertNil(state.vocabulary)
        XCTAssertNil(state.quiz)
        XCTAssertNil(state.quizTitle)
    }

    // MARK: Words

    func test_everyWordStartsChosenAndTheButtonSaysHowManyWillBeSaved() {
        presenter.viewDidLoad()
        let vocabulary = state.vocabulary!
        XCTAssertEqual(vocabulary.rows.map(\.isSelected), [true, true])
        XCTAssertEqual(vocabulary.primaryTitle, String.localizedStringWithFormat("Save %lld words", 2))
        XCTAssertTrue(vocabulary.primaryEnabled)
        XCTAssertEqual(vocabulary.status, .idle)
    }

    func test_choosingNoWordsDisablesSavingAndAnUnknownWordChangesNothing() {
        presenter.viewDidLoad()
        presenter.toggleWord(id: "v1")
        presenter.toggleWord(id: "v2")
        XCTAssertEqual(state.vocabulary?.rows.map(\.isSelected), [false, false])
        XCTAssertEqual(state.vocabulary?.primaryEnabled, false)
        let count = view.states.count
        presenter.toggleWord(id: "nope")
        XCTAssertEqual(view.states.count, count)
        presenter.saveWords()
        XCTAssertTrue(interactor.saveCalls.isEmpty)
    }

    func test_savingStoresTheChosenWordsInTheOrderOfTheArticleAndReportsAfterTheWrite() throws {
        interactor.saveResult = .success(MagazineSaveOutcome(deckID: "magazine", deckName: "Magazine", added: ["v2"], alreadyPresent: [], cardIDs: ["c2"]))
        presenter.viewDidLoad()
        presenter.toggleWord(id: "v1")
        presenter.saveWords()

        XCTAssertEqual(interactor.saveCalls.count, 1)
        XCTAssertEqual(interactor.saveCalls[0].words.map(\.id), ["v2"])
        XCTAssertEqual(interactor.saveCalls[0].target, .newMagazineDeck)
        guard case .saved(let message) = state.vocabulary?.status else { return XCTFail("expected saved") }
        XCTAssertTrue(message.contains("Magazine"))
        XCTAssertEqual(view.announcements.last, message)
        XCTAssertEqual(state.vocabulary?.canReview, true)
    }

    func test_savingWordsThatWereAlreadyThereSaysNothingWasAddedTwice() {
        interactor.saveResult = .success(MagazineSaveOutcome(deckID: "magazine", deckName: "Magazine", added: [], alreadyPresent: ["v1", "v2"], cardIDs: ["c1", "c2"]))
        presenter.viewDidLoad()
        presenter.saveWords()
        guard case .saved(let message) = state.vocabulary?.status else { return XCTFail("expected saved") }
        XCTAssertEqual(message, "These words were already in “Magazine”. Nothing was added twice.")
    }

    func test_afterSavingTheButtonStudiesTheCardsInsteadOfSavingAgain() {
        interactor.saveResult = .success(MagazineSaveOutcome(deckID: "magazine", deckName: "Magazine", added: ["v1", "v2"], alreadyPresent: [], cardIDs: ["c1", "c2"]))
        presenter.viewDidLoad()
        presenter.saveWords()
        XCTAssertEqual(state.vocabulary?.primaryTitle, "Study these cards")
        presenter.saveWords()
        XCTAssertEqual(interactor.saveCalls.count, 1, "Pressing again must not write again")
        XCTAssertEqual(wireframe.studied.first?.deck, "magazine")
        XCTAssertEqual(wireframe.studied.first?.cards, ["c1", "c2"])
    }

    func test_aFailedSaveSaysSoStoresNothingAndCanBeTriedAgain() {
        interactor.saveResult = .failure(AppError.databaseWriteFailed("disk full"))
        presenter.viewDidLoad()
        presenter.saveWords()
        guard case .failed = state.vocabulary?.status else { return XCTFail("expected failed") }
        XCTAssertEqual(state.vocabulary?.canReview, false)
        XCTAssertEqual(state.vocabulary?.primaryTitle, "Try again")
        XCTAssertTrue(wireframe.studied.isEmpty)

        interactor.saveResult = .success(MagazineSaveOutcome(deckID: "magazine", deckName: "Magazine", added: ["v1", "v2"], alreadyPresent: [], cardIDs: ["c1", "c2"]))
        presenter.saveWords()
        guard case .saved = state.vocabulary?.status else { return XCTFail("expected saved") }
        XCTAssertEqual(interactor.saveCalls.count, 2)
    }

    func test_changingTheChoiceAfterSavingStartsANewSave() {
        interactor.saveResult = .success(MagazineSaveOutcome(deckID: "magazine", deckName: "Magazine", added: ["v1", "v2"], alreadyPresent: [], cardIDs: ["c1", "c2"]))
        presenter.viewDidLoad()
        presenter.saveWords()
        presenter.toggleWord(id: "v1")
        XCTAssertEqual(state.vocabulary?.status, .idle)
        XCTAssertEqual(state.vocabulary?.canReview, false)
    }

    func test_theDeckChooserOffersTheDecksAndTheChosenOneIsWhereWordsGo() {
        interactor.choices = [TodayDeckChoice(id: "d1", name: "My words", cardCount: 3)]
        presenter.viewDidLoad()
        presenter.chooseDeck()
        XCTAssertEqual(wireframe.chooserCalls.first?.choices.map(\.id), ["d1"])
        XCTAssertEqual(wireframe.chooserCalls.first?.deckExists, false)
        XCTAssertEqual(wireframe.chooserCalls.first?.selected, .newMagazineDeck)

        wireframe.onSelect?(.existing(deckID: "d1"))
        XCTAssertEqual(state.vocabulary?.deckName, "My words")
        presenter.saveWords()
        XCTAssertEqual(interactor.saveCalls.first?.target, .existing(deckID: "d1"))
    }

    // MARK: Quiz

    /// The position, as shown, of the right answer of a question.
    private func rightPosition(_ question: Int) -> Int {
        let order = MagazineArticlePresenter.displayOrder(slug: article.slug, questions: article.questions)[question]
        let right = article.questions[question].options.firstIndex(where: \.isCorrect)!
        return order.firstIndex(of: right)!
    }

    private func wrongPosition(_ question: Int) -> Int { rightPosition(question) == 0 ? 1 : 0 }

    private func question() -> MagazineArticleState.QuizQuestion? {
        if case .question(let question)? = state.quiz { return question } else { return nil }
    }

    func test_theQuizStartsAtTheFirstQuestionWithNoAnswerMarked() {
        presenter.viewDidLoad()
        let first = question()
        XCTAssertEqual(first?.progress, "Question 1 of 2")
        XCTAssertEqual(first?.promptJapanese, "「梅雨」の読み方はどれですか？")
        XCTAssertEqual(first?.options.count, 3)
        XCTAssertTrue(first?.options.allSatisfy { $0.mark == .neutral } ?? false)
        XCTAssertNil(first?.feedbackTitle)
        XCTAssertNil(first?.primaryTitle, "Nothing to press until an answer is picked")
        XCTAssertEqual(state.quizTitle, "Quick quiz")
    }

    func test_aRightAnswerIsMarkedAndExplained() {
        presenter.viewDidLoad()
        presenter.selectOption(rightPosition(0))
        let answered = question()
        XCTAssertEqual(answered?.feedbackTitle, "Correct")
        XCTAssertEqual(answered?.feedbackIsCorrect, true)
        XCTAssertEqual(answered?.feedbackDetail, "「つゆ」と読みます。\nĐọc là つゆ.")
        XCTAssertEqual(answered?.options.filter { $0.mark == .correct }.count, 1)
        XCTAssertEqual(answered?.primaryTitle, "Next question")
        XCTAssertEqual(view.announcements.last, "Correct")
    }

    func test_aWrongAnswerIsMarkedAndTheRightOneIsShown() {
        presenter.viewDidLoad()
        let wrong = wrongPosition(0)
        presenter.selectOption(wrong)
        let answered = question()
        XCTAssertEqual(answered?.feedbackTitle, "Not quite")
        XCTAssertEqual(answered?.options[wrong].mark, .wrong)
        XCTAssertEqual(answered?.options[rightPosition(0)].mark, .correct)
        XCTAssertEqual(answered?.options.filter { $0.mark == .dimmed }.count, 1)
    }

    func test_oncePickedTheAnswerCannotBeChanged() {
        presenter.viewDidLoad()
        presenter.selectOption(wrongPosition(0))
        presenter.selectOption(rightPosition(0))
        presenter.nextQuestion()
        presenter.nextQuestion()
        XCTAssertEqual(question()?.progress, "Question 2 of 2", "The second next, with nothing picked, did not skip a question")
        presenter.selectOption(99)
        XCTAssertNil(question()?.feedbackTitle)
    }

    func test_theResultCountsRightAnswersAndOffersAnotherTry() {
        presenter.viewDidLoad()
        presenter.selectOption(rightPosition(0))
        presenter.nextQuestion()
        presenter.selectOption(wrongPosition(1))
        XCTAssertEqual(question()?.primaryTitle, "See results")
        presenter.nextQuestion()
        guard case .result(let result)? = state.quiz else { return XCTFail("expected the result") }
        XCTAssertEqual(result.score, String(format: "%1$lld of %2$lld correct", 1, 2))
        XCTAssertEqual(result.actionTitle, "Try again")

        presenter.restartQuiz()
        XCTAssertEqual(question()?.progress, "Question 1 of 2")
        XCTAssertNil(question()?.feedbackTitle)
    }

    func test_anExplanationIsOmittedWhenTheServerGaveNone() {
        presenter.viewDidLoad()
        presenter.selectOption(rightPosition(0))
        presenter.nextQuestion()
        presenter.selectOption(rightPosition(1))
        XCTAssertNil(question()?.feedbackDetail)
    }

    func test_theOrderOfTheOptionsIsMixedButTheSameEveryTime() {
        let first = MagazineArticlePresenter.displayOrder(slug: article.slug, questions: article.questions)
        let second = MagazineArticlePresenter.displayOrder(slug: article.slug, questions: article.questions)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.map { $0.sorted() }, [[0, 1, 2], [0, 1]], "Every option is shown once")
        // The server always lists the right answer first; across many articles it must not always stay first.
        let firsts = (0..<30).map { MagazineArticlePresenter.displayOrder(slug: "slug-\($0)", questions: article.questions)[0][0] }
        XCTAssertGreaterThan(Set(firsts).count, 1)
    }

    func test_theStableHashDoesNotChangeBetweenRuns() {
        XCTAssertEqual(MagazineArticlePresenter.stableHash(""), 14695981039346656037)
        XCTAssertEqual(MagazineArticlePresenter.stableHash("a"), 12638187200555641996)
    }
}
