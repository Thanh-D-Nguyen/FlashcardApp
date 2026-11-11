import RealmSwift
import RxSwift
import XCTest
@testable import FlashcardApp

final class LessonPracticePresenterTests: XCTestCase {
    private var store: RealmLessonProgressStore!
    private var api: ProgressAPIStub!
    private var owner = ""
    private var language: AppLanguage = .vietnamese
    private var lesson: BJTLessonDetailDTO!
    private let account = "11111111-1111-1111-1111-111111111111"
    private let otherAccount = "22222222-2222-2222-2222-222222222222"
    private let day = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        RealmService.shared.realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString, objectTypes: RealmService.storedTypes))
        store = RealmLessonProgressStore()
        api = ProgressAPIStub()
        owner = ""
        language = .vietnamese
        lesson = try JSONDecoder().decode(BJTLessonDetailDTO.self, from: Data(BJTLessonFixtures.j5Lesson01JSON.utf8))
    }

    override func tearDown() {
        RealmService.shared.realm = nil
        super.tearDown()
    }

    private func makePresenter(store customStore: LessonProgressStoreInterface? = nil) -> LessonPracticePresenter {
        let presenter = LessonPracticePresenter(lesson: lesson, store: customStore ?? store, api: api,
                                                ownerKey: { [unowned self] in owner }, language: { [unowned self] in language }, now: { [day] in day })
        presenter.viewDidLoad()
        return presenter
    }

    private var activities: [BJTLessonActivityDTO] { lesson.lessonContent.activities }

    private func question(_ presenter: LessonPracticePresenter) throws -> PracticeQuestionState {
        guard case .question(let state) = presenter.screen else { XCTFail("expected a question, got \(presenter.screen)"); throw WrongScreen() }
        return state
    }

    private func summary(_ presenter: LessonPracticePresenter) throws -> PracticeSummary {
        guard case .summary(let state) = presenter.screen else { XCTFail("expected a summary, got \(presenter.screen)"); throw WrongScreen() }
        return state
    }

    private func indexOfOption(_ key: String, in state: PracticeQuestionState) throws -> Int {
        try XCTUnwrap(state.options.firstIndex { $0.key == key })
    }

    /// Answers the question on screen with its correct option and moves on.
    private func answerCorrectly(_ presenter: LessonPracticePresenter) throws {
        let state = try question(presenter)
        presenter.selectOption(at: try indexOfOption(activities[state.index].answer, in: state))
        presenter.next()
    }

    /// Chooses an option that is not the right answer; returns nothing, the question stays on screen.
    private func chooseWrongOption(_ presenter: LessonPracticePresenter) throws {
        let state = try question(presenter)
        let wrong = try XCTUnwrap(state.options.firstIndex { $0.key != activities[state.index].answer })
        presenter.selectOption(at: wrong)
    }

    func test_startsOnTheFirstQuestionWithTheServersTextAndNothingChosen() throws {
        let state = try question(makePresenter())
        XCTAssertEqual(state.index, 0)
        XCTAssertEqual(state.total, 5, "From the payload")
        XCTAssertEqual(state.activityId, "act-j5-w01-u1-01")
        XCTAssertEqual(state.options.map(\.key), ["A", "B", "C", "D"])
        XCTAssertEqual(state.options.map(\.text), activities[0].options.map(\.text))
        XCTAssertTrue(state.options.allSatisfy { $0.outcome == .none && $0.rationale == nil }, "Nothing is revealed before answering")
        XCTAssertFalse(state.isAnswered)
        XCTAssertNil(state.isCorrect)
        XCTAssertNil(state.explanation)
        XCTAssertEqual(state.prompt, activities[0].prompt)
        XCTAssertEqual(state.promptTranslation, activities[0].promptVi)
        XCTAssertEqual(state.stimulus, activities[0].stimulusText)
        XCTAssertFalse(state.isLast)
    }

    func test_aCorrectChoiceIsRevealedWithTheServersRationaleAndSavedOnce() throws {
        let presenter = makePresenter()
        let first = try question(presenter)
        presenter.selectOption(at: try indexOfOption("A", in: first))
        let state = try question(presenter)
        XCTAssertTrue(state.isAnswered)
        XCTAssertEqual(state.isCorrect, true)
        XCTAssertEqual(state.options[0].outcome, .correct)
        XCTAssertEqual(state.options[0].rationale, activities[0].options[0].rationaleVi)
        XCTAssertTrue(state.options.dropFirst().allSatisfy { $0.outcome == .none })
        XCTAssertEqual(state.explanation, activities[0].explanationVi)
        XCTAssertEqual(store.progress(slug: lesson.slug, ownerKey: "")?.answers, [LessonAnswer(activityId: "act-j5-w01-u1-01", optionKey: "A")])
    }

    func test_aWrongChoiceShowsWhyAndWhichAnswerWasRight() throws {
        let presenter = makePresenter()
        presenter.selectOption(at: 2)   // C
        let state = try question(presenter)
        XCTAssertEqual(state.isCorrect, false)
        XCTAssertEqual(state.options[2].outcome, .incorrect)
        XCTAssertEqual(state.options[2].rationale, activities[0].options[2].rationaleVi)
        XCTAssertEqual(state.options[0].outcome, .correctAnswer)
        XCTAssertEqual(state.options[0].rationale, activities[0].options[0].rationaleVi)
        XCTAssertEqual(state.options[1].outcome, .none)
        XCTAssertNil(state.options[1].rationale)
    }

    func test_theChoiceCannotBeChangedAfterAnswering() throws {
        let presenter = makePresenter()
        presenter.selectOption(at: 2)
        presenter.selectOption(at: 0)
        XCTAssertEqual(try question(presenter).options[2].outcome, .incorrect)
        XCTAssertEqual(store.progress(slug: lesson.slug, ownerKey: "")?.answers.count, 1)
        presenter.selectOption(at: 9)
        presenter.selectOption(at: -1)
        XCTAssertEqual(store.progress(slug: lesson.slug, ownerKey: "")?.answers.count, 1, "Out-of-range positions choose nothing")
    }

    func test_nextWaitsForAnAnswer() throws {
        let presenter = makePresenter()
        presenter.next()
        XCTAssertEqual(try question(presenter).index, 0)
        presenter.selectOption(at: 0)
        presenter.next()
        XCTAssertEqual(try question(presenter).index, 1)
    }

    func test_finishingEveryQuestionCompletesTheLessonOnThisDeviceForAGuestWithoutTouchingTheServer() throws {
        let presenter = makePresenter()
        for position in 0..<5 {
            XCTAssertEqual(try question(presenter).index, position)
            XCTAssertEqual(try question(presenter).isLast, position == 4)
            if position == 3 { try chooseWrongOption(presenter); presenter.next() } else { try answerCorrectly(presenter) }
        }
        let done = try summary(presenter)
        XCTAssertEqual(done.total, 5)
        XCTAssertEqual(done.correct, 4)
        XCTAssertEqual(done.server, .notApplicable)
        XCTAssertEqual(store.progress(slug: lesson.slug, ownerKey: "")?.completedAt, day)
        XCTAssertEqual(store.completedSlugs(ownerKey: ""), [lesson.slug])
        XCTAssertEqual(api.requested, [], "A guest's progress is never sent")
    }

    func test_aSignedInLearnerIsSavedToTheAccountOnceAfterCompleting() throws {
        owner = account
        let presenter = makePresenter()
        for _ in 0..<5 { try answerCorrectly(presenter) }
        XCTAssertEqual(try summary(presenter).server, .sending)
        XCTAssertEqual(api.requested, [lesson.slug])
        api.succeed()
        XCTAssertEqual(try summary(presenter).server, .confirmed)
        let progress = try XCTUnwrap(store.progress(slug: lesson.slug, ownerKey: account))
        XCTAssertTrue(progress.isCompletedLocally)
        XCTAssertEqual(progress.serverConfirmedAt, day)
        XCTAssertEqual(api.requested.count, 1)
    }

    func test_aFailedSaveKeepsLocalCompletionIsNeverRetriedAutomaticallyAndCanBeRetriedByTheLearner() throws {
        owner = account
        let presenter = makePresenter()
        for _ in 0..<5 { try answerCorrectly(presenter) }
        api.fail(LearnerAPIError.offline)
        XCTAssertEqual(try summary(presenter).server, .failed(LearnerAPIError.offline.errorDescription ?? ""))
        XCTAssertEqual(api.requested.count, 1, "No automatic retry")
        let progress = try XCTUnwrap(store.progress(slug: lesson.slug, ownerKey: account))
        XCTAssertTrue(progress.isCompletedLocally)
        XCTAssertFalse(progress.isServerConfirmed)
        presenter.retrySync()
        XCTAssertEqual(try summary(presenter).server, .sending)
        XCTAssertEqual(api.requested.count, 2)
        api.succeed()
        XCTAssertEqual(try summary(presenter).server, .confirmed)
        presenter.retrySync()
        XCTAssertEqual(api.requested.count, 2, "A confirmed lesson is not sent again")
    }

    func test_aConnectionThatBrokeMidRequestIsReportedAsUnknownNotAsSaved() throws {
        owner = account
        let presenter = makePresenter()
        for _ in 0..<5 { try answerCorrectly(presenter) }
        api.fail(LearnerAPIError.interrupted)
        XCTAssertEqual(try summary(presenter).server, .unknown(LearnerAPIError.interrupted.errorDescription ?? ""))
        XCTAssertFalse(try XCTUnwrap(store.progress(slug: lesson.slug, ownerKey: account)).isServerConfirmed)
    }

    func test_anAnswerThatArrivesAfterTheAccountChangedIsDiscarded() throws {
        owner = account
        let presenter = makePresenter()
        for _ in 0..<5 { try answerCorrectly(presenter) }
        owner = otherAccount   // signed out and into another account while the request ran
        api.succeed()
        XCTAssertFalse(try XCTUnwrap(store.progress(slug: lesson.slug, ownerKey: account)).isServerConfirmed)
        XCTAssertNil(store.progress(slug: lesson.slug, ownerKey: otherAccount))
        XCTAssertEqual(try summary(presenter).server, .notSent, "Nothing is claimed for an account the request was not made for")
    }

    func test_leavingBeforeTheAnswerArrivesCancelsTheRequest() throws {
        owner = account
        let presenter = makePresenter()
        for _ in 0..<5 { try answerCorrectly(presenter) }
        presenter.cancelLoading()
        XCTAssertEqual(api.cancelledCount, 1)
        api.succeed()
        XCTAssertFalse(try XCTUnwrap(store.progress(slug: lesson.slug, ownerKey: account)).isServerConfirmed, "A late answer is ignored")
    }

    func test_comingBackResumesAtTheFirstUnansweredQuestion() throws {
        let presenter = makePresenter()
        try answerCorrectly(presenter)
        try chooseWrongOption(presenter)   // answered but left before tapping Next
        let resumed = makePresenter()
        let state = try question(resumed)
        XCTAssertEqual(state.index, 2, "Questions 1 and 2 are answered")
        for _ in 0..<3 { try answerCorrectly(resumed) }
        let done = try summary(resumed)
        XCTAssertEqual(done.total, 5)
        XCTAssertEqual(done.correct, 4, "The earlier answers count: one right, one wrong, then three right")
    }

    func test_aCompletedLessonReopensOnItsSummaryAndDoesNotResendOnItsOwn() throws {
        owner = account
        let presenter = makePresenter()
        for _ in 0..<5 { try answerCorrectly(presenter) }
        api.fail(LearnerAPIError.offline)
        api.reset()
        let reopened = makePresenter()
        XCTAssertEqual(try summary(reopened).server, .notSent)
        XCTAssertEqual(api.requested, [], "Opening a lesson never sends a write")
        reopened.retrySync()
        XCTAssertEqual(api.requested.count, 1)
    }

    func test_anAnswerThatCannotBeSavedIsNotShownAsAnswered() throws {
        let presenter = makePresenter(store: FailingProgressStore())
        presenter.selectOption(at: 0)
        XCTAssertFalse(try question(presenter).isAnswered)
        XCTAssertNotNil(presenter.errorMessage)
    }

    func test_translationFollowsTheAppLanguage() throws {
        language = .japanese
        let presenter = makePresenter()
        presenter.selectOption(at: 0)
        XCTAssertNil(try question(presenter).promptTranslation, "Japanese readers get the Japanese prompt only")
        XCTAssertEqual(try question(presenter).explanation, activities[0].explanationJa)
    }
}

private struct WrongScreen: Error {}

final class ProgressAPIStub: BJTLessonProgressAPIInterface {
    private(set) var requested: [String] = []
    private(set) var cancelledCount = 0
    private var requests: [PublishSubject<Void>] = []

    func markLessonCompleted(slug: String) -> Single<Void> {
        requested.append(slug)
        let subject = PublishSubject<Void>()
        requests.append(subject)
        return subject.take(1).asSingle().do(onDispose: { [weak self] in self?.cancelledCount += 1 })
    }

    func succeed() { requests.last?.onNext(()) }
    func fail(_ error: Error) { requests.last?.onError(error) }
    func reset() { requested = []; requests = [] }
}

final class FailingProgressStore: LessonProgressStoreInterface {
    func progress(slug: String, ownerKey: String) -> LessonProgress? { nil }
    func allProgress(ownerKey: String) -> [LessonProgress] { [] }
    func completedSlugs(ownerKey: String) -> Set<String> { [] }
    func recordAnswer(_ answer: LessonAnswer, for lesson: LessonProgressSubject, ownerKey: String, at date: Date) throws -> LessonProgress { throw LessonProgressError.notFound }
    func markCompleted(for lesson: LessonProgressSubject, ownerKey: String, at date: Date) throws -> LessonProgress { throw LessonProgressError.notFound }
    func markServerConfirmed(slug: String, ownerKey: String, at date: Date) throws {}
}
