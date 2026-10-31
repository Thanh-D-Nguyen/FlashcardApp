import Alamofire
import Foundation
import RxSwift

enum RemoteImageError: Error, Equatable, LocalizedError {
    case invalidURL
    case insecureScheme
    case notAnImage
    case tooLarge(maximumMegabytes: Int)
    case server(Int)
    case offline
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return NSLocalizedString("Enter a valid web address for the picture.", comment: "")
        case .insecureScheme: return NSLocalizedString("Picture addresses must start with https://.", comment: "")
        case .notAnImage: return NSLocalizedString("That address is not a JPEG, PNG, HEIC, WebP or GIF picture.", comment: "")
        case .tooLarge(let megabytes):
            return String(format: NSLocalizedString("The picture is larger than %lld MB.", comment: ""), megabytes)
        case .server(let status):
            return String(format: NSLocalizedString("The server answered with error %lld.", comment: ""), status)
        case .offline: return NSLocalizedString("You appear to be offline. Check the connection and try again.", comment: "")
        case .failed(let reason):
            return String(format: NSLocalizedString("Couldn't download the picture: %@", comment: ""), reason)
        }
    }
}

/// Downloads one picture for a card. Plain unauthenticated GET to a user-supplied https address: no session
/// token or header is ever attached, so no credential can leak to a third-party host. The one exception is the
/// API's own `/api/media/...` address (`APIImageAuthorization`), where the learner's copy needs the session.
/// Disposing the subscription cancels the request.
final class RemoteImageLoader {
    static let shared = RemoteImageLoader()
    /// Matches the website composer's upload limit.
    static let maximumBytes = 10 * 1024 * 1024
    static let acceptedContentTypes = ["image/jpeg", "image/png", "image/gif", "image/webp", "image/heic", "image/heif"]

    private let session: Session

    /// Ephemeral: no shared cookie jar or URL cache is involved in fetching a user-supplied address.
    init(session: Session = Session(configuration: .ephemeral)) {
        self.session = session
    }

    /// Validates user input; returns the normalized https URL.
    static func validatedURL(_ text: String) throws -> URL {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), url.host?.isEmpty == false,
              let scheme = url.scheme?.lowercased() else { throw RemoteImageError.invalidURL }
        guard scheme == "https" else { throw scheme == "http" ? RemoteImageError.insecureScheme : RemoteImageError.invalidURL }
        return url
    }

    /// `nil` stops a redirect: only another https address may be followed (never http, never a local-network host).
    static func allowedRedirect(_ request: URLRequest) -> URLRequest? {
        request.url?.scheme?.lowercased() == "https" ? request : nil
    }

    /// `authorization` is only attached when `url` is the API's own media address; for any other address it is ignored.
    func fetch(_ url: URL, authorization: String? = nil) -> Single<Data> {
        Single.create { [session] observer in
            let isAPIAddress = APIImageAuthorization.isAPIAddress(url)
            guard url.scheme?.lowercased() == "https" || isAPIAddress else {
                observer(.failure(RemoteImageError.insecureScheme))
                return Disposables.create()
            }
            let limit = Self.maximumBytes
            var headers: HTTPHeaders = ["Accept": Self.acceptedContentTypes.joined(separator: ", ")]
            if isAPIAddress, let authorization { headers.add(name: "Authorization", value: authorization) }
            var request: DataRequest!
            request = session.request(url, headers: headers)
                // A redirect may only lead to another https address, never to http or a local-network host.
                .redirect(using: Redirector(behavior: .modify { _, request, _ in Self.allowedRedirect(request) }))
                .validate(statusCode: 200..<300)
                .validate(contentType: Self.acceptedContentTypes)
                .validate { _, response, _ in
                    response.expectedContentLength > Int64(limit)
                        ? .failure(RemoteImageError.tooLarge(maximumMegabytes: limit / (1024 * 1024))) : .success(())
                }
                .downloadProgress { progress in
                    // Chunked responses have no Content-Length: stop as soon as the cap is crossed.
                    if progress.completedUnitCount > Int64(limit) { request.cancel() }
                }
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        observer(data.count > limit
                                 ? .failure(RemoteImageError.tooLarge(maximumMegabytes: limit / (1024 * 1024))) : .success(data))
                    case .failure(let error):
                        observer(.failure(Self.map(error, response: response.response, wasCancelledByLimit: response.data.map { $0.count > limit } ?? false)))
                    }
                }
            return Disposables.create { request.cancel() }
        }
    }

    private static func map(_ error: AFError, response: HTTPURLResponse?, wasCancelledByLimit: Bool) -> RemoteImageError {
        if wasCancelledByLimit { return .tooLarge(maximumMegabytes: maximumBytes / (1024 * 1024)) }
        switch error {
        case .responseValidationFailed(let reason):
            switch reason {
            case .unacceptableStatusCode(let code): return .server(code)
            case .unacceptableContentType, .missingContentType: return .notAnImage
            case .customValidationFailed(let inner): return (inner as? RemoteImageError) ?? .failed(inner.localizedDescription)
            default: return .failed(error.localizedDescription)
            }
        case .explicitlyCancelled:
            return .tooLarge(maximumMegabytes: maximumBytes / (1024 * 1024))
        case .sessionTaskFailed(let underlying):
            if let urlError = underlying as? URLError,
               [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost].contains(urlError.code) {
                return .offline
            }
            return .failed(underlying.localizedDescription)
        default:
            return .failed(error.localizedDescription)
        }
    }
}
