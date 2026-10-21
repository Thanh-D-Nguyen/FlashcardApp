//
//  SettingPresenterTests.swift
//  FlashcardAppTests
//
//  Created by Claude on 2026/09/07.
//

import XCTest
import RxSwift
@testable import FlashcardApp

// MARK: - Mocks

final class MockSettingInteractor: SettingInteractorInterface {
    var currentUser: SocialUserEntity?
    var logoutCalled = false
    var logoutError: Error?
    var darkModeEnabled = false
    var notificationEnabled = true
    var soundEnabled = true

    func getCurrentUser() -> SocialUserEntity? { currentUser }

    func logout() throws {
        logoutCalled = true
        if let error = logoutError { throw error }
    }

    func getDarkModeEnabled() -> Bool { darkModeEnabled }
    func setDarkModeEnabled(_ enabled: Bool) { darkModeEnabled = enabled }
    func getNotificationEnabled() -> Bool { notificationEnabled }
    func setNotificationEnabled(_ enabled: Bool) { notificationEnabled = enabled }
    func getSoundEnabled() -> Bool { soundEnabled }
    func setSoundEnabled(_ enabled: Bool) { soundEnabled = enabled }
}

final class MockSettingWireframe: SettingWireframeInterface {
    var logoutConfirmationHandler: (() -> Void)?
    var navigateToWelcomeCalled = false
    var lastErrorMessage: String?

    func showLogoutConfirmation(onConfirm: @escaping () -> Void) {
        logoutConfirmationHandler = onConfirm
    }

    func navigateToWelcome() {
        navigateToWelcomeCalled = true
    }

    func showError(message: String) {
        lastErrorMessage = message
    }
}

// MARK: - Tests

final class SettingPresenterTests: XCTestCase {

    private var presenter: SettingPresenter!
    private var mockInteractor: MockSettingInteractor!
    private var mockWireframe: MockSettingWireframe!
    private var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()
        mockInteractor = MockSettingInteractor()
        mockWireframe = MockSettingWireframe()
        presenter = SettingPresenter(interactor: mockInteractor, wireframe: mockWireframe)
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        presenter = nil
        mockInteractor = nil
        mockWireframe = nil
        disposeBag = nil
        super.tearDown()
    }

    // MARK: - viewDidLoad

    func test_viewDidLoad_loadsFourSections() {
        presenter.viewDidLoad()

        let sections = presenter.sectionsRelay.value
        XCTAssertEqual(sections.count, 4, "Expected account, preferences, general, logout sections")
    }

    func test_viewDidLoad_firstSectionIsAccount() {
        presenter.viewDidLoad()

        let sections = presenter.sectionsRelay.value
        guard case .account = sections[0].items.first else {
            XCTFail("First section should contain an account item")
            return
        }
    }

    func test_viewDidLoad_preferencesSectionHasThreeToggles() {
        presenter.viewDidLoad()

        let sections = presenter.sectionsRelay.value
        let prefItems = sections[1].items
        XCTAssertEqual(prefItems.count, 3)
        for item in prefItems {
            guard case .toggle = item else {
                XCTFail("Preferences section should only contain toggle items")
                return
            }
        }
    }

    func test_viewDidLoad_reflectsCurrentToggleStates() {
        mockInteractor.darkModeEnabled = true
        mockInteractor.notificationEnabled = false
        mockInteractor.soundEnabled = true

        presenter.viewDidLoad()

        let toggles = presenter.sectionsRelay.value[1].items.compactMap { item -> ToggleConfig? in
            if case .toggle(let config) = item { return config }
            return nil
        }
        XCTAssertTrue(toggles[0].isOn, "Dark mode should be on")
        XCTAssertFalse(toggles[1].isOn, "Notification should be off")
        XCTAssertTrue(toggles[2].isOn, "Sound should be on")
    }

    // MARK: - Toggle actions

    func test_toggleDarkMode_persistsValue() {
        presenter.viewDidLoad()
        presenter.toggleDarkMode(to: true)

        XCTAssertTrue(mockInteractor.darkModeEnabled)
    }

    func test_toggleNotification_persistsValue() {
        presenter.viewDidLoad()
        presenter.toggleNotification(to: false)

        XCTAssertFalse(mockInteractor.notificationEnabled)
    }

    func test_toggleSound_persistsValue() {
        presenter.viewDidLoad()
        presenter.toggleSound(to: false)

        XCTAssertFalse(mockInteractor.soundEnabled)
    }

    func test_toggleDarkMode_reloadsSections() {
        var reloadCount = 0
        presenter.sectionsRelay
            .skip(1)
            .subscribe(onNext: { _ in reloadCount += 1 })
            .disposed(by: disposeBag)

        presenter.viewDidLoad()
        presenter.toggleDarkMode(to: true)

        XCTAssertGreaterThanOrEqual(reloadCount, 1, "Sections should reload after toggle")
    }

    // MARK: - Logout

    func test_requestLogout_showsConfirmation() {
        presenter.viewDidLoad()
        presenter.requestLogout()

        XCTAssertNotNil(mockWireframe.logoutConfirmationHandler, "Should show logout confirmation")
        XCTAssertFalse(mockInteractor.logoutCalled, "Should not logout before confirmation")
    }

    func test_requestLogout_onConfirm_callsLogoutAndNavigates() {
        presenter.viewDidLoad()
        presenter.requestLogout()

        mockWireframe.logoutConfirmationHandler?()

        XCTAssertTrue(mockInteractor.logoutCalled)
        XCTAssertTrue(mockWireframe.navigateToWelcomeCalled)
    }

    func test_requestLogout_onError_showsErrorWithoutNavigating() {
        mockInteractor.logoutError = AppError.authenticationFailed("Test error")
        presenter.viewDidLoad()
        presenter.requestLogout()

        mockWireframe.logoutConfirmationHandler?()

        XCTAssertTrue(mockInteractor.logoutCalled)
        XCTAssertFalse(mockWireframe.navigateToWelcomeCalled)
        XCTAssertEqual(mockWireframe.lastErrorMessage, "Test error")
    }

    // MARK: - Account display

    func test_viewDidLoad_withLoggedInUser_showsUserInfo() {
        let user = SocialUserEntity(displayName: "Test User", email: "test@example.com")
        mockInteractor.currentUser = user

        presenter.viewDidLoad()

        let sections = presenter.sectionsRelay.value
        guard case .account(let displayedUser) = sections[0].items.first else {
            XCTFail("First item should be account")
            return
        }
        XCTAssertEqual(displayedUser?.displayName, "Test User")
        XCTAssertEqual(displayedUser?.email, "test@example.com")
    }

    func test_viewDidLoad_withoutUser_showsNilAccount() {
        mockInteractor.currentUser = nil

        presenter.viewDidLoad()

        let sections = presenter.sectionsRelay.value
        guard case .account(let displayedUser) = sections[0].items.first else {
            XCTFail("First item should be account")
            return
        }
        XCTAssertNil(displayedUser)
    }
}

// MARK: - SocialUserEntity test helper

private extension SocialUserEntity {
    init(displayName: String?, email: String?) {
        self.displayName = displayName
        self.email = email
        self.phoneNumber = nil
        self.photoUrl = nil
    }
}