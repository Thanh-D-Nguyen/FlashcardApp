import Alamofire
import RxSwift
import XCTest
@testable import FlashcardApp

/// Request shape and decoding of the everyday-situation calls. The fixtures are payloads recorded from the Go handlers
/// (`handler_scenario.go`) of a local backend that carries the daily-life catalogue.
final class BJTScenarioAPITests: XCTestCase {
    private var session: Session!
    private var api: BJTLearnerAPI!
    private var bag: DisposeBag!
    private let scenarioID = "4d29f2b2-8004-43f7-8e87-28181eb7fcfd"
    private let stepID = "56a22402-e9ce-4451-9472-3cb0e4ed192a"

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LearnerURLProtocol.self]
        session = Session(configuration: config)
        api = BJTLearnerAPI(session: session, baseURL: { "https://api.test/api" }, token: { "opaque-session-token" })
        bag = DisposeBag()
        LearnerURLProtocol.handler = nil
        LearnerURLProtocol.onStop = nil
        LearnerURLProtocol.requests = []
    }

    override func tearDown() {
        bag = nil
        session.session.invalidateAndCancel()
        LearnerURLProtocol.handler = nil
        super.tearDown()
    }

    private func result<T>(_ single: Single<T>) -> Result<T, Error> {
        var outcome: Result<T, Error>?
        let done = expectation(description: "request")
        single.subscribe(onSuccess: { outcome = .success($0); done.fulfill() },
                         onFailure: { outcome = .failure($0); done.fulfill() }).disposed(by: bag)
        wait(for: [done], timeout: 3)
        return outcome ?? .failure(LearnerAPIError.invalidResponse)
    }

    func test_scenariosDecodesTheCatalogueAndSendsTheBearer() throws {
        LearnerURLProtocol.handler = { _, proto in
            proto.respond(status: 200, json: """
            [{"id":"\(self.scenarioID)","slug":"life101-haircut-length","titleVi":"Dặn thợ cắt tóc ngắn hơn một chút","titleJa":"髪を少し短く切る","descriptionVi":"Dặn thợ","difficulty":"beginner","category":"beauty","iconEmoji":"🗾","estimatedMin":2,"_count":{"steps":1,"attempts":0}},
             {"id":"89fec9bf-156b-4e3b-90a2-0bc7ededc60a","slug":"email-late-meeting","titleVi":"Email xin lỗi","titleJa":null,"descriptionVi":null,"difficulty":"beginner","category":"email","iconEmoji":"📧","estimatedMin":3,"_count":{"steps":3,"attempts":2}}]
            """)
        }
        let list = try result(api.scenarios()).get()
        XCTAssertEqual(list.map(\.category), ["beauty", "email"])
        XCTAssertEqual(list[0].titleJa, "髪を少し短く切る")
        XCTAssertNil(list[1].titleJa)
        XCTAssertEqual(list[0].count.steps, 1)
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.method, "GET")
        XCTAssertEqual(sent.url.path, "/api/scenarios")
        XCTAssertEqual(sent.headers["Authorization"], "Bearer opaque-session-token")
    }

    func test_scenariosTreatsNullAsAnEmptyCatalogue() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: "null") }
        XCTAssertEqual(try result(api.scenarios()).get(), [])
    }

    func test_scenarioDecodesStepsAndChoicesWithoutAnswers() throws {
        LearnerURLProtocol.handler = { _, proto in
            proto.respond(status: 200, json: """
            {"id":"\(self.scenarioID)","slug":"life101-haircut-length","titleVi":"Dặn thợ cắt tóc ngắn hơn một chút","titleJa":"髪を少し短く切る","descriptionVi":"Dặn thợ","difficulty":"beginner","category":"beauty","iconEmoji":"🗾","estimatedMin":2,
             "steps":[{"id":"\(self.stepID)","stepOrder":1,"situationVi":"Tình huống","situationJa":"髪を少し短く切る。どのように伝えますか。",
               "choices":[{"id":"be8df3e0-8fc5-4958-b2af-fb15a459c965","choiceKey":"A","textVi":"Xin hãy cắt ngắn.","textJa":"全体的に２センチくらい切ってください。"},
                          {"id":"47d8e7c1-8291-432e-95df-2e0defdfd9ab","choiceKey":"B","textVi":"Da đầu tôi nhạy cảm.","textJa":null}]}]}
            """)
        }
        let detail = try result(api.scenario(id: scenarioID)).get()
        XCTAssertEqual(detail.steps.count, 1)
        XCTAssertEqual(detail.steps[0].choices.map(\.choiceKey), ["A", "B"])
        XCTAssertNil(detail.steps[0].speakerName)
        XCTAssertNil(detail.steps[0].choices[1].textJa)
        XCTAssertEqual(LearnerURLProtocol.requests.first?.url.path, "/api/scenarios/\(scenarioID)")
    }

    func test_scenarioRefusesAnIdTheServerWouldAnswerWithA500() {
        guard case .failure(let error) = result(api.scenario(id: "../x")) else { return XCTFail("expected failure") }
        XCTAssertEqual(error as? LearnerAPIError, .invalidRequest(nil))
        XCTAssertTrue(LearnerURLProtocol.requests.isEmpty)
    }

    func test_answerPostsOnlyTheChoiceKeyWithTheOrigin() throws {
        LearnerURLProtocol.handler = { _, proto in
            proto.respond(status: 200, json: #"{"choiceKey":"A","isOptimal":true,"pointsAwarded":10,"feedbackVi":"Phù hợp."}"#)
        }
        let answer = try result(api.answer(stepID: stepID, choiceKey: "A")).get()
        XCTAssertTrue(answer.isOptimal)
        XCTAssertEqual(answer.pointsAwarded, 10)
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.url.path, "/api/scenarios/steps/\(stepID)/answer")
        XCTAssertEqual(sent.headers["Origin"], "https://api.test")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: sent.body) as? [String: Any])
        XCTAssertEqual(body as? [String: String], ["choiceKey": "A"])
    }

    func test_completeSendsOneEntryPerStepAndNoPoints() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: #"{"id":"a1","totalPoints":10,"maxPoints":10}"#) }
        let attempt = try result(api.complete(scenarioID: scenarioID, choices: [BJTScenarioChoiceInput(stepOrder: 1, choiceKey: "A")])).get()
        XCTAssertEqual(attempt.totalPoints, 10)
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.url.path, "/api/scenarios/\(scenarioID)/complete")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: sent.body) as? [String: Any])
        let choices = try XCTUnwrap(body["choices"] as? [[String: Any]])
        XCTAssertEqual(choices.count, 1)
        XCTAssertEqual(Set(choices[0].keys), ["stepOrder", "choiceKey"], "the server computes the points; the client sends none")
    }

    func test_completeIsNotRepeatedByTheClientWhenTheConnectionBreaks() {
        LearnerURLProtocol.handler = { _, proto in proto.fail(URLError(.networkConnectionLost)) }
        guard case .failure(let error) = result(api.complete(scenarioID: scenarioID, choices: [BJTScenarioChoiceInput(stepOrder: 1, choiceKey: "A")])) else {
            return XCTFail("expected failure")
        }
        XCTAssertEqual(error as? LearnerAPIError, .interrupted)
        XCTAssertEqual(LearnerURLProtocol.requests.count, 1)
    }

    func test_signedOutLearnerNeverReachesTheNetwork() {
        let signedOut = BJTLearnerAPI(session: session, baseURL: { "https://api.test/api" }, token: { nil })
        guard case .failure(let error) = result(signedOut.scenarios()) else { return XCTFail("expected failure") }
        XCTAssertEqual(error as? LearnerAPIError, .signInRequired)
        XCTAssertTrue(LearnerURLProtocol.requests.isEmpty)
    }
}
