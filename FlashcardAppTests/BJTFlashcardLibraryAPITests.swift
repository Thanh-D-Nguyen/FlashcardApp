import Alamofire
import RxSwift
import XCTest
@testable import FlashcardApp

/// Request shape and decoding of the flashcard library calls the Cards tab makes (deck list, due cards, rating,
/// archive). Fixtures mirror the JSON tags in `flashcarddeck/store.go` and `flashcardreview/store.go`.
final class BJTFlashcardLibraryAPITests: XCTestCase {
    private var session: Session!
    private var api: BJTLearnerAPI!
    private var bag: DisposeBag!
    private var token: String? = "opaque-session-token"
    private let ufId = "99999999-2222-4333-8444-555555555555"

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

    // MARK: Deck list

    func test_decksReadsTheListWithTheLimitAndForeignDecksWithoutAnOwner() throws {
        LearnerURLProtocol.handler = { _, proto in
            proto.respond(status: 200, json: """
            [{"id":"d1","ownerUserId":"me","titleVi":"Của tôi","titleJa":null,"descriptionVi":"mô tả","descriptionJa":null,"visibility":"private","status":"active","cardCount":3,"_count":{"cards":3},"shareToken":"tok","createdAt":"2026-10-22T10:00:00.123456Z","updatedAt":"2026-10-23T10:00:00Z"},
             {"id":"d2","ownerUserId":null,"titleVi":"Công khai","titleJa":"公開","descriptionVi":null,"descriptionJa":null,"visibility":"public","status":"active","cardCount":80,"_count":{"cards":80},"createdAt":"2026-10-20T10:00:00Z","updatedAt":"2026-10-20T10:00:00Z"}]
            """)
        }
        let decks = try result(api.libraryDecks(limit: 80)).get()
        XCTAssertEqual(decks.map(\.id), ["d1", "d2"])
        XCTAssertEqual(decks[0].ownerUserId, "me")
        XCTAssertNil(decks[1].ownerUserId, "The server redacts the owner of a deck that is not the learner's")
        XCTAssertEqual(decks[1].cardCount, 80)
        XCTAssertEqual(decks[1].titleJa, "公開")
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.method, "GET")
        XCTAssertEqual(sent.url.path, "/api/flashcards/decks")
        XCTAssertEqual(URLComponents(url: sent.url, resolvingAgainstBaseURL: false)?.queryItems, [URLQueryItem(name: "limit", value: "80")])
        XCTAssertEqual(sent.headers["Authorization"], "Bearer opaque-session-token")
    }

    func test_decksRejectsALimitTheServerWouldClamp() {
        guard case .failure(let error) = result(api.libraryDecks(limit: 500)) else { return XCTFail("expected failure") }
        XCTAssertEqual(error as? LearnerAPIError, .invalidRequest(nil))
        XCTAssertTrue(LearnerURLProtocol.requests.isEmpty)
    }

    // MARK: Due cards

    func test_dueCardsDecodesTheSchedulingFields() throws {
        LearnerURLProtocol.handler = { _, proto in
            proto.respond(status: 200, json: """
            [{"id":"\(self.ufId)","cardId":"c1","state":"learning","dueAt":"2026-10-29T08:00:00Z","intervalDays":3,"easeFactor":2.5,"repetitions":2,"lapses":1,"leeched":false,"comebackMode":false,
              "card":{"id":"c1","frontText":"食べる","backText":"ăn","reading":"たべる"}}]
            """)
        }
        let cards = try result(api.dueCards(limit: 50)).get()
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].id, ufId)
        XCTAssertEqual(cards[0].state, "learning")
        XCTAssertEqual(cards[0].card.frontText, "食べる")
        XCTAssertEqual(cards[0].card.reading, "たべる")
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.url.path, "/api/flashcards/reviews/due")
        XCTAssertEqual(URLComponents(url: sent.url, resolvingAgainstBaseURL: false)?.queryItems, [URLQueryItem(name: "limit", value: "50")])
    }

    func test_dueCardsTreatsANullListAsNothingDue() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: "null") }
        XCTAssertEqual(try result(api.dueCards(limit: 50)).get().count, 0)
    }

    // MARK: Rating

    func test_submitReviewPostsTheRatingAndElapsedTimeToTheCardsOwnRoute() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: #"{"success":true}"#) }
        _ = try result(api.submitReview(userFlashcardId: ufId, rating: .good, elapsedMs: 4200)).get()
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.url.path, "/api/flashcards/reviews/\(ufId)")
        XCTAssertEqual(sent.headers["Origin"], "https://api.test")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: sent.body) as? [String: Any])
        XCTAssertEqual(body["rating"] as? String, "good")
        XCTAssertEqual(body["elapsedMs"] as? Int, 4200)
        XCTAssertEqual(Set(body.keys), ["rating", "elapsedMs"])
    }

    func test_submitReviewRefusesAnIdThatIsNotAUUIDInsteadOfBuildingARoute() {
        guard case .failure(let error) = result(api.submitReview(userFlashcardId: "../decks", rating: .again, elapsedMs: 1)) else { return XCTFail("expected failure") }
        XCTAssertEqual(error as? LearnerAPIError, .invalidRequest(nil))
        XCTAssertTrue(LearnerURLProtocol.requests.isEmpty)
    }

    func test_submitReviewNeverRetriesAServerError() {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 500, json: #"{"error":"internal error"}"#) }
        guard case .failure(let error) = result(api.submitReview(userFlashcardId: ufId, rating: .easy, elapsedMs: nil)) else { return XCTFail("expected failure") }
        XCTAssertEqual(error as? LearnerAPIError, .server(500))
        XCTAssertEqual(LearnerURLProtocol.requests.count, 1, "A rating changes the schedule; it is sent once")
    }

    func test_submitReviewMapsAnUnknownCardToNotFound() {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 404, json: #"{"error":"user flashcard not found"}"#) }
        guard case .failure(let error) = result(api.submitReview(userFlashcardId: ufId, rating: .hard, elapsedMs: 10)) else { return XCTFail("expected failure") }
        XCTAssertEqual(error as? LearnerAPIError, .notFound)
    }

    // MARK: Archive

    func test_archiveDeckPostsToTheArchiveRoute() throws {
        let id = "11111111-2222-4333-8444-555555555555"
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: #"{"archived":true}"#) }
        _ = try result(api.archiveDeck(id: id)).get()
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.url.path, "/api/flashcards/decks/\(id)/archive")
    }

    func test_archiveByANonOwnerIsForbidden() {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 403, json: #"{"error":"not owner"}"#) }
        guard case .failure(let error) = result(api.archiveDeck(id: "11111111-2222-4333-8444-555555555555")) else { return XCTFail("expected failure") }
        XCTAssertEqual(error as? LearnerAPIError, .forbidden("not owner"))
    }

    // MARK: Deck detail

    func test_deckDetailKeepsVisibilityAndOwnership() throws {
        let id = "11111111-2222-4333-8444-555555555555"
        LearnerURLProtocol.handler = { _, proto in
            proto.respond(status: 200, json: """
            {"id":"\(id)","ownerUserId":null,"titleVi":"Công khai","titleJa":null,"descriptionVi":"Từ vựng","descriptionJa":null,"visibility":"public","status":"active","cardCount":1,
             "cards":[{"id":"aaaaaaaa-0000-4000-8000-000000000001","position":0,"card":{"id":"bbbbbbbb-0000-4000-8000-000000000001","frontText":"猫","backText":"mèo","reading":"ねこ","sourceId":"s","sourceType":"lexeme"}}]}
            """)
        }
        let deck = try result(api.deck(id: id)).get()
        XCTAssertEqual(deck.visibility, "public")
        XCTAssertNil(deck.ownerUserId)
        XCTAssertEqual(deck.descriptionVi, "Từ vựng")
        XCTAssertEqual(deck.cards.count, 1)
    }
}
