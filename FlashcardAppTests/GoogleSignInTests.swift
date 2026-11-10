import XCTest
import RxSwift
import UIKit
@testable import FlashcardApp

final class GoogleSignInTests: XCTestCase {
    private let ios = "987654321098-abcdef0123456789abcdef0123456789.apps.googleusercontent.com"
    private let web = "112477118682-4b6pb2ph8i2lrbao13l90rvn5qitra4g.apps.googleusercontent.com"
    private let scheme = "com.googleusercontent.apps.987654321098-abcdef0123456789abcdef0123456789"

    // MARK: Configuration

    func testConfigurationRequiresBothClientsAndTheMatchingRedirectScheme() {
        let configuration = GoogleSignInConfiguration(clientID: ios, serverClientID: web, urlSchemes: ["other", scheme])
        XCTAssertEqual(configuration?.clientID, ios)
        XCTAssertEqual(configuration?.serverClientID, web)
    }

    func testConfigurationRejectsMissingMalformedAndSwappedClients() {
        XCTAssertNil(GoogleSignInConfiguration(clientID: nil, serverClientID: web, urlSchemes: [scheme]))
        XCTAssertNil(GoogleSignInConfiguration(clientID: ios, serverClientID: nil, urlSchemes: [scheme]))
        // Build settings expand to these when the iOS client has not been created yet.
        XCTAssertNil(GoogleSignInConfiguration(clientID: ".apps.googleusercontent.com", serverClientID: web, urlSchemes: ["com.googleusercontent.apps."]))
        XCTAssertNil(GoogleSignInConfiguration(clientID: "", serverClientID: web, urlSchemes: [scheme]))
        XCTAssertNil(GoogleSignInConfiguration(clientID: "not-a-client", serverClientID: web, urlSchemes: [scheme]))
        XCTAssertNil(GoogleSignInConfiguration(clientID: ios, serverClientID: "web", urlSchemes: [scheme]))
        XCTAssertNil(GoogleSignInConfiguration(clientID: " \(ios)", serverClientID: web, urlSchemes: [scheme]))
    }

    func testTheWebClientCannotBeUsedAsTheIOSClient() {
        let webScheme = "com.googleusercontent.apps.112477118682-4b6pb2ph8i2lrbao13l90rvn5qitra4g"
        XCTAssertNil(GoogleSignInConfiguration(clientID: web, serverClientID: web, urlSchemes: [webScheme]))
    }

    func testConfigurationNeedsTheReversedClientIDURLScheme() {
        XCTAssertNil(GoogleSignInConfiguration(clientID: ios, serverClientID: web, urlSchemes: []))
        XCTAssertNil(GoogleSignInConfiguration(clientID: ios, serverClientID: web, urlSchemes: ["com.ds.FlashcardApp"]))
        // The scheme of another environment's client must not satisfy this one.
        XCTAssertNil(GoogleSignInConfiguration(clientID: ios, serverClientID: web,
                                               urlSchemes: ["com.googleusercontent.apps.111111111111-zzzz"]))
    }

    func testTheShippedTestHostIsConsistentlyConfiguredOrDisabled() {
        // Whatever the build settings provide, the app never half-enables Google: both the Info.plist client IDs and the
        // URL scheme are present, or the configuration is nil and the button is hidden.
        let configuration = GoogleSignInConfiguration(bundle: Bundle(for: GoogleIDTokenProvider.self))
        let info = Bundle(for: GoogleIDTokenProvider.self)
        XCTAssertEqual(info.object(forInfoDictionaryKey: "GIDServerClientID") as? String, web,
                       "The server audience must be the Web client the backend verifies")
        if let configuration {
            XCTAssertNotEqual(configuration.clientID, configuration.serverClientID)
        }
        XCTAssertEqual(GoogleIDTokenProvider(configuration: configuration).isAvailable, configuration != nil)
    }

    // MARK: Audience

    private func jwt(claims: [String: Any]) -> String {
        func encode(_ object: [String: Any]) -> String {
            let data = try! JSONSerialization.data(withJSONObject: object)
            return data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        }
        return [encode(["alg": "RS256"]), encode(claims), "signature"].joined(separator: ".")
    }

    func testAudienceIsReadFromTheTokenPayload() {
        XCTAssertEqual(GoogleSignInConfiguration.audience(ofIDToken: jwt(claims: ["aud": web, "sub": "1"])), web)
        // Payloads whose base64 needs padding and URL-safe characters.
        XCTAssertEqual(GoogleSignInConfiguration.audience(ofIDToken: jwt(claims: ["aud": web, "name": "Nguyễn Thanh ???>>>"])), web)
    }

    func testAudienceOfMalformedTokensIsNil() {
        for token in ["", "a.b", "a.b.c.d", "a.!!!.c", jwt(claims: ["sub": "1"]), jwt(claims: ["aud": 7])] {
            XCTAssertNil(GoogleSignInConfiguration.audience(ofIDToken: token), token)
        }
    }

    // MARK: Provider and interactor

    func testUnconfiguredProviderFailsWithoutOpeningGoogle() {
        let provider = GoogleIDTokenProvider(configuration: nil)
        XCTAssertFalse(provider.isAvailable)
        var failure: Error?
        _ = provider.idToken(presenting: UIViewController()).subscribe(onFailure: { failure = $0 })
        XCTAssertEqual(failure as? GoogleSignInError, .notConfigured)
    }

    func testInteractorExchangesTheGoogleTokenForAWebsiteSession() {
        let tokens = StubGoogleTokens(result: .success("header.payload.signature"))
        let api = RecordingGoogleAuthAPI()
        let keychain = InMemoryTokens()
        let interactor = MailLoginInteractor(session: AuthSession(tokens: keychain, api: api), googleTokens: tokens)
        let screen = UIViewController()
        var user: SocialUserEntity?

        _ = interactor.loginWithGoogle(presenting: screen).subscribe(onSuccess: { user = $0 }, onFailure: { XCTFail("\($0)") })

        XCTAssertTrue(tokens.presenter === screen)
        XCTAssertEqual(api.googleIDTokens, ["header.payload.signature"])
        XCTAssertEqual(keychain.accessToken, "app-session-token", "The stored session is the application token")
        XCTAssertEqual(keychain.userId, "7c2218b4-590b-49b2-8be0-076fd9992135")
        XCTAssertEqual(user?.id, "7c2218b4-590b-49b2-8be0-076fd9992135")
    }

    func testInteractorDoesNotCallTheServerWhenGoogleFailsOrIsCancelled() {
        for failure in [GoogleSignInError.cancelled, .failed, .notConfigured] {
            let api = RecordingGoogleAuthAPI()
            let keychain = InMemoryTokens()
            let interactor = MailLoginInteractor(session: AuthSession(tokens: keychain, api: api),
                                                 googleTokens: StubGoogleTokens(result: .failure(failure)))
            var error: Error?
            _ = interactor.loginWithGoogle(presenting: UIViewController()).subscribe(onFailure: { error = $0 })

            XCTAssertEqual(error as? GoogleSignInError, failure)
            XCTAssertTrue(api.googleIDTokens.isEmpty)
            XCTAssertNil(keychain.accessToken)
        }
    }

    func testInteractorReportsGoogleAvailabilityFromTheProvider() {
        let provider = StubGoogleTokens(result: .failure(.failed))
        let interactor = MailLoginInteractor(session: AuthSession(tokens: InMemoryTokens(), api: RecordingGoogleAuthAPI()),
                                             googleTokens: provider)
        XCTAssertTrue(interactor.isGoogleSignInAvailable)
        provider.isAvailable = false
        XCTAssertFalse(interactor.isGoogleSignInAvailable)
    }
}

private final class StubGoogleTokens: GoogleIDTokenProviding {
    var isAvailable = true
    private let result: Result<String, GoogleSignInError>
    private(set) var presenter: UIViewController?
    init(result: Result<String, GoogleSignInError>) { self.result = result }
    func idToken(presenting viewController: UIViewController) -> Single<String> {
        presenter = viewController
        return Single.create { [result] observer in
            switch result {
            case .success(let token): observer(.success(token))
            case .failure(let error): observer(.failure(error))
            }
            return Disposables.create()
        }
    }
}

private final class InMemoryTokens: AuthTokenManagerInterface {
    var accessToken: String?
    var userId: String?
    func save(accessToken: String, userId: String) throws { self.accessToken = accessToken; self.userId = userId }
    func clear() throws { accessToken = nil; userId = nil }
}

private final class RecordingGoogleAuthAPI: NativeAuthAPIInterface {
    private(set) var googleIDTokens: [String] = []
    func login(email: String, password: String) -> Single<NativeLoginResponse> { .error(NativeAuthError.unavailable) }
    func loginWithGoogle(idToken: String) -> Single<NativeLoginResponse> {
        googleIDTokens.append(idToken)
        return .just(NativeLoginResponse(ok: true, token: "app-session-token"))
    }
    func me(token: @escaping () -> String?) -> Single<NativeProfile> {
        .just(NativeProfile(id: "7c2218b4-590b-49b2-8be0-076fd9992135", displayName: "Learner", email: "learner@example.com"))
    }
    func logout(token: @escaping () -> String?) -> Single<Void> { .just(()) }
}
