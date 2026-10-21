import Foundation
import RxSwift
import RxRelay

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

    init(tokens: AuthTokenManagerInterface = KeychainAuthTokenManager.shared,
         api: NativeAuthAPIInterface = NativeAuthAPI()) {
        self.tokens = tokens
        self.api = api
    }

    func login(email: String, password: String) -> Single<SocialUserEntity> {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil,
              !password.isEmpty, password.utf8.count <= 1024 else { return .error(NativeAuthError.invalidInput) }
        return Single.create { [self] observer in
            lock.lock()
            let attempt = UUID()
            generation = attempt
            lock.unlock()

            let request = api.login(email: email, password: password)
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

    func logout() -> Single<Void> {
        Single.deferred { [self] in
            lock.lock()
            defer { lock.unlock() }
            let token = tokens.accessToken
            let storageError: Error?
            do { try clear(); storageError = nil }
            catch { storageError = error }
            let request = token.map { token in api.logout(token: { token }) } ?? .just(())
            return request.map {
                if let storageError { throw storageError }
                return ()
            }.catch { .error(storageError ?? $0) }
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
