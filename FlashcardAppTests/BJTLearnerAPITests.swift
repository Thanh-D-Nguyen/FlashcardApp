import Alamofire
import RxSwift
import XCTest
@testable import FlashcardApp

/// Request shape, status mapping and failure semantics of the authenticated learner API. The response fixtures
/// mirror the JSON tags of the Go handlers (`handler_flashcard_deck.go`, `flashcarddeck/store.go`).
final class BJTLearnerAPITests: XCTestCase {
    private var session: Session!
    private var api: BJTLearnerAPI!
    private var bag: DisposeBag!
    private var token: String? = "opaque-session-token"
    private let deckId = "11111111-2222-4333-8444-555555555555"

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LearnerURLProtocol.self]
        session = Session(configuration: config)
        api = BJTLearnerAPI(session: session, baseURL: { "https://api.test/api" }, token: { [unowned self] in token })
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

    private var request: DeckGenerationRequest {
        DeckGenerationRequest(name: "  N5 Vocabulary ", level: .n5, contentTypes: [.vocabulary, .grammar], direction: .both, count: 30)
    }

    // MARK: Request shape

    func test_generateSendsTheBearerTokenAndTheApisOwnOriginWithTheVerifiedBody() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 201, json: #"{"id":"\#(self.deckId)","titleVi":"N5 Vocabulary","cardCount":30,"status":"active"}"#) }
        let deck = try result(api.generateDeck(request)).get()
        XCTAssertEqual(deck, BJTGeneratedDeckDTO(id: deckId, titleVi: "N5 Vocabulary", cardCount: 30))
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.url.path, "/api/flashcards/decks/generate")
        XCTAssertEqual(sent.headers["Authorization"], "Bearer opaque-session-token")
        XCTAssertEqual(sent.headers["Origin"], "https://api.test", "The API's own origin (scheme + host), never a made-up one")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: sent.body) as? [String: Any])
        XCTAssertEqual(body["name"] as? String, "N5 Vocabulary")
        XCTAssertEqual(body["levels"] as? [String], ["J5"])
        XCTAssertEqual(body["sourceTypes"] as? [String], ["lexeme", "grammar"])
        XCTAssertEqual(body["direction"] as? String, "both")
        XCTAssertEqual(body["limit"] as? Int, 30)
        XCTAssertEqual(Set(body.keys), ["name", "levels", "sourceTypes", "direction", "limit"], "Unsupported options such as topic are never sent")
    }

    func test_previewSendsOnlyLevelsAndSourceTypesAndReadsTheCount() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: #"{"availableCount":1240}"#) }
        let count = try result(api.previewGeneration(level: .n3, contentTypes: [.kanji])).get()
        XCTAssertEqual(count, 1240)
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.url.path, "/api/flashcards/decks/generate/preview")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: sent.body) as? [String: Any])
        XCTAssertEqual(body["levels"] as? [String], ["J3"])
        XCTAssertEqual(body["sourceTypes"] as? [String], ["kanji"])
        XCTAssertEqual(body.count, 2)
    }

    func test_deckDetailDecodesCardsWithTheirDeckCardIds() throws {
        LearnerURLProtocol.handler = { request, proto in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/flashcards/decks/\(self.deckId)")
            proto.respond(status: 200, json: Self.deckJSON(self.deckId))
        }
        let deck = try result(api.deck(id: deckId)).get()
        XCTAssertEqual(deck.id, deckId)
        // Decoding keeps the server's order; the interactor sorts by `position`.
        XCTAssertEqual(deck.cards.map(\.id), ["aaaaaaaa-0000-4000-8000-000000000002", "aaaaaaaa-0000-4000-8000-000000000001"])
        XCTAssertEqual(deck.cards.map(\.position), [1, 0])
        XCTAssertEqual(deck.cards[1].card.frontText, "食べる")
        XCTAssertEqual(deck.cards[1].card.reading, "たべる")
        XCTAssertNil(deck.cards[0].card.reading)
    }

    private static let searchBody = #"{"results":[{"handle":"h.sig","provider":"unsplash","url":"https://images.unsplash.com/a.jpg","sourceUrl":"https://unsplash.com/photos/a","author":"Ana Lee","authorUrl":"https://unsplash.com/@ana","license":"Unsplash License"}]}"#

    func test_imageSearchSendsOnlyTheQueryAndReadsTheResults() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: Self.searchBody) }
        let images = try result(api.searchImages(query: " con chó ")).get()
        XCTAssertEqual(images, [BJTImageResultDTO(handle: "h.sig", provider: "unsplash", url: "https://images.unsplash.com/a.jpg",
                                                  sourceUrl: "https://unsplash.com/photos/a", author: "Ana Lee",
                                                  authorUrl: "https://unsplash.com/@ana", license: "Unsplash License", licenseUrl: nil)])
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.url.path, "/api/media/search-images")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: sent.body) as? [String: Any])
        XCTAssertEqual(body as? [String: String], ["query": "con chó"], "The server rejects any other field")
    }

    func test_selectingAnImagePostsTheHandleAndReturnsTheAssetId() throws {
        let asset = UUID().uuidString.lowercased()
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 201, json: #"{"assetId":"\#(asset)","status":"pending_review"}"#) }
        XCTAssertEqual(try result(api.selectImage(handle: "h.sig")).get(), asset)
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.url.path, "/api/media/image-selections")
        XCTAssertEqual(try JSONSerialization.jsonObject(with: sent.body) as? [String: String], ["handle": "h.sig"])
    }

    func test_anAssetIdThatIsNotAUUIDIsAnInvalidResponse() {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 201, json: #"{"assetId":"../x","status":"pending_review"}"#) }
        XCTAssertEqual(failure(api.selectImage(handle: "h.sig")), .invalidResponse)
    }

    // MARK: Uploading a picture and creating a deck

    func test_uploadingAPictureGoesPresignPutCompleteWithTheOneTimeToken() throws {
        let asset = UUID().uuidString.lowercased()
        LearnerURLProtocol.handler = { request, proto in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/media/presign-upload"?):
                proto.respond(status: 201, json: #"{"assetId":"\#(asset)","uploadUrl":"/api/media/upload/\#(asset)","uploadToken":"one-time","expiresAt":"2026-10-31T00:00:00Z"}"#)
            case ("PUT", _):
                proto.respond(status: 200, json: "{}")
            default:
                proto.respond(status: 200, json: #"{"url":"/api/media/\#(asset)/stream","status":"completed"}"#)
            }
        }
        let bytes = Data(repeating: 0xFF, count: 1234)
        XCTAssertEqual(try result(api.uploadPicture(data: bytes, fileName: "card.jpg", mimeType: "image/jpeg")).get(), asset)
        let sent = LearnerURLProtocol.requests
        XCTAssertEqual(sent.map(\.method), ["POST", "PUT", "POST"])
        XCTAssertEqual(try JSONSerialization.jsonObject(with: sent[0].body) as? [String: String],
                       ["fileName": "card.jpg", "mimeType": "image/jpeg", "purpose": "flashcard"])
        XCTAssertEqual(sent[1].url.path, "/api/media/upload/\(asset)")
        XCTAssertEqual(sent[1].headers["X-Media-Upload-Token"], "one-time")
        XCTAssertEqual(sent[1].headers["Content-Type"], "image/jpeg")
        XCTAssertEqual(sent[1].headers["Authorization"], "Bearer opaque-session-token")
        XCTAssertEqual(sent[1].headers["Origin"], "https://api.test")
        XCTAssertEqual(sent[1].body, bytes)
        let completion = try XCTUnwrap(JSONSerialization.jsonObject(with: sent[2].body) as? [String: Any])
        XCTAssertEqual(completion["assetId"] as? String, asset)
        XCTAssertEqual(completion["byteSize"] as? Int, 1234)
    }

    func test_anUploadAddressThatIsNotTheAssetsOwnIsNeverFollowed() {
        let asset = UUID().uuidString.lowercased()
        LearnerURLProtocol.handler = { _, proto in
            proto.respond(status: 201, json: #"{"assetId":"\#(asset)","uploadUrl":"https://evil.test/steal","uploadToken":"t"}"#)
        }
        XCTAssertEqual(failure(api.uploadPicture(data: Data([1]), fileName: "a.jpg", mimeType: "image/jpeg")), .invalidResponse)
        XCTAssertEqual(LearnerURLProtocol.requests.count, 1, "Nothing was uploaded")
    }

    func test_aRejectedUploadStopsBeforeCompletion() {
        let asset = UUID().uuidString.lowercased()
        LearnerURLProtocol.handler = { request, proto in
            request.httpMethod == "PUT" ? proto.respond(status: 413, json: #"{"error":"file too large"}"#)
                : proto.respond(status: 201, json: #"{"assetId":"\#(asset)","uploadUrl":"/api/media/upload/\#(asset)","uploadToken":"t"}"#)
        }
        XCTAssertEqual(failure(api.uploadPicture(data: Data([1]), fileName: "a.jpg", mimeType: "image/jpeg")), .server(413))
        XCTAssertEqual(LearnerURLProtocol.requests.map(\.method), ["POST", "PUT"])
    }

    func test_picturesThatAreEmptyOrNotImagesAreRefusedLocally() {
        XCTAssertEqual(failure(api.uploadPicture(data: Data(), fileName: "a.jpg", mimeType: "image/jpeg")), .invalidRequest(nil))
        XCTAssertEqual(failure(api.uploadPicture(data: Data([1]), fileName: "a.svg", mimeType: "image/svg+xml")), .invalidRequest(nil))
        XCTAssertTrue(LearnerURLProtocol.requests.isEmpty)
    }

    func test_createDeckSendsTheCardsWithTheirAssetIdsAndNoDirectImageUrl() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 201, json: #"{"id":"\#(self.deckId)","titleVi":"N5","cardCount":2}"#) }
        let deck = AccountDeckInput(titleVi: "N5", visibility: "private", cards: [
            AccountDeckCardInput(frontText: "犬", backText: "chó", reading: "いぬ", primaryImageAssetId: "asset-1"),
            AccountDeckCardInput(frontText: "猫", backText: "mèo", reading: nil, primaryImageAssetId: nil)])
        XCTAssertEqual(try result(api.createDeck(deck)).get().id, deckId)
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.url.path, "/api/flashcards/decks")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: sent.body) as? [String: Any])
        XCTAssertEqual(body["titleVi"] as? String, "N5")
        XCTAssertEqual(body["visibility"] as? String, "private")
        let cards = try XCTUnwrap(body["cards"] as? [[String: Any]])
        XCTAssertEqual(cards[0]["primaryImageAssetId"] as? String, "asset-1")
        XCTAssertNil(cards[1]["primaryImageAssetId"])
        XCTAssertNil(cards[0]["imageUrl"])
        XCTAssertEqual(failure(api.createDeck(AccountDeckInput(titleVi: "", visibility: "private", cards: []))), .invalidRequest(nil))
    }

    // MARK: Requests that never reach the network

    func test_noSessionMeansSignInRequiredWithoutAnyRequest() {
        token = nil
        LearnerURLProtocol.handler = { _, _ in XCTFail("A signed-out learner must not send a request") }
        XCTAssertEqual(failure(api.previewGeneration(level: .n5, contentTypes: [.vocabulary])), .signInRequired)
        XCTAssertEqual(failure(api.generateDeck(request)), .signInRequired)
        XCTAssertTrue(LearnerURLProtocol.requests.isEmpty)
    }

    func test_invalidInputIsRejectedLocally() {
        LearnerURLProtocol.handler = { _, _ in XCTFail("invalid input must not reach the network") }
        var empty = request; empty.name = "  "
        XCTAssertEqual(failure(api.generateDeck(empty)), .invalidRequest(nil))
        var none = request; none.contentTypes = []
        XCTAssertEqual(failure(api.generateDeck(none)), .invalidRequest(nil))
        var huge = request; huge.count = 5000
        XCTAssertEqual(failure(api.generateDeck(huge)), .invalidRequest(nil), "The server would silently fall back to 50 cards")
        XCTAssertEqual(failure(api.deck(id: "../../admin")), .invalidRequest(nil), "Only a UUID may become a path segment")
        XCTAssertEqual(failure(api.searchImages(query: "a")), .invalidRequest(nil))
        XCTAssertEqual(failure(api.searchImages(query: String(repeating: "x", count: 201))), .invalidRequest(nil))
        XCTAssertEqual(failure(api.selectImage(handle: "")), .invalidRequest(nil))
    }

    // MARK: Status handling

    func test_statusCodesMapToWhatTheLearnerCanDo() {
        let cases: [(Int, String, LearnerAPIError)] = [
            (400, #"{"error":"name is required"}"#, .invalidRequest(nil)),
            (401, #"{"error":"unauthorized"}"#, .signInRequired),
            (403, #"{"error":"forbidden: untrusted origin"}"#, .originRejected),
            (403, #"{"error":"forbidden: missing origin"}"#, .originRejected),
            (403, #"{"error":"not owner"}"#, .forbidden("not owner")),
            (404, #"{"error":"not found"}"#, .notFound),
            (429, #"{"error":"too many requests"}"#, .rateLimited),
            (503, #"{"error":"image search unavailable: Go API provider integration is missing"}"#,
             .serviceUnavailable("image search unavailable: Go API provider integration is missing")),
            (500, #"{"error":"internal error"}"#, .server(500)),
            (502, "<html>bad gateway</html>", .server(502))
        ]
        for (status, body, expected) in cases {
            LearnerURLProtocol.handler = { _, proto in proto.respond(status: status, json: body) }
            XCTAssertEqual(failure(api.previewGeneration(level: .n5, contentTypes: [.vocabulary])), expected, "HTTP \(status)")
        }
    }

    func test_aMalformedSuccessIsAnInvalidResponse() {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: #"{"unexpected":true}"#) }
        XCTAssertEqual(failure(api.previewGeneration(level: .n5, contentTypes: [.vocabulary])), .invalidResponse)
    }

    func test_aConnectionThatNeverOpenedIsOfflineButOneThatBrokeMidWayIsUnknown() {
        LearnerURLProtocol.handler = { _, proto in proto.fail(URLError(.notConnectedToInternet)) }
        XCTAssertEqual(failure(api.generateDeck(request)), .offline)
        LearnerURLProtocol.handler = { _, proto in proto.fail(URLError(.timedOut)) }
        XCTAssertEqual(failure(api.generateDeck(request)), .interrupted)
        LearnerURLProtocol.handler = { _, proto in proto.fail(URLError(.networkConnectionLost)) }
        XCTAssertEqual(failure(api.generateDeck(request)), .interrupted)
    }

    func test_aFailedGenerationIsSentExactlyOnce() {
        LearnerURLProtocol.handler = { _, proto in proto.fail(URLError(.timedOut)) }
        _ = failure(api.generateDeck(request))
        XCTAssertEqual(LearnerURLProtocol.requests.count, 1, "Creating a deck has no idempotency key, so it is never retried")
    }

    // MARK: Session safety and cancellation

    func test_aResultThatArrivesAfterLogoutIsDiscarded() {
        LearnerURLProtocol.handler = { [unowned self] _, proto in
            self.token = nil // the learner signs out while the request is in flight
            proto.respond(status: 201, json: #"{"id":"\#(self.deckId)","titleVi":"x","cardCount":1}"#)
        }
        XCTAssertEqual(failure(api.generateDeck(request)), .staleSession)
    }

    func test_aResultThatArrivesAfterAnAccountSwitchIsDiscarded() {
        LearnerURLProtocol.handler = { [unowned self] _, proto in
            self.token = "another-accounts-token"
            proto.respond(status: 200, json: #"{"availableCount":3}"#)
        }
        XCTAssertEqual(failure(api.previewGeneration(level: .n5, contentTypes: [.vocabulary])), .staleSession)
    }

    func test_disposingTheSubscriptionCancelsTheRequest() {
        let started = expectation(description: "started")
        let stopped = expectation(description: "cancelled")
        LearnerURLProtocol.handler = { _, _ in started.fulfill() }
        LearnerURLProtocol.onStop = { stopped.fulfill() }
        let subscription = api.previewGeneration(level: .n5, contentTypes: [.vocabulary]).subscribe()
        wait(for: [started], timeout: 3)
        subscription.dispose()
        wait(for: [stopped], timeout: 3)
    }

    // MARK: Fixtures

    static func deckJSON(_ id: String) -> String {
        """
        {"id":"\(id)","ownerUserId":"u","titleVi":"N5 Vocabulary","titleJa":null,"descriptionVi":null,"descriptionJa":null,
         "visibility":"private","status":"active","cardCount":2,"_count":{"cards":2},"createdAt":"2026-10-22T10:00:00Z","updatedAt":"2026-10-22T10:00:00Z",
         "cards":[
          {"id":"aaaaaaaa-0000-4000-8000-000000000002","position":1,"card":{"id":"bbbbbbbb-0000-4000-8000-000000000002","frontText":"猫","backText":"mèo","reading":null,"sourceId":"s2","sourceType":"lexeme"}},
          {"id":"aaaaaaaa-0000-4000-8000-000000000001","position":0,"card":{"id":"bbbbbbbb-0000-4000-8000-000000000001","frontText":"食べる","backText":"ăn","reading":"たべる","sourceId":"s1","sourceType":"lexeme"}}
         ]}
        """
    }
}

final class LearnerURLProtocol: URLProtocol {
    struct Sent { let method: String; let url: URL; let headers: [String: String]; let body: Data }
    static var handler: ((URLRequest, LearnerURLProtocol) -> Void)?
    static var onStop: (() -> Void)?
    static var requests: [Sent] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 { break }
                body.append(buffer, count: read)
            }
            stream.close()
        }
        Self.requests.append(Sent(method: request.httpMethod ?? "", url: request.url!, headers: request.allHTTPHeaderFields ?? [:], body: body))
        Self.handler?(request, self)
    }

    override func stopLoading() { Self.onStop?() }

    func respond(status: Int, json: String) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    func fail(_ error: URLError) {
        client?.urlProtocol(self, didFailWithError: error)
    }
}
