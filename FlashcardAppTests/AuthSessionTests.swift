import XCTest
import Alamofire
import RxSwift
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
    var loginCalls = 0
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
    func me(token: @escaping () -> String?) -> Single<NativeProfile> {
        bearer = token()
        return profileResult.take(1).asSingle()
    }
    func logout(token: @escaping () -> String?) -> Single<Void> {
        bearer = token()
        return logoutResult.take(1).asSingle()
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

    func testLogoutClearsLocalSessionEvenWhenRemoteFails() {
        tokens.accessToken = "opaque-test-token"
        tokens.userId = userID
        var failed = false
        session.logout().subscribe(onFailure: { _ in failed = true }).disposed(by: bag)
        XCTAssertNil(tokens.accessToken)
        XCTAssertNil(tokens.userId)
        XCTAssertNil(session.currentUser)
        XCTAssertEqual(api.bearer, "opaque-test-token")
        api.logoutResult.onError(NativeAuthError.unavailable)
        XCTAssertTrue(failed)
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
