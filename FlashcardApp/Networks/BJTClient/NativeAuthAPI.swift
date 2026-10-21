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
    case invalidInput, invalidCredentials, unauthorized, invalidResponse, unavailable, staleSession, storageFailed

    var errorDescription: String? {
        switch self {
        case .invalidInput: return NSLocalizedString("Enter a valid email address and password.", comment: "")
        case .invalidCredentials: return NSLocalizedString("Email or password is incorrect.", comment: "")
        case .unauthorized: return NSLocalizedString("Your session has expired. Please log in again.", comment: "")
        case .invalidResponse: return NSLocalizedString("The account service returned an invalid response.", comment: "")
        case .unavailable: return NSLocalizedString("The account service is unavailable. Please try again.", comment: "")
        case .staleSession: return NSLocalizedString("Sign-in was cancelled. Please try again.", comment: "")
        case .storageFailed: return NSLocalizedString("Unable to save your session securely. Please try again.", comment: "")
        }
    }
}

protocol NativeAuthAPIInterface {
    func login(email: String, password: String) -> Single<NativeLoginResponse>
    func me(token: @escaping () -> String?) -> Single<NativeProfile>
    func logout(token: @escaping () -> String?) -> Single<Void>
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
                        if response.response?.statusCode == 401 {
                            observer(.failure(NativeAuthError.unauthorized))
                        } else if error.isResponseSerializationError {
                            observer(.failure(NativeAuthError.invalidResponse))
                        } else {
                            observer(.failure(NativeAuthError.unavailable))
                        }
                    }
                }
            return Disposables.create { request.cancel() }
        }
    }

    static func isValidToken(_ token: String) -> Bool {
        !token.isEmpty && token.unicodeScalars.allSatisfy { $0.value > 32 && $0.value < 127 }
    }
}
