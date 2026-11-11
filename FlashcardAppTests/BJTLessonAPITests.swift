import Alamofire
import RxSwift
import XCTest
@testable import FlashcardApp

/// Decoding of the production lesson payloads (`BJTLessonFixtures`) and the request/failure semantics of the lesson API.
final class BJTLessonAPITests: XCTestCase {
    private var session: Session!
    private var bag: DisposeBag!
    private var token: String? = "opaque-session-token"
    private let slug = "j5-01-greetings-intro"

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LearnerURLProtocol.self]
        session = Session(configuration: config)
        bag = DisposeBag()
        token = "opaque-session-token"
        LearnerURLProtocol.handler = nil
        LearnerURLProtocol.onStop = nil
        LearnerURLProtocol.requests = []
    }

    override func tearDown() {
        bag = nil
        session.session.invalidateAndCancel()
        LearnerURLProtocol.handler = nil
        LearnerURLProtocol.onStop = nil
        super.tearDown()
    }

    private var lessonAPI: BJTLessonAPI { BJTLessonAPI(session: session, baseURL: { "https://api.test/api" }) }
    private var learnerAPI: BJTLearnerAPI {
        BJTLearnerAPI(session: session, baseURL: { "https://api.test/api" }, token: { [unowned self] in token })
    }

    private func result<T>(_ single: Single<T>, timeout: TimeInterval = 3) -> Result<T, Error> {
        var outcome: Result<T, Error>?
        let done = expectation(description: "request")
        single.subscribe(onSuccess: { outcome = .success($0); done.fulfill() },
                         onFailure: { outcome = .failure($0); done.fulfill() }).disposed(by: bag)
        wait(for: [done], timeout: timeout)
        return outcome ?? .failure(LearnerAPIError.invalidResponse)
    }

    private func failure<T>(_ single: Single<T>) -> LearnerAPIError? {
        if case .failure(let error) = result(single) { return error as? LearnerAPIError }
        return nil
    }

    /// The detail fixture with `edit` applied to its JSON object.
    private func detailJSON(_ edit: (inout [String: Any]) -> Void) throws -> String {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(BJTLessonFixtures.j5Lesson01JSON.utf8)) as? [String: Any])
        edit(&object)
        return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    private func editContent(_ object: inout [String: Any], _ edit: (inout [String: Any]) -> Void) {
        var content = object["lessonContent"] as? [String: Any] ?? [:]
        edit(&content)
        object["lessonContent"] = content
    }

    private func editFirstActivity(_ object: inout [String: Any], _ edit: (inout [String: Any]) -> Void) {
        editContent(&object) { content in
            var activities = content["activities"] as? [[String: Any]] ?? []
            edit(&activities[0])
            content["activities"] = activities
        }
    }

    // MARK: List

    func test_listIsAnAnonymousGetAndKeepsTheServersOrderAndIds() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: BJTLessonFixtures.j5ListJSON) }
        let rows = try result(lessonAPI.lessons(levelCode: "J5")).get()
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.method, "GET")
        XCTAssertEqual(sent.url.path, "/api/levels/J5/lessons")
        XCTAssertNil(sent.headers["Authorization"], "The public read never carries a session")
        XCTAssertNil(sent.headers["Origin"])
        XCTAssertEqual(rows.count, 3)
        let first = try XCTUnwrap(rows.first)
        XCTAssertEqual(first.id, "bdf97bd4-6318-409c-991b-b076526d6c28")
        XCTAssertEqual(first.slug, slug)
        XCTAssertEqual(first.unitType, "lesson")
        XCTAssertEqual(first.weekNumber, 1)
        XCTAssertEqual(first.activityCount, 5)
        XCTAssertEqual(first.estimatedDurationMin, 25)
        XCTAssertEqual(first.titleVi, "Chào hỏi tại nơi làm việc: Chào buổi sáng")
        XCTAssertEqual(first.titleJa, "職場の挨拶：おはようございます。")
        XCTAssertFalse(first.isCompleted)
        XCTAssertEqual(rows.map(\.unitType), ["lesson", "review", "checkpoint"])
    }

    func test_listRejectsAnUnsupportedLevelBeforeAnyRequest() {
        for code in ["J1+", "j5", "", "J5/../x", "J5?x=1", "N5", "J5\n"] {
            XCTAssertEqual(failure(lessonAPI.lessons(levelCode: code)), .invalidRequest(nil), code)
        }
        XCTAssertTrue(LearnerURLProtocol.requests.isEmpty)
    }

    func test_listFailsWhenARequiredFieldIsMissing() {
        let broken = BJTLessonFixtures.j5ListJSON.replacingOccurrences(of: "\"weekNumber\"", with: "\"week\"")
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: broken) }
        XCTAssertEqual(failure(lessonAPI.lessons(levelCode: "J5")), .invalidResponse)
    }

    // MARK: Detail

    func test_detailDecodesTheProductionLessonContent() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: BJTLessonFixtures.j5Lesson01JSON) }
        let lesson = try result(lessonAPI.lesson(slug: slug)).get()
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.url.path, "/api/levels/lessons/\(slug)")
        XCTAssertNil(sent.headers["Authorization"])
        XCTAssertEqual(lesson.slug, slug)
        XCTAssertEqual(lesson.levelCode, "J5")
        XCTAssertEqual(lesson.titleVi, "Chào hỏi tại nơi làm việc: Chào buổi sáng")
        XCTAssertFalse(lesson.canSaveProgress)
        XCTAssertNil(lesson.prevLesson)
        XCTAssertEqual(lesson.nextLesson?.slug, "j5-02-office-daily")

        let content = lesson.lessonContent
        XCTAssertEqual(content.vocabulary.count, 6)
        XCTAssertEqual(content.grammar.count, 2)
        XCTAssertFalse(content.examples.isEmpty)
        XCTAssertFalse(content.summaryVi.isEmpty)
        XCTAssertFalse(content.vietnameseLearnerPitfalls.isEmpty)
        XCTAssertNotNil(content.workplaceScenario?.contextJa)
        XCTAssertNotNil(content.workplaceScenario?.contextVi)
        XCTAssertTrue(content.vocabulary.allSatisfy { !$0.japanese.isEmpty && !$0.meaningVi.isEmpty })

        XCTAssertEqual(content.activities.count, 5, "The count comes from the payload, not from an assumption")
        let activity = try XCTUnwrap(content.activities.first)
        XCTAssertEqual(activity.id, "act-j5-w01-u1-01")
        XCTAssertEqual(activity.questionType, "best_expression")
        XCTAssertEqual(activity.answer, "A")
        XCTAssertEqual(activity.options.map(\.key), ["A", "B", "C", "D"])
        XCTAssertEqual(activity.options.filter(\.isCorrect).map(\.key), ["A"])
        XCTAssertTrue(activity.options.allSatisfy { ($0.rationaleVi ?? "").isEmpty == false })
        XCTAssertNil(activity.audioUrl)
        XCTAssertTrue(content.activities.allSatisfy { $0.options.count == 4 })
    }

    func test_detailToleratesUnknownKeysAndAbsentOptionalSections() throws {
        let json = try detailJSON { object in
            object["somethingNew"] = ["x": 1]
            object["skillTags"] = nil
            object["prevLesson"] = NSNull()
            editContent(&object) { content in
                content["futureSection"] = "x"
                content["vocabulary"] = nil
                content["workplaceScenario"] = nil
                content["vietnameseLearnerPitfalls"] = nil
            }
            editFirstActivity(&object) { $0["newActivityField"] = true }
        }
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: json) }
        let lesson = try result(lessonAPI.lesson(slug: slug)).get()
        XCTAssertEqual(lesson.skillTags, [])
        XCTAssertNil(lesson.prevLesson)
        XCTAssertEqual(lesson.lessonContent.vocabulary, [])
        XCTAssertNil(lesson.lessonContent.workplaceScenario)
        XCTAssertEqual(lesson.lessonContent.vietnameseLearnerPitfalls, [])
        XCTAssertEqual(lesson.lessonContent.activities.count, 5)
    }

    func test_detailWithoutLessonContentIsAnErrorNotAnEmptyLesson() throws {
        let json = try detailJSON { $0["lessonContent"] = nil }
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: json) }
        XCTAssertEqual(failure(lessonAPI.lesson(slug: slug)), .invalidResponse)

        let nullContent = try detailJSON { $0["lessonContent"] = NSNull() }
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: nullContent) }
        XCTAssertEqual(failure(lessonAPI.lesson(slug: slug)), .invalidResponse)
    }

    func test_detailWithoutActivitiesIsAnErrorNotALessonWithNothingToPractise() throws {
        let missing = try detailJSON { object in editContent(&object) { $0["activities"] = nil } }
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: missing) }
        XCTAssertEqual(failure(lessonAPI.lesson(slug: slug)), .invalidResponse)

        let null = try detailJSON { object in editContent(&object) { $0["activities"] = NSNull() } }
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: null) }
        XCTAssertEqual(failure(lessonAPI.lesson(slug: slug)), .invalidResponse)
    }

    func test_detailRejectsAnActivityWhoseAnswerCannotBeTrusted() throws {
        let corruptions: [(String, (inout [String: Any]) -> Void)] = [
            ("answer names no option", { $0["answer"] = "Z" }),
            ("answer disagrees with isCorrect", { $0["answer"] = "B" }),
            ("no option is correct", { activity in
                activity["options"] = (activity["options"] as? [[String: Any]] ?? []).map { var o = $0; o["isCorrect"] = false; return o }
            }),
            ("two options are correct", { activity in
                activity["options"] = (activity["options"] as? [[String: Any]] ?? []).map { var o = $0; o["isCorrect"] = true; return o }
            }),
            ("duplicate option keys", { activity in
                activity["options"] = (activity["options"] as? [[String: Any]] ?? []).map { var o = $0; o["key"] = "A"; return o }
            }),
            ("a single option", { activity in activity["options"] = Array((activity["options"] as? [[String: Any]] ?? []).prefix(1)) }),
            ("options missing", { $0["options"] = nil }),
            ("answer missing", { $0["answer"] = nil })
        ]
        for (name, corrupt) in corruptions {
            let json = try detailJSON { object in editFirstActivity(&object, corrupt) }
            LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: json) }
            XCTAssertEqual(failure(lessonAPI.lesson(slug: slug)), .invalidResponse, name)
        }
    }

    func test_detailRejectsAnInvalidSlugBeforeAnyRequest() {
        let invalid = ["", "..", "../levels", "a/b", "a%2Fb", "A-upper", "-lead", "has space", "tab\t", "new\nline", "ｊ5", "a?b=1", "a#b",
                       String(repeating: "a", count: 129)]
        for value in invalid {
            XCTAssertEqual(failure(lessonAPI.lesson(slug: value)), .invalidRequest(nil), value)
        }
        XCTAssertTrue(LearnerURLProtocol.requests.isEmpty)
        XCTAssertTrue(BJTLessonAPI.isValid(slug: "j5-w01-review"))
        XCTAssertTrue(BJTLessonAPI.isValid(slug: slug))
    }

    // MARK: Failures

    func test_statusesAreMappedToDistinctErrors() {
        let expected: [(Int, LearnerAPIError)] = [(404, .notFound), (429, .rateLimited), (500, .server(500)), (502, .server(502)),
                                                  (401, .signInRequired), (400, .invalidRequest(nil))]
        for (status, error) in expected {
            LearnerURLProtocol.handler = { _, proto in proto.respond(status: status, json: #"{"error":"lesson not found"}"#) }
            XCTAssertEqual(failure(lessonAPI.lesson(slug: slug)), error, "status \(status)")
        }
    }

    func test_malformedJSONAndOfflineAreReported() {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: "{not json") }
        XCTAssertEqual(failure(lessonAPI.lessons(levelCode: "J5")), .invalidResponse)
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: "{}") }
        XCTAssertEqual(failure(lessonAPI.lessons(levelCode: "J5")), .invalidResponse, "An object instead of a list")
        LearnerURLProtocol.handler = { _, proto in proto.fail(URLError(.notConnectedToInternet)) }
        XCTAssertEqual(failure(lessonAPI.lesson(slug: slug)), .offline)
        LearnerURLProtocol.handler = { _, proto in proto.fail(URLError(.networkConnectionLost)) }
        XCTAssertEqual(failure(lessonAPI.lesson(slug: slug)), .interrupted)
    }

    func test_disposingTheSubscriptionCancelsTheRequest() {
        let stopped = expectation(description: "request cancelled")
        LearnerURLProtocol.onStop = { stopped.fulfill() }
        LearnerURLProtocol.handler = { _, _ in }   // never answers
        let started = expectation(description: "request started")
        LearnerURLProtocol.handler = { _, _ in started.fulfill() }
        let subscription = lessonAPI.lesson(slug: slug).subscribe(onSuccess: { _ in XCTFail("no result expected") },
                                                                  onFailure: { _ in XCTFail("no result expected") })
        wait(for: [started], timeout: 3)
        subscription.dispose()
        wait(for: [stopped], timeout: 3)
    }

    // MARK: Progress

    func test_markCompletedSendsAnAuthenticatedPutWithTheApisOwnOrigin() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: #"{"isCompleted":true}"#) }
        XCTAssertNoThrow(try result(learnerAPI.markLessonCompleted(slug: slug)).get())
        XCTAssertEqual(LearnerURLProtocol.requests.count, 1)
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.method, "PUT")
        XCTAssertEqual(sent.url.path, "/api/levels/lessons/\(slug)/progress")
        XCTAssertEqual(sent.headers["Authorization"], "Bearer opaque-session-token")
        XCTAssertEqual(sent.headers["Origin"], "https://api.test")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: sent.body) as? [String: Any])
        XCTAssertEqual(body as NSDictionary, ["completed": true], "The server rejects any other field")
    }

    func test_markCompletedWithoutASessionNeverReachesTheNetwork() {
        token = nil
        XCTAssertEqual(failure(learnerAPI.markLessonCompleted(slug: slug)), .signInRequired)
        XCTAssertTrue(LearnerURLProtocol.requests.isEmpty)
    }

    func test_markCompletedRejectsAnInvalidSlugAndAnUnconfirmedAnswer() {
        XCTAssertEqual(failure(learnerAPI.markLessonCompleted(slug: "../x")), .invalidRequest(nil))
        XCTAssertTrue(LearnerURLProtocol.requests.isEmpty)
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: #"{"isCompleted":false}"#) }
        XCTAssertEqual(failure(learnerAPI.markLessonCompleted(slug: slug)), .invalidResponse)
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: "{}") }
        XCTAssertEqual(failure(learnerAPI.markLessonCompleted(slug: slug)), .invalidResponse)
    }

    func test_markCompletedMapsFailuresAndNeverRetries() {
        let expected: [(Int, String, LearnerAPIError)] = [
            (401, #"{"error":"unauthorized"}"#, .signInRequired),
            (403, #"{"error":"forbidden: untrusted origin"}"#, .originRejected),
            (404, #"{"error":"lesson not found"}"#, .notFound),
            (429, "{}", .rateLimited),
            (500, #"{"error":"unable to save lesson progress"}"#, .server(500))
        ]
        for (status, body, error) in expected {
            LearnerURLProtocol.requests = []
            LearnerURLProtocol.handler = { _, proto in proto.respond(status: status, json: body) }
            XCTAssertEqual(failure(learnerAPI.markLessonCompleted(slug: slug)), error, "status \(status)")
            XCTAssertEqual(LearnerURLProtocol.requests.count, 1, "status \(status) is never retried")
        }
        LearnerURLProtocol.requests = []
        LearnerURLProtocol.handler = { _, proto in proto.fail(URLError(.networkConnectionLost)) }
        XCTAssertEqual(failure(learnerAPI.markLessonCompleted(slug: slug)), .interrupted)
        XCTAssertEqual(LearnerURLProtocol.requests.count, 1)
    }

    func test_markCompletedDropsAnAnswerThatArrivesAfterLogout() {
        LearnerURLProtocol.handler = { [unowned self] _, proto in
            self.token = nil   // signed out while the request is in flight
            proto.respond(status: 200, json: #"{"isCompleted":true}"#)
        }
        XCTAssertEqual(failure(learnerAPI.markLessonCompleted(slug: slug)), .staleSession)
    }
}
