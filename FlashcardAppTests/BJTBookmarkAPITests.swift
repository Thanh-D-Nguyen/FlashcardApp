import Alamofire
import RxSwift
import XCTest
@testable import FlashcardApp

/// Contract tests for the bookmark endpoints (handler_bookmark.go): auth, CSRF origin, toggle semantics and path safety.
final class BJTBookmarkAPITests: XCTestCase {
    private var session: Session!
    private var api: BJTBookmarkAPI!
    private var bag: DisposeBag!
    private var token: String? = "opaque-session-token"
    private let wordID = "9adc769d-2d6f-48a1-a9ca-5fe729033518"

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LearnerURLProtocol.self]
        session = Session(configuration: config)
        api = BJTBookmarkAPI(learner: BJTLearnerAPI(session: session, baseURL: { "https://api.test/api" }, token: { [unowned self] in token }))
        bag = DisposeBag()
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

    private func result<T>(_ single: Single<T>) -> Result<T, Error> {
        var outcome: Result<T, Error>?
        let done = expectation(description: "request")
        single.subscribe(onSuccess: { outcome = .success($0); done.fulfill() },
                         onFailure: { outcome = .failure($0); done.fulfill() }).disposed(by: bag)
        wait(for: [done], timeout: 3)
        return outcome ?? .failure(LearnerAPIError.invalidResponse)
    }

    func testToggleIsAPostWithBearerAndOriginAndUsesTheBackendTypeName() throws {
        LearnerURLProtocol.handler = { _, proto in
            proto.respond(status: 200, json: #"{"bookmarked":true,"bookmarkId":"b1","targetId":"\#(self.wordID)","type":"lexeme"}"#)
        }
        XCTAssertTrue(try result(api.toggle(.vocabulary, id: wordID)).get())
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.url.path, "/api/bookmarks/lexeme/\(wordID)")
        XCTAssertEqual(sent.headers["Authorization"], "Bearer opaque-session-token")
        XCTAssertEqual(sent.headers["Origin"], "https://api.test")
    }

    func testCheckIsAReadOnlyGetAndReportsTheServerState() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: #"{"bookmarked":false,"targetId":"\#(self.wordID)","type":"kanji"}"#) }
        XCTAssertFalse(try result(api.check(.kanji, id: wordID)).get())
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.method, "GET")
        XCTAssertEqual(sent.url.path, "/api/bookmarks/check/kanji/\(wordID)")
    }

    func testListAsksForTheKindsOwnEndpointWithAClampedLimit() throws {
        LearnerURLProtocol.handler = { _, proto in
            proto.respond(status: 200, json: #"{"items":[{"id":"b1","targetId":"\#(self.wordID)","type":"lexeme","createdAt":"2026-10-25T10:00:00Z"}],"limit":100,"type":"lexeme"}"#)
        }
        let rows = try result(api.list(.vocabulary, limit: 500)).get()
        XCTAssertEqual(rows.map(\.targetId), [wordID])
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.url.path, "/api/bookmarks/words")
        XCTAssertEqual(URLComponents(url: sent.url, resolvingAgainstBaseURL: false)?.queryItems, [URLQueryItem(name: "limit", value: "100")])
    }

    func testGuestsAreToldToSignInWithoutAnyRequest() {
        token = nil
        LearnerURLProtocol.handler = { _, _ in XCTFail("no session, no request") }
        for single in [api.check(.vocabulary, id: wordID), api.toggle(.vocabulary, id: wordID)] {
            guard case .failure(let error) = result(single) else { return XCTFail("must fail") }
            XCTAssertEqual(error as? LearnerAPIError, .signInRequired)
        }
    }

    func testSentencesAndMalformedIdsNeverReachTheNetwork() {
        LearnerURLProtocol.handler = { _, _ in XCTFail("invalid bookmark target must not be sent") }
        for single in [api.toggle(.sentence, id: wordID), api.toggle(.vocabulary, id: "../x"), api.check(.grammar, id: "1")] {
            guard case .failure(let error) = result(single) else { return XCTFail("must fail") }
            XCTAssertEqual(error as? LearnerAPIError, .invalidRequest(nil))
        }
        guard case .failure = result(api.list(.sentence, limit: 5)) else { return XCTFail("sentences have no list") }
    }

    func testExpiredSessionIsSignInRequiredAndAToggleIsNeverSentTwice() {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 401, json: #"{"error":"unauthorized"}"#) }
        guard case .failure(let error) = result(api.toggle(.grammar, id: wordID)) else { return XCTFail("must fail") }
        XCTAssertEqual(error as? LearnerAPIError, .signInRequired)
        XCTAssertEqual(LearnerURLProtocol.requests.count, 1, "A toggle must not be retried: a second call would undo the first")
    }
}
