import RxSwift
import XCTest
@testable import FlashcardApp

final class LessonListPresenterTests: XCTestCase {
    private var interactor: LessonListInteractorStub!
    private var language: AppLanguage = .vietnamese

    override func setUp() {
        super.setUp()
        interactor = LessonListInteractorStub()
        language = .vietnamese
    }

    private func makePresenter(level: String = "J5") -> LessonListPresenter {
        LessonListPresenter(levelCode: level, interactor: interactor, language: { [unowned self] in language })
    }

    private func lesson(_ slug: String, week: Int, sort: Int, unit: String = "lesson", minutes: Int = 25, activities: Int = 5,
                        titleVi: String = "Tiêu đề", titleJa: String = "題名", descVi: String = "Mô tả", descJa: String = "説明") -> BJTLessonSummaryDTO {
        BJTLessonSummaryDTO(id: "id-\(slug)", slug: slug, titleVi: titleVi, titleJa: titleJa, descriptionVi: descVi, descriptionJa: descJa,
                            weekNumber: week, sortOrder: sort, unitOrder: sort, unitType: unit, estimatedDurationMin: minutes,
                            vocabCount: 6, grammarCount: 2, kanjiCount: 0, activityCount: activities, isCompleted: false)
    }

    func test_loadsTheRequestedLevelOnceAndGroupsRowsByWeek() {
        let presenter = makePresenter(level: "J4")
        presenter.viewDidLoad()
        XCTAssertEqual(presenter.state, .loading)
        XCTAssertEqual(interactor.requestedLevels, ["J4"])
        interactor.respond(with: [lesson("a2", week: 2, sort: 8), lesson("a1", week: 1, sort: 1), lesson("a3", week: 1, sort: 2)])
        XCTAssertEqual(presenter.state, .loaded)
        XCTAssertEqual(presenter.sections.map(\.weekNumber), [1, 2])
        XCTAssertEqual(presenter.sections[0].rows.map(\.slug), ["a1", "a3"], "Rows keep the server's sortOrder inside a week")
        XCTAssertEqual(presenter.sections[1].rows.map(\.slug), ["a2"])
        presenter.viewDidLoad()
        XCTAssertEqual(interactor.requestedLevels.count, 1, "Appearing again does not reload a loaded list")
    }

    func test_rowCarriesServerFactsAndOnlyAvailableCounts() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        interactor.respond(with: [lesson("a1", week: 1, sort: 1, unit: "checkpoint", minutes: 0, activities: 0)])
        let row = presenter.sections[0].rows[0]
        XCTAssertEqual(row.id, "id-a1")
        XCTAssertEqual(row.unitType, "checkpoint")
        XCTAssertNil(row.minutes, "A zero duration is not shown as '0 min'")
        XCTAssertNil(row.activityCount, "No activities is not shown as a count")
        interactor.reset()
        let again = makePresenter()
        again.viewDidLoad()
        interactor.respond(with: [lesson("b1", week: 1, sort: 1, minutes: 25, activities: 5)])
        XCTAssertEqual(again.sections[0].rows[0].minutes, 25)
        XCTAssertEqual(again.sections[0].rows[0].activityCount, 5)
    }

    func test_textFollowsTheAppLanguageAndFallsBackWhenATranslationIsEmpty() {
        language = .japanese
        let presenter = makePresenter()
        presenter.viewDidLoad()
        interactor.respond(with: [lesson("a1", week: 1, sort: 1, titleJa: "職場", descJa: ""),
                                  lesson("a2", week: 1, sort: 2, titleJa: "  ", descJa: "説明2")])
        let rows = presenter.sections[0].rows
        XCTAssertEqual(rows[0].title, "職場")
        XCTAssertEqual(rows[0].summary, "Mô tả", "An empty Japanese description falls back to Vietnamese, never to blank")
        XCTAssertEqual(rows[1].title, "Tiêu đề")
        XCTAssertEqual(rows[1].summary, "説明2")
        language = .english
        let english = makePresenter()
        english.viewDidLoad()
        interactor.respond(with: [lesson("a1", week: 1, sort: 1)])
        XCTAssertEqual(english.sections[0].rows[0].title, "Tiêu đề", "The API has no English text: Vietnamese is shown")
    }

    func test_emptyListIsAnEmptyStateNotASilentBlank() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        interactor.respond(with: [])
        XCTAssertEqual(presenter.state, .empty)
        XCTAssertTrue(presenter.sections.isEmpty)
    }

    func test_failureShowsAMessageAndRetryLoadsAgain() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        interactor.fail(LearnerAPIError.offline)
        guard case .failed(let message) = presenter.state else { return XCTFail("expected failed, got \(presenter.state)") }
        XCTAssertEqual(message, LearnerAPIError.offline.errorDescription)
        presenter.viewDidLoad()
        XCTAssertEqual(interactor.requestedLevels.count, 1, "A failed list is only reloaded by an explicit retry")
        presenter.retry()
        XCTAssertEqual(presenter.state, .loading)
        XCTAssertEqual(interactor.requestedLevels.count, 2)
        interactor.respond(with: [lesson("a1", week: 1, sort: 1)])
        XCTAssertEqual(presenter.state, .loaded)
        XCTAssertEqual(presenter.sections.count, 1)
    }

    func test_leavingCancelsTheRequestAndComingBackLoadsAgain() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.cancelLoading()
        XCTAssertEqual(interactor.cancelledCount, 1, "Disposing the subscription cancels the owned network request")
        XCTAssertEqual(presenter.state, .idle)
        interactor.respondToFirst(with: [lesson("late", week: 1, sort: 1)])
        XCTAssertTrue(presenter.sections.isEmpty, "A response that arrives after cancel is ignored")
        presenter.viewDidLoad()
        XCTAssertEqual(interactor.requestedLevels.count, 2)
        XCTAssertEqual(presenter.state, .loading)
    }

    func test_selectingARowOpensThatLessonWithItsTitle() {
        let presenter = makePresenter()
        let spy = LessonListWireframeSpy()
        presenter.wireframe = spy
        presenter.viewDidLoad()
        interactor.respond(with: [lesson("a1", week: 1, sort: 1, titleVi: "Một"), lesson("a2", week: 2, sort: 8, titleVi: "Hai")])
        presenter.selectRow(section: 1, row: 0)
        XCTAssertEqual(spy.opened.map(\.slug), ["a2"])
        XCTAssertEqual(spy.opened.map(\.title), ["Hai"])
        presenter.selectRow(section: 5, row: 0)
        presenter.selectRow(section: 0, row: 9)
        presenter.selectRow(section: -1, row: 0)
        XCTAssertEqual(spy.opened.count, 1, "A position outside the list opens nothing")
    }

    func test_retryWhileLoadingDoesNotStartASecondRequest() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.retry()
        XCTAssertEqual(interactor.requestedLevels.count, 1)
    }

    func test_onChangeFiresForEachStateChange() {
        let presenter = makePresenter()
        var changes = 0
        presenter.onChange = { changes += 1 }
        presenter.viewDidLoad()
        interactor.respond(with: [lesson("a1", week: 1, sort: 1)])
        XCTAssertEqual(changes, 2, "loading, then loaded")
    }
}

final class LessonListInteractorStub: LessonListInteractorInterface {
    private(set) var requestedLevels: [String] = []
    private(set) var cancelledCount = 0
    private var requests: [PublishSubject<[BJTLessonSummaryDTO]>] = []

    func lessons(levelCode: String) -> Single<[BJTLessonSummaryDTO]> {
        requestedLevels.append(levelCode)
        let subject = PublishSubject<[BJTLessonSummaryDTO]>()
        requests.append(subject)
        return subject.take(1).asSingle().do(onDispose: { [weak self] in self?.cancelledCount += 1 })
    }

    func respond(with rows: [BJTLessonSummaryDTO]) { requests.last?.onNext(rows) }
    func respondToFirst(with rows: [BJTLessonSummaryDTO]) { requests.first?.onNext(rows) }
    func fail(_ error: Error) { requests.last?.onError(error) }
    func reset() { requestedLevels = []; requests = [] }
}

final class LessonListWireframeSpy: LessonListWireframeInterface {
    private(set) var opened: [(slug: String, title: String)] = []
    func showLesson(slug: String, title: String) { opened.append((slug, title)) }
}
