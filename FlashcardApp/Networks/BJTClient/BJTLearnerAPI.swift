import Alamofire
import Foundation
import RxSwift

/// Why an authenticated learner request failed. Each case maps to one thing the learner can do about it.
enum LearnerAPIError: Error, Equatable, LocalizedError {
    /// No session, or the server answered 401: the learner has to sign in (again).
    case signInRequired
    /// 403 from the CSRF guard: the API's own origin is not on its allow-list. A deployment problem, not the learner's.
    case originRejected
    /// Any other 403 (for example "not owner").
    case forbidden(String?)
    case invalidRequest(String?)
    case rateLimited
    /// 503: the feature is not available on the server (for example no image provider is configured).
    case serviceUnavailable(String?)
    case server(Int)
    /// The request never reached the server (no connection), so nothing was changed there.
    case offline
    /// The connection broke after the request may have been sent: whether the server acted is unknown.
    case interrupted
    case invalidResponse
    /// The learner signed out or switched account while the request was running; its result is discarded.
    case staleSession
    case notFound

    var errorDescription: String? {
        switch self {
        case .signInRequired: return NSLocalizedString("Sign in to use this feature.", comment: "")
        case .originRejected:
            return NSLocalizedString("The server rejected this app's request (403). The app's address is not on the server's allow-list, so this needs a server configuration change.", comment: "")
        case .forbidden: return NSLocalizedString("Your account isn't allowed to do that.", comment: "")
        case .invalidRequest(let message): return message ?? NSLocalizedString("The server did not accept these choices.", comment: "")
        case .rateLimited: return NSLocalizedString("Too many requests. Please wait a moment and try again.", comment: "")
        case .serviceUnavailable: return NSLocalizedString("This feature isn't available on the server right now.", comment: "")
        case .server(let status): return String(format: NSLocalizedString("The server answered with error %lld.", comment: ""), status)
        case .offline: return NSLocalizedString("You appear to be offline. Check the connection and try again.", comment: "")
        case .interrupted: return NSLocalizedString("The connection was interrupted.", comment: "")
        case .invalidResponse: return NSLocalizedString("The server returned an unexpected response.", comment: "")
        case .staleSession: return NSLocalizedString("You signed out while this was running, so the result was discarded.", comment: "")
        case .notFound: return NSLocalizedString("The server could not find that item.", comment: "")
        }
    }
}

protocol BJTLearnerAPIInterface: AnyObject {
    /// Number of cards available for the filters. Read-only.
    func previewGeneration(level: GenerationLevel, contentTypes: [GenerationContentType]) -> Single<Int>
    /// Creates a deck on the server. NOT idempotent: every call creates another deck, so callers never retry it.
    func generateDeck(_ request: DeckGenerationRequest) -> Single<BJTGeneratedDeckDTO>
    /// Read-only; safe to repeat.
    func deck(id: String) -> Single<BJTRemoteDeckDTO>
    func searchImages(query: String, limit: Int) -> Single<[BJTImageResultDTO]>
}

/// Authenticated calls for the learner's flashcards and media, using the opaque session token as a bearer.
/// Unsafe methods send the API's own origin, which the Go CSRF guard checks against `CORS_ORIGINS` (the same
/// approach `NativeAuthAPI` uses for login). Nothing here fabricates a different origin: if the server rejects it
/// the learner sees `originRejected`.
final class BJTLearnerAPI: BJTLearnerAPIInterface {
    static let shared = BJTLearnerAPI()

    private let session: Session
    private let baseURL: () -> String
    private let token: () -> String?

    init(session: Session? = nil,
         baseURL: @escaping () -> String = { EnvironmentConfig.baseUrl() },
         token: @escaping () -> String? = { AuthSession.shared.bearerToken }) {
        // Bearer auth only: never keep website cookies or cache an authenticated response.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        self.session = session ?? Session(configuration: configuration)
        self.baseURL = baseURL
        self.token = token
    }

    // MARK: Operations

    private struct PreviewBody: Encodable { let levels: [String]; let sourceTypes: [String] }
    private struct GenerateBody: Encodable {
        let name: String, levels: [String], sourceTypes: [String], direction: String, limit: Int
    }
    private struct ImageSearchBody: Encodable { let query: String; let limit: Int }

    func previewGeneration(level: GenerationLevel, contentTypes: [GenerationContentType]) -> Single<Int> {
        let body = PreviewBody(levels: [level.rawValue], sourceTypes: contentTypes.map(\.rawValue))
        let response: Single<BJTGenerationPreviewDTO> = perform(["flashcards", "decks", "generate", "preview"], method: .post, body: body)
        return response.map { $0.availableCount }
    }

    func generateDeck(_ request: DeckGenerationRequest) -> Single<BJTGeneratedDeckDTO> {
        guard request.issues.isEmpty else {
            return .error(LearnerAPIError.invalidRequest(nil))
        }
        let body = GenerateBody(name: request.trimmedName, levels: [request.level.rawValue], sourceTypes: request.sourceTypes,
                                direction: request.direction.rawValue, limit: request.count)
        return perform(["flashcards", "decks", "generate"], method: .post, body: body)
    }

    func deck(id: String) -> Single<BJTRemoteDeckDTO> {
        // The id becomes a path segment: accept only a UUID so nothing can alter the route.
        guard UUID(uuidString: id) != nil else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return perform(["flashcards", "decks", id], method: .get, body: Optional<PreviewBody>.none)
    }

    func searchImages(query: String, limit: Int) -> Single<[BJTImageResultDTO]> {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, (1...20).contains(limit) else { return .error(LearnerAPIError.invalidRequest(nil)) }
        let response: Single<BJTImageSearchResponseDTO> = perform(["media", "search-images"], method: .post,
                                                                   body: ImageSearchBody(query: trimmed, limit: limit))
        return response.map { $0.images }
    }

    // MARK: Transport

    func perform<Response: Decodable, Body: Encodable>(_ path: [String], method: HTTPMethod, body: Body?,
                                                       query: [String: String] = [:]) -> Single<Response> {
        Single.create { [self] observer in
            guard let bearer = token() else {
                observer(.failure(LearnerAPIError.signInRequired))
                return Disposables.create()
            }
            guard let base = URL(string: baseURL()), let scheme = base.scheme, ["https", "http"].contains(scheme),
                  base.host != nil, base.user == nil, base.password == nil, base.query == nil, base.fragment == nil,
                  var origin = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
                observer(.failure(LearnerAPIError.server(0)))
                return Disposables.create()
            }
            origin.path = ""
            guard let originValue = origin.string else {
                observer(.failure(LearnerAPIError.server(0)))
                return Disposables.create()
            }
            var headers: HTTPHeaders = ["Accept": "application/json", "Origin": originValue]
            headers.add(.authorization(bearerToken: bearer))
            var url = path.reduce(base) { $0.appendingPathComponent($1) }
            if !query.isEmpty, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
                url = components.url ?? url
            }

            let request: DataRequest
            if let body {
                request = session.request(url, method: method, parameters: body, encoder: JSONParameterEncoder.default,
                                          headers: headers, requestModifier: { $0.timeoutInterval = 30 })
            } else {
                request = session.request(url, method: method, headers: headers, requestModifier: { $0.timeoutInterval = 30 })
            }
            request.responseData { response in
                // A logout or account switch while the request ran: drop the result instead of acting on it.
                guard self.token() == bearer else { return observer(.failure(LearnerAPIError.staleSession)) }
                observer(Self.result(of: response))
            }
            return Disposables.create { request.cancel() }
        }
    }

    static func result<Response: Decodable>(of response: AFDataResponse<Data>) -> Result<Response, Error> {
        if let error = response.error, response.response == nil {
            return .failure(transportError(error))
        }
        guard let status = response.response?.statusCode else { return .failure(LearnerAPIError.invalidResponse) }
        let data = response.data ?? Data()
        guard (200..<300).contains(status) else { return .failure(statusError(status, data: data)) }
        do {
            return .success(try JSONDecoder().decode(Response.self, from: data))
        } catch {
            return .failure(LearnerAPIError.invalidResponse)
        }
    }

    static func transportError(_ error: AFError) -> LearnerAPIError {
        let code = (error.underlyingError as? URLError)?.code
        switch code {
        case .notConnectedToInternet?, .dataNotAllowed?, .cannotFindHost?, .cannotConnectToHost?, .internationalRoamingOff?:
            return .offline
        default:
            return .interrupted
        }
    }

    static func statusError(_ status: Int, data: Data) -> LearnerAPIError {
        let message = (try? JSONDecoder().decode(BJTErrorBodyDTO.self, from: data))?.error
        switch status {
        case 400: return .invalidRequest(nil)
        case 401: return .signInRequired
        // The CSRF guard answers "forbidden: missing origin" / "forbidden: untrusted origin".
        case 403: return message?.lowercased().hasPrefix("forbidden:") == true ? .originRejected : .forbidden(message)
        case 404: return .notFound
        case 429: return .rateLimited
        case 503: return .serviceUnavailable(message)
        default: return .server(status)
        }
    }
}
