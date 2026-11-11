import RxSwift
import XCTest
@testable import FlashcardApp

final class LessonReaderPresenterTests: XCTestCase {
    private let slug = "j5-01-greetings-intro"
    private var interactor: ReaderInteractorStub!
    private var language: AppLanguage = .vietnamese

    override func setUp() {
        super.setUp()
        interactor = ReaderInteractorStub()
        language = .vietnamese
    }

    private func makePresenter() -> LessonReaderPresenter {
        LessonReaderPresenter(slug: slug, title: "Tiêu đề danh sách", interactor: interactor, language: { [unowned self] in language })
    }

    private func lesson(_ edit: (inout [String: Any]) -> Void = { _ in }) throws -> BJTLessonDetailDTO {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(BJTLessonFixtures.j5Lesson01JSON.utf8)) as? [String: Any])
        edit(&object)
        return try JSONDecoder().decode(BJTLessonDetailDTO.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func editContent(_ object: inout [String: Any], _ edit: (inout [String: Any]) -> Void) {
        var content = object["lessonContent"] as? [String: Any] ?? [:]
        edit(&content)
        object["lessonContent"] = content
    }

    func test_loadsTheLessonOnceAndShowsEverySectionInReadingOrder() throws {
        let presenter = makePresenter()
        XCTAssertEqual(presenter.title, "Tiêu đề danh sách", "The list's title is shown while the lesson loads")
        presenter.viewDidLoad()
        XCTAssertEqual(presenter.state, .loading)
        XCTAssertEqual(interactor.requested, [slug])
        interactor.respond(LessonReadResult(lesson: try lesson(), isFromCache: false))
        XCTAssertEqual(presenter.state, .loaded)
        XCTAssertEqual(presenter.sections.map(\.kind), [.context, .vocabulary, .grammar, .examples, .remember, .pitfalls])
        XCTAssertEqual(presenter.title, "Chào hỏi tại nơi làm việc: Chào buổi sáng")
        XCTAssertEqual(presenter.minutes, 25)
        XCTAssertFalse(presenter.isFromCache)
        presenter.viewDidLoad()
        XCTAssertEqual(interactor.requested.count, 1)
    }

    func test_vocabularyGrammarAndExamplesAreTheServersTextUnchanged() throws {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        interactor.respond(LessonReadResult(lesson: try lesson(), isFromCache: false))
        let vocabulary = try XCTUnwrap(presenter.sections.first { $0.kind == .vocabulary })
        XCTAssertEqual(vocabulary.entries.count, 6)
        XCTAssertEqual(vocabulary.entries[0], ReaderEntry(headline: "初めまして", reading: "はじめまして", body: "rất hân hạnh"))
        let grammar = try XCTUnwrap(presenter.sections.first { $0.kind == .grammar })
        XCTAssertEqual(grammar.entries[0], ReaderEntry(headline: "～です", body: "Giới thiệu danh tính hoặc thông tin một cách lịch sự."))
        let examples = try XCTUnwrap(presenter.sections.first { $0.kind == .examples })
        XCTAssertEqual(examples.entries[0].headline, "新入社員：おはようございます。")
        XCTAssertEqual(examples.entries[0].body, "新入社員: Chào buổi sáng.")
        XCTAssertEqual(examples.entries[0].note, "Dùng khi gặp đồng nghiệp vào buổi sáng; nói rõ và vừa đủ trang trọng.")
        let pitfalls = try XCTUnwrap(presenter.sections.first { $0.kind == .pitfalls })
        XCTAssertEqual(pitfalls.entries.count, 3)
    }

    func test_contextCarriesTheScenarioFactsTheServerSent() throws {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        interactor.respond(LessonReadResult(lesson: try lesson(), isFromCache: false))
        let context = try XCTUnwrap(presenter.sections.first { $0.kind == .context })
        XCTAssertEqual(context.entries.first?.headline, "ベトナム人の新入社員が初日に同じ部署の人へ挨拶します。 本時の焦点は「おはようございます。」です。")
        XCTAssertEqual(context.entries.first?.body, "Nhân viên mới người Việt chào mọi người trong phòng ban vào ngày đầu. Trọng tâm của đơn vị là “Chào buổi sáng”.")
        let bodies = context.entries.compactMap(\.body)
        XCTAssertTrue(bodies.contains("chào khi bắt đầu ngày làm việc"), "goalVi")
        XCTAssertTrue(bodies.contains("người học cần tạo thiện cảm nhưng chưa biết vai trò của từng người."), "problemVi")
        XCTAssertTrue(bodies.contains("đối phương hiểu tên, bộ phận và mong muốn hợp tác của người nói."), "desiredOutcomeVi")
        XCTAssertTrue(bodies.contains("Chào, tự giới thiệu và kết thúc trao đổi ngắn đúng thời điểm."), "learning objectives")
        XCTAssertFalse(bodies.contains("senior-junior"), "A machine key such as the relationship code is not learner text")
    }

    func test_sectionsWithoutContentAreHiddenAndABlankReadingIsNotShown() throws {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        let sparse = try lesson { object in
            editContent(&object) { content in
                content["grammar"] = []
                content["examples"] = nil
                content["vietnameseLearnerPitfalls"] = [" "]
                content["knowledgePoints"] = []
                content["nuanceNotesVi"] = []
                content["summaryVi"] = []
                content["businessUsageVi"] = ""
                content["politenessHierarchyVi"] = nil
                content["workplaceScenario"] = nil
                content["learningObjectives"] = []
                content["vocabulary"] = [["japanese": "挨拶", "reading": "", "meaningVi": "chào hỏi"]]
            }
        }
        interactor.respond(LessonReadResult(lesson: sparse, isFromCache: false))
        XCTAssertEqual(presenter.sections.map(\.kind), [.vocabulary])
        XCTAssertNil(presenter.sections[0].entries[0].reading)
    }

    func test_titleFollowsTheAppLanguageAndFallsBackToVietnamese() throws {
        language = .japanese
        let presenter = makePresenter()
        presenter.viewDidLoad()
        interactor.respond(LessonReadResult(lesson: try lesson(), isFromCache: false))
        XCTAssertEqual(presenter.title, "職場の挨拶：おはようございます。")
        language = .english
        let english = makePresenter()
        english.viewDidLoad()
        interactor.respond(LessonReadResult(lesson: try lesson { $0["titleJa"] = " " }, isFromCache: false))
        XCTAssertEqual(english.title, "Chào hỏi tại nơi làm việc: Chào buổi sáng")
    }

    func test_aSavedCopyIsFlaggedSoTheScreenCanSaySo() throws {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        interactor.respond(LessonReadResult(lesson: try lesson(), isFromCache: true))
        XCTAssertTrue(presenter.isFromCache)
        XCTAssertEqual(presenter.state, .loaded)
    }

    func test_practiceShowsTheServersActivityCountButStaysUnavailableUntilActivitiesExist() throws {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        interactor.respond(LessonReadResult(lesson: try lesson(), isFromCache: false))
        XCTAssertEqual(presenter.practiceActivityCount, 5, "From the payload, not an assumed number")
        XCTAssertFalse(presenter.isPracticeAvailable)
    }

    func test_failureShowsAMessageAndOnlyRetryLoadsAgain() throws {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        interactor.fail(LearnerAPIError.offline)
        XCTAssertEqual(presenter.state, .failed(LearnerAPIError.offline.errorDescription ?? ""))
        XCTAssertTrue(presenter.sections.isEmpty)
        presenter.viewDidLoad()
        XCTAssertEqual(interactor.requested.count, 1)
        presenter.retry()
        XCTAssertEqual(presenter.state, .loading)
        XCTAssertEqual(interactor.requested.count, 2)
        interactor.respond(LessonReadResult(lesson: try lesson(), isFromCache: false))
        XCTAssertEqual(presenter.state, .loaded)
    }

    func test_leavingCancelsTheRequestAndALateAnswerIsIgnored() throws {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.cancelLoading()
        XCTAssertEqual(interactor.cancelledCount, 1)
        XCTAssertEqual(presenter.state, .idle)
        interactor.respondToFirst(LessonReadResult(lesson: try lesson(), isFromCache: false))
        XCTAssertTrue(presenter.sections.isEmpty)
        presenter.viewDidLoad()
        XCTAssertEqual(interactor.requested.count, 2)
    }

    func test_retryWhileLoadingStartsNoSecondRequest() {
        let presenter = makePresenter()
        presenter.viewDidLoad()
        presenter.retry()
        XCTAssertEqual(interactor.requested.count, 1)
    }
}

final class ReaderInteractorStub: LessonReaderInteractorInterface {
    private(set) var requested: [String] = []
    private(set) var cancelledCount = 0
    private var requests: [PublishSubject<LessonReadResult>] = []

    func lesson(slug: String) -> Single<LessonReadResult> {
        requested.append(slug)
        let subject = PublishSubject<LessonReadResult>()
        requests.append(subject)
        return subject.take(1).asSingle().do(onDispose: { [weak self] in self?.cancelledCount += 1 })
    }

    func respond(_ result: LessonReadResult) { requests.last?.onNext(result) }
    func respondToFirst(_ result: LessonReadResult) { requests.first?.onNext(result) }
    func fail(_ error: Error) { requests.last?.onError(error) }
}
