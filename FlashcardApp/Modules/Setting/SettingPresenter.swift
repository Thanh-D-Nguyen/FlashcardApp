//
//  SettingPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import UIKit
import Foundation
import RxRelay
import RxSwift
import UserNotifications

// MARK: - Models

enum AppearanceOption: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var title: String {
        switch self {
        case .system: return NSLocalizedString("System", comment: "")
        case .light: return NSLocalizedString("Light", comment: "")
        case .dark: return NSLocalizedString("Dark", comment: "")
        }
    }

    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Stored preference → option; anything unrecognised means "follow the system".
    static func resolve(_ stored: String) -> AppearanceOption {
        AppearanceOption(rawValue: stored) ?? .system
    }

    static func from(userInterfaceStyle: UIUserInterfaceStyle) -> AppearanceOption {
        switch userInterfaceStyle {
        case .light: return .light
        case .dark: return .dark
        default: return .system
        }
    }
}

struct SettingSection {
    let title: String?
    let items: [SettingItem]
}

enum SettingItem {
    case account(SocialUserEntity?)
    case toggle(ToggleConfig)
    /// One value picked from a short list (appearance); the view shows it as a pop-up menu.
    case choice(ChoiceConfig)
    case navigation(NavigationConfig)
    case destructive(NavigationConfig)
}

struct ToggleConfig {
    let id: String
    let title: String
    let iconName: String
    var isOn: Bool
    var isEnabled: Bool
    var subtitle: String?

    init(id: String, title: String, iconName: String, isOn: Bool, isEnabled: Bool = true, subtitle: String? = nil) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.isOn = isOn
        self.isEnabled = isEnabled
        self.subtitle = subtitle
    }
}

struct ChoiceOption: Equatable {
    let id: String
    let title: String
}

struct ChoiceConfig {
    let id: String
    let title: String
    let iconName: String
    let options: [ChoiceOption]
    let selectedID: String

    var selectedTitle: String { options.first { $0.id == selectedID }?.title ?? "" }
}

struct NavigationConfig {
    let id: String
    let title: String
    let iconName: String
    let subText: String
    let disclosure: Bool

    init(id: String, title: String, iconName: String, subText: String = "", disclosure: Bool = true) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.subText = subText
        self.disclosure = disclosure
    }
}

// MARK: - Presenter Protocol

protocol SettingPresenterInterface: AnyObject {
    var sectionsRelay: BehaviorRelay<[SettingSection]> { get }

    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func updateNotificationAuthorizationStatus(_ status: UNAuthorizationStatus)
    func didSelectItem(at indexPath: IndexPath)
    func toggleDarkMode(to value: Bool)
    func toggleNotification(to value: Bool)
    func toggleSound(to value: Bool)
    /// Anonymous usage counts; off until the learner turns it on.
    func toggleAnalytics(to value: Bool)
    func selectChoice(id: String, optionID: String)
    func requestLogout()
    func handleNavigationTap(config: NavigationConfig)
}

// MARK: - Presenter

final class SettingPresenter: SettingPresenterInterface {

    private let interactor: SettingInteractorInterface
    private let wireframe: SettingWireframeInterface
    private let disposeBag = DisposeBag()
    private var refreshRequest: Disposable?
    private var isLoggingOut = false
    private var isDeletingAccount = false
    private var reminderChangeID = 0
    private var reminderScheduleInFlight = false
    private var pendingReminderSchedule: (() -> Void)?

    let sectionsRelay = BehaviorRelay<[SettingSection]>(value: [])

    private let analytics: AnalyticsService
    private let adsPrivacyRequired: () -> Bool
    private var adPrivacyObserver: NSObjectProtocol?

    init(interactor: SettingInteractorInterface,
         wireframe: SettingWireframeInterface,
         analytics: AnalyticsService = .shared,
         adsPrivacyRequired: @escaping () -> Bool = { AdsService.shared.privacyOptionsRequired }) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.analytics = analytics
        self.adsPrivacyRequired = adsPrivacyRequired
    }

    deinit {
        refreshRequest?.dispose()
        if let adPrivacyObserver { NotificationCenter.default.removeObserver(adPrivacyObserver) }
    }
}

// MARK: - SettingPresenterInterface

extension SettingPresenter {

    func viewDidLoad() {
        observeAuthState()
        adPrivacyObserver = NotificationCenter.default.addObserver(forName: AdsService.stateDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.reloadSections()
        }
        reloadSections()
    }

    func viewWillAppear() {
        reloadSections()
        refreshRequest?.dispose()
        refreshRequest = interactor.refreshCurrentUser()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in self?.reloadSections() }, onFailure: { [weak self] error in
                self?.reloadSections()
                // Offline or a flaky server keeps the stored session; only an expired one needs the user's attention.
                if case NativeAuthError.unauthorized = error {
                    self?.wireframe.showError(message: error.localizedDescription)
                }
            })
    }

    func viewWillDisappear() {
        refreshRequest?.dispose()
        refreshRequest = nil
    }

    func updateNotificationAuthorizationStatus(_ status: UNAuthorizationStatus) {
        interactor.setNotificationAuthorizationStatus(status)
        reloadSections()
    }

    func didSelectItem(at indexPath: IndexPath) {
        let sections = sectionsRelay.value
        guard indexPath.section < sections.count,
              indexPath.row < sections[indexPath.section].items.count else { return }

        let item = sections[indexPath.section].items[indexPath.row]
        switch item {
        case .account(let user):
            if user == nil {
                wireframe.navigateToWelcome()
            }
        case .toggle, .choice:
            break
        case .navigation(let config):
            handleNavigationTap(config: config)
        case .destructive(let config):
            handleNavigationTap(config: config)
        }
    }

    func toggleDarkMode(to value: Bool) {
        let option: AppearanceOption = value ? .dark : .light
        interactor.setAppearance(option.rawValue)
        applyAppearance(option)
        reloadSections()
    }

    func toggleNotification(to value: Bool) {
        reminderChangeID += 1
        let changeID = reminderChangeID
        guard value else {
            pendingReminderSchedule = nil
            interactor.setNotificationEnabled(false)
            interactor.cancelDailyReminder()
            reloadSections()
            return
        }
        interactor.requestNotificationPermission { [weak self] granted in
            guard let self else { return }
            guard changeID == self.reminderChangeID else { return }
            self.interactor.setNotificationAuthorizationStatus(granted ? .authorized : .denied)
            guard granted else {
                self.interactor.setNotificationEnabled(false)
                self.wireframe.showNotificationDeniedAlert()
                self.reloadSections()
                return
            }
            self.scheduleReminder(hour: self.interactor.getReminderHour()) { [weak self] error in
                guard let self else { return }
                guard changeID == self.reminderChangeID else {
                    if !self.interactor.getNotificationEnabled() { self.interactor.cancelDailyReminder() }
                    return
                }
                self.interactor.setNotificationEnabled(error == nil)
                if error != nil { self.showReminderScheduleError() }
                self.reloadSections()
            }
        }
    }

    func toggleAnalytics(to value: Bool) {
        analytics.isSharingAllowed = value
        reloadSections()
    }

    func toggleSound(to value: Bool) {
        let oldValue = interactor.getSoundEnabled()
        interactor.setSoundEnabled(value)
        guard interactor.getNotificationEnabled(), oldValue != value else {
            reloadSections()
            return
        }
        reminderChangeID += 1
        let changeID = reminderChangeID
        scheduleReminder(hour: interactor.getReminderHour()) { [weak self] error in
            guard let self, changeID == self.reminderChangeID else { return }
            if error != nil {
                self.interactor.setSoundEnabled(oldValue)
                self.showReminderScheduleError()
            }
            self.reloadSections()
        }
    }

    private func showReminderScheduleError() {
        wireframe.showError(message: NSLocalizedString("Could not schedule your study reminder. Please try again.", comment: "Notification scheduling failure"))
    }

    private func scheduleReminder(hour: Int, completion: @escaping (Error?) -> Void) {
        let perform = { [weak self] in
            guard let self else { return }
            self.reminderScheduleInFlight = true
            self.interactor.scheduleDailyReminder(hour: hour) { [weak self] error in
                guard let self else { return }
                completion(error)
                self.reminderScheduleInFlight = false
                if let pending = self.pendingReminderSchedule {
                    self.pendingReminderSchedule = nil
                    pending()
                } else if !self.interactor.getNotificationEnabled() {
                    // Disabling during an in-flight add must not leave a reminder behind.
                    self.interactor.cancelDailyReminder()
                }
            }
        }
        if reminderScheduleInFlight {
            pendingReminderSchedule = perform
        } else {
            perform()
        }
    }

    func selectChoice(id: String, optionID: String) {
        switch id {
        case "appearance":
            guard let option = AppearanceOption(rawValue: optionID) else { return }
            interactor.setAppearance(option.rawValue)
            applyAppearance(option)
            reloadSections()
        case "language":
            guard let option = LanguageOption(rawValue: optionID),
                  option != LanguageOption.resolve(interactor.getLanguage()) else { return }
            interactor.setLanguage(option.rawValue)
            reloadSections()
            wireframe.reloadInterfaceForLanguage()
        case "reminder_time":
            guard let hour = Int(optionID), (0..<24).contains(hour),
                  hour != interactor.getReminderHour(), interactor.getNotificationEnabled() else { return }
            reminderChangeID += 1
            let changeID = reminderChangeID
            scheduleReminder(hour: hour) { [weak self] error in
                guard let self, changeID == self.reminderChangeID else { return }
                if error == nil {
                    self.interactor.setReminderHour(hour)
                } else {
                    self.showReminderScheduleError()
                }
                self.reloadSections()
            }
        default:
            return
        }
    }

    func requestLogout() {
        guard !isLoggingOut, !isDeletingAccount else { return }
        wireframe.showLogoutConfirmation { [weak self] in
            guard let self else { return }
            guard !self.isLoggingOut, !self.isDeletingAccount else { return }
            self.isLoggingOut = true
            self.refreshRequest?.dispose()
            self.interactor.logoutSession()
                .observe(on: MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] result in
                    guard let self else { return }
                    self.isLoggingOut = false
                    self.reloadSections()
                    switch result {
                    case .revoked:
                        self.wireframe.navigateToWelcome()
                    case .remoteUnconfirmed:
                        // Signed out on this device regardless; say plainly that the server was not told.
                        self.wireframe.showLogoutNotice(
                            message: NSLocalizedString("You are signed out on this device, but the server could not be reached to end your session there.", comment: "Shown after Log Out when the remote revocation failed"),
                            onDismiss: { [weak self] in self?.wireframe.navigateToWelcome() })
                    }
                }, onFailure: { [weak self] error in
                    self?.isLoggingOut = false
                    self?.reloadSections()
                    self?.wireframe.showError(message: error.localizedDescription)
                })
                .disposed(by: self.disposeBag)
        }
    }

    func requestDeleteAccount() {
        guard !isDeletingAccount, !isLoggingOut, interactor.getCurrentUser() != nil else { return }
        wireframe.showDeleteAccountConfirmation { [weak self] in
            guard let self, !self.isDeletingAccount, !self.isLoggingOut,
                  self.interactor.getCurrentUser() != nil else { return }
            self.isDeletingAccount = true
            self.refreshRequest?.dispose()
            self.interactor.deleteAccountSession()
                .observe(on: MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] in
                    guard let self else { return }
                    self.isDeletingAccount = false
                    self.reloadSections()
                    self.wireframe.showAccountDeletedNotice(
                        message: NSLocalizedString("Your online account has been deleted. If you used Sign in with Apple, open iPhone Settings > your name > Sign in with Apple, select this app, and stop using Sign in with Apple to revoke access.", comment: "Manual Apple credential revocation after account deletion"),
                        onDismiss: { [weak self] in self?.wireframe.navigateToWelcome() })
                }, onFailure: { [weak self] error in
                    self?.isDeletingAccount = false
                    self?.reloadSections()
                    self?.wireframe.showError(message: error.localizedDescription)
                })
                .disposed(by: self.disposeBag)
        }
    }

    func handleNavigationTap(config: NavigationConfig) {
        switch config.id {
        case "logout":
            requestLogout()
        case "delete_account":
            requestDeleteAccount()
        case "notifications_system":
            wireframe.openSystemSettings()
        case "privacy":
            wireframe.showPrivacyPolicy()
        case "terms":
            wireframe.showTermsOfService()
        case "support", "report_ad":
            wireframe.showContactSupport()
        case "about":
            wireframe.showAbout()
        case "data_export":
            wireframe.showDataExport()
        default:
            break
        }
    }
}

// MARK: - Private Helpers

private extension SettingPresenter {

    func observeAuthState() {
        interactor.authStateChanges
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in self?.reloadSections() })
            .disposed(by: disposeBag)
    }

    func currentAppearance() -> AppearanceOption {
        AppearanceOption.resolve(interactor.getAppearance())
    }

    func applyAppearance(_ option: AppearanceOption) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first else { return }

        window.overrideUserInterfaceStyle = option.userInterfaceStyle
    }

    func reloadSections() {
        sectionsRelay.accept(buildSections())
    }

    func buildSections() -> [SettingSection] {
        let user = interactor.getCurrentUser()
        let appearance = currentAppearance()

        let accountSection = SettingSection(
            title: nil,
            items: [.account(user)]
        )

        var preferencesItems: [SettingItem] = []

        preferencesItems.append(.choice(ChoiceConfig(
            id: "appearance",
            title: NSLocalizedString("Appearance", comment: ""),
            iconName: "circle.lefthalf.filled",
            options: AppearanceOption.allCases.map { ChoiceOption(id: $0.rawValue, title: $0.title) },
            selectedID: appearance.rawValue
        )))

        // Notifications. Before the system prompt has been answered the switch must stay usable:
        // turning it on is the only place the permission is requested.
        let notificationStatus = interactor.getNotificationAuthorizationStatus()
        let isAuthorized = [.authorized, .provisional, .ephemeral].contains(notificationStatus)
        let notificationEnabled = interactor.getNotificationEnabled() && isAuthorized
        let notificationSubtitle: String?
        let notificationIsEnabled: Bool
        switch notificationStatus {
        case .notDetermined:
            notificationSubtitle = NSLocalizedString("Turn on to allow notifications", comment: "")
            notificationIsEnabled = true
        case .denied:
            notificationSubtitle = NSLocalizedString("Turned off in System Settings", comment: "")
            notificationIsEnabled = false
        case .authorized, .provisional, .ephemeral:
            notificationSubtitle = nil
            notificationIsEnabled = true
        @unknown default:
            notificationSubtitle = nil
            notificationIsEnabled = true
        }

        preferencesItems.append(.toggle(ToggleConfig(
            id: "notification",
            title: NSLocalizedString("Notifications", comment: ""),
            iconName: "bell",
            isOn: notificationEnabled,
            isEnabled: notificationIsEnabled,
            subtitle: notificationSubtitle
        )))

        if notificationEnabled {
            preferencesItems.append(.choice(ChoiceConfig(
                id: "reminder_time",
                title: NSLocalizedString("Daily reminder time", comment: "Time of local daily notification"),
                iconName: "clock",
                options: (0..<24).map { ChoiceOption(id: String($0), title: String(format: "%02d:00", $0)) },
                selectedID: String(interactor.getReminderHour())
            )))
        }

        if notificationStatus == .denied {
            preferencesItems.append(.navigation(NavigationConfig(
                id: "notifications_system",
                title: NSLocalizedString("Open System Settings", comment: ""),
                iconName: "gearshape"
            )))
        }

        preferencesItems.append(.toggle(ToggleConfig(
            id: "sound",
            title: NSLocalizedString("Sounds & Haptics", comment: ""),
            iconName: "speaker.wave.2",
            isOn: interactor.getSoundEnabled()
        )))

        let preferencesSection = SettingSection(title: NSLocalizedString("Preferences", comment: ""), items: preferencesItems)

        var generalItems: [SettingItem] = [
                .choice(ChoiceConfig(
                    id: "language",
                    title: NSLocalizedString("Language", comment: ""),
                    iconName: "globe",
                    options: LanguageOption.allCases.map { ChoiceOption(id: $0.rawValue, title: $0.title) },
                    selectedID: LanguageOption.resolve(interactor.getLanguage()).rawValue
                )),
                .toggle(ToggleConfig(
                    id: "analytics",
                    title: NSLocalizedString("Share anonymous usage data", comment: "Settings: analytics consent switch"),
                    iconName: "chart.bar",
                    isOn: analytics.isSharingAllowed,
                    subtitle: NSLocalizedString("Only counts such as 'a lesson was finished'. Never the words you look up, your cards, your account or a device ID.", comment: "Settings: what the analytics consent covers")
                )),
                .navigation(NavigationConfig(
                    id: "privacy",
                    title: NSLocalizedString("Privacy Policy", comment: ""),
                    iconName: "hand.raised"
                )),
                .navigation(NavigationConfig(
                    id: "terms",
                    title: NSLocalizedString("Terms of Service", comment: ""),
                    iconName: "doc.text"
                )),
                .navigation(NavigationConfig(
                    id: "support",
                    title: NSLocalizedString("Contact Support", comment: ""),
                    iconName: "bubble.left"
                )),
                .navigation(NavigationConfig(
                    id: "report_ad",
                    title: NSLocalizedString("Report an ad", comment: "Settings: report an inappropriate advertisement"),
                    iconName: "flag"
                ))
            ]
        if adsPrivacyRequired() {
            generalItems.insert(.navigation(NavigationConfig(
                id: "ad_privacy",
                title: NSLocalizedString("Ad privacy choices", comment: "AdMob UMP privacy options entry point"),
                iconName: "hand.raised.slash"
            )), at: 3)
        }
        let generalSection = SettingSection(title: NSLocalizedString("General", comment: ""), items: generalItems)

        let aboutSection = SettingSection(
            title: NSLocalizedString("About", comment: ""),
            items: [
                .navigation(NavigationConfig(
                    id: "about",
                    title: NSLocalizedString("About Flashcard", comment: ""),
                    iconName: "info.circle",
                    subText: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                    disclosure: false
                ))
            ]
        )

        var sections = [accountSection, preferencesSection, generalSection, aboutSection]
        if user != nil {
            sections.insert(SettingSection(
                title: NSLocalizedString("Your data", comment: "Settings section about the account's data"),
                items: [.navigation(NavigationConfig(
                    id: "data_export",
                    title: NSLocalizedString("Get a copy of your data", comment: "Settings row: request/download a data export"),
                    iconName: "square.and.arrow.down"
                ))]
            ), at: 3)
        }

        if user != nil {
            sections.append(SettingSection(
                title: nil,
                items: [
                    .destructive(NavigationConfig(
                        id: "logout",
                        title: NSLocalizedString("Log Out", comment: ""),
                        iconName: "rectangle.portrait.and.arrow.right",
                        disclosure: false
                    )),
                    .destructive(NavigationConfig(
                        id: "delete_account",
                        title: NSLocalizedString("Delete Account", comment: ""),
                        iconName: "trash",
                        disclosure: false
                    ))
                ]
            ))
        }

        return sections
    }
}
