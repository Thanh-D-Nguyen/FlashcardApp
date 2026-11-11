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
    /// Read-only; safe to repeat. The server decides how many results to return and rejects any extra request field.
    func searchImages(query: String) -> Single<[BJTImageResultDTO]>
    /// Records the learner's choice (the server registers the download with the picture provider and keeps a pending-review copy)
    /// and returns the asset id. Each call creates server-side state, so a caller never retries it by itself.
    func selectImage(handle: String) -> Single<String>
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
    private struct ImageSearchBody: Encodable { let query: String }
    private struct ImageSelectionBody: Encodable { let handle: String }

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

    func searchImages(query: String) -> Single<[BJTImageResultDTO]> {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // The server accepts 1...200 characters; below two characters the website does not search either.
        guard (2...200).contains(trimmed.count) else { return .error(LearnerAPIError.invalidRequest(nil)) }
        let response: Single<BJTImageSearchResponseDTO> = perform(["media", "search-images"], method: .post, body: ImageSearchBody(query: trimmed))
        return response.map { $0.results }
    }

    func selectImage(handle: String) -> Single<String> {
        guard !handle.isEmpty, handle.count <= 16_000 else { return .error(LearnerAPIError.invalidRequest(nil)) }
        let response: Single<BJTImageSelectionDTO> = perform(["media", "image-selections"], method: .post, body: ImageSelectionBody(handle: handle))
        return response.map { selection in
            guard UUID(uuidString: selection.assetId) != nil else { throw LearnerAPIError.invalidResponse }
            return selection.assetId
        }
    }

    // MARK: Transport

    func perform<Response: Decodable, Body: Encodable>(_ path: [String], method: HTTPMethod, body: Body?,
                                                       query: [String: String] = [:]) -> Single<Response> {
        performData(path, method: method, body: body, query: query).map { data in
            do { return try JSONDecoder().decode(Response.self, from: data) } catch { throw LearnerAPIError.invalidResponse }
        }
    }

    /// The body of a 2xx answer, unchanged (for a file the learner keeps, such as a data export).
    func performData<Body: Encodable>(_ path: [String], method: HTTPMethod, body: Body?, query: [String: String] = [:]) -> Single<Data> {
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
                observer(Self.dataResult(of: response))
            }
            return Disposables.create { request.cancel() }
        }
    }

    static func dataResult(of response: AFDataResponse<Data>) -> Result<Data, Error> {
        if let error = response.error, response.response == nil {
            return .failure(transportError(error))
        }
        guard let status = response.response?.statusCode else { return .failure(LearnerAPIError.invalidResponse) }
        let data = response.data ?? Data()
        guard (200..<300).contains(status) else { return .failure(statusError(status, data: data)) }
        return .success(data)
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

/// A card of a deck being created on the account. `primaryImageAssetId` comes from `image-selections` or an upload;
/// the server rejects a direct `imageUrl`.
struct AccountDeckCardInput: Encodable, Equatable {
    let frontText: String
    let backText: String
    let reading: String?
    let primaryImageAssetId: String?
}

struct AccountDeckInput: Encodable, Equatable {
    let titleVi: String
    let visibility: String
    let cards: [AccountDeckCardInput]
}

/// Uploading a picture and creating a deck with it: the calls behind the website's deck composer.
protocol BJTAccountDeckAPIInterface: AnyObject {
    /// Uploads one JPEG/PNG/WebP/GIF (at most 10 MB; the app sends far less) and returns its asset id. Each call creates a
    /// server-side asset, but a repeated call is harmless: an unused asset is never shown to anyone.
    func uploadPicture(data: Data, fileName: String, mimeType: String) -> Single<String>
    /// Creates a deck with its cards. NOT idempotent: every call creates another deck, so callers never retry it.
    func createDeck(_ deck: AccountDeckInput) -> Single<BJTGeneratedDeckDTO>
}

extension BJTLearnerAPI: BJTAccountDeckAPIInterface {
    private struct PresignBody: Encodable { let fileName: String; let mimeType: String; let purpose: String }
    private struct CompleteBody: Encodable { let assetId: String; let byteSize: Int }

    /// The server accepts 10 MB; this is a client-side ceiling so a request never carries more than a card picture needs.
    static let uploadCeilingBytes = 10 * 1024 * 1024

    func uploadPicture(data: Data, fileName: String, mimeType: String) -> Single<String> {
        guard (1...Self.uploadCeilingBytes).contains(data.count), ["image/jpeg", "image/png", "image/webp", "image/gif"].contains(mimeType) else {
            return .error(LearnerAPIError.invalidRequest(nil))
        }
        let presign: Single<BJTPresignedUploadDTO> = perform(["media", "presign-upload"], method: .post,
                                                               body: PresignBody(fileName: fileName, mimeType: mimeType, purpose: "flashcard"))
        return presign.flatMap { [self] presigned -> Single<String> in
            // The address is derived from the id, not taken from the response: a response cannot redirect the upload.
            guard UUID(uuidString: presigned.assetId) != nil, presigned.uploadUrl == "/api/media/upload/" + presigned.assetId,
                  !presigned.uploadToken.isEmpty else { return .error(LearnerAPIError.invalidResponse) }
            return put(data, mimeType: mimeType, assetId: presigned.assetId, uploadToken: presigned.uploadToken)
                .andThen(Single.deferred { [self] in
                    let done: Single<BJTCompletedUploadDTO> = perform(["media", "complete-upload"], method: .post,
                                                                      body: CompleteBody(assetId: presigned.assetId, byteSize: data.count))
                    return done.map { _ in presigned.assetId }
                })
        }
    }

    func createDeck(_ deck: AccountDeckInput) -> Single<BJTGeneratedDeckDTO> {
        guard !deck.titleVi.isEmpty, !deck.cards.isEmpty else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return perform(["flashcards", "decks"], method: .post, body: deck)
    }

    private func put(_ data: Data, mimeType: String, assetId: String, uploadToken: String) -> Completable {
        Completable.create { [self] observer in
            guard let bearer = token(), let base = URL(string: baseURL()), let scheme = base.scheme, ["https", "http"].contains(scheme),
                  base.host != nil, var origin = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
                observer(.error(token() == nil ? LearnerAPIError.signInRequired : LearnerAPIError.server(0)))
                return Disposables.create()
            }
            origin.path = ""
            guard let originValue = origin.string else {
                observer(.error(LearnerAPIError.server(0)))
                return Disposables.create()
            }
            var headers: HTTPHeaders = ["Accept": "application/json", "Origin": originValue, "Content-Type": mimeType,
                                        "X-Media-Upload-Token": uploadToken]
            headers.add(.authorization(bearerToken: bearer))
            let url = ["media", "upload", assetId].reduce(base) { $0.appendingPathComponent($1) }
            let request = session.upload(data, to: url, method: .put, headers: headers, requestModifier: { $0.timeoutInterval = 60 })
            request.responseData { response in
                guard self.token() == bearer else { return observer(.error(LearnerAPIError.staleSession)) }
                if let error = response.error, response.response == nil { return observer(.error(Self.transportError(error))) }
                guard let status = response.response?.statusCode else { return observer(.error(LearnerAPIError.invalidResponse)) }
                (200..<300).contains(status) ? observer(.completed) : observer(.error(Self.statusError(status, data: response.data ?? Data())))
            }
            return Disposables.create { request.cancel() }
        }
    }
}
