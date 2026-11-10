import XCTest
import RxSwift
import UIKit
@testable import FlashcardApp

final class MailLoginPresenterTests: XCTestCase {
    private var interactor: MailLoginInteractorStub!
    private var wireframe: MailLoginWireframeSpy!
    private var presenter: MailLoginPresenter!

    override func setUp() {
        super.setUp()
        interactor = MailLoginInteractorStub()
        wireframe = MailLoginWireframeSpy()
        presenter = MailLoginPresenter(interactor: interactor, wireframe: wireframe)
    }

    override func tearDown() {
        presenter = nil
        interactor = nil
        wireframe = nil
        super.tearDown()
    }

    func testInitiallyIdleWithoutNavigation() {
        XCTAssertEqual(presenter.viewState.value, .idle)
        XCTAssertEqual(wireframe.showMainCount, 0)
    }

    func testLoginPassesCredentialsAndWaitsForSuccess() {
        presenter.loginWithEmail(email: " reader@example.com \n", password: " secret ")

        XCTAssertEqual(interactor.credentials.first?.email, "reader@example.com")
        XCTAssertEqual(interactor.credentials.first?.password, " secret ")
        XCTAssertEqual(presenter.viewState.value, .loading)
        XCTAssertEqual(wireframe.showMainCount, 0)

        interactor.complete(.success(SocialUserEntity(email: "reader@example.com")))

        XCTAssertEqual(presenter.viewState.value, .idle)
        XCTAssertEqual(wireframe.showMainCount, 1)
        XCTAssertTrue(wireframe.navigationWasOnMainThread)
    }

    func testFailureStaysOnLoginAndShowsInlineError() {
        presenter.loginWithEmail(email: "reader@example.com", password: "secret")
        interactor.complete(.failure(LoginFailure.rejected))

        XCTAssertEqual(presenter.viewState.value, .error("Credentials rejected"))
        XCTAssertEqual(wireframe.showMainCount, 0)
    }

    func testOfflineFailureReleasesRequestAndAllowsRetry() {
        presenter.loginWithEmail(email: "reader@example.com", password: "secret")
        interactor.complete(.failure(URLError(.notConnectedToInternet)))

        guard case .error(let message) = presenter.viewState.value else {
            return XCTFail("Offline failure should be visible inline")
        }
        XCTAssertFalse(message.isEmpty)
        XCTAssertEqual(interactor.disposedCount, 1)
        XCTAssertEqual(wireframe.showMainCount, 0)

        presenter.loginWithEmail(email: "reader@example.com", password: "secret")

        XCTAssertEqual(interactor.credentials.count, 2)
        XCTAssertEqual(presenter.viewState.value, .loading)
    }

    func testDuplicateSubmissionWhileLoadingIsIgnored() {
        presenter.loginWithEmail(email: "reader@example.com", password: "secret")
        presenter.loginWithEmail(email: "other@example.com", password: "other")

        XCTAssertEqual(interactor.credentials.count, 1)
        XCTAssertEqual(interactor.disposedCount, 0)
        XCTAssertEqual(presenter.viewState.value, .loading)
    }

    func testCancellationOnLoadingDoesNotStartNetworkWork() {
        let observation = presenter.viewState.subscribe(onNext: { [weak presenter = self.presenter] state in
            if state == .loading { presenter?.cancelLogin() }
        })
        defer { observation.dispose() }

        presenter.loginWithEmail(email: "reader@example.com", password: "secret")

        XCTAssertTrue(interactor.credentials.isEmpty)
        XCTAssertEqual(presenter.viewState.value, .idle)
        XCTAssertEqual(wireframe.showMainCount, 0)
    }

    func testCancelDisposesRequestAndIgnoresLateSuccess() {
        presenter.loginWithEmail(email: "reader@example.com", password: "secret")
        presenter.cancelLogin()
        presenter.cancelLogin()
        interactor.complete(.success(SocialUserEntity()))

        XCTAssertEqual(interactor.disposedCount, 1)
        XCTAssertEqual(presenter.viewState.value, .idle)
        XCTAssertEqual(wireframe.showMainCount, 0)
    }

    func testCancelledCompletionCannotOverrideNewRequest() {
        presenter.loginWithEmail(email: "reader@example.com", password: "secret")
        presenter.cancelLogin()
        presenter.loginWithEmail(email: "reader@example.com", password: "retry")
        interactor.complete(.failure(LoginFailure.rejected), at: 0)

        XCTAssertEqual(presenter.viewState.value, .loading)
        XCTAssertEqual(wireframe.showMainCount, 0)

        interactor.complete(.success(SocialUserEntity()), at: 1)

        XCTAssertEqual(presenter.viewState.value, .idle)
        XCTAssertEqual(wireframe.showMainCount, 1)
    }

    func testContinueWithoutLoginCancelsBeforeNavigating() {
        presenter.loginWithEmail(email: "reader@example.com", password: "secret")
        wireframe.onShowMain = { [interactor = self.interactor!] in
            XCTAssertEqual(interactor.disposedCount, 1)
        }

        presenter.continueWithoutLogin()
        interactor.complete(.success(SocialUserEntity()))

        XCTAssertEqual(interactor.credentials.count, 1)
        XCTAssertEqual(presenter.viewState.value, .idle)
        XCTAssertEqual(wireframe.showMainCount, 1)
    }

    func testContinueWithoutLoginNeverStartsAuthentication() {
        presenter.continueWithoutLogin()

        XCTAssertTrue(interactor.credentials.isEmpty)
        XCTAssertEqual(wireframe.showMainCount, 1)
    }

    func testInvalidCredentialsNeverStartAuthentication() {
        for email in ["", "reader", "@example.com", "reader@", "reader@@example.com", "read er@example.com"] {
            presenter.loginWithEmail(email: email, password: "secret")
            guard case .error = presenter.viewState.value else {
                return XCTFail("Invalid email should be rejected")
            }
        }
        presenter.loginWithEmail(email: "reader@example.com", password: "")

        guard case .error = presenter.viewState.value else {
            return XCTFail("An empty password should be rejected")
        }
        XCTAssertTrue(interactor.credentials.isEmpty)
        XCTAssertEqual(wireframe.showMainCount, 0)
    }

    func testMalformedEmailAndOversizedPasswordAreRejectedBeforeInteractor() {
        presenter.loginWithEmail(email: "reader@example", password: "secret")
        guard case .error = presenter.viewState.value else {
            return XCTFail("An address without a domain suffix must be rejected")
        }

        presenter.loginWithEmail(email: "reader@example.com", password: String(repeating: "a", count: 1025))
        guard case .error = presenter.viewState.value else {
            return XCTFail("A password exceeding the API limit must be rejected")
        }
        XCTAssertTrue(interactor.credentials.isEmpty)
    }

    func testSynchronousFailureDoesNotBlockRetry() {
        interactor.immediateResult = .failure(LoginFailure.rejected)

        presenter.loginWithEmail(email: "reader@example.com", password: "secret")
        presenter.loginWithEmail(email: "reader@example.com", password: "retry")

        XCTAssertEqual(interactor.credentials.count, 2)
        XCTAssertEqual(interactor.disposedCount, 2)
        XCTAssertEqual(presenter.viewState.value, .error("Credentials rejected"))
        XCTAssertEqual(wireframe.showMainCount, 0)
    }

    func testSynchronousSuccessDisposesSubscription() {
        interactor.immediateResult = .success(SocialUserEntity())

        presenter.loginWithEmail(email: "reader@example.com", password: "secret")

        XCTAssertEqual(interactor.disposedCount, 1)
        XCTAssertEqual(presenter.viewState.value, .idle)
        XCTAssertEqual(wireframe.showMainCount, 1)
    }

    func testBackgroundCompletionNavigatesOnMainThread() {
        let navigated = expectation(description: "Navigation on main thread")
        wireframe.onShowMain = { navigated.fulfill() }
        presenter.loginWithEmail(email: "reader@example.com", password: "secret")
        let completion = interactor.completions[0]

        DispatchQueue.global().async {
            completion(.success(SocialUserEntity()))
        }
        wait(for: [navigated], timeout: 1)

        XCTAssertTrue(wireframe.navigationWasOnMainThread)
        XCTAssertEqual(presenter.viewState.value, .idle)
    }

    // MARK: Google

    func testGoogleLoginPresentsOverTheScreenAndWaitsForTheSession() {
        presenter.loginWithGoogle()

        XCTAssertEqual(interactor.googlePresenters.count, 1)
        XCTAssertTrue(interactor.googlePresenters.first === wireframe.presentingViewController)
        XCTAssertEqual(presenter.viewState.value, .signingInWithGoogle)
        XCTAssertEqual(wireframe.showMainCount, 0)

        interactor.complete(.success(SocialUserEntity(email: "reader@example.com")))

        XCTAssertEqual(presenter.viewState.value, .idle)
        XCTAssertEqual(wireframe.showMainCount, 1)
        XCTAssertEqual(interactor.disposedCount, 1)
    }

    func testClosingGoogleSheetReturnsToIdleWithoutAnError() {
        presenter.loginWithGoogle()
        interactor.complete(.failure(GoogleSignInError.cancelled))

        XCTAssertEqual(presenter.viewState.value, .idle)
        XCTAssertEqual(wireframe.showMainCount, 0)

        presenter.loginWithGoogle()
        XCTAssertEqual(interactor.googlePresenters.count, 2, "The user can try again")
    }

    func testGoogleFailuresStayOnTheLoginScreenWithAReadableMessage() {
        let failures: [Error] = [NativeAuthError.googleCredentialsRejected, NativeAuthError.googleAccountConflict,
                                 NativeAuthError.rateLimited, NativeAuthError.unavailable, NativeAuthError.offline,
                                 GoogleSignInError.failed, GoogleSignInError.invalidToken]
        for failure in failures {
            presenter.loginWithGoogle()
            interactor.complete(.failure(failure), at: interactor.completions.count - 1)

            guard case .error(let message) = presenter.viewState.value else {
                return XCTFail("\(failure) should be shown inline")
            }
            XCTAssertEqual(message, failure.localizedDescription)
            XCTAssertFalse(message.isEmpty)
            XCTAssertEqual(wireframe.showMainCount, 0)
        }
    }

    func testAccountConflictTellsTheUserToUseTheirPasswordInsteadOfLinking() {
        presenter.loginWithGoogle()
        interactor.complete(.failure(NativeAuthError.googleAccountConflict))

        XCTAssertEqual(presenter.viewState.value,
                       .error(NativeAuthError.googleAccountConflict.localizedDescription))
        XCTAssertEqual(interactor.credentials.count, 0, "Nothing falls back to a password attempt")
    }

    func testGoogleLoginIsIgnoredWhileAnotherSignInRuns() {
        presenter.loginWithEmail(email: "reader@example.com", password: "secret")
        presenter.loginWithGoogle()
        XCTAssertTrue(interactor.googlePresenters.isEmpty)
        XCTAssertEqual(presenter.viewState.value, .loading)

        presenter.cancelLogin()
        presenter.loginWithGoogle()
        presenter.loginWithEmail(email: "reader@example.com", password: "secret")
        presenter.loginWithGoogle()
        XCTAssertEqual(interactor.googlePresenters.count, 1)
        XCTAssertEqual(interactor.credentials.count, 1)
        XCTAssertEqual(presenter.viewState.value, .signingInWithGoogle)
    }

    func testCancelDuringGoogleSignInIgnoresALateSuccess() {
        presenter.loginWithGoogle()
        presenter.cancelLogin()
        interactor.complete(.success(SocialUserEntity()))

        XCTAssertEqual(interactor.disposedCount, 1)
        XCTAssertEqual(presenter.viewState.value, .idle)
        XCTAssertEqual(wireframe.showMainCount, 0)
    }

    func testContinueWithoutLoginCancelsGoogleSignInFirst() {
        presenter.loginWithGoogle()
        presenter.continueWithoutLogin()
        interactor.complete(.success(SocialUserEntity()))

        XCTAssertEqual(interactor.disposedCount, 1)
        XCTAssertEqual(wireframe.showMainCount, 1, "Only the guest route navigates; the cancelled sign-in does not")
    }

    func testUnconfiguredBuildHidesGoogleAndNeverStartsTheFlow() {
        interactor.isGoogleSignInAvailable = false
        XCTAssertFalse(presenter.isGoogleSignInAvailable)

        presenter.loginWithGoogle()

        XCTAssertTrue(interactor.googlePresenters.isEmpty)
        XCTAssertEqual(presenter.viewState.value, .error(GoogleSignInError.notConfigured.localizedDescription))
    }

    func testAppleSignInWaitsForVerifiedAppSessionAndHandlesCancellation() {
        presenter.loginWithApple()
        XCTAssertEqual(interactor.applePresenters.count, 1)
        XCTAssertTrue(interactor.applePresenters[0] === wireframe.presentingViewController)
        XCTAssertEqual(presenter.viewState.value, .signingInWithApple)
        XCTAssertEqual(wireframe.showMainCount, 0)

        interactor.complete(.failure(AppleSignInError.cancelled))
        XCTAssertEqual(presenter.viewState.value, .idle)

        presenter.loginWithApple()
        interactor.complete(.success(SocialUserEntity()), at: 1)
        XCTAssertEqual(wireframe.showMainCount, 1)
        XCTAssertEqual(presenter.viewState.value, .idle)
    }

    func testAppleSignInIsCancelledWhenLeavingTheScreen() {
        presenter.loginWithApple()
        presenter.cancelLogin()
        interactor.complete(.success(SocialUserEntity()))
        XCTAssertEqual(wireframe.showMainCount, 0)
        XCTAssertEqual(interactor.disposedCount, 1)
    }

    func testDeinitDisposesOwnedRequest() {
        presenter.loginWithEmail(email: "reader@example.com", password: "secret")
        weak var releasedPresenter = presenter

        presenter = nil

        XCTAssertNil(releasedPresenter)
        XCTAssertEqual(interactor.disposedCount, 1)
    }
}

private final class MailLoginInteractorStub: MailLoginInteractorInterface {
    var credentials: [(email: String, password: String)] = []
    var completions: [(SingleEvent<SocialUserEntity>) -> Void] = []
    var disposedCount = 0
    var immediateResult: SingleEvent<SocialUserEntity>?
    var isGoogleSignInAvailable = true
    var googlePresenters: [UIViewController] = []
    var applePresenters: [UIViewController] = []

    func loginWithApple(presenting viewController: UIViewController) -> Single<SocialUserEntity> {
        applePresenters.append(viewController)
        return Single.create { [unowned self] completion in
            self.completions.append(completion)
            if let result = self.immediateResult { completion(result) }
            return Disposables.create { [weak self] in self?.disposedCount += 1 }
        }
    }

    func loginWithGoogle(presenting viewController: UIViewController) -> Single<SocialUserEntity> {
        googlePresenters.append(viewController)
        return Single.create { [unowned self] completion in
            self.completions.append(completion)
            if let result = self.immediateResult { completion(result) }
            return Disposables.create { [weak self] in self?.disposedCount += 1 }
        }
    }

    func login(email: String, password: String) -> Single<SocialUserEntity> {
        credentials.append((email, password))
        return Single.create { [unowned self] completion in
            self.completions.append(completion)
            if let result = self.immediateResult { completion(result) }
            return Disposables.create { [weak self] in self?.disposedCount += 1 }
        }
    }

    func complete(_ event: SingleEvent<SocialUserEntity>, at index: Int = 0) {
        completions[index](event)
    }
}

private final class MailLoginWireframeSpy: MailLoginWireframeInterface {
    var showMainCount = 0
    var navigationWasOnMainThread = false
    var onShowMain: (() -> Void)?
    let presentingViewController = UIViewController()

    func showMain() {
        showMainCount += 1
        navigationWasOnMainThread = Thread.isMainThread
        onShowMain?()
    }
}

private enum LoginFailure: LocalizedError {
    case rejected

    var errorDescription: String? { "Credentials rejected" }
}
