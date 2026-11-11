import RxSwift
import XCTest
@testable import FlashcardApp

final class LessonReaderInteractorTests: XCTestCase {
    private let slug = "j5-01-greetings-intro"
    private var payload: Data { Data(BJTLessonFixtures.j5Lesson01JSON.utf8) }
    private var lesson: BJTLessonDetailDTO { try! JSONDecoder().decode(BJTLessonDetailDTO.self, from: payload) }
    private var api: LessonAPIStub!
    private var cache: LessonCacheStub!
    private var bag: DisposeBag!

    override func setUp() {
        super.setUp()
        api = LessonAPIStub()
        cache = LessonCacheStub()
        bag = DisposeBag()
    }

    private func read() -> Result<LessonReadResult, Error> {
        var outcome: Result<LessonReadResult, Error> = .failure(LearnerAPIError.invalidResponse)
        LessonReaderInteractor(api: api, cache: cache).lesson(slug: slug)
            .subscribe(onSuccess: { outcome = .success($0) }, onFailure: { outcome = .failure($0) }).disposed(by: bag)
        return outcome
    }

    func test_aLessonFromTheServerIsReturnedAndSavedForOffline() throws {
        api.result = .just(BJTLessonPayload(lesson: lesson, data: payload))
        let result = try read().get()
        XCTAssertEqual(result.lesson, lesson)
        XCTAssertFalse(result.isFromCache)
        XCTAssertEqual(cache.stored.map(\.slug), [slug])
        XCTAssertEqual(cache.stored.first?.payload, payload, "The server's own bytes are what is kept")
    }

    func test_whenTheServerCannotBeReachedTheSavedCopyIsShownAndMarkedAsSuch() throws {
        cache.saved = lesson
        for error in [LearnerAPIError.offline, .interrupted, .server(503), .rateLimited] {
            api.result = .error(error)
            let result = try read().get()
            XCTAssertEqual(result.lesson, lesson, "\(error)")
            XCTAssertTrue(result.isFromCache, "\(error)")
        }
    }

    func test_withoutASavedCopyTheErrorIsReported() {
        api.result = .error(LearnerAPIError.offline)
        guard case .failure(let error) = read() else { return XCTFail("expected a failure") }
        XCTAssertEqual(error as? LearnerAPIError, .offline)
    }

    func test_aSavedCopyDoesNotHideAMissingOrBrokenLesson() {
        cache.saved = lesson
        for error in [LearnerAPIError.notFound, .invalidResponse, .invalidRequest(nil)] {
            api.result = .error(error)
            guard case .failure(let thrown) = read() else { return XCTFail("\(error) must not fall back to the saved copy") }
            XCTAssertEqual(thrown as? LearnerAPIError, error)
        }
    }

    func test_aFailureToSaveDoesNotStopTheLessonFromBeingRead() throws {
        cache.storeError = LessonCacheError.invalidPayload
        api.result = .just(BJTLessonPayload(lesson: lesson, data: payload))
        XCTAssertEqual(try read().get().lesson, lesson)
    }
}

final class LessonAPIStub: BJTLessonAPIInterface {
    var result: Single<BJTLessonPayload> = .never()
    func lessons(levelCode: String) -> Single<[BJTLessonSummaryDTO]> { .just([]) }
    func lesson(slug: String) -> Single<BJTLessonDetailDTO> { result.map(\.lesson) }
    func lessonPayload(slug: String) -> Single<BJTLessonPayload> { result }
}

final class LessonCacheStub: LessonCacheInterface {
    var saved: BJTLessonDetailDTO?
    var storeError: Error?
    private(set) var stored: [(slug: String, payload: Data)] = []
    func lesson(slug: String) -> BJTLessonDetailDTO? { saved }
    func store(payload: Data, slug: String) throws {
        if let storeError { throw storeError }
        stored.append((slug, payload))
    }
}
