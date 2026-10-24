import RxSwift
import XCTest
@testable import FlashcardApp

/// The journey of one lesson: story → practice → save → done. What each step says, what a tap does, and above all what is
/// never claimed: a word is "saved" only after the store accepted it, and an unfinished exercise is never "done".
final class LifeLessonPresenterTests: XCTestCase {
    private var interactor: FakeLifeInteractor!
    private var wireframe: FakeLifeWireframe!
    private var view: SpyLifeView!
    private var presenter: LifeLessonPresenter!
    private var lesson: LifeLesson!
    private var language = AppLanguage.vietnamese

    override func setUpWithError() throws {
        interactor = FakeLifeInteractor()
        wireframe = FakeLifeWireframe()
        view = SpyLifeView()
        lesson = try LifeLessonFixtures.lesson()
    }

    private func start(lesson: LifeLesson?) {
        presenter = LifeLessonPresenter(cityID: "tokyo", lesson: lesson, interactor: interactor, wireframe: wireframe,
                                        language: { [unowned self] in language }, now: { LifeLessonFixtures.morning })
        presenter.view = view
        presenter.viewDidLoad()
    }

    private func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    private var story: LifeStoryState? { if case .story(let s)? = view.last { return s } else { return nil } }
    private var practice: LifePracticeState? { if case .practice(let p)? = view.last { return p } else { return nil } }
    private var save: LifeSaveState? { if case .save(let s)? = view.last { return s } else { return nil } }
    private var done: LifeDoneState? { if case .done(let d)? = view.last { return d } else { return nil } }

    /// Answers both exercises correctly and arrives at the save step.
    private func reachSave(correct: Bool = true) throws {
        start(lesson: lesson)
        presenter.startPractice()
        presenter.primaryTapped(answer: correct ? "あめ" : "ゆき")
        presenter.primaryTapped(answer: "")                       // next
        presenter.selectChoice(0)
        presenter.primaryTapped(answer: "")                       // check
        presenter.primaryTapped(answer: "")                       // see results
        XCTAssertNotNil(save, "expected the save step")
    }

    private func outcome(added: [String] = ["weather:rain"], present: [String] = [], cards: [String] = ["c1"]) -> LifeSaveOutcome {
        LifeSaveOutcome(deckID: "life-learning", deckName: "Learn from Life", added: added, alreadyPresent: present, cardIDs: cards)
    }

    // MARK: Story

    func test_aLoadedLessonOpensOnTheStoryWithFactsSourceAndTagsStatedAsSuch() throws {
        start(lesson: lesson)
        let story = try XCTUnwrap(self.story)
        XCTAssertEqual(story.title, "今日の東京の天気")
        XCTAssertEqual(story.titleReading, "きょうのとうきょうのてんき")
        XCTAssertEqual(story.factChips.count, 2)
        XCTAssertTrue(story.factChips[0].contains("16") && story.factChips[0].contains("14"))
        XCTAssertTrue(story.factChips[1].contains("80"))
        XCTAssertTrue(story.sourceLine.contains("Open-Meteo"))
        XCTAssertTrue(story.sourceLine.contains(LifeLessonPresenter.timeText(lesson.source.observedAt, language: .vietnamese)), "The observation time is the source's own")
        XCTAssertEqual(story.attribution, "Weather data by Open-Meteo.com")
        XCTAssertEqual(story.tags, [text("Development source")], "A non-commercial source is labelled, not hidden")
        XCTAssertEqual(story.sentences.map(\.isAdvice), [false, false, false, true])
        XCTAssertEqual(story.sentences[0].translation, "Hôm nay thời tiết ở Tokyo là mưa.")
        XCTAssertTrue(interactor.loadedCities.isEmpty, "A lesson handed over is not fetched again")
    }

    func test_theTranslationFollowsTheLanguage() throws {
        language = .english
        start(lesson: lesson)
        XCTAssertEqual(story?.sentences[0].translation, "Today's weather in Tokyo is rain.")
    }

    func test_aStaleLessonSaysSo() throws {
        let stale = try LifeLessonFixtures.lesson { var s = $0["source"] as! [String: Any]; s["freshness"] = "stale"; $0["source"] = s }
        start(lesson: stale)
        XCTAssertTrue(story?.tags.contains(text("Not the latest")) == true)
    }

    func test_withoutALessonItLoadsOneAndShowsTheProgress() throws {
        let subject = PublishSubject<LifeLesson>()
        interactor.loadResult = { _ in subject.asSingle() }
        start(lesson: nil)
        XCTAssertEqual(view.last, .loading(message: text("Loading today's lesson…")))
        subject.onNext(lesson)
        subject.onCompleted()
        XCTAssertNotNil(story)
        XCTAssertEqual(interactor.loadedCities, ["tokyo"])
    }

    func test_aFailedLoadSaysWhyAndRetryAsksAgain() throws {
        interactor.loadResult = { _ in .error(LearnerAPIError.offline) }
        start(lesson: nil)
        guard case .failed(_, let message)? = view.last else { return XCTFail("expected failure, got \(String(describing: view.last))") }
        XCTAssertEqual(message, LearnerAPIError.offline.errorDescription)
        interactor.loadResult = { [unowned self] _ in .just(lesson) }
        presenter.retry()
        XCTAssertNotNil(story)
        XCTAssertEqual(interactor.loadedCities.count, 2)
    }

    func test_theSourceLinkOpensTheProvidersPage() {
        start(lesson: lesson)
        presenter.openSource()
        XCTAssertEqual(wireframe.openedSources, [URL(string: "https://open-meteo.com/")!])
    }

    // MARK: Practice

    func test_practiceStartsWithARecallExerciseThatDoesNotContainTheAnswer() throws {
        start(lesson: lesson)
        presenter.startPractice()
        let practice = try XCTUnwrap(self.practice)
        XCTAssertEqual(practice.progress, String(format: text("Exercise %1$lld of %2$lld"), 1, 2))
        XCTAssertEqual(practice.skill, text("Recall: type the answer"))
        XCTAssertEqual(practice.promptJapanese, "今日の東京の天気は＿＿です。")
        XCTAssertEqual(practice.input, .typed(placeholder: text("Your answer")))
        XCTAssertNil(practice.feedback)
        XCTAssertEqual(practice.primaryTitle, text("Check"))
        for shown in [practice.prompt, practice.promptJapanese] {
            XCTAssertFalse(shown.contains("あめ") || shown.contains("雨"), "The prompt must not give the answer away")
        }
    }

    func test_aCorrectTypedAnswerIsConfirmedAndExplainedAfterwards() throws {
        start(lesson: lesson)
        presenter.startPractice()
        presenter.primaryTapped(answer: " あめ ")
        let feedback = try XCTUnwrap(practice?.feedback)
        XCTAssertTrue(feedback.isCorrect)
        XCTAssertEqual(feedback.title, text("Correct"))
        XCTAssertTrue(feedback.detail.contains("雨"))
        XCTAssertEqual(practice?.primaryTitle, text("Next"))
        XCTAssertEqual(view.announcements.count, 1, "The result is announced, not only drawn")
    }

    func test_aWrongAnswerShowsTheRightOneAndCannotBeChangedAfterChecking() throws {
        start(lesson: lesson)
        presenter.startPractice()
        presenter.primaryTapped(answer: "ゆき")
        XCTAssertEqual(practice?.feedback?.isCorrect, false)
        XCTAssertEqual(practice?.feedback?.title, text("Not quite"))
        XCTAssertTrue(practice?.feedback?.detail.contains("雨") == true)
        let before = view.states.count
        presenter.primaryTapped(answer: "あめ")   // this is "Next", not a second try
        XCTAssertEqual(practice?.progress, String(format: text("Exercise %1$lld of %2$lld"), 2, 2))
        XCTAssertGreaterThan(view.states.count, before)
    }

    func test_anEmptyAnswerIsNotCorrect() {
        start(lesson: lesson)
        presenter.startPractice()
        presenter.primaryTapped(answer: "   ")
        XCTAssertEqual(practice?.feedback?.isCorrect, false)
    }

    func test_aChoiceExerciseNeedsAPickBeforeItCanBeChecked() throws {
        start(lesson: lesson)
        presenter.startPractice()
        presenter.primaryTapped(answer: "あめ")
        presenter.primaryTapped(answer: "")                       // next → the choice exercise
        var current = try XCTUnwrap(practice)
        XCTAssertEqual(current.skill, text("Recognition: pick the answer"), "A recognition exercise says what it is")
        XCTAssertFalse(current.primaryEnabled)
        presenter.primaryTapped(answer: "")                       // nothing picked: nothing happens
        XCTAssertNil(practice?.feedback)
        presenter.selectChoice(1)
        current = try XCTUnwrap(practice)
        XCTAssertTrue(current.primaryEnabled)
        guard case .choices(_, let selected) = current.input else { return XCTFail("expected choices") }
        XCTAssertEqual(selected, 1)
    }

    func test_checkingAChoiceMarksThePickAndTheRightRow() throws {
        start(lesson: lesson)
        presenter.startPractice()
        presenter.primaryTapped(answer: "あめ")
        presenter.primaryTapped(answer: "")
        guard case .choice(_, _, _, let choices, let correctID, _) = lesson.exercises[1] else { return XCTFail() }
        let correct = try XCTUnwrap(choices.firstIndex { $0.id == correctID })
        let wrong = (0..<choices.count).first { $0 != correct }!
        presenter.selectChoice(wrong)
        presenter.primaryTapped(answer: "")
        let feedback = try XCTUnwrap(practice?.feedback)
        XCTAssertFalse(feedback.isCorrect)
        XCTAssertEqual(feedback.selectedChoice, wrong)
        XCTAssertEqual(feedback.correctChoice, correct)
        XCTAssertEqual(practice?.primaryTitle, text("See results"))
        presenter.selectChoice(correct)   // locked after checking
        XCTAssertEqual(practice?.feedback?.selectedChoice, wrong)
    }

    func test_finishingTheExercisesLeadsToTheSaveStepWithEveryWordChosen() throws {
        try reachSave()
        let save = try XCTUnwrap(self.save)
        XCTAssertEqual(save.rows.map(\.id), lesson.vocabulary.map(\.id))
        XCTAssertTrue(save.rows.allSatisfy(\.isSelected))
        XCTAssertEqual(save.rows.first?.meaning, "mưa")
        XCTAssertEqual(save.deckName, text("Learn from Life"))
        XCTAssertEqual(save.status, .idle)
        XCTAssertTrue(save.primaryEnabled)
        XCTAssertEqual(save.secondaryTitle, text("Not now"))
    }

    // MARK: Saving

    func test_savingStoresTheChosenWordsOnceAndOnlyThenReportsThemSaved() throws {
        try reachSave()
        interactor.saveResult = .success(outcome(added: ["weather:rain", "weather:umbrella"], cards: ["c1", "c2"]))
        presenter.toggleWord(id: "weather:max-temperature")
        presenter.toggleWord(id: "weather:min-temperature")
        presenter.toggleWord(id: "weather:precipitation-probability")
        XCTAssertEqual(save?.rows.filter(\.isSelected).map(\.id), ["weather:rain", "weather:umbrella"])

        presenter.saveWords()
        XCTAssertEqual(interactor.saveCalls.count, 1)
        XCTAssertEqual(interactor.saveCalls[0].words.map(\.id), ["weather:rain", "weather:umbrella"])
        XCTAssertEqual(interactor.saveCalls[0].target, .newLifeDeck)
        XCTAssertEqual(interactor.saveCalls[0].language, .vietnamese)
        guard case .saved(let message)? = save?.status else { return XCTFail("expected saved, got \(String(describing: save?.status))") }
        XCTAssertTrue(message.contains("Learn from Life"))
        XCTAssertEqual(save?.primaryTitle, text("Continue"))
        XCTAssertNil(save?.secondaryTitle, "Nothing left to skip")
    }

    func test_theSavingStateIsShownBeforeTheStoreAnswersAndIsNotSavedYet() throws {
        try reachSave()
        // The fake answers synchronously, so look at the states rendered during the call.
        interactor.saveResult = .success(outcome())
        let before = view.states.count
        presenter.saveWords()
        let during = view.states[before..<view.states.count].compactMap { state -> LifeSaveState.Status? in
            if case .save(let s) = state { return s.status } else { return nil }
        }
        XCTAssertEqual(during.first, .saving, "Nothing is reported as saved until the store has answered")
    }

    func test_aSecondTapAfterSavingNeverWritesAgain() throws {
        try reachSave()
        interactor.saveResult = .success(outcome())
        presenter.saveWords()
        presenter.saveWords()   // the button now says "Continue"
        XCTAssertEqual(interactor.saveCalls.count, 1)
        XCTAssertNotNil(done, "The second tap only moves on")
    }

    func test_aFailedSaveIsNotReportedAndCanBeRetriedWithTheSameChoice() throws {
        try reachSave()
        interactor.saveResult = .failure(AppError.databaseWriteFailed("disk full"))
        presenter.saveWords()
        guard case .failed(let message)? = save?.status else { return XCTFail("expected failure") }
        XCTAssertEqual(message, text("The words could not be stored on this device. No cards were added."))
        XCTAssertEqual(view.announcements.last, message, "A failure is announced like a success")
        XCTAssertEqual(save?.primaryTitle, text("Try again"))
        XCTAssertEqual(save?.rows.filter(\.isSelected).count, lesson.vocabulary.count, "The choice is kept")

        interactor.saveResult = .success(outcome())
        presenter.saveWords()
        XCTAssertEqual(interactor.saveCalls.count, 2)
        guard case .saved? = save?.status else { return XCTFail("expected saved after the retry") }
    }

    func test_alreadySavedWordsAreSaidToBeAlreadyThere() throws {
        try reachSave()
        interactor.saveResult = .success(outcome(added: [], present: ["weather:rain"], cards: ["c1"]))
        presenter.saveWords()
        guard case .saved(let message)? = save?.status else { return XCTFail("expected saved") }
        XCTAssertEqual(message, String(format: text("Already in “%@”. Nothing was added twice."), "Learn from Life"))
    }

    func test_withNothingChosenThereIsNothingToSave() throws {
        try reachSave()
        lesson.vocabulary.forEach { presenter.toggleWord(id: $0.id) }
        XCTAssertEqual(save?.primaryEnabled, false)
        presenter.saveWords()
        XCTAssertTrue(interactor.saveCalls.isEmpty)
    }

    func test_theDeckCanBeChosenAndTheChoiceIsWhatIsSavedInto() throws {
        try reachSave()
        interactor.choices = [TodayDeckChoice(id: "deck-1", name: "My words", cardCount: 4)]
        presenter.chooseDeck()
        XCTAssertEqual(wireframe.chooserCalls.first?.choices, interactor.choices)
        XCTAssertEqual(wireframe.chooserCalls.first?.lifeDeckExists, false)
        XCTAssertEqual(wireframe.chooserCalls.first?.selected, .newLifeDeck)
        wireframe.onSelect?(.existing(deckID: "deck-1"))
        XCTAssertEqual(save?.deckName, "My words")
        interactor.saveResult = .success(LifeSaveOutcome(deckID: "deck-1", deckName: "My words", added: ["weather:rain"], alreadyPresent: [], cardIDs: ["c1"]))
        presenter.saveWords()
        XCTAssertEqual(interactor.saveCalls.first?.target, .existing(deckID: "deck-1"))
    }

    func test_theDeckCannotBeChangedOnceTheWordsAreStored() throws {
        try reachSave()
        interactor.saveResult = .success(outcome())
        presenter.saveWords()
        presenter.chooseDeck()
        XCTAssertTrue(wireframe.chooserCalls.isEmpty)
    }

    // MARK: Done

    func test_doneKeepsTheExerciseResultSeparateFromWhatWasSaved() throws {
        try reachSave(correct: true)
        interactor.saveResult = .success(outcome(added: ["weather:rain"], cards: ["c1"]))
        presenter.saveWords()
        presenter.continueToDone()
        let done = try XCTUnwrap(self.done)
        XCTAssertEqual(done.exerciseTitle, text("Exercises finished"))
        XCTAssertEqual(done.exerciseDetail, String(format: text("%1$lld of %2$lld correct"), 1, 2), "Only the recall answer was right; the picked choice 0 was a guess")
        XCTAssertEqual(done.saveResult, .saved)
        XCTAssertEqual(done.saveTitle, text("Words saved"))
        XCTAssertTrue(done.saveDetail.contains("Learn from Life"))
        XCTAssertTrue(done.canReviewCards)
    }

    func test_oneNewWordIsNotCalledManyCards() throws {
        try reachSave()
        interactor.saveResult = .success(outcome(added: ["weather:rain"], cards: ["c1"]))
        presenter.saveWords()
        presenter.continueToDone()
        let detail = try XCTUnwrap(done?.saveDetail)
        XCTAssertFalse(detail.contains("1 new cards"), detail)
        XCTAssertTrue(detail.contains("1"), detail)
    }

    func test_skippingTheSaveSaysNothingWasSaved() throws {
        try reachSave()
        presenter.skipSaving()
        let done = try XCTUnwrap(self.done)
        XCTAssertEqual(done.saveResult, .notSaved)
        XCTAssertEqual(done.saveTitle, text("Words not saved"))
        XCTAssertFalse(done.canReviewCards)
        XCTAssertTrue(interactor.saveCalls.isEmpty)
    }

    func test_afterAFailedSaveTheDoneStepDoesNotClaimTheWordsAreStored() throws {
        try reachSave()
        interactor.saveResult = .failure(AppError.databaseWriteFailed("disk full"))
        presenter.saveWords()
        presenter.skipSaving()
        XCTAssertEqual(done?.saveResult, .notSaved)
        XCTAssertEqual(done?.saveDetail, text("The words could not be stored on this device. No cards were added."))
    }

    func test_theSavedCardsCanBeStudiedAndTheLessonCanBeLeft() throws {
        try reachSave()
        interactor.saveResult = .success(outcome(cards: ["c1", "c2"]))
        presenter.saveWords()
        presenter.continueToDone()
        presenter.reviewSavedCards()
        XCTAssertEqual(wireframe.studied.first?.deck, "life-learning")
        XCTAssertEqual(wireframe.studied.first?.cards, ["c1", "c2"])
        presenter.finish()
        XCTAssertEqual(wireframe.finished, 1)
    }

    func test_nothingIsStoredBeforeTheLearnerSaves() throws {
        try reachSave()
        presenter.skipSaving()
        XCTAssertTrue(interactor.saveCalls.isEmpty, "Finishing the exercises alone writes nothing")
    }
}
