import XCTest
import Alamofire
import RxSwift
import Security
@testable import FlashcardApp

private final class MemoryAuthTokens: AuthTokenManagerInterface {
    var accessToken: String?
    var userId: String?
    var saveError: Error?
    var clearError: Error?
    func save(accessToken: String, userId: String) throws {
        if let saveError { throw saveError }
        self.accessToken = accessToken
        self.userId = userId
    }
    func clear() throws {
        if let clearError { throw clearError }
        accessToken = nil
        userId = nil
    }
}

private final class ControlledAuthAPI: NativeAuthAPIInterface {
    let loginResult = PublishSubject<NativeLoginResponse>()
    let profileResult = PublishSubject<NativeProfile>()
    let logoutResult = PublishSubject<Void>()
    let deleteResult = PublishSubject<Void>()
    let googleResult = PublishSubject<NativeLoginResponse>()
    let appleResult = PublishSubject<NativeLoginResponse>()
    var loginCalls = 0
    var googleCalls = 0
    var googleIDToken: String?
    var appleIDToken: String?
    var appleNonce: String?
    var cancelled = false
    var email: String?
    var password: String?
    var bearer: String?
    func login(email: String, password: String) -> Single<NativeLoginResponse> {
        loginCalls += 1
        self.email = email
        self.password = password
        return loginResult.take(1).asSingle().do(onDispose: { self.cancelled = true })
    }
    func loginWithGoogle(idToken: String) -> Single<NativeLoginResponse> {
        googleCalls += 1
        googleIDToken = idToken
        return googleResult.take(1).asSingle().do(onDispose: { self.cancelled = true })
    }
    func loginWithApple(idToken: String, nonce: String) -> Single<NativeLoginResponse> {
        appleIDToken = idToken
        appleNonce = nonce
        return appleResult.take(1).asSingle()
    }
    func me(token: @escaping () -> String?) -> Single<NativeProfile> {
        bearer = token()
        return profileResult.take(1).asSingle()
    }
    func logout(token: @escaping () -> String?) -> Single<Void> {
        bearer = token()
        return logoutResult.take(1).asSingle()
    }
    func deleteAccount(token: @escaping () -> String?) -> Single<Void> {
        bearer = token()
        return deleteResult.take(1).asSingle()
    }
}

final class AuthSessionTests: XCTestCase {
    private let userID = "7c2218b4-590b-49b2-8be0-076fd9992135"
    private var tokens: MemoryAuthTokens!
    private var api: ControlledAuthAPI!
    private var session: AuthSession!
    private var bag: DisposeBag!

    override func setUp() {
        tokens = MemoryAuthTokens()
        api = ControlledAuthAPI()
        session = AuthSession(tokens: tokens, api: api)
        bag = DisposeBag()
    }

    private func profile(id: String? = nil) -> NativeProfile {
        NativeProfile(id: id ?? userID, displayName: "Learner", email: "learner@example.com")
    }

    func testAccountDeletionClearsOnlyAfterServerConfirmation() {
        tokens.accessToken = "opaque-test-token"
        tokens.userId = userID
        var completed = false
        session.deleteAccount().subscribe(onSuccess: { completed = true }, onFailure: { XCTFail("\($0)") }).disposed(by: bag)
        XCTAssertEqual(api.bearer, "opaque-test-token")
        XCTAssertNotNil(session.currentUser)
        XCTAssertFalse(completed)
        api.deleteResult.onNext(())
        XCTAssertTrue(completed)
        XCTAssertNil(session.currentUser)
        XCTAssertNil(tokens.accessToken)
    }

    func testAccountDeletionFailurePreservesSessionAndDataAccess() {
        tokens.accessToken = "opaque-test-token"
        tokens.userId = userID
        var error: Error?
        session.deleteAccount().subscribe(onFailure: { error = $0 }).disposed(by: bag)
        api.deleteResult.onError(NativeAuthError.offline)
        XCTAssertNotNil(error)
        XCTAssertEqual(tokens.accessToken, "opaque-test-token")
        XCTAssertEqual(session.currentUser?.id, userID)
    }

    func testOldAccountDeletionCannotClearNewLogin() {
        tokens.accessToken = "old-test-token"
        tokens.userId = userID
        var error: Error?
        session.deleteAccount().subscribe(onFailure: { error = $0 }).disposed(by: bag)
        session.login(email: "user@example.com", password: "test")
            .subscribe(onFailure: { XCTFail("\($0)") }).disposed(by: bag)
        api.loginResult.onNext(NativeLoginResponse(ok: true, token: "new-test-token"))
        api.profileResult.onNext(profile())
        api.deleteResult.onNext(())
        XCTAssertEqual(tokens.accessToken, "new-test-token")
        XCTAssertEqual(error as? NativeAuthError, .staleSession)
    }

    func testInvalidInputNeverStartsRequest() {
        for (email, password) in [("", "test"), ("bad", "test"), ("user@example.com", ""), ("user@example.com", String(repeating: "x", count: 1025))] {
            var failed = false
            session.login(email: email, password: password)
                .subscribe(onFailure: { _ in failed = true }).disposed(by: bag)
            XCTAssertTrue(failed)
        }
        XCTAssertEqual(api.loginCalls, 0)
    }

    func testSuccessRequiresProfileAndPreservesUUIDAndPassword() {
        var user: SocialUserEntity?
        session.login(email: " USER@EXAMPLE.COM ", password: " test password ")
            .subscribe(onSuccess: { user = $0 }).disposed(by: bag)
        XCTAssertEqual(api.email, "user@example.com")
        XCTAssertEqual(api.password, " test password ")
        api.loginResult.onNext(NativeLoginResponse(ok: true, token: "opaque-test-token"))
        XCTAssertNil(tokens.accessToken)
        XCTAssertNil(user)
        XCTAssertEqual(api.bearer, "opaque-test-token")
        api.profileResult.onNext(profile())
        XCTAssertEqual(tokens.accessToken, "opaque-test-token")
        XCTAssertEqual(tokens.userId, userID)
        XCTAssertEqual(user?.id, userID)
    }

    // MARK: Google

    private let googleToken = "header.payload.signature"

    func testAppleTokenIsExchangedAndNeverStoredInKeychain() {
        var user: SocialUserEntity?
        session.loginWithApple(idToken: "apple.jwt.signature", nonce: "random-proof-of-request")
            .subscribe(onSuccess: { user = $0 }, onFailure: { XCTFail("\($0)") }).disposed(by: bag)
        XCTAssertEqual(api.appleIDToken, "apple.jwt.signature")
        XCTAssertEqual(api.appleNonce, "random-proof-of-request")
        api.appleResult.onNext(NativeLoginResponse(ok: true, token: "opaque-session"))
        XCTAssertNil(tokens.accessToken)
        api.profileResult.onNext(profile())
        XCTAssertEqual(tokens.accessToken, "opaque-session")
        XCTAssertEqual(user?.id, userID)
    }

    func testMalformedAppleProofNeverCallsBackend() {
        for (token, nonce) in [("", "valid-long-nonce"), ("a.b.c", ""), ("contains space", "valid-long-nonce"),
                               ("a.b.c", "bad"), (String(repeating: "x", count: 4001), "valid-long-nonce")] {
            var error: Error?
            session.loginWithApple(idToken: token, nonce: nonce)
                .subscribe(onFailure: { error = $0 }).disposed(by: bag)
            XCTAssertEqual(error as? NativeAuthError, .appleCredentialsRejected)
        }
        XCTAssertNil(api.appleIDToken)
    }

    func testGoogleLoginPersistsOnlyTheApplicationSessionAfterTheProfileConfirmsIt() {
        var user: SocialUserEntity?
        session.loginWithGoogle(idToken: googleToken)
            .subscribe(onSuccess: { user = $0 }, onFailure: { XCTFail("\($0)") }).disposed(by: bag)
        XCTAssertEqual(api.googleIDToken, googleToken)
        api.googleResult.onNext(NativeLoginResponse(ok: true, token: "opaque-test-token"))
        XCTAssertNil(tokens.accessToken, "Nothing is stored before the profile confirms the session")
        XCTAssertEqual(api.bearer, "opaque-test-token", "The profile is fetched with the application token")
        api.profileResult.onNext(profile())
        XCTAssertEqual(tokens.accessToken, "opaque-test-token")
        XCTAssertNotEqual(tokens.accessToken, googleToken)
        XCTAssertEqual(tokens.userId, userID)
        XCTAssertEqual(user?.id, userID)
        XCTAssertEqual(session.bearerToken, "opaque-test-token")
    }

    func testMalformedGoogleTokenNeverReachesTheServer() {
        for token in ["", String(repeating: "a", count: 4001), "has space.in.it", "line\nbreak", "ünicode.token.value"] {
            var error: Error?
            session.loginWithGoogle(idToken: token).subscribe(onFailure: { error = $0 }).disposed(by: bag)
            XCTAssertEqual(error as? NativeAuthError, .googleCredentialsRejected)
        }
        XCTAssertEqual(api.googleCalls, 0)
    }

    func testGoogleServerFailuresDoNotAuthenticate() {
        for failure in [NativeAuthError.googleCredentialsRejected, .googleAccountConflict, .rateLimited, .unavailable, .offline] {
            api = ControlledAuthAPI()
            session = AuthSession(tokens: tokens, api: api)
            var error: Error?
            session.loginWithGoogle(idToken: googleToken).subscribe(onFailure: { error = $0 }).disposed(by: bag)
            api.googleResult.onError(failure)
            XCTAssertEqual(error as? NativeAuthError, failure)
            XCTAssertNil(tokens.accessToken)
            XCTAssertNil(session.currentUser)
        }
    }

    func testGoogleResponseWithoutAUsableTokenOrProfileCannotAuthenticate() {
        session.loginWithGoogle(idToken: googleToken).subscribe(onFailure: { _ in }).disposed(by: bag)
        api.googleResult.onNext(NativeLoginResponse(ok: false, token: "opaque-test-token"))
        XCTAssertNil(api.bearer)
        XCTAssertNil(tokens.accessToken)

        api = ControlledAuthAPI()
        session = AuthSession(tokens: tokens, api: api)
        session.loginWithGoogle(idToken: googleToken).subscribe(onFailure: { _ in }).disposed(by: bag)
        api.googleResult.onNext(NativeLoginResponse(ok: true, token: "opaque-test-token"))
        api.profileResult.onNext(profile(id: "invalid-id"))
        XCTAssertNil(tokens.accessToken)
    }

    func testLogoutWhileTheGoogleExchangeIsInFlightRejectsTheStaleSession() {
        session.loginWithGoogle(idToken: googleToken)
            .subscribe(onSuccess: { _ in XCTFail("Stale Google login succeeded") }, onFailure: { _ in }).disposed(by: bag)
        api.googleResult.onNext(NativeLoginResponse(ok: true, token: "opaque-test-token"))
        session.logout().subscribe(onFailure: { _ in }).disposed(by: bag)
        api.profileResult.onNext(profile())
        XCTAssertNil(tokens.accessToken)
        XCTAssertNil(session.currentUser)
    }

    func testDisposingTheGoogleLoginCancelsTheRequestAndKeepsNoSession() {
        let request = session.loginWithGoogle(idToken: googleToken)
            .subscribe(onSuccess: { _ in XCTFail("Cancelled Google login succeeded") })
        request.dispose()
        XCTAssertTrue(api.cancelled)
        api.googleResult.onNext(NativeLoginResponse(ok: true, token: "opaque-test-token"))
        api.profileResult.onNext(profile())
        XCTAssertNil(tokens.accessToken)
    }

    func testKeychainFailureAfterGoogleLoginLeavesNoSession() {
        tokens.saveError = NativeAuthError.unavailable
        var error: Error?
        session.loginWithGoogle(idToken: googleToken).subscribe(onFailure: { error = $0 }).disposed(by: bag)
        api.googleResult.onNext(NativeLoginResponse(ok: true, token: "opaque-test-token"))
        api.profileResult.onNext(profile())
        XCTAssertEqual(error as? NativeAuthError, .storageFailed)
        XCTAssertNil(session.currentUser)
        XCTAssertNil(tokens.accessToken)
    }

    func testLogoutAfterGoogleLoginUsesTheSameSessionTeardown() {
        session.loginWithGoogle(idToken: googleToken).subscribe(onFailure: { _ in }).disposed(by: bag)
        api.googleResult.onNext(NativeLoginResponse(ok: true, token: "opaque-test-token"))
        api.profileResult.onNext(profile())
        XCTAssertNotNil(session.currentUser)
        var result: LogoutResult?
        session.logout().subscribe(onSuccess: { result = $0 }).disposed(by: bag)
        XCTAssertEqual(api.bearer, "opaque-test-token")
        api.logoutResult.onNext(())
        XCTAssertEqual(result, .revoked)
        XCTAssertNil(session.currentUser)
        XCTAssertNil(session.bearerToken)
        XCTAssertNil(tokens.accessToken)
    }

    func testLoginFailureDoesNotAuthenticate() {
        var failed = false
        session.login(email: "user@example.com", password: "test")
            .subscribe(onFailure: { _ in failed = true }).disposed(by: bag)
        api.loginResult.onError(NativeAuthError.invalidCredentials)
        XCTAssertTrue(failed)
        XCTAssertNil(tokens.accessToken)
        XCTAssertNil(session.currentUser)
    }

    func testMissingTokenAndInvalidProfileCannotAuthenticate() {
        session.login(email: "user@example.com", password: "test")
            .subscribe(onFailure: { _ in }).disposed(by: bag)
        api.loginResult.onNext(NativeLoginResponse(ok: true, token: ""))
        XCTAssertNil(tokens.accessToken)
        XCTAssertNil(api.bearer)

        session.login(email: "user@example.com", password: "test")
            .subscribe(onFailure: { _ in }).disposed(by: bag)
        api.loginResult.onNext(NativeLoginResponse(ok: true, token: "opaque-test-token"))
        api.profileResult.onNext(profile(id: "invalid-id"))
        XCTAssertNil(tokens.accessToken)
    }

    func testProfileFailureAndKeychainFailureNeverPersistToken() {
        session.login(email: "user@example.com", password: "test")
            .subscribe(onFailure: { _ in }).disposed(by: bag)
        api.loginResult.onNext(NativeLoginResponse(ok: true, token: "opaque-test-token"))
        api.profileResult.onError(NativeAuthError.unavailable)
        XCTAssertNil(tokens.accessToken)

        api = ControlledAuthAPI()
        session = AuthSession(tokens: tokens, api: api)
        tokens.saveError = NativeAuthError.unavailable
        var failed = false
        session.login(email: "user@example.com", password: "test")
            .subscribe(onFailure: { _ in failed = true }).disposed(by: bag)
        api.loginResult.onNext(NativeLoginResponse(ok: true, token: "opaque-test-token"))
        api.profileResult.onNext(profile())
        XCTAssertTrue(failed)
        XCTAssertNil(session.currentUser)
        XCTAssertNil(tokens.accessToken)
    }

    func testDisposalCancelsRequestAndPreventsCompletion() {
        let request = session.login(email: "user@example.com", password: "test")
            .subscribe(onSuccess: { _ in XCTFail("Cancelled login succeeded") })
        request.dispose()
        XCTAssertTrue(api.cancelled)
        api.loginResult.onNext(NativeLoginResponse(ok: true, token: "opaque-test-token"))
        api.profileResult.onNext(profile())
        XCTAssertNil(tokens.accessToken)
    }

    func testLogoutDuringProfileFetchRejectsStaleLogin() {
        session.login(email: "user@example.com", password: "test")
            .subscribe(onSuccess: { _ in XCTFail("Stale login succeeded") }, onFailure: { _ in })
            .disposed(by: bag)
        api.loginResult.onNext(NativeLoginResponse(ok: true, token: "opaque-test-token"))
        session.logout().subscribe(onFailure: { _ in }).disposed(by: bag)
        api.profileResult.onNext(profile())
        XCTAssertNil(tokens.accessToken)
        XCTAssertNil(session.currentUser)
    }

    func testCancelDuringProfileFetchDoesNotPersistSession() {
        let operation = session.login(email: "user@example.com", password: "test")
            .subscribe(onSuccess: { _ in XCTFail("Cancelled login succeeded") }, onFailure: { _ in })
        api.loginResult.onNext(NativeLoginResponse(ok: true, token: "opaque-test-token"))
        operation.dispose()
        api.profileResult.onNext(profile())
        XCTAssertNil(tokens.accessToken)
        XCTAssertNil(session.currentUser)
    }

    func testLogoutBeforeTokenResponseRejectsStaleLogin() {
        session.login(email: "user@example.com", password: "test")
            .subscribe(onSuccess: { _ in XCTFail("Stale login succeeded") }, onFailure: { _ in })
            .disposed(by: bag)
        session.logout().subscribe(onFailure: { _ in }).disposed(by: bag)
        api.loginResult.onNext(NativeLoginResponse(ok: true, token: "opaque-test-token"))
        XCTAssertNil(api.bearer)
        XCTAssertNil(tokens.accessToken)
    }

    func testOldLogoutFailureCannotClearNewLogin() {
        tokens.accessToken = "old-test-token"
        tokens.userId = userID
        session.logout().subscribe(onFailure: { _ in }).disposed(by: bag)
        session.login(email: "user@example.com", password: "test")
            .subscribe(onFailure: { _ in }).disposed(by: bag)
        api.loginResult.onNext(NativeLoginResponse(ok: true, token: "new-test-token"))
        api.profileResult.onNext(profile())
        api.logoutResult.onError(NativeAuthError.unavailable)
        XCTAssertEqual(tokens.accessToken, "new-test-token")
        XCTAssertEqual(session.currentUser?.id, userID)
    }

    func testLogoutClearsLocalSessionAndReportsUnconfirmedWhenRemoteFails() {
        tokens.accessToken = "opaque-test-token"
        tokens.userId = userID
        var result: LogoutResult?
        session.logout().subscribe(onSuccess: { result = $0 }, onFailure: { XCTFail("\($0)") }).disposed(by: bag)
        XCTAssertNil(tokens.accessToken)
        XCTAssertNil(tokens.userId)
        XCTAssertNil(session.currentUser)
        XCTAssertEqual(api.bearer, "opaque-test-token")
        XCTAssertNil(result, "Result waits for the server answer")
        api.logoutResult.onError(NativeAuthError.unavailable)
        XCTAssertEqual(result, .remoteUnconfirmed)
    }

    func testLogoutReportsRevokedWhenServerConfirms() {
        tokens.accessToken = "opaque-test-token"
        tokens.userId = userID
        var result: LogoutResult?
        session.logout().subscribe(onSuccess: { result = $0 }).disposed(by: bag)
        api.logoutResult.onNext(())
        XCTAssertEqual(result, .revoked)
        XCTAssertNil(tokens.accessToken)
    }

    func testDuplicateLogoutWithNoSessionNeverCallsTheServer() {
        var results: [LogoutResult] = []
        session.logout().subscribe(onSuccess: { results.append($0) }).disposed(by: bag)
        session.logout().subscribe(onSuccess: { results.append($0) }).disposed(by: bag)
        XCTAssertEqual(results, [.revoked, .revoked])
        XCTAssertNil(api.bearer)
    }

    func testLogoutRejectedAsUnauthorizedMeansTheServerSessionIsAlreadyGone() {
        tokens.accessToken = "opaque-test-token"
        tokens.userId = userID
        var result: LogoutResult?
        session.logout().subscribe(onSuccess: { result = $0 }, onFailure: { XCTFail("\($0)") }).disposed(by: bag)
        api.logoutResult.onError(NativeAuthError.unauthorized)
        XCTAssertEqual(result, .revoked, "A token the server no longer accepts needs no revocation")
        XCTAssertNil(session.currentUser)
    }

    func testFailedKeychainDeletionIsReportedAndCannotRestoreAccount() {
        tokens.accessToken = "opaque-test-token"
        tokens.userId = userID
        tokens.clearError = NativeAuthError.storageFailed
        var failed = false
        session.logout().subscribe(onFailure: { _ in failed = true }).disposed(by: bag)
        XCTAssertEqual(api.bearer, "opaque-test-token")
        XCTAssertNil(session.currentUser)
        api.logoutResult.onNext(())
        XCTAssertTrue(failed)
        session.refresh().subscribe(onFailure: { _ in }).disposed(by: bag)
        api.profileResult.onNext(profile())
        XCTAssertNil(session.currentUser)
    }

    func testRefreshUnauthorizedClearsSessionButNetworkFailureDoesNot() {
        tokens.accessToken = "opaque-test-token"
        tokens.userId = userID
        session.refresh().subscribe(onFailure: { _ in }).disposed(by: bag)
        api.profileResult.onError(NativeAuthError.unavailable)
        XCTAssertNotNil(tokens.accessToken)
        api = ControlledAuthAPI()
        session = AuthSession(tokens: tokens, api: api)
        session.refresh().subscribe(onFailure: { _ in }).disposed(by: bag)
        api.profileResult.onError(NativeAuthError.unauthorized)
        XCTAssertNil(tokens.accessToken)
        XCTAssertNil(session.currentUser)
    }

    func testProfileDecodesMountedFullProfileAndRejectsEnvelope() throws {
        // LearnerFullProfile encoded directly by learnerGetMeHandler in handler_profile.go.
        let json = #"{"id":"7c2218b4-590b-49b2-8be0-076fd9992135","email":"learner@example.com","displayName":"Learner","status":"active","themeMode":"system","fontSizePreference":"default","densityPreference":"comfortable","flashcardStyleSlug":null,"coverAssetId":null,"adsPersonalizationOptIn":false,"sharePostcardOptIn":false,"createdAt":"2026-10-21T00:00:00Z","updatedAt":"2026-10-21T00:00:00Z"}"#
        let profile = try JSONDecoder().decode(NativeProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.id, userID)
        XCTAssertEqual(profile.email, "learner@example.com")
        XCTAssertEqual(profile.displayName, "Learner")
        XCTAssertThrowsError(try JSONDecoder().decode(NativeProfile.self, from: Data(#"{"profile":{"id":"7c2218b4-590b-49b2-8be0-076fd9992135","displayName":"Learner","email":"learner@example.com"}}"#.utf8)))
    }
}

private final class AuthURLProtocol: URLProtocol {
    static var handler: ((URLRequest, AuthURLProtocol) -> Void)?
    static var stopped: (() -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.handler?(request, self) }
    override func stopLoading() { Self.stopped?() }
    func reply(status: Int, body: String) {
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status,
            httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class NativeAuthAPITests: XCTestCase {
    private var api: NativeAuthAPI!
    private var bag: DisposeBag!
    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthURLProtocol.self]
        api = NativeAuthAPI(session: Session(configuration: config), baseURL: { "https://auth.invalid/api" })
        bag = DisposeBag()
    }
    override func tearDown() {
        bag = nil
        api = nil
        AuthURLProtocol.handler = nil
        AuthURLProtocol.stopped = nil
    }

    func testLoginUsesJSONAndNoBearer() {
        let done = expectation(description: "login")
        AuthURLProtocol.handler = { request, transport in
            XCTAssertEqual(request.url?.path, "/api/auth/login")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://auth.invalid")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            // URLSession may represent the body as a stream when URLProtocol intercepts it.
            var body = request.httpBody ?? Data()
            if let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var bytes = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable {
                    let count = stream.read(&bytes, maxLength: bytes.count)
                    if count <= 0 { break }
                    body.append(contentsOf: bytes.prefix(count))
                }
            }
            let payload = try? JSONSerialization.jsonObject(with: body) as? [String: String]
            XCTAssertEqual(payload?["email"], "user@example.com")
            XCTAssertEqual(payload?["password"], " test ")
            transport.reply(status: 200, body: #"{"ok":true,"token":"opaque-test-token"}"#)
        }
        api.login(email: "user@example.com", password: " test ")
            .subscribe(onSuccess: { _ in done.fulfill() }, onFailure: { error in XCTFail("\(error)"); done.fulfill() })
            .disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testHTTPFailureIsValidatedBeforeSuccessDecoding() {
        let done = expectation(description: "rejected")
        AuthURLProtocol.handler = { _, transport in
            transport.reply(status: 401, body: #"{"ok":true,"token":"must-not-accept"}"#)
        }
        api.login(email: "user@example.com", password: "test")
            .subscribe(onSuccess: { _ in XCTFail("Accepted 401"); done.fulfill() }, onFailure: { _ in done.fulfill() })
            .disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testLoginRateLimitIsNotReportedAsServiceOutage() {
        let done = expectation(description: "rate limited login")
        AuthURLProtocol.handler = { _, transport in
            transport.reply(status: 429, body: #"{"error":"too many requests"}"#)
        }
        api.login(email: "user@example.com", password: "test")
            .subscribe(onSuccess: { _ in
                XCTFail("Accepted rate-limited login")
                done.fulfill()
            }, onFailure: { error in
                XCTAssertEqual(error.localizedDescription,
                               NSLocalizedString("Too many sign-in attempts. Please try again later.", comment: ""))
                done.fulfill()
            }).disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    private func body(of request: URLRequest) -> Data {
        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var bytes = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&bytes, maxLength: bytes.count)
                if count <= 0 { break }
                body.append(contentsOf: bytes.prefix(count))
            }
        }
        return body
    }

    func testGoogleLoginPostsOnlyTheIDTokenAsJSONWithoutBearer() {
        let done = expectation(description: "google login")
        AuthURLProtocol.handler = { [self] request, transport in
            XCTAssertEqual(request.url?.absoluteString, "https://auth.invalid/api/auth/google")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let payload = try? JSONSerialization.jsonObject(with: body(of: request)) as? [String: String]
            XCTAssertEqual(payload, ["idToken": "header.payload.signature"], "The body carries the ID token and nothing else")
            transport.reply(status: 200, body: #"{"ok":true,"token":"opaque-test-token"}"#)
        }
        api.loginWithGoogle(idToken: "header.payload.signature")
            .subscribe(onSuccess: { response in
                XCTAssertTrue(response.ok)
                XCTAssertEqual(response.token, "opaque-test-token")
                done.fulfill()
            }, onFailure: { XCTFail("\($0)"); done.fulfill() }).disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testGoogleLoginFailureStatusesAreClassifiedAndNeverAuthenticate() {
        let cases: [(Int, String, NativeAuthError)] = [
            (400, #"{"error":"invalid request"}"#, .unavailable),
            (401, #"{"error":"invalid Google credentials"}"#, .googleCredentialsRejected),
            (409, #"{"error":"account already exists; sign in with your existing method"}"#, .googleAccountConflict),
            (429, #"{"error":"too many requests"}"#, .rateLimited),
            (500, #"{"error":"internal error"}"#, .unavailable),
            (503, #"{"error":"service unavailable"}"#, .unavailable),
            (200, #"{"ok":true}"#, .invalidResponse),
            (200, #"{"ok":true,"tok"#, .invalidResponse)
        ]
        for (status, body, expected) in cases {
            let done = expectation(description: "google \(status)")
            AuthURLProtocol.handler = { _, transport in transport.reply(status: status, body: body) }
            api.loginWithGoogle(idToken: "header.payload.signature")
                .subscribe(onSuccess: { _ in XCTFail("Accepted \(status) \(body)"); done.fulfill() }, onFailure: { error in
                    XCTAssertEqual(error as? NativeAuthError, expected, "status \(status)")
                    done.fulfill()
                }).disposed(by: bag)
            wait(for: [done], timeout: 3)
        }
    }

    func testGoogleLoginWithoutConnectivityIsReportedAsOffline() {
        let done = expectation(description: "offline")
        AuthURLProtocol.handler = { _, transport in
            transport.client?.urlProtocol(transport, didFailWithError: URLError(.notConnectedToInternet))
        }
        api.loginWithGoogle(idToken: "header.payload.signature")
            .subscribe(onSuccess: { _ in XCTFail("Accepted offline"); done.fulfill() }, onFailure: { error in
                XCTAssertEqual(error as? NativeAuthError, .offline)
                done.fulfill()
            }).disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testEmailLoginDoesNotTreatConflictAsAGoogleConflict() {
        let done = expectation(description: "email 409")
        AuthURLProtocol.handler = { _, transport in transport.reply(status: 409, body: #"{"error":"conflict"}"#) }
        api.login(email: "user@example.com", password: "test")
            .subscribe(onSuccess: { _ in XCTFail("Accepted 409"); done.fulfill() }, onFailure: { error in
                XCTAssertEqual(error as? NativeAuthError, .unavailable)
                done.fulfill()
            }).disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testMeResolvesBearerOnSubscription() {
        let done = expectation(description: "profile")
        var token = "old-test-token"
        let operation = api.me(token: { token })
        token = "current-test-token"
        AuthURLProtocol.handler = { request, transport in
            XCTAssertEqual(request.url?.path, "/api/auth/me")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer current-test-token")
            transport.reply(status: 200, body: #"{"id":"7c2218b4-590b-49b2-8be0-076fd9992135","displayName":"Learner","email":"learner@example.com"}"#)
        }
        operation.subscribe(onSuccess: { _ in done.fulfill() }, onFailure: { _ in XCTFail("Profile failed"); done.fulfill() })
            .disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testMeDecodesDirectProfileFromMountedHandler() {
        let done = expectation(description: "mounted me response")
        AuthURLProtocol.handler = { _, transport in
            transport.reply(status: 200, body: #"{"id":"7c2218b4-590b-49b2-8be0-076fd9992135","displayName":"Learner","email":"learner@example.com","status":"active","coverAssetId":null,"sharePostcardOptIn":false}"#)
        }
        api.me(token: { "opaque-test-token" })
            .subscribe(onSuccess: { _ in done.fulfill() }, onFailure: { _ in
                XCTFail("GET /auth/me must decode the mounted handler's direct profile")
                done.fulfill()
            }).disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testOriginUsesConfiguredSchemeHostAndPortWithoutAPIPath() {
        let done = expectation(description: "local origin")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthURLProtocol.self]
        var base = "https://old.invalid/api"
        let localAPI = NativeAuthAPI(session: Session(configuration: config), baseURL: { base })
        let login = localAPI.login(email: "user@example.com", password: "test")
        base = "http://localhost:18081/api"
        AuthURLProtocol.handler = { request, transport in
            XCTAssertEqual(request.url?.absoluteString, "http://localhost:18081/api/auth/login")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "http://localhost:18081")
            transport.reply(status: 200, body: #"{"ok":true,"token":"opaque-test-token"}"#)
        }
        login.subscribe(onSuccess: { _ in done.fulfill() }, onFailure: { _ in
            XCTFail("Login request failed"); done.fulfill()
        }).disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testLogoutIsBearerPostAndRequiresOK() {
        let done = expectation(description: "logout")
        AuthURLProtocol.handler = { request, transport in
            XCTAssertEqual(request.url?.path, "/api/auth/logout")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://auth.invalid")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer opaque-test-token")
            transport.reply(status: 200, body: #"{"ok":false}"#)
        }
        api.logout(token: { "opaque-test-token" })
            .subscribe(onSuccess: { _ in XCTFail("Accepted failed logout"); done.fulfill() }, onFailure: { _ in done.fulfill() })
            .disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testAccountDeletionUsesBearerPostAndRejectsFalseResponse() {
        let done = expectation(description: "delete account")
        AuthURLProtocol.handler = { request, transport in
            XCTAssertEqual(request.url?.path, "/api/auth/delete")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), "https://auth.invalid")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer opaque-test-token")
            transport.reply(status: 200, body: #"{"ok":false}"#)
        }
        api.deleteAccount(token: { "opaque-test-token" })
            .subscribe(onSuccess: { _ in XCTFail("Accepted failed deletion"); done.fulfill() },
                       onFailure: { _ in done.fulfill() }).disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testLoginFailureStatusesNeverAuthenticateAndAreClassified() {
        let cases: [(Int, String, String)] = [
            (400, #"{"error":"invalid request"}"#, NativeAuthError.unavailable.localizedDescription),
            (401, #"{"error":"invalid credentials"}"#, NativeAuthError.invalidCredentials.localizedDescription),
            (403, #"{"error":"forbidden: untrusted origin"}"#, NativeAuthError.unavailable.localizedDescription),
            (429, #"{"error":"too many requests"}"#, NativeAuthError.rateLimited.localizedDescription),
            (500, #"{"error":"internal error"}"#, NativeAuthError.unavailable.localizedDescription),
            (503, #"{"error":"service unavailable"}"#, NativeAuthError.unavailable.localizedDescription),
            // 200 with a body that is not a session must be rejected, not treated as success.
            (200, #"{"ok":true}"#, NativeAuthError.invalidResponse.localizedDescription),
            (200, #"{"ok":true,"tok"#, NativeAuthError.invalidResponse.localizedDescription)
        ]
        for (status, body, expected) in cases {
            let done = expectation(description: "login \(status)")
            AuthURLProtocol.handler = { _, transport in transport.reply(status: status, body: body) }
            api.login(email: "user@example.com", password: "test")
                .subscribe(onSuccess: { _ in XCTFail("Accepted \(status) \(body)"); done.fulfill() },
                           onFailure: { error in
                    XCTAssertEqual(error.localizedDescription, expected, "status \(status)")
                    done.fulfill()
                }).disposed(by: bag)
            wait(for: [done], timeout: 3)
        }
    }

    func testNetworkTimeoutIsReportedAsUnavailable() {
        let done = expectation(description: "timeout")
        AuthURLProtocol.handler = { _, transport in
            transport.client?.urlProtocol(transport, didFailWithError: URLError(.timedOut))
        }
        api.login(email: "user@example.com", password: "test")
            .subscribe(onSuccess: { _ in XCTFail("Accepted timeout"); done.fulfill() }, onFailure: { error in
                XCTAssertEqual(error.localizedDescription, NativeAuthError.unavailable.localizedDescription)
                done.fulfill()
            }).disposed(by: bag)
        wait(for: [done], timeout: 3)
    }

    func testDisposeCancelsAlamofireRequest() {
        let started = expectation(description: "started")
        let stopped = expectation(description: "cancelled")
        AuthURLProtocol.handler = { _, _ in started.fulfill() }
        AuthURLProtocol.stopped = { stopped.fulfill() }
        let operation = api.me(token: { "opaque-test-token" }).subscribe(onFailure: { _ in })
        wait(for: [started], timeout: 3)
        operation.dispose()
        wait(for: [stopped], timeout: 3)
    }
}

final class KeychainAuthTokenManagerTests: XCTestCase {
    private let userID = "7c2218b4-590b-49b2-8be0-076fd9992135"
    private let namespace = "com.flashcardapp.tests.\(UUID().uuidString)"
    private var keychain: KeychainAuthTokenManager!

    override func setUpWithError() throws {
        keychain = KeychainAuthTokenManager(namespace: namespace)
        // An unsigned build (CODE_SIGNING_ALLOWED=NO) has no Keychain entitlement: infrastructure, not a source failure.
        do { try keychain.save(accessToken: "probe", userId: userID) }
        catch { throw XCTSkip("Keychain unavailable in this build: \(error)") }
        try keychain.clear()
    }

    override func tearDown() {
        try? keychain.clear()
    }

    private func addLegacyItem(_ suffix: String, _ value: String) {
        let status = SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "\(namespace).\(suffix)",
            kSecValueData as String: Data(value.utf8)
        ] as CFDictionary, nil)
        XCTAssertEqual(status, errSecSuccess)
    }

    private func legacyItemExists(_ suffix: String) -> Bool {
        SecItemCopyMatching([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "\(namespace).\(suffix)"
        ] as CFDictionary, nil) == errSecSuccess
    }

    func testSavedSessionRoundTripsAndReplacesThePreviousOne() throws {
        XCTAssertNil(keychain.accessToken)
        try keychain.save(accessToken: "first-test-token", userId: userID)
        XCTAssertEqual(keychain.accessToken, "first-test-token")
        XCTAssertEqual(keychain.userId, userID)

        let other = "0b0f5b52-2d3c-4a8c-9d4e-7b52b6f2a111"
        try keychain.save(accessToken: "second-test-token", userId: other)
        XCTAssertEqual(keychain.accessToken, "second-test-token")
        XCTAssertEqual(keychain.userId, other, "Token and user always come from the same save")
    }

    func testClearRemovesTheSession() throws {
        try keychain.save(accessToken: "first-test-token", userId: userID)
        try keychain.clear()
        XCTAssertNil(keychain.accessToken)
        XCTAssertNil(keychain.userId)
        XCTAssertNoThrow(try keychain.clear(), "Clearing an empty store is not an error")
    }

    func testSessionStoredAsTwoItemsByAnEarlierVersionStillRestoresAndIsReplacedOnSave() throws {
        addLegacyItem("accessToken", "legacy-test-token")
        addLegacyItem("userId", userID)
        XCTAssertEqual(keychain.accessToken, "legacy-test-token")
        XCTAssertEqual(keychain.userId, userID)

        try keychain.save(accessToken: "new-test-token", userId: userID)
        XCTAssertEqual(keychain.accessToken, "new-test-token")
        XCTAssertFalse(legacyItemExists("accessToken"))
        XCTAssertFalse(legacyItemExists("userId"))
    }

    func testClearAlsoRemovesAnEarlierVersionsItems() throws {
        addLegacyItem("accessToken", "legacy-test-token")
        addLegacyItem("userId", userID)
        try keychain.clear()
        XCTAssertNil(keychain.accessToken)
        XCTAssertFalse(legacyItemExists("accessToken"))
        XCTAssertFalse(legacyItemExists("userId"))
    }

    func testHalfWrittenEarlierSessionIsNotUsable() {
        addLegacyItem("accessToken", "orphan-test-token")
        XCTAssertNil(keychain.accessToken)
        XCTAssertNil(keychain.userId)
    }
}
