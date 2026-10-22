import Alamofire
import RxSwift
import XCTest
@testable import FlashcardApp

final class LevelAPITests: XCTestCase {
    private var api: BJTLevelAPI!
    private var session: Session!
    private var bag: DisposeBag!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LevelURLProtocol.self]
        session = Session(configuration: configuration)
        api = BJTLevelAPI(session: session, baseURL: "https://levels.test/api/")
        bag = DisposeBag()
    }

    override func tearDown() {
        bag = nil
        api = nil
        session.session.invalidateAndCancel()
        session = nil
        LevelURLProtocol.handler = nil
        LevelURLProtocol.stopped = nil
        super.tearDown()
    }

    func testListUsesPublicGETAndRealLevelFields() {
        LevelURLProtocol.handler = { stub in
            XCTAssertEqual(stub.request.httpMethod, "GET")
            XCTAssertEqual(stub.request.url?.path, "/api/levels")
            XCTAssertNil(stub.request.value(forHTTPHeaderField: "Authorization"))
            stub.respond(Self.levelFixture)
        }
        success(api.list()) { levels in
            XCTAssertEqual(levels.first?.code, "J5")
            XCTAssertEqual(levels.first?.nameVi, "J5 — Sơ cấp")
            XCTAssertEqual(levels.first?.descriptionVi, "Giao tiếp cơ bản: chào hỏi, tự giới thiệu, đọc biển hiệu đơn giản tại nơi làm việc.")
            XCTAssertEqual(levels.first?.vocabCount, 574)
            XCTAssertEqual(levels.first?.kanjiCount, 79)
            XCTAssertEqual(levels.first?.grammarCount, 194)
            // The same level in the two other UI languages, exactly as the backend sends it.
            XCTAssertEqual(levels.first?.nameEn, "J5 — Lower beginner")
            XCTAssertEqual(levels.first?.nameJa, "J5 — 初級前半")
            XCTAssertEqual(levels.first?.descriptionEn, "Handle basic greetings and self-introductions, and read simple workplace signs.")
            XCTAssertEqual(levels.first?.descriptionJa, "基本的な挨拶、自己紹介、職場の簡単な表示の読解。")
            XCTAssertEqual(levels.first?.localizedName(for: .japanese), "J5 — 初級前半")
            XCTAssertEqual(levels.first?.localizedDescription(for: .english),
                           "Handle basic greetings and self-introductions, and read simple workplace signs.")
        }
    }

    func testVocabularyDecodesRealUUIDHeadwordAndSensesWithPagination() {
        stubPage("vocabulary", json: Self.vocabularyFixture, offset: 30)
        success(api.vocabulary(code: "J5", offset: 30)) { items in
            XCTAssertEqual(items.first?.id, "de165483-5065-45c3-a4be-f2607727c587")
            XCTAssertEqual(items.first?.headword, "お弁当")
            XCTAssertEqual(items.first?.reading, "おべんとう")
            XCTAssertEqual(items.first?.shortMeaningVi, "cơm hộp; cơm trưa")
            XCTAssertEqual(items.first?.senses.first?.meaningVi, "cơm hộp")
        }
    }

    func testKanjiDecodesStringReadingsWithPagination() {
        stubPage("kanji", json: Self.kanjiFixture, offset: 60)
        success(api.kanji(code: "J5", offset: 60)) { items in
            XCTAssertEqual(items.first?.id, "38ebde58-b3c7-4935-ae49-9c72cf634f64")
            XCTAssertEqual(items.first?.character, "日")
            XCTAssertEqual(items.first?.onyomi, "ニチ ジツ")
            XCTAssertEqual(items.first?.kunyomi, "ひ -び -か")
            XCTAssertEqual(items.first?.meaningVi, "NHẬT, NHỰT")
        }
    }

    func testGrammarDecodesRealPatternAndMeaningWithPagination() {
        stubPage("grammar", json: Self.grammarFixture, offset: 90)
        success(api.grammar(code: "J5", offset: 90)) { items in
            XCTAssertEqual(items.first?.id, "130a49b5-661f-4db4-ad90-c6491125ad61")
            XCTAssertEqual(items.first?.pattern, "いつも")
            XCTAssertEqual(items.first?.meaningVi, "Lúc nào cũng/Luôn...")
            XCTAssertEqual(items.first?.details.first?.explanationVi, "『いつも』diễn tả một hành động, một thói quen thường xuyên xảy ra.")
        }
    }

    func testJ1PlusAndEmptyFinalPage() {
        LevelURLProtocol.handler = { stub in
            XCTAssertEqual(stub.request.url?.path, "/api/levels/J1+/vocabulary")
            stub.respond("[]")
        }
        success(api.vocabulary(code: "J1+")) { XCTAssertTrue($0.isEmpty) }
    }

    func testRejectsHTTPErrorStatusesBeforeDecoding() {
        for status in [401, 404, 429, 500] {
            LevelURLProtocol.handler = { $0.respond("[]", status: status) }
            failure(api.list()) { error in
                XCTAssertEqual((error as? AFError)?.responseCode, status)
            }
        }
    }

    func testRejectsMalformedJSONAndMissingRequiredFields() {
        for json in ["not json", "[{}]", "[{\"code\":\"J5\"}]"] {
            LevelURLProtocol.handler = { $0.respond(json) }
            failure(api.list()) { XCTAssertNotNil($0 as? AFError) }
        }
        LevelURLProtocol.handler = { $0.respond("[{\"id\":\"uuid\",\"word\":\"obsolete field\"}]") }
        failure(api.vocabulary(code: "J5")) { XCTAssertNotNil($0 as? AFError) }
    }

    func testInvalidCodeAndPaginationNeverReachNetwork() {
        LevelURLProtocol.handler = { _ in XCTFail("Invalid input reached network") }
        failure(api.vocabulary(code: "../J5")) { _ in }
        failure(api.vocabulary(code: "J5", limit: 0)) { _ in }
        failure(api.kanji(code: "J5", limit: 51)) { _ in }
        failure(api.grammar(code: "J5", offset: -1)) { _ in }
    }

    func testInteractorPreservesIdentityAndMapsAvailableMeanings() {
        let interactor = HomeInteractor(api: api)
        stubPage("vocabulary", json: Self.vocabularyFixture, offset: 0)
        success(interactor.content(code: "J5", kind: .vocabulary, offset: 0)) { rows in
            XCTAssertEqual(rows.first?.id, "de165483-5065-45c3-a4be-f2607727c587")
            XCTAssertEqual(rows.first?.title, "お弁当")
            XCTAssertTrue(rows.first?.detail.contains("cơm trưa") == true)
        }
        stubPage("kanji", json: Self.kanjiFixture, offset: 0)
        success(interactor.content(code: "J5", kind: .kanji, offset: 0)) { rows in
            XCTAssertEqual(rows.first?.id, "38ebde58-b3c7-4935-ae49-9c72cf634f64")
            XCTAssertTrue(rows.first?.detail.contains("ニチ ジツ") == true)
        }
        stubPage("grammar", json: Self.grammarFixture, offset: 0)
        success(interactor.content(code: "J5", kind: .grammar, offset: 0)) { rows in
            XCTAssertEqual(rows.first?.id, "130a49b5-661f-4db4-ad90-c6491125ad61")
            XCTAssertTrue(rows.first?.detail.contains("thói quen") == true)
        }
    }

    func testVocabularyCanUseSensesWhenShortMeaningIsNull() {
        LevelURLProtocol.handler = { stub in
            stub.respond(#"[{"id":"de165483-5065-45c3-a4be-f2607727c587","headword":"お弁当","reading":null,"shortMeaningVi":null,"senses":[{"meaningVi":"cơm hộp"}]}]"#)
        }
        success(HomeInteractor(api: api).content(code: "J5", kind: .vocabulary, offset: 0)) { rows in
            XCTAssertEqual(rows.first?.detail, "cơm hộp")
            XCTAssertEqual(rows.first?.subtitle, "cơm hộp")
        }
    }

    func testDisposingSubscriptionCancelsOwnedRequest() {
        let started = expectation(description: "request started")
        let stopped = expectation(description: "URLProtocol stopped")
        LevelURLProtocol.handler = { _ in started.fulfill() }
        LevelURLProtocol.stopped = { stopped.fulfill() }
        let subscription = api.list().subscribe(onSuccess: { _ in XCTFail("Cancelled request delivered success") },
                                                onFailure: { _ in XCTFail("Disposed observer received error") })
        wait(for: [started], timeout: 2)
        subscription.dispose()
        wait(for: [stopped], timeout: 2)
    }

    private func stubPage(_ kind: String, json: String, offset: Int) {
        LevelURLProtocol.handler = { stub in
            XCTAssertEqual(stub.request.httpMethod, "GET")
            XCTAssertEqual(stub.request.url?.path, "/api/levels/J5/\(kind)")
            XCTAssertNil(stub.request.value(forHTTPHeaderField: "Authorization"))
            let query = URLComponents(url: stub.request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertEqual(query.first { $0.name == "limit" }?.value, "30")
            XCTAssertEqual(query.first { $0.name == "offset" }?.value, String(offset))
            stub.respond(json)
        }
    }

    private func success<T>(_ single: Single<T>, verify: @escaping (T) -> Void) {
        let done = expectation(description: "success")
        single.subscribe(onSuccess: { value in verify(value); done.fulfill() },
                         onFailure: { error in XCTFail("Unexpected error: \(error)"); done.fulfill() })
            .disposed(by: bag)
        wait(for: [done], timeout: 2)
    }

    private func failure<T>(_ single: Single<T>, verify: @escaping (Error) -> Void) {
        let done = expectation(description: "failure")
        single.subscribe(onSuccess: { _ in XCTFail("Unexpected success"); done.fulfill() },
                         onFailure: { error in verify(error); done.fulfill() })
            .disposed(by: bag)
        wait(for: [done], timeout: 2)
    }

    // Public localhost responses, captured 2026-10-21; no credentials or learner data.
    private static let levelFixture = #"[{"code":"J5","nameVi":"J5 — Sơ cấp","descriptionVi":"Giao tiếp cơ bản: chào hỏi, tự giới thiệu, đọc biển hiệu đơn giản tại nơi làm việc.","vocabCount":574,"kanjiCount":79,"grammarCount":194,"nameEn":"J5 — Lower beginner","nameJa":"J5 — 初級前半","descriptionEn":"Handle basic greetings and self-introductions, and read simple workplace signs.","descriptionJa":"基本的な挨拶、自己紹介、職場の簡単な表示の読解。"}]"#
    private static let vocabularyFixture = #"[{"id":"de165483-5065-45c3-a4be-f2607727c587","senses":[{"pos":"n","meaningVi":"cơm hộp"},{"pos":"n","meaningVi":"cơm trưa"}],"reading":"おべんとう","headword":"お弁当","jlptLevel":"N5","shortMeaningVi":"cơm hộp; cơm trưa"}]"#
    private static let kanjiFixture = #"[{"id":"38ebde58-b3c7-4935-ae49-9c72cf634f64","character":"日","meaningVi":"NHẬT, NHỰT","onyomi":"ニチ ジツ","kunyomi":"ひ -び -か","level":5}]"#
    private static let grammarFixture = #"[{"id":"130a49b5-661f-4db4-ad90-c6491125ad61","pattern":"いつも","meaningVi":"Lúc nào cũng/Luôn...","details":[{"explanationVi":"『いつも』diễn tả một hành động, một thói quen thường xuyên xảy ra."}]}]"#
}

private final class LevelURLProtocol: URLProtocol {
    static var handler: ((LevelURLProtocol) -> Void)?
    static var stopped: (() -> Void)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.handler?(self) }
    override func stopLoading() { Self.stopped?() }

    func respond(_ json: String, status: Int = 200) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
