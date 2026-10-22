//
//  StartUpPresenterTests.swift
//  FlashcardAppTests
//

import XCTest
import RxSwift
@testable import FlashcardApp

// MARK: - Mocks

private final class MockStartUpInteractor: StartUpInteractorInterface {
    private(set) var prepareCalls = 0
    private var onComplete: (() -> Void)?
    private var onError: ((AppError) -> Void)?
    /// When set, preparation finishes synchronously like a warm launch.
    var completesImmediately = false

    func prepareDatabase(onComplete: @escaping () -> Void, onError: @escaping (AppError) -> Void) {
        prepareCalls += 1
        self.onComplete = onComplete
        self.onError = onError
        if completesImmediately { complete() }
    }

    func complete() { onComplete?() }
    func fail(_ error: AppError) { onError?(error) }
}

private final class MockStartUpWireframe: StartUpWireframeInterface {
    private(set) var navigations: [Bool] = []
    func navigateToMain(animated: Bool) { navigations.append(animated) }
    func showAlert(with title: String?, message: String?) {}
    func back() {}
    func close() {}
}

// MARK: - Tests

final class StartUpPresenterTests: XCTestCase {
    private var interactor: MockStartUpInteractor!
    private var wireframe: MockStartUpWireframe!
    private var states: [StartUpState] = []
    private let disposeBag = DisposeBag()

    override func setUp() {
        super.setUp()
        interactor = MockStartUpInteractor()
        wireframe = MockStartUpWireframe()
        states = []
    }

    private func makePresenter(grace: DispatchTimeInterval = .milliseconds(40)) -> StartUpPresenter {
        let presenter = StartUpPresenter(interactor: interactor, wireframe: wireframe, loadingGraceDelay: grace)
        presenter.stateRelay.subscribe(onNext: { [weak self] in self?.states.append($0) }).disposed(by: disposeBag)
        return presenter
    }

    private func wait(_ seconds: TimeInterval) {
        let expectation = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { expectation.fulfill() }
        wait(for: [expectation], timeout: seconds + 2)
    }

    // Warm launch: the local database is ready at once, so the user must never see an interstitial.
    func test_fastPreparationHandsOffToMainWithoutLoadingUI() {
        interactor.completesImmediately = true
        let presenter = makePresenter()
        presenter.viewWillAppear()
        wait(0.15)
        XCTAssertEqual(wireframe.navigations, [false], "Navigates once, without a transition")
        XCTAssertFalse(states.contains(.slow), "The grace period must cancel the loading reveal")
    }

    // Repeated appearance callbacks must not run the Realm bootstrap twice or push Main twice.
    func test_repeatedViewWillAppearStartsPreparationOnlyOnce() {
        let presenter = makePresenter()
        presenter.viewWillAppear()
        presenter.viewWillAppear()
        presenter.viewWillAppear()
        XCTAssertEqual(interactor.prepareCalls, 1)
        interactor.complete()
        presenter.viewWillAppear()
        XCTAssertEqual(interactor.prepareCalls, 1, "No restart after the database is ready")
        XCTAssertEqual(wireframe.navigations.count, 1)
    }

    // First install: the bundled store is copied, which takes noticeable time.
    func test_slowPreparationShowsLoadingAfterGraceAndCrossfadesToMain() {
        let presenter = makePresenter()
        presenter.viewWillAppear()
        XCTAssertEqual(states.last, .preparing, "Nothing is shown during the grace period")
        wait(0.2)
        XCTAssertEqual(states.last, .slow)
        interactor.complete()
        XCTAssertEqual(wireframe.navigations, [true], "A visible loading state hands off with a cross-fade")
    }

    func test_completingTwiceNavigatesOnce() {
        let presenter = makePresenter()
        presenter.viewWillAppear()
        interactor.complete()
        interactor.complete()
        XCTAssertEqual(wireframe.navigations.count, 1)
    }

    func test_failureShowsRetryableErrorAndDoesNotNavigate() {
        let presenter = makePresenter()
        presenter.viewWillAppear()
        let error = AppError.databaseInitializationFailed("disk full")
        interactor.fail(error)
        XCTAssertEqual(states.last, .failed("disk full"), "Shows the specific reason without the generic prefix")
        XCTAssertTrue(wireframe.navigations.isEmpty)
        wait(0.15)
        XCTAssertEqual(states.last, .failed("disk full"), "A pending loading reveal must not overwrite the error")
    }

    func test_otherErrorsFallBackToTheirDescription() {
        let presenter = makePresenter()
        presenter.viewWillAppear()
        interactor.fail(.entityNotFound("Level"))
        XCTAssertEqual(states.last, .failed(AppError.entityNotFound("Level").errorDescription ?? ""))
    }

    func test_retryAfterFailureRunsPreparationAgainAndNavigatesOnSuccess() {
        let presenter = makePresenter()
        presenter.viewWillAppear()
        interactor.fail(.databaseInitializationFailed("busy"))
        presenter.retry()
        XCTAssertEqual(interactor.prepareCalls, 2)
        XCTAssertEqual(states.last, .slow, "Retry shows progress immediately; the user already saw the screen")
        interactor.complete()
        XCTAssertEqual(wireframe.navigations, [true])
    }

    func test_retryWhileStillPreparingIsIgnored() {
        let presenter = makePresenter()
        presenter.viewWillAppear()
        presenter.retry()
        XCTAssertEqual(interactor.prepareCalls, 1)
    }
}

// The system launch screen can only reference a color asset, so keep it equal to the in-app token.
final class LaunchBackgroundTests: XCTestCase {
    func test_launchBackgroundAssetMatchesDesignBackgroundInBothAppearances() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let asset = try XCTUnwrap(UIColor(named: "LaunchBackground", in: Bundle(for: StartUpPresenter.self), compatibleWith: traits))
            let expected = components(of: Design.Color.background.resolvedColor(with: traits))
            let actual = components(of: asset.resolvedColor(with: traits))
            for (a, e) in zip(actual, expected) {
                XCTAssertEqual(a, e, accuracy: 0.003, "LaunchBackground differs from Design.Color.background (\(style))")
            }
        }
    }

    private func components(of color: UIColor) -> [CGFloat] {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha]
    }
}

// The shipped launch screen is the compiled storyboard; it must stay an empty surface in the app background
// (HIG: no logo, text, timers or animation) so the hand-off to the first screen has no visible change.
final class LaunchScreenStoryboardTests: XCTestCase {
    func test_launchScreenIsAnEmptyViewInTheAppBackgroundColor() throws {
        let storyboard = UIStoryboard(name: "LaunchScreen", bundle: Bundle(for: StartUpPresenter.self))
        let controller = try XCTUnwrap(storyboard.instantiateInitialViewController())
        controller.loadViewIfNeeded()
        XCTAssertTrue(controller.view.subviews.isEmpty, "Launch screen must not contain branding, text or indicators")
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let launch = try XCTUnwrap(controller.view.backgroundColor).resolvedColor(with: traits)
            let app = Design.Color.background.resolvedColor(with: traits)
            var l: (CGFloat, CGFloat, CGFloat) = (0, 0, 0), a: (CGFloat, CGFloat, CGFloat) = (0, 0, 0), alpha: CGFloat = 0
            launch.getRed(&l.0, green: &l.1, blue: &l.2, alpha: &alpha)
            app.getRed(&a.0, green: &a.1, blue: &a.2, alpha: &alpha)
            XCTAssertEqual(l.0, a.0, accuracy: 0.003, "red (\(style))")
            XCTAssertEqual(l.1, a.1, accuracy: 0.003, "green (\(style))")
            XCTAssertEqual(l.2, a.2, accuracy: 0.003, "blue (\(style))")
        }
    }
}
