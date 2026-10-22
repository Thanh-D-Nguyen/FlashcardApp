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

    var logoutSessionResult: Single<LogoutResult>?
    func logoutSession() -> Single<LogoutResult> {
        logoutSessionResult ?? .deferred { try self.logout(); return .just(.revoked) }
    }

    var refreshResult: Single<Void> = .just(())
    func refreshCurrentUser() -> Single<Void> { refreshResult }

    func logout() throws {
        logoutCalled = true
        if let error = logoutError { throw error }
    }

    var appearance = "system"
    var notificationStatus: UNAuthorizationStatus = .authorized
    func getAppearance() -> String { appearance }
    func setAppearance(_ value: String) { appearance = value }
    func getNotificationAuthorizationStatus() -> UNAuthorizationStatus { notificationStatus }
    func setNotificationAuthorizationStatus(_ status: UNAuthorizationStatus) { notificationStatus = status }
    var permissionGranted = true
    var permissionRequests = 0
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        permissionRequests += 1
        completion(permissionGranted)
    }

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

    var logoutNoticeMessage: String?
    var logoutNoticeDismissed: (() -> Void)?
    func showLogoutNotice(message: String, onDismiss: @escaping () -> Void) {
        logoutNoticeMessage = message
        logoutNoticeDismissed = onDismiss
    }

    var deniedAlertCount = 0
    func showNotificationDeniedAlert() { deniedAlertCount += 1 }
    var openSystemSettingsCount = 0
    func openSystemSettings() { openSystemSettingsCount += 1 }
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
        guard case .choice(let appearance) = prefItems[0],
              case .toggle(let notifications) = prefItems[1],
              case .toggle(let sound) = prefItems[2] else {
            return XCTFail("Expected appearance choice, notifications toggle and sound toggle")
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
        guard items.count == 3, case .choice(let appearance) = items[0] else {
            return XCTFail("Expected appearance choice")
        }
        XCTAssertEqual(appearance.selectedTitle, AppearanceOption.dark.title)
        XCTAssertEqual(appearance.selectedID, "dark")
        let toggles = items.compactMap { item -> ToggleConfig? in
            if case .toggle(let config) = item { return config }
            return nil
        }
        guard toggles.count == 2 else { return XCTFail("Expected two toggles") }
        XCTAssertFalse(toggles[0].isOn, "Notification should be off")
        XCTAssertTrue(toggles[1].isOn, "Sound should be on")
    }

    // MARK: - Appearance choice

    func test_appearanceChoiceOffersSystemLightAndDarkInOrder() {
        presenter.viewDidLoad()

        guard case .choice(let appearance) = presenter.sectionsRelay.value[1].items[0] else {
            return XCTFail("Expected appearance choice")
        }
        XCTAssertEqual(appearance.id, "appearance")
        XCTAssertEqual(appearance.options.map(\.id), ["system", "light", "dark"])
        XCTAssertEqual(appearance.selectedID, "system")
    }

    func test_selectChoicePersistsAppearanceAndReloadsSelection() {
        presenter.viewDidLoad()

        presenter.selectChoice(id: "appearance", optionID: "light")

        XCTAssertEqual(mockInteractor.appearance, "light")
        guard case .choice(let appearance) = presenter.sectionsRelay.value[1].items[0] else {
            return XCTFail("Expected appearance choice")
        }
        XCTAssertEqual(appearance.selectedID, "light")
    }

    func test_selectChoiceIgnoresUnknownChoiceOrOption() {
        presenter.viewDidLoad()

        presenter.selectChoice(id: "appearance", optionID: "sepia")
        presenter.selectChoice(id: "unknown", optionID: "dark")

        XCTAssertEqual(mockInteractor.appearance, "system")
    }

    func test_storedAppearanceIsResolvedToItsInterfaceStyleAndUnknownFallsBackToSystem() {
        XCTAssertEqual(AppearanceOption.resolve("dark").userInterfaceStyle, .dark)
        XCTAssertEqual(AppearanceOption.resolve("light").userInterfaceStyle, .light)
        XCTAssertEqual(AppearanceOption.resolve("system").userInterfaceStyle, .unspecified)
        XCTAssertEqual(AppearanceOption.resolve("sepia"), .system, "A corrupt stored value must not force a style")
        XCTAssertEqual(AppearanceOption.resolve(""), .system)
    }

    func test_languageRowShowsTheAppLanguageAndOpensSystemSettings() throws {
        presenter.viewDidLoad()
        let general = presenter.sectionsRelay.value[2].items
        guard case .navigation(let language) = try XCTUnwrap(general.first) else { return XCTFail("Expected the language row") }
        XCTAssertEqual(language.id, "language")
        XCTAssertEqual(language.subText, AppLanguage.current.nativeName, "The value is the language in its own words")

        presenter.handleNavigationTap(config: language)

        XCTAssertEqual(mockWireframe.openSystemSettingsCount, 1, "iOS owns the per-app language; the row hands over to Settings")
    }

    // MARK: - Notification permission

    func test_notDeterminedNotificationToggleIsEnabledSoPermissionCanBeRequested() {
        mockInteractor.notificationStatus = .notDetermined

        presenter.viewDidLoad()

        guard case .toggle(let notifications) = presenter.sectionsRelay.value[1].items[1] else {
            return XCTFail("Expected notifications toggle")
        }
        XCTAssertTrue(notifications.isEnabled, "A disabled switch can never trigger the system permission prompt")
        XCTAssertFalse(notifications.isOn)
    }

    func test_deniedNotificationToggleIsOffAndOffersSystemSettings() {
        mockInteractor.notificationStatus = .denied
        mockInteractor.notificationEnabled = true

        presenter.viewDidLoad()

        let items = presenter.sectionsRelay.value[1].items
        guard case .toggle(let notifications) = items[1] else { return XCTFail("Expected notifications toggle") }
        XCTAssertFalse(notifications.isEnabled)
        XCTAssertFalse(notifications.isOn)
        guard case .navigation(let system) = items[2] else { return XCTFail("Expected system settings row") }
        XCTAssertEqual(system.id, "notifications_system")
    }

    func test_enablingNotificationsRequestsPermissionAndKeepsSwitchOnWhenGranted() {
        mockInteractor.notificationStatus = .notDetermined
        mockInteractor.notificationEnabled = false
        mockInteractor.permissionGranted = true
        presenter.viewDidLoad()

        presenter.toggleNotification(to: true)

        XCTAssertEqual(mockInteractor.permissionRequests, 1)
        XCTAssertEqual(mockInteractor.notificationStatus, .authorized, "The cached status must follow the answer, or the switch snaps back off")
        guard case .toggle(let notifications) = presenter.sectionsRelay.value[1].items[1] else {
            return XCTFail("Expected notifications toggle")
        }
        XCTAssertTrue(notifications.isOn)
        XCTAssertTrue(notifications.isEnabled)
        XCTAssertEqual(mockWireframe.deniedAlertCount, 0)
    }

    func test_enablingNotificationsDeniedExplainsAndKeepsSwitchOff() {
        mockInteractor.notificationStatus = .notDetermined
        mockInteractor.notificationEnabled = false
        mockInteractor.permissionGranted = false
        presenter.viewDidLoad()

        presenter.toggleNotification(to: true)

        XCTAssertEqual(mockInteractor.notificationStatus, .denied)
        XCTAssertEqual(mockWireframe.deniedAlertCount, 1)
        let items = presenter.sectionsRelay.value[1].items
        guard case .toggle(let notifications) = items[1] else { return XCTFail("Expected notifications toggle") }
        XCTAssertFalse(notifications.isOn)
        XCTAssertFalse(notifications.isEnabled)
        guard case .navigation(let system) = items[2] else { return XCTFail("Expected system settings row") }
        XCTAssertEqual(system.id, "notifications_system")
    }

    func test_provisionalNotificationAuthorizationCountsAsOnWhenEnabled() {
        mockInteractor.notificationStatus = .provisional
        mockInteractor.notificationEnabled = true

        presenter.viewDidLoad()

        guard case .toggle(let notifications) = presenter.sectionsRelay.value[1].items[1] else {
            return XCTFail("Expected notifications toggle")
        }
        XCTAssertTrue(notifications.isOn)
        XCTAssertTrue(notifications.isEnabled)
    }

    func test_disablingNotificationsNeverRequestsPermission() {
        mockInteractor.notificationEnabled = true
        presenter.viewDidLoad()

        presenter.toggleNotification(to: false)

        XCTAssertEqual(mockInteractor.permissionRequests, 0)
        XCTAssertFalse(mockInteractor.notificationEnabled)
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

    func test_requestLogout_whenRemoteRevocationIsUnconfirmed_saysSoThenLeavesTheSignedOutScreen() {
        mockInteractor.logoutSessionResult = .just(.remoteUnconfirmed)
        presenter.viewDidLoad()
        presenter.requestLogout()

        mockWireframe.logoutConfirmationHandler?()

        XCTAssertNotNil(mockWireframe.logoutNoticeMessage, "The user must be told the server was not informed")
        XCTAssertNil(mockWireframe.lastErrorMessage)
        XCTAssertFalse(mockWireframe.navigateToWelcomeCalled, "Navigation waits until the notice is dismissed")
        mockWireframe.logoutNoticeDismissed?()
        XCTAssertTrue(mockWireframe.navigateToWelcomeCalled,
                      "The local session is gone, so the screen must not keep showing a signed-in context")
    }

    func test_requestLogout_whenServerConfirms_navigatesWithoutNotice() {
        mockInteractor.logoutSessionResult = .just(.revoked)
        presenter.viewDidLoad()
        presenter.requestLogout()

        mockWireframe.logoutConfirmationHandler?()

        XCTAssertNil(mockWireframe.logoutNoticeMessage)
        XCTAssertTrue(mockWireframe.navigateToWelcomeCalled)
    }

    func test_requestLogout_confirmedTwice_logsOutOnce() {
        let pending = PublishSubject<LogoutResult>()
        mockInteractor.logoutSessionResult = pending.take(1).asSingle()
        presenter.viewDidLoad()
        presenter.requestLogout()
        let confirm = mockWireframe.logoutConfirmationHandler
        confirm?()
        confirm?()
        presenter.requestLogout()

        pending.onNext(.revoked)

        XCTAssertTrue(mockWireframe.navigateToWelcomeCalled)
        XCTAssertNil(mockWireframe.lastErrorMessage)
    }

    // MARK: - Session refresh

    func test_viewWillAppear_whenOfflineKeepsTheSessionWithoutInterruptingTheUser() {
        mockInteractor.currentUser = SocialUserEntity(id: "7c2218b4-590b-49b2-8be0-076fd9992135")
        mockInteractor.refreshResult = .error(NativeAuthError.unavailable)
        presenter.viewDidLoad()

        presenter.viewWillAppear()

        XCTAssertNil(mockWireframe.lastErrorMessage)
    }

    func test_viewWillAppear_whenSessionExpired_tellsTheUser() {
        mockInteractor.refreshResult = .error(NativeAuthError.unauthorized)
        presenter.viewDidLoad()

        presenter.viewWillAppear()

        XCTAssertEqual(mockWireframe.lastErrorMessage, NativeAuthError.unauthorized.localizedDescription)
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
