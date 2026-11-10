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
    var deleteAccountResult: Single<Void> = .just(())
    var deletionCalls = 0
    func deleteAccountSession() -> Single<Void> {
        deletionCalls += 1
        return deleteAccountResult
    }
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
    var language = "system"
    func getLanguage() -> String { language }
    func setLanguage(_ value: String) { language = value }
    var notificationStatus: UNAuthorizationStatus = .authorized
    var reminderHour = 20
    var scheduledHours: [Int] = []
    var reminderCancelCount = 0
    var scheduleError: Error?
    var deferSchedules = false
    var pendingScheduleCompletions: [(Error?) -> Void] = []
    func getReminderHour() -> Int { reminderHour }
    func setReminderHour(_ hour: Int) { reminderHour = hour }
    func scheduleDailyReminder(hour: Int, completion: @escaping (Error?) -> Void) {
        scheduledHours.append(hour)
        if deferSchedules {
            pendingScheduleCompletions.append(completion)
        } else {
            completion(scheduleError)
        }
    }
    func finishNextSchedule(error: Error? = nil) {
        pendingScheduleCompletions.removeFirst()(error)
    }
    func cancelDailyReminder() { reminderCancelCount += 1 }
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
    var deleteConfirmationHandler: (() -> Void)?
    func showDeleteAccountConfirmation(onConfirm: @escaping () -> Void) {
        deleteConfirmationHandler = onConfirm
    }
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

    var accountDeletedNoticeMessage: String?
    var accountDeletedNoticeDismissed: (() -> Void)?
    func showAccountDeletedNotice(message: String, onDismiss: @escaping () -> Void) {
        accountDeletedNoticeMessage = message
        accountDeletedNoticeDismissed = onDismiss
    }

    var deniedAlertCount = 0
    func showNotificationDeniedAlert() { deniedAlertCount += 1 }
    var languageReloadCount = 0
    func reloadInterfaceForLanguage() { languageReloadCount += 1 }
    var openSystemSettingsCount = 0
    func openSystemSettings() { openSystemSettingsCount += 1 }
    func showPrivacyPolicy() {}
    var termsOpened = false
    func showTermsOfService() { termsOpened = true }
    var supportOpened = false
    func showContactSupport() { supportOpened = true }
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

    func test_legalAndSupportLinksExistAndRouteToWireframe() {
        presenter.viewDidLoad()
        let generalItems = presenter.sectionsRelay.value[2].items
        let actions = generalItems.compactMap { item -> NavigationConfig? in
            if case .navigation(let config) = item { return config }
            return nil
        }
        XCTAssertTrue(actions.contains(where: { $0.id == "terms" }))
        XCTAssertTrue(actions.contains(where: { $0.id == "support" }))

        presenter.handleNavigationTap(config: NavigationConfig(id: "terms", title: "Terms of Service", iconName: "doc.text"))
        presenter.handleNavigationTap(config: NavigationConfig(id: "support", title: "Contact Support", iconName: "bubble.left"))
        XCTAssertTrue(mockWireframe.termsOpened)
        XCTAssertTrue(mockWireframe.supportOpened)
    }

    func test_viewDidLoad_preferencesSectionShowsReminderTimeWhenEnabled() {
        presenter.viewDidLoad()

        let sections = presenter.sectionsRelay.value
        let prefItems = sections[1].items
        guard prefItems.count == 4 else { return XCTFail("Expected four preferences") }
        guard case .choice(let appearance) = prefItems[0],
              case .toggle(let notifications) = prefItems[1],
              case .choice(let reminderTime) = prefItems[2],
              case .toggle(let sound) = prefItems[3] else {
            return XCTFail("Expected appearance, notifications, reminder time and sound")
        }
        XCTAssertEqual(appearance.id, "appearance")
        XCTAssertEqual(notifications.id, "notification")
        XCTAssertEqual(reminderTime.id, "reminder_time")
        XCTAssertEqual(reminderTime.selectedID, "20")
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

    func test_languageChoiceDefaultsToTheSystemLanguageAndOffersThreeLanguages() throws {
        presenter.viewDidLoad()
        let general = presenter.sectionsRelay.value[2].items
        guard case .choice(let language) = try XCTUnwrap(general.first) else { return XCTFail("Expected the language choice") }
        XCTAssertEqual(language.id, "language")
        XCTAssertEqual(language.options.map(\.id), ["system", "vi", "en", "ja"])
        XCTAssertEqual(language.selectedID, "system", "Without a choice the app follows the device language")
        XCTAssertEqual(mockWireframe.openSystemSettingsCount, 0, "The app no longer hands the language over to iOS Settings")
    }

    func test_pickingALanguageStoresItAndRebuildsTheInterfaceOnlyWhenItChanges() throws {
        presenter.viewDidLoad()

        presenter.selectChoice(id: "language", optionID: "ja")

        XCTAssertEqual(mockInteractor.language, "ja")
        XCTAssertEqual(mockWireframe.languageReloadCount, 1, "Every open screen must read the new language, so the interface is rebuilt")
        guard case .choice(let language) = presenter.sectionsRelay.value[2].items[0] else { return XCTFail("Expected the language choice") }
        XCTAssertEqual(language.selectedID, "ja")

        presenter.selectChoice(id: "language", optionID: "ja")
        XCTAssertEqual(mockWireframe.languageReloadCount, 1, "Choosing the language already in use changes nothing")

        presenter.selectChoice(id: "language", optionID: "system")
        XCTAssertEqual(mockInteractor.language, "system", "Going back to the system language is a choice too")
        XCTAssertEqual(mockWireframe.languageReloadCount, 2)
    }

    func test_unknownLanguageOptionIsIgnored() {
        presenter.viewDidLoad()

        presenter.selectChoice(id: "language", optionID: "fr")

        XCTAssertEqual(mockInteractor.language, "system")
        XCTAssertEqual(mockWireframe.languageReloadCount, 0)
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
        XCTAssertEqual(mockInteractor.scheduledHours, [20])
        XCTAssertTrue(mockInteractor.notificationEnabled)
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
        XCTAssertEqual(mockInteractor.reminderCancelCount, 1)
    }

    func test_scheduleFailureKeepsNotificationOffAndReportsError() {
        mockInteractor.notificationEnabled = false
        mockInteractor.scheduleError = NSError(domain: "test", code: 5)
        presenter.viewDidLoad()

        presenter.toggleNotification(to: true)

        XCTAssertEqual(mockInteractor.scheduledHours, [20])
        XCTAssertFalse(mockInteractor.notificationEnabled)
        XCTAssertNotNil(mockWireframe.lastErrorMessage)
    }

    func test_choosingReminderHourReschedulesBeforePersistingTime() {
        presenter.viewDidLoad()

        presenter.selectChoice(id: "reminder_time", optionID: "7")

        XCTAssertEqual(mockInteractor.scheduledHours, [7])
        XCTAssertEqual(mockInteractor.reminderHour, 7)
        presenter.selectChoice(id: "reminder_time", optionID: "24")
        XCTAssertEqual(mockInteractor.scheduledHours, [7])
    }

    func test_failedHourChangeRetainsPreviousTime() {
        mockInteractor.scheduleError = NSError(domain: "test", code: 6)
        presenter.viewDidLoad()

        presenter.selectChoice(id: "reminder_time", optionID: "9")

        XCTAssertEqual(mockInteractor.reminderHour, 20)
        XCTAssertNotNil(mockWireframe.lastErrorMessage)
    }

    func test_rapidReminderHourChangesScheduleInOrderAndPersistTheLastHour() {
        mockInteractor.deferSchedules = true
        presenter.viewDidLoad()

        presenter.selectChoice(id: "reminder_time", optionID: "7")
        presenter.selectChoice(id: "reminder_time", optionID: "9")
        XCTAssertEqual(mockInteractor.scheduledHours, [7], "Never issue overlapping requests for the same notification ID")

        mockInteractor.finishNextSchedule()
        XCTAssertEqual(mockInteractor.scheduledHours, [7, 9])
        XCTAssertEqual(mockInteractor.reminderHour, 20, "A superseded request must not persist its hour")
        mockInteractor.finishNextSchedule()
        XCTAssertEqual(mockInteractor.reminderHour, 9)
    }

    func test_disablingReminderDuringScheduleCancelsLateResult() {
        mockInteractor.deferSchedules = true
        presenter.viewDidLoad()

        presenter.selectChoice(id: "reminder_time", optionID: "7")
        presenter.toggleNotification(to: false)
        XCTAssertFalse(mockInteractor.notificationEnabled)
        XCTAssertEqual(mockInteractor.reminderCancelCount, 1)

        mockInteractor.finishNextSchedule()
        XCTAssertFalse(mockInteractor.notificationEnabled)
        XCTAssertEqual(mockInteractor.reminderHour, 20)
        XCTAssertEqual(mockInteractor.reminderCancelCount, 2)
    }

    func test_newestSoundAndHourChangesAreAppliedWithoutOverlappingAdds() {
        mockInteractor.deferSchedules = true
        presenter.viewDidLoad()

        presenter.toggleSound(to: false)
        presenter.selectChoice(id: "reminder_time", optionID: "8")
        presenter.selectChoice(id: "reminder_time", optionID: "9")
        XCTAssertEqual(mockInteractor.scheduledHours, [20])

        mockInteractor.finishNextSchedule()
        XCTAssertEqual(mockInteractor.scheduledHours, [20, 9])
        mockInteractor.finishNextSchedule()
        XCTAssertFalse(mockInteractor.soundEnabled)
        XCTAssertEqual(mockInteractor.reminderHour, 9)
    }

    func test_soundChangeReschedulesActiveReminder() {
        presenter.viewDidLoad()

        presenter.toggleSound(to: false)

        XCTAssertFalse(mockInteractor.soundEnabled)
        XCTAssertEqual(mockInteractor.scheduledHours, [20])
    }

    func test_dailyReminderRequestRepeatsAtChosenHourAndRespectsSoundSetting() {
        let request = DailyStudyReminder.makeRequest(hour: 7, soundEnabled: false)
        XCTAssertEqual(request.identifier, DailyStudyReminder.identifier)
        let trigger = request.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.dateComponents.hour, 7)
        XCTAssertEqual(trigger?.dateComponents.minute, 0)
        XCTAssertEqual(trigger?.repeats, true)
        XCTAssertNil(request.content.sound)
    }

    func test_dailyReminderReconcilesChangedHourSoundAndLanguage() {
        let current = DailyStudyReminder.makeRequest(hour: 7, soundEnabled: true)
        XCTAssertFalse(DailyStudyReminder.needsRescheduling(existing: current, hour: 7, soundEnabled: true))
        XCTAssertTrue(DailyStudyReminder.needsRescheduling(existing: current, hour: 8, soundEnabled: true))
        XCTAssertTrue(DailyStudyReminder.needsRescheduling(existing: current, hour: 7, soundEnabled: false))

        let obsoleteContent = UNMutableNotificationContent()
        obsoleteContent.title = "Old language"
        obsoleteContent.body = current.content.body
        obsoleteContent.sound = .default
        let obsolete = UNNotificationRequest(identifier: DailyStudyReminder.identifier,
            content: obsoleteContent, trigger: current.trigger)
        XCTAssertTrue(DailyStudyReminder.needsRescheduling(existing: obsolete, hour: 7, soundEnabled: true))
        XCTAssertTrue(DailyStudyReminder.needsRescheduling(existing: nil, hour: 7, soundEnabled: true))
    }

    func test_dailyReminderCancelsPendingRequestWhenSystemPermissionIsRevoked() {
        XCTAssertTrue(DailyStudyReminder.canSchedule(enabled: true, authorization: .authorized))
        XCTAssertTrue(DailyStudyReminder.canSchedule(enabled: true, authorization: .provisional))
        XCTAssertTrue(DailyStudyReminder.canSchedule(enabled: true, authorization: .ephemeral))
        XCTAssertFalse(DailyStudyReminder.canSchedule(enabled: true, authorization: .denied))
        XCTAssertFalse(DailyStudyReminder.canSchedule(enabled: true, authorization: .notDetermined))
        XCTAssertFalse(DailyStudyReminder.canSchedule(enabled: false, authorization: .authorized))
    }

    func test_reminderTapNotifiesObserversAndDoesNotLeaveAConsumedIntent() {
        _ = DailyStudyReminder.consumeOpenReview()
        var received = 0
        let center = NotificationCenter()
        let observer = center.addObserver(forName: DailyStudyReminder.openReviewNotification,
                                          object: nil, queue: nil) { _ in received += 1 }
        defer { center.removeObserver(observer) }
        DailyStudyReminder.requestOpenReview(center: center)
        XCTAssertEqual(received, 1)
        XCTAssertTrue(DailyStudyReminder.consumeOpenReview())
        XCTAssertFalse(DailyStudyReminder.consumeOpenReview())
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

    func testDeleteAccountRequiresConfirmationThenShowsSuccessOnlyAfterServerReply() {
        let pending = PublishSubject<Void>()
        mockInteractor.currentUser = SocialUserEntity(id: "7c2218b4-590b-49b2-8be0-076fd9992135")
        mockInteractor.deleteAccountResult = pending.take(1).asSingle()
        presenter.viewDidLoad()
        guard let last = presenter.sectionsRelay.value.last,
              last.items.contains(where: { if case .destructive(let item) = $0 { return item.id == "delete_account" }; return false }) else {
            return XCTFail("Account deletion must be discoverable when signed in")
        }
        presenter.handleNavigationTap(config: NavigationConfig(id: "delete_account", title: "Delete Account", iconName: "trash"))
        XCTAssertNotNil(mockWireframe.deleteConfirmationHandler)
        XCTAssertEqual(mockInteractor.deletionCalls, 0)
        let confirm = mockWireframe.deleteConfirmationHandler
        confirm?()
        confirm?()
        XCTAssertEqual(mockInteractor.deletionCalls, 1)
        XCTAssertFalse(mockWireframe.navigateToWelcomeCalled)
        pending.onNext(())
        XCTAssertNotNil(mockWireframe.accountDeletedNoticeMessage)
        XCTAssertTrue(mockWireframe.accountDeletedNoticeMessage?.contains("Apple") == true)
        XCTAssertFalse(mockWireframe.navigateToWelcomeCalled)
        mockWireframe.accountDeletedNoticeDismissed?()
        XCTAssertTrue(mockWireframe.navigateToWelcomeCalled)
    }

    func testDeleteAccountFailureDoesNotNavigateOrLogOut() {
        mockInteractor.currentUser = SocialUserEntity(id: "7c2218b4-590b-49b2-8be0-076fd9992135")
        mockInteractor.deleteAccountResult = .error(NativeAuthError.offline)
        presenter.viewDidLoad()
        presenter.handleNavigationTap(config: NavigationConfig(id: "delete_account", title: "Delete Account", iconName: "trash"))
        mockWireframe.deleteConfirmationHandler?()
        XCTAssertFalse(mockWireframe.navigateToWelcomeCalled)
        XCTAssertEqual(mockInteractor.deletionCalls, 1)
        XCTAssertNotNil(mockWireframe.lastErrorMessage)
    }

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
