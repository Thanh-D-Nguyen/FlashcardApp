//
//  SettingPresenterTests.swift
//  FlashcardAppTests
//
//  Created by Claude on 2026/09/07.
//

import XCTest
import RxSwift
import UserNotifications
@testable import FlashcardApp

// MARK: - Mocks

final class MockSettingInteractor: SettingInteractorInterface {
    var currentUser: SocialUserEntity?
    var logoutCalled = false
    var logoutError: Error?
    var notificationEnabled = true
    var soundEnabled = true

    func getCurrentUser() -> SocialUserEntity? { currentUser }

    func logout() throws {
        logoutCalled = true
        if let error = logoutError { throw error }
    }

    var appearance = "system"
    var notificationStatus: UNAuthorizationStatus = .authorized
    func getAppearance() -> String { appearance }
    func setAppearance(_ value: String) { appearance = value }
    func getNotificationAuthorizationStatus() -> UNAuthorizationStatus { notificationStatus }

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

    func showNotificationDeniedAlert() {}
    func openSystemSettings() {}
    func showAppearancePicker(current: AppearanceOption, onSelect: @escaping (AppearanceOption) -> Void) {}
    func showLanguagePicker() {}
    func showPrivacyPolicy() {}
    func showAbout() {}
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

    func test_viewDidLoad_preferencesSectionHasAppearanceAndTwoToggles() {
        presenter.viewDidLoad()

        let sections = presenter.sectionsRelay.value
        let prefItems = sections[1].items
        guard prefItems.count == 3 else { return XCTFail("Expected three preferences") }
        guard case .navigation(let appearance) = prefItems[0],
              case .toggle(let notifications) = prefItems[1],
              case .toggle(let sound) = prefItems[2] else {
            return XCTFail("Expected appearance navigation, notifications toggle and sound toggle")
        }
        XCTAssertEqual(appearance.id, "appearance")
        XCTAssertEqual(notifications.id, "notification")
        XCTAssertEqual(sound.id, "sound")
    }

    func test_viewDidLoad_reflectsCurrentToggleStates() {
        mockInteractor.appearance = "dark"
        mockInteractor.notificationEnabled = false
        mockInteractor.soundEnabled = true

        presenter.viewDidLoad()

        let items = presenter.sectionsRelay.value[1].items
        guard items.count == 3, case .navigation(let appearance) = items[0] else {
            return XCTFail("Expected appearance navigation")
        }
        XCTAssertEqual(appearance.subText, AppearanceOption.dark.title)
        let toggles = items.compactMap { item -> ToggleConfig? in
            if case .toggle(let config) = item { return config }
            return nil
        }
        guard toggles.count == 2 else { return XCTFail("Expected two toggles") }
        XCTAssertFalse(toggles[0].isOn, "Notification should be off")
        XCTAssertTrue(toggles[1].isOn, "Sound should be on")
    }

    // MARK: - Toggle actions

    func test_toggleDarkMode_persistsValue() {
        presenter.viewDidLoad()
        presenter.toggleDarkMode(to: true)

        XCTAssertEqual(mockInteractor.appearance, "dark")
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

        XCTAssertEqual(reloadCount, 2, "One reload on load and one after appearance changes")
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
        XCTAssertEqual(mockWireframe.lastErrorMessage, mockInteractor.logoutError?.localizedDescription)
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
