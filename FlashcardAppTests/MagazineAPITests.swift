import Alamofire
import RxSwift
import XCTest
@testable import FlashcardApp

/// The public magazine endpoints: what the request looks like, what is refused before it is sent, and how an odd payload is read.
final class MagazineAPITests: XCTestCase {
    private var session: Session!
    private var api: BJTMagazineAPI!
    private var bag: DisposeBag!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LearnerURLProtocol.self]
        session = Session(configuration: config)
        api = BJTMagazineAPI(session: session, baseURL: { "https://api.test/api" })
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

    func test_listAsksForThePageWithTheKindAndSendsNoCredentials() throws {
        LearnerURLProtocol.handler = { _, proto in
            proto.respond(status: 200, json: MagazineFixtures.list([MagazineFixtures.listItem(slug: "a")], page: 2, total: 41))
        }
        let list = try result(api.articles(kind: .businessPhrase, page: 2, limit: 20)).get()

        XCTAssertEqual(list.data.map(\.slug), ["a"])
        XCTAssertEqual(list.page, 2)
        XCTAssertEqual(list.total, 41)
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.method, "GET")
        XCTAssertEqual(sent.url.path, "/api/magazine")
        let query = URLComponents(url: sent.url, resolvingAgainstBaseURL: false)?.queryItems?.reduce(into: [String: String]()) { $0[$1.name] = $1.value }
        XCTAssertEqual(query, ["page": "2", "limit": "20", "kind": "bjt_phrase"])
        XCTAssertNil(sent.headers["Authorization"], "The magazine is public: no session reaches it")
        XCTAssertNil(sent.headers["Origin"])
    }

    func test_everyKindIsAskedForByTheNameTheServerKnows() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: MagazineFixtures.list([])) }
        for kind in MagazineKind.allCases { _ = result(api.articles(kind: kind, page: 1, limit: 20)) }
        let kinds = LearnerURLProtocol.requests.compactMap { URLComponents(url: $0.url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "kind" }?.value }
        XCTAssertEqual(kinds, ["vocab", "weather", "horoscope", "bjt_phrase"])
    }

    func test_allKindsLeavesTheKindOut() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: MagazineFixtures.list([])) }
        _ = result(api.articles(kind: nil, page: 1, limit: 20))
        XCTAssertFalse(try XCTUnwrap(LearnerURLProtocol.requests.first).url.absoluteString.contains("kind="))
    }

    func test_anArticleIsReadByItsSlugAndDecodesItsBody() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: MagazineFixtures.vocabularyArticle) }
        let article = try result(api.article(slug: "2026-10-26-vocab-vi")).get()
        XCTAssertEqual(try XCTUnwrap(LearnerURLProtocol.requests.first).url.path, "/api/magazine/2026-10-26-vocab-vi")
        XCTAssertEqual(article.vocabItems.count, 2)
        XCTAssertEqual(article.quizzes.count, 2)
        XCTAssertEqual(article.content?.introduction, "6月から7月にかけて、日本は梅雨の季節を迎えます。")
    }

    func test_aSlugThatCouldChangeTheRouteIsRefusedWithoutARequest() {
        for slug in ["", "../admin", "a/b", "a b", "%2e%2e", "a?x=1", ".hidden", String(repeating: "a", count: 201)] {
            XCTAssertEqual(result(api.article(slug: slug)).failureValue as? LearnerAPIError, .invalidRequest(nil), "\(slug)")
        }
        XCTAssertTrue(LearnerURLProtocol.requests.isEmpty)
    }

    func test_aPageOrSizeOutOfRangeIsRefusedWithoutARequest() {
        XCTAssertEqual(result(api.articles(kind: nil, page: 0, limit: 20)).failureValue as? LearnerAPIError, .invalidRequest(nil))
        XCTAssertEqual(result(api.articles(kind: nil, page: 1, limit: 0)).failureValue as? LearnerAPIError, .invalidRequest(nil))
        XCTAssertEqual(result(api.articles(kind: nil, page: 1, limit: 51)).failureValue as? LearnerAPIError, .invalidRequest(nil))
        XCTAssertTrue(LearnerURLProtocol.requests.isEmpty)
    }

    func test_failuresAreNamedForWhatTheLearnerCanDoAboutThem() {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 404, json: #"{"error":"article not found"}"#) }
        XCTAssertEqual(result(api.article(slug: "gone")).failureValue as? LearnerAPIError, .notFound)
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 500, json: "{}") }
        XCTAssertEqual(result(api.articles(kind: nil, page: 1, limit: 20)).failureValue as? LearnerAPIError, .server(500))
        LearnerURLProtocol.handler = { _, proto in proto.fail(URLError(.notConnectedToInternet)) }
        XCTAssertEqual(result(api.articles(kind: nil, page: 1, limit: 20)).failureValue as? LearnerAPIError, .offline)
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: "not json") }
        XCTAssertEqual(result(api.articles(kind: nil, page: 1, limit: 20)).failureValue as? LearnerAPIError, .invalidResponse)
    }

    func test_disposingTheSubscriptionCancelsTheRequest() {
        let cancelled = expectation(description: "cancelled")
        LearnerURLProtocol.handler = { _, _ in }
        LearnerURLProtocol.onStop = { cancelled.fulfill() }
        let subscription = api.articles(kind: nil, page: 1, limit: 20).subscribe()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { subscription.dispose() }
        wait(for: [cancelled], timeout: 3)
    }

    // MARK: Lenient decoding

    func test_aBrokenVocabularyItemIsDroppedAndTheRestOfTheArticleStays() throws {
        let json = #"""
        {"id":"a","slug":"s","widgetKind":"magazine_vocab","titleJp":"題","titleVi":"Tiêu đề",
         "vocabItems":[{"id":"v1","wordJp":"傘","meaningVi":"ô"},{"id":"v2","meaningVi":"thiếu từ"},"lạ",{"id":"v3","wordJp":"雨","meaningVi":"mưa"}],"quizzes":null}
        """#
        let article = try MagazineFixtures.decodeArticle(json)
        XCTAssertEqual(article.vocabItems.map(\.id), ["v1", "v3"])
        XCTAssertTrue(article.quizzes.isEmpty)
    }

    func test_aFieldOfTheWrongTypeInTheBodyIsIgnoredNotFatal() throws {
        let json = #"""
        {"id":"a","slug":"s","widgetKind":"magazine_weather","titleJp":"題","titleVi":"Tiêu đề",
         "contentJson":{"description":"晴れ","highTemp":"hot","lowTemp":12,"situations":"không phải mảng","dialogue":[{"speaker":"A"},{"textJp":"こんにちは"}]}}
        """#
        let content = try XCTUnwrap(MagazineFixtures.decodeArticle(json).content)
        XCTAssertEqual(content.description, "晴れ")
        XCTAssertNil(content.highTemp)
        XCTAssertEqual(content.lowTemp, 12)
        XCTAssertTrue(content.situations.isEmpty)
        XCTAssertEqual(content.dialogue.map(\.text), ["こんにちは"], "The website's reader looks for textJp, the generator writes text; both are accepted")
    }

    func test_aBodyThatIsNotAnObjectLeavesTheArticleWithoutABody() throws {
        let json = #"{"id":"a","slug":"s","widgetKind":"magazine_vocab","titleJp":"題","titleVi":"v","contentJson":"oops"}"#
        XCTAssertNil(try MagazineFixtures.decodeArticle(json).content)
    }
}

private extension Result {
    var failureValue: Failure? { if case .failure(let error) = self { return error } else { return nil } }
}
