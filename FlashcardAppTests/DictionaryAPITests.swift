import Alamofire
import RxSwift
import XCTest
@testable import FlashcardApp

final class DictionaryAPITests: XCTestCase {
    private var session: Session!
    private var api: BJTSearchAPI!
    private var bag: DisposeBag!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SearchURLProtocol.self]
        session = Session(configuration: config)
        api = BJTSearchAPI(session: session, baseURL: "https://api.test/api")
        bag = DisposeBag()
        SearchURLProtocol.handler = nil
        SearchURLProtocol.onStop = nil
    }

    override func tearDown() {
        bag = nil
        session.session.invalidateAndCancel()
        api = nil
        session = nil
        SearchURLProtocol.handler = nil
        SearchURLProtocol.onStop = nil
        super.tearDown()
    }

    func testDecodesRealSearchFieldsAndPreservesUUID() throws {
        let rows = try JSONDecoder().decode([BJTSearchResultDTO].self, from: Self.fixture)
        XCTAssertEqual(rows.first?.id, "00167089-a2d4-4a6d-a1f2-93ced10a5973")
        XCTAssertEqual(rows.first?.kind, "lexeme")
        XCTAssertEqual(rows.first?.title, "日本史")
        XCTAssertEqual(rows.first?.description, "lịch sử nhật bản")
        XCTAssertEqual(rows.first?.reading, "にほんし")
        XCTAssertNil(rows.first?.jlptLevel)
    }

    func testMissingRequiredFieldsFailDecoding() {
        XCTAssertThrowsError(try JSONDecoder().decode([BJTSearchResultDTO].self, from: Data("[{\"id\":\"123\"}]".utf8)))
    }

    func testPublicSearchEncodesQueryAndScopeWithoutBearer() {
        let done = expectation(description: "search")
        SearchURLProtocol.handler = { request, proto in
            let url = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            XCTAssertEqual(url.path, "/api/search")
            XCTAssertEqual(url.queryItems?.first(where: { $0.name == "q" })?.value, "日本 & học")
            XCTAssertEqual(url.queryItems?.first(where: { $0.name == "scope" })?.value, "lexeme")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            proto.respond(status: 200, data: Self.fixture)
        }
        api.search(q: " 日本 & học ", scope: .vocabulary)
            .subscribe(onSuccess: { rows in
                XCTAssertEqual(rows.count, 1)
                done.fulfill()
            }, onFailure: { error in XCTFail("\(error)"); done.fulfill() })
            .disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testInvalidQueryFailsWithoutNetwork() {
        SearchURLProtocol.handler = { _, _ in XCTFail("invalid query must not reach network") }
        for query in [" ", "a", String(repeating: "日", count: 67)] {
            let done = expectation(description: "invalid query")
            api.search(q: query, scope: .vocabulary)
                .subscribe(onSuccess: { _ in XCTFail("should reject query"); done.fulfill() },
                           onFailure: { _ in done.fulfill() })
                .disposed(by: bag)
            wait(for: [done], timeout: 1)
        }
    }

    func testHTTPFailureAndMalformedSuccessPropagate() {
        for (status, data) in [(503, Self.fixture), (200, Data("{}".utf8))] {
            let done = expectation(description: "failure")
            SearchURLProtocol.handler = { _, proto in proto.respond(status: status, data: data) }
            api.search(q: "日本", scope: .vocabulary)
                .subscribe(onSuccess: { _ in XCTFail("should fail"); done.fulfill() },
                           onFailure: { _ in done.fulfill() })
                .disposed(by: bag)
            wait(for: [done], timeout: 3)
        }
    }

    func testDisposalCancelsOwnedRequest() {
        let started = expectation(description: "started")
        let stopped = expectation(description: "cancelled")
        SearchURLProtocol.handler = { _, _ in started.fulfill() }
        SearchURLProtocol.onStop = { stopped.fulfill() }
        let request = api.search(q: "日本", scope: .kanji).subscribe()
        wait(for: [started], timeout: 3)
        request.dispose()
        wait(for: [stopped], timeout: 3)
    }

    private static let fixture = Data(#"[{"description":"lịch sử nhật bản","id":"00167089-a2d4-4a6d-a1f2-93ced10a5973","kind":"lexeme","reading":"にほんし","title":"日本史"}]"#.utf8)
}

private final class SearchURLProtocol: URLProtocol {
    static var handler: ((URLRequest, SearchURLProtocol) -> Void)?
    static var onStop: (() -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.handler?(request, self) }
    override func stopLoading() { Self.onStop?() }

    func respond(status: Int, data: Data) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}
