import Foundation
import Alamofire
import RxSwift

struct NativeLoginResponse: Decodable {
    let ok: Bool
    let token: String
}

struct NativeProfile: Decodable {
    let id: String
    let displayName: String
    let email: String
}

private struct NativeLogoutResponse: Decodable {
    let ok: Bool
}

enum NativeAuthError: Error, LocalizedError {
    case invalidInput, invalidCredentials, rateLimited, unauthorized, invalidResponse, unavailable, staleSession, storageFailed
    /// Google ID token malformed, rejected, or for an account the server will not sign in (HTTP 401 from `/auth/google`).
    case googleCredentialsRejected
    /// The Google email already belongs to another account; the server never links accounts automatically (HTTP 409).
    case googleAccountConflict
    case appleCredentialsRejected, appleAccountConflict
    /// The device could not reach the account service at all (no connection, timeout, connection lost).
    case offline

    var errorDescription: String? {
        switch self {
        case .invalidInput: return NSLocalizedString("Enter a valid email address and password.", comment: "")
        case .invalidCredentials: return NSLocalizedString("Email or password is incorrect.", comment: "")
        case .rateLimited: return NSLocalizedString("Too many sign-in attempts. Please try again later.", comment: "")
        case .unauthorized: return NSLocalizedString("Your session has expired. Please log in again.", comment: "")
        case .invalidResponse: return NSLocalizedString("The account service returned an invalid response.", comment: "")
        case .unavailable: return NSLocalizedString("The account service is unavailable. Please try again.", comment: "")
        case .staleSession: return NSLocalizedString("Sign-in was cancelled. Please try again.", comment: "")
        case .storageFailed: return NSLocalizedString("Unable to save your session securely. Please try again.", comment: "")
        case .googleCredentialsRejected:
            return NSLocalizedString("Google could not verify your account. Please try again.", comment: "Google sign-in rejected by the server")
        case .googleAccountConflict:
            return NSLocalizedString("An account with this email already exists. Sign in with your email and password instead.",
                                     comment: "Google sign-in: email already registered with a password")
        case .appleCredentialsRejected:
            return NSLocalizedString("Apple could not verify your account. Please try again.", comment: "")
        case .appleAccountConflict:
            return NSLocalizedString("An account with this email already exists. Sign in with your email and password instead.", comment: "")
        case .offline: return NSLocalizedString("No internet connection. Check your network and try again.", comment: "")
        }
    }
}

protocol NativeAuthAPIInterface {
    func login(email: String, password: String) -> Single<NativeLoginResponse>
    /// Exchanges a Google ID token (audience: the server's web client) for an application session token.
    func loginWithGoogle(idToken: String) -> Single<NativeLoginResponse>
    func loginWithApple(idToken: String, nonce: String) -> Single<NativeLoginResponse>
    func me(token: @escaping () -> String?) -> Single<NativeProfile>
    func logout(token: @escaping () -> String?) -> Single<Void>
    func deleteAccount(token: @escaping () -> String?) -> Single<Void>
}

extension NativeAuthAPIInterface {
    func loginWithApple(idToken: String, nonce: String) -> Single<NativeLoginResponse> { .error(NativeAuthError.unavailable) }
    func deleteAccount(token: @escaping () -> String?) -> Single<Void> { .error(NativeAuthError.unavailable) }
}

final class NativeAuthAPI: NativeAuthAPIInterface {
    private let session: Session
    private let baseURL: () -> String

    init(session: Session? = nil, baseURL: @escaping () -> String = { EnvironmentConfig.baseUrl() }) {
        // Native auth uses bearer tokens; never persist website cookies or cached responses.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        self.session = session ?? Session(configuration: configuration)
        self.baseURL = baseURL
    }

    func login(email: String, password: String) -> Single<NativeLoginResponse> {
        request(path: "login", method: .post, parameters: ["email": email, "password": password])
            .catch { error in
                if case NativeAuthError.unauthorized = error { return .error(NativeAuthError.invalidCredentials) }
                return .error(error)
            }
    }

    func loginWithGoogle(idToken: String) -> Single<NativeLoginResponse> {
        request(path: "google", method: .post, parameters: ["idToken": idToken])
            .catch { error in
                if case NativeAuthError.unauthorized = error { return .error(NativeAuthError.googleCredentialsRejected) }
                return .error(error)
            }
    }

    func loginWithApple(idToken: String, nonce: String) -> Single<NativeLoginResponse> {
        request(path: "apple", method: .post, parameters: ["idToken": idToken, "nonce": nonce])
            .catch { error in
                if case NativeAuthError.unauthorized = error { return .error(NativeAuthError.appleCredentialsRejected) }
                return .error(error)
            }
    }

    func me(token: @escaping () -> String?) -> Single<NativeProfile> {
        request(path: "me", method: .get, token: token)
    }

    func logout(token: @escaping () -> String?) -> Single<Void> {
        let response: Single<NativeLogoutResponse> = request(path: "logout", method: .post, token: token)
        return response.map {
            guard $0.ok else { throw NativeAuthError.invalidResponse }
            return ()
        }
    }

    func deleteAccount(token: @escaping () -> String?) -> Single<Void> {
        let response: Single<NativeLogoutResponse> = request(path: "delete", method: .post, token: token)
        return response.map {
            guard $0.ok else { throw NativeAuthError.invalidResponse }
            return ()
        }
    }

    private func request<Response: Decodable>(path: String, method: HTTPMethod,
                                              parameters: [String: String]? = nil,
                                              token: (() -> String?)? = nil) -> Single<Response> {
        Single.create { [self] observer in
            guard let base = URL(string: baseURL()), let scheme = base.scheme,
                  ["https", "http"].contains(scheme), base.host != nil,
                  base.user == nil, base.password == nil, base.query == nil, base.fragment == nil else {
                observer(.failure(NativeAuthError.unavailable))
                return Disposables.create()
            }
            guard var origin = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
                observer(.failure(NativeAuthError.unavailable))
                return Disposables.create()
            }
            origin.path = ""
            guard let originValue = origin.string else {
                observer(.failure(NativeAuthError.unavailable))
                return Disposables.create()
            }
            // Mounted login/logout routes enforce CSRF Origin even for native bearer sessions.
            var headers: HTTPHeaders = ["Accept": "application/json", "Origin": originValue]
            if let token {
                guard let value = token(), Self.isValidToken(value) else {
                    observer(.failure(NativeAuthError.unauthorized))
                    return Disposables.create()
                }
                headers.add(.authorization(bearerToken: value))
            }
            let url = base.appendingPathComponent("auth").appendingPathComponent(path)
            let request = session.request(url, method: method, parameters: parameters,
                                          encoding: JSONEncoding.default, headers: headers)
                .validate()
                .responseDecodable(of: Response.self) { response in
                    switch response.result {
                    case .success(let value): observer(.success(value))
                    case .failure(let error):
                        let isCredentialExchange = path == "login" || path == "google" || path == "apple"
                        if response.response?.statusCode == 401 {
                            observer(.failure(NativeAuthError.unauthorized))
                        } else if isCredentialExchange, response.response?.statusCode == 429 {
                            observer(.failure(NativeAuthError.rateLimited))
                        } else if (path == "google" || path == "apple"), response.response?.statusCode == 409 {
                            observer(.failure(path == "apple" ? NativeAuthError.appleAccountConflict : NativeAuthError.googleAccountConflict))
                        } else if error.isResponseSerializationError {
                            observer(.failure(NativeAuthError.invalidResponse))
                        } else if response.response == nil, Self.isConnectivityFailure(error) {
                            observer(.failure(NativeAuthError.offline))
                        } else {
                            observer(.failure(NativeAuthError.unavailable))
                        }
                    }
                }
            return Disposables.create { request.cancel() }
        }
    }

    private static func isConnectivityFailure(_ error: AFError) -> Bool {
        guard let code = (error.underlyingError as? URLError)?.code else { return false }
        // A timeout or an unreachable host may be the service rather than the device, so those stay `.unavailable`.
        return [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff].contains(code)
    }

    static func isValidToken(_ token: String) -> Bool {
        !token.isEmpty && token.unicodeScalars.allSatisfy { $0.value > 32 && $0.value < 127 }
    }
}
