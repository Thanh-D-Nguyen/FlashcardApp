import Alamofire
import Foundation
import RxSwift

/// A share link of a deck, as the website builds it: `https://kiokoto.com/{locale}/decks/shared/{token}`, or the website's own
/// `…/flashcards?cloneToken={token}`. The token is 32 random bytes in base64url (43 characters, production 2026-11-11); it is a
/// capability: anyone holding it can preview and copy the deck until the owner stops sharing. It is never logged or stored by the app.
struct DeckShareLink: Equatable {
    let token: String

    static func isValid(token: String) -> Bool {
        (32...64).contains(token.count) && token.unicodeScalars.allSatisfy {
            ("A"..."Z").contains($0) || ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "-" || $0 == "_"
        }
    }

    /// Reads what the learner pasted: a link of `webHost` (or its `www.`), or the bare token. Any other host is refused so a
    /// look-alike link cannot pass for a Kiokoto deck.
    static func parse(_ text: String, webHost: String) -> DeckShareLink? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValid(token: trimmed) { return DeckShareLink(token: trimmed) }
        guard let components = URLComponents(string: trimmed), let scheme = components.scheme?.lowercased(),
              ["https", "http"].contains(scheme), let host = components.host?.lowercased(),
              host == webHost.lowercased() || host == "www." + webHost.lowercased() else { return nil }
        // Segments as sent (an encoded "/" stays inside its segment), and the token must be the last one.
        let parts = components.percentEncodedPath.split(separator: "/").map(String.init)
        if let index = parts.firstIndex(of: "shared"), index > 0, parts[index - 1] == "decks", index + 2 == parts.count,
           let token = parts[index + 1].removingPercentEncoding, isValid(token: token) {
            return DeckShareLink(token: token)
        }
        if let token = components.queryItems?.first(where: { $0.name == "cloneToken" })?.value, isValid(token: token) {
            return DeckShareLink(token: token)
        }
        return nil
    }

    /// The website's page for this link, which also works for someone without the app.
    func url(webOrigin: URL, localeCode: String) -> URL? {
        var components = URLComponents(url: webOrigin, resolvingAgainstBaseURL: false)
        components?.path = "/\(localeCode)/decks/shared/\(token)"
        components?.query = nil
        return components?.url
    }

    /// The website's origin for the API in use: the API base without its path (`https://kiokoto.com/api` → `https://kiokoto.com`).
    static func webOrigin(apiBase: String) -> URL? {
        guard var components = URLComponents(string: apiBase), components.host != nil else { return nil }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
    }
}

/// `GET /api/public/decks/{token}` (public): only public fields, at most 5 sample fronts.
struct BJTSharedDeckPreviewDTO: Decodable, Equatable {
    struct Sample: Decodable, Equatable {
        let frontText: String
        let reading: String?
    }

    let titleVi: String
    let titleJa: String?
    let descriptionVi: String?
    let cardCount: Int
    let cloneCount: Int?
    let sampleCards: [Sample]
}

/// `POST /api/flashcards/decks/clone/{token}` → 201 with the new deck (production also sends `visibility:""` and `_count.cards:0`
/// for it, so only the id and title are read).
struct BJTClonedDeckDTO: Decodable, Equatable {
    let id: String
    let titleVi: String
}

protocol BJTDeckShareAPIInterface: AnyObject {
    /// Returns the deck's share token, creating one the first time. Repeating it returns the same token (verified on production).
    func shareDeck(id: String) -> Single<String>
    /// Revokes the token: the link stops working for everyone.
    func unshareDeck(id: String) -> Single<Void>
    /// Public preview; works without an account.
    func sharedDeckPreview(token: String) -> Single<BJTSharedDeckPreviewDTO>
    /// Copies the deck into the account. NOT idempotent: each call creates another copy, so it is sent once per learner action.
    func cloneSharedDeck(token: String) -> Single<BJTClonedDeckDTO>
}

extension BJTLearnerAPI: BJTDeckShareAPIInterface {
    private struct NoBody: Encodable {}
    private struct ShareResponse: Decodable { let shareToken: String }
    private struct UnshareResponse: Decodable { let unshared: Bool }

    func shareDeck(id: String) -> Single<String> {
        guard UUID(uuidString: id) != nil else { return .error(LearnerAPIError.invalidRequest(nil)) }
        let response: Single<ShareResponse> = perform(["flashcards", "decks", id, "share"], method: .post, body: NoBody())
        return response.map { answer in
            guard DeckShareLink.isValid(token: answer.shareToken) else { throw LearnerAPIError.invalidResponse }
            return answer.shareToken
        }
    }

    func unshareDeck(id: String) -> Single<Void> {
        guard UUID(uuidString: id) != nil else { return .error(LearnerAPIError.invalidRequest(nil)) }
        let response: Single<UnshareResponse> = perform(["flashcards", "decks", id, "share"], method: .delete, body: Optional<NoBody>.none)
        return response.map { guard $0.unshared else { throw LearnerAPIError.invalidResponse } }
    }

    func sharedDeckPreview(token: String) -> Single<BJTSharedDeckPreviewDTO> {
        guard DeckShareLink.isValid(token: token) else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return BJTPublicDeckAPI.shared.preview(token: token)
    }

    func cloneSharedDeck(token: String) -> Single<BJTClonedDeckDTO> {
        guard DeckShareLink.isValid(token: token) else { return .error(LearnerAPIError.invalidRequest(nil)) }
        let response: Single<BJTClonedDeckDTO> = perform(["flashcards", "decks", "clone", token], method: .post, body: NoBody())
        return response.map { deck in
            guard UUID(uuidString: deck.id) != nil else { throw LearnerAPIError.invalidResponse }
            return deck
        }
    }
}

/// The anonymous preview request: no bearer and no cookie, so a guest sees exactly what anyone with the link sees.
final class BJTPublicDeckAPI {
    static let shared = BJTPublicDeckAPI()
    private let session: Session
    private let baseURL: () -> String

    init(session: Session? = nil, baseURL: @escaping () -> String = { EnvironmentConfig.baseUrl() }) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        self.session = session ?? Session(configuration: configuration)
        self.baseURL = baseURL
    }

    func preview(token: String) -> Single<BJTSharedDeckPreviewDTO> {
        guard DeckShareLink.isValid(token: token) else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return Single.create { [self] observer in
            guard let base = URL(string: baseURL()), let scheme = base.scheme, ["https", "http"].contains(scheme), base.host != nil else {
                observer(.failure(LearnerAPIError.server(0)))
                return Disposables.create()
            }
            let url = ["public", "decks", token].reduce(base) { $0.appendingPathComponent($1) }
            let request = session.request(url, method: .get, headers: ["Accept": "application/json"], requestModifier: { $0.timeoutInterval = 30 })
            request.responseData { response in observer(BJTLearnerAPI.result(of: response)) }
            return Disposables.create { request.cancel() }
        }
    }
}
