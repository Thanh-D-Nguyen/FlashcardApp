import Foundation
import RxSwift
import RxRelay

/// What logging out achieved on the server. The local session is always gone by the time this is delivered.
enum LogoutResult: Equatable {
    /// The server ended the session, or already refused the token (expired or revoked earlier).
    case revoked
    /// The server could not be reached or failed, so the session may stay valid there until it expires.
    case remoteUnconfirmed
}

final class AuthSession {
    static let shared = AuthSession()

    private let tokens: AuthTokenManagerInterface
    private let api: NativeAuthAPIInterface
    private let lock = NSRecursiveLock()
    private var generation = UUID()
    private var profile: SocialUserEntity?
    private var isSignedOut = false
    private let changes = PublishRelay<Void>()

    var authStateChanges: Observable<Void> { changes.asObservable() }

    var currentUser: SocialUserEntity? {
        lock.lock()
        defer { lock.unlock() }
        guard !isSignedOut, let token = tokens.accessToken, NativeAuthAPI.isValidToken(token),
              let id = tokens.userId, UUID(uuidString: id) != nil else { return nil }
        return profile ?? SocialUserEntity(id: id)
    }

    /// The opaque session token for an authenticated request; nil once signed out or if the stored value is malformed.
    /// Read it when the request starts and again when it finishes to detect a logout or account change in between.
    var bearerToken: String? {
        lock.lock()
        defer { lock.unlock() }
        guard !isSignedOut, let token = tokens.accessToken, NativeAuthAPI.isValidToken(token) else { return nil }
        return token
    }

    init(tokens: AuthTokenManagerInterface = KeychainAuthTokenManager.shared,
         api: NativeAuthAPIInterface = NativeAuthAPI()) {
        self.tokens = tokens
        self.api = api
    }

    func login(email: String, password: String) -> Single<SocialUserEntity> {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil,
              !password.isEmpty, password.utf8.count <= 1024 else { return .error(NativeAuthError.invalidInput) }
        return signIn { [api] in api.login(email: email, password: password) }
    }

    /// Exchanges a Google ID token for the website's own session. The Google token is used for this one request and is
    /// never stored: the session that is kept (Keychain, bearer header, profile) is the application token only.
    func loginWithGoogle(idToken: String) -> Single<SocialUserEntity> {
        // The server accepts 1...4000 bytes of a compact JWS; anything else cannot be a Google ID token.
        guard !idToken.isEmpty, idToken.utf8.count <= 4000, NativeAuthAPI.isValidToken(idToken) else {
            return .error(NativeAuthError.googleCredentialsRejected)
        }
        return signIn { [api] in api.loginWithGoogle(idToken: idToken) }
    }

    func loginWithApple(idToken: String, nonce: String) -> Single<SocialUserEntity> {
        guard !idToken.isEmpty, idToken.utf8.count <= 4000, NativeAuthAPI.isValidToken(idToken),
              (8...256).contains(nonce.utf8.count), NativeAuthAPI.isValidToken(nonce) else {
            return .error(NativeAuthError.appleCredentialsRejected)
        }
        return signIn { [api] in api.loginWithApple(idToken: idToken, nonce: nonce) }
    }

    /// Shared tail of every sign-in method: exchange credentials for an application token, confirm it with the profile,
    /// and only then persist it. A newer attempt, `clear()` or disposal invalidates the attempt (`generation`).
    private func signIn(_ exchange: @escaping () -> Single<NativeLoginResponse>) -> Single<SocialUserEntity> {
        Single.create { [self] observer in
            lock.lock()
            let attempt = UUID()
            generation = attempt
            lock.unlock()

            let request = exchange()
                .flatMap { [self] response -> Single<(NativeProfile, String)> in
                    guard isCurrent(attempt) else { return .error(NativeAuthError.staleSession) }
                    guard response.ok, NativeAuthAPI.isValidToken(response.token) else {
                        return .error(NativeAuthError.invalidResponse)
                    }
                    return api.me(token: { response.token }).map { ($0, response.token) }
                }
                .subscribe(onSuccess: { [self] accountProfile, token in
                    lock.lock()
                    defer { lock.unlock() }
                    do {
                        guard generation == attempt else { throw NativeAuthError.staleSession }
                        let user = try self.user(from: accountProfile)
                        do { try tokens.save(accessToken: token, userId: accountProfile.id) }
                        catch {
                            try? clear()
                            throw NativeAuthError.storageFailed
                        }
                        profile = user
                        isSignedOut = false
                        changes.accept(())
                        observer(.success(user))
                    } catch { observer(.failure(error)) }
                }, onFailure: { observer(.failure($0)) })
            return Disposables.create { [self] in
                lock.lock()
                if generation == attempt { generation = UUID() }
                lock.unlock()
                request.dispose()
            }
        }
    }

    func refresh() -> Single<Void> {
        Single.deferred { [self] in
            lock.lock()
            let attempt = generation
            let token = isSignedOut ? nil : tokens.accessToken
            lock.unlock()
            guard token != nil else { return .just(()) }
            return api.me(token: { [self] in
                lock.lock()
                defer { lock.unlock() }
                return generation == attempt ? tokens.accessToken : nil
            }).map { [self] accountProfile in
                lock.lock()
                defer { lock.unlock() }
                guard generation == attempt else { throw NativeAuthError.staleSession }
                let user = try self.user(from: accountProfile)
                guard user.id == tokens.userId else { throw NativeAuthError.invalidResponse }
                profile = user
                changes.accept(())
                return ()
            }.catch { [self] error in
                lock.lock()
                defer { lock.unlock() }
                if generation == attempt, case NativeAuthError.unauthorized = error { try clear() }
                return .error(error)
            }
        }
    }

    /// Clears the local session first, then asks the server to end it. Only a local storage failure is an error:
    /// the server outcome is reported as a `LogoutResult` because the user is signed out on this device either way.
    func logout() -> Single<LogoutResult> {
        Single.deferred { [self] in
            lock.lock()
            defer { lock.unlock() }
            let token = tokens.accessToken
            let storageError: Error?
            do { try clear(); storageError = nil }
            catch { storageError = error }
            let request = token.map { token in api.logout(token: { token }) } ?? .just(())
            return request.map { LogoutResult.revoked }
                .catch { error in
                    if case NativeAuthError.unauthorized = error { return .just(.revoked) }
                    return .just(.remoteUnconfirmed)
                }
                .map { result in
                    if let storageError { throw storageError }
                    return result
                }
        }
    }

    /// Preserve the local account on request failure; only clear it after server confirmation.
    func deleteAccount() -> Single<Void> {
        Single.deferred { [self] in
            lock.lock()
            let attempt = generation
            let token = isSignedOut ? nil : tokens.accessToken
            lock.unlock()
            guard let token, NativeAuthAPI.isValidToken(token) else {
                return .error(NativeAuthError.unauthorized)
            }
            return api.deleteAccount(token: { token }).map { [self] in
                lock.lock()
                defer { lock.unlock() }
                guard generation == attempt, tokens.accessToken == token, !isSignedOut else {
                    throw NativeAuthError.staleSession
                }
                try clear()
            }
        }
    }

    func clear() throws {
        lock.lock()
        defer { lock.unlock() }
        generation = UUID()
        profile = nil
        isSignedOut = true
        defer { changes.accept(()) }
        do { try tokens.clear() }
        catch { throw NativeAuthError.storageFailed }
    }

    private func isCurrent(_ attempt: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return generation == attempt
    }

    private func user(from profile: NativeProfile) throws -> SocialUserEntity {
        guard UUID(uuidString: profile.id) != nil, !profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NativeAuthError.invalidResponse
        }
        return SocialUserEntity(id: profile.id, displayName: profile.displayName, email: profile.email)
    }
}
