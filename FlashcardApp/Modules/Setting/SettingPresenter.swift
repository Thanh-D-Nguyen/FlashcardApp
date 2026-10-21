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
    func didSelectItem(at indexPath: IndexPath)
    func toggleDarkMode(to value: Bool)
    func toggleNotification(to value: Bool)
    func toggleSound(to value: Bool)
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

    let sectionsRelay = BehaviorRelay<[SettingSection]>(value: [])

    init(interactor: SettingInteractorInterface,
         wireframe: SettingWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    deinit {
        refreshRequest?.dispose()
    }
}

// MARK: - SettingPresenterInterface

extension SettingPresenter {

    func viewDidLoad() {
        observeAuthState()
        reloadSections()
    }

    func viewWillAppear() {
        reloadSections()
        refreshRequest?.dispose()
        refreshRequest = interactor.refreshCurrentUser()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in self?.reloadSections() }, onFailure: { [weak self] error in
                self?.reloadSections()
                self?.wireframe.showError(message: error.localizedDescription)
            })
    }

    func viewWillDisappear() {
        refreshRequest?.dispose()
        refreshRequest = nil
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
        case .toggle:
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
        if value {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.interactor.setNotificationEnabled(granted)
                    if !granted {
                        self?.wireframe.showNotificationDeniedAlert()
                    }
                    self?.reloadSections()
                }
            }
        } else {
            interactor.setNotificationEnabled(false)
            reloadSections()
        }
    }

    func toggleSound(to value: Bool) {
        interactor.setSoundEnabled(value)
        reloadSections()
    }

    func requestLogout() {
        guard !isLoggingOut else { return }
        wireframe.showLogoutConfirmation { [weak self] in
            guard let self else { return }
            guard !self.isLoggingOut else { return }
            self.isLoggingOut = true
            self.refreshRequest?.dispose()
            self.interactor.logoutSession()
                .observe(on: MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] in
                    self?.isLoggingOut = false
                    self?.reloadSections()
                    self?.wireframe.navigateToWelcome()
                }, onFailure: { [weak self] error in
                    self?.isLoggingOut = false
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
        case "appearance":
            wireframe.showAppearancePicker(current: currentAppearance()) { [weak self] selected in
                guard let self else { return }
                self.interactor.setAppearance(selected.rawValue)
                self.applyAppearance(selected)
                self.reloadSections()
            }
        case "notifications_system":
            wireframe.openSystemSettings()
        case "language":
            wireframe.showLanguagePicker()
        case "privacy":
            wireframe.showPrivacyPolicy()
        case "about":
            wireframe.showAbout()
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
        let stored = interactor.getAppearance()
        if let option = AppearanceOption(rawValue: stored) {
            return option
        }
        return .system
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

        // Appearance
        preferencesItems.append(.navigation(NavigationConfig(
            id: "appearance",
            title: NSLocalizedString("Appearance", comment: ""),
            iconName: "paintbrush.fill",
            subText: appearance.title
        )))

        // Notifications
        let notificationStatus = interactor.getNotificationAuthorizationStatus()
        let notificationEnabled = interactor.getNotificationEnabled() && notificationStatus == .authorized
        let notificationSubtitle: String?
        let notificationIsEnabled: Bool
        switch notificationStatus {
        case .notDetermined:
            notificationSubtitle = NSLocalizedString("Not determined", comment: "")
            notificationIsEnabled = false
        case .denied:
            notificationSubtitle = NSLocalizedString("Disabled in System Settings", comment: "")
            notificationIsEnabled = false
        case .authorized, .provisional, .ephemeral:
            notificationSubtitle = nil
            notificationIsEnabled = notificationEnabled
        @unknown default:
            notificationSubtitle = nil
            notificationIsEnabled = notificationEnabled
        }

        preferencesItems.append(.toggle(ToggleConfig(
            id: "notification",
            title: NSLocalizedString("Notifications", comment: ""),
            iconName: "bell.fill",
            isOn: notificationIsEnabled,
            isEnabled: notificationStatus != .denied && notificationStatus != .notDetermined,
            subtitle: notificationSubtitle
        )))

        if notificationStatus == .denied {
            preferencesItems.append(.navigation(NavigationConfig(
                id: "notifications_system",
                title: NSLocalizedString("Open System Settings", comment: ""),
                iconName: "gear",
                subText: ""
            )))
        }

        // Sound
        preferencesItems.append(.toggle(ToggleConfig(
            id: "sound",
            title: NSLocalizedString("Sounds & Haptics", comment: ""),
            iconName: "speaker.wave.2.fill",
            isOn: interactor.getSoundEnabled()
        )))

        let preferencesSection = SettingSection(
            title: NSLocalizedString("Preferences", comment: ""),
            items: preferencesItems
        )

        let generalSection = SettingSection(
            title: NSLocalizedString("General", comment: ""),
            items: [
                .navigation(NavigationConfig(
                    id: "language",
                    title: NSLocalizedString("Language", comment: ""),
                    iconName: "globe",
                    subText: Locale.current.localizedString(forIdentifier: Locale.current.identifier) ?? NSLocalizedString("English", comment: "")
                )),
                .navigation(NavigationConfig(
                    id: "privacy",
                    title: NSLocalizedString("Privacy Policy", comment: ""),
                    iconName: "hand.raised.fill"
                ))
            ]
        )

        let aboutSection = SettingSection(
            title: NSLocalizedString("About", comment: ""),
            items: [
                .navigation(NavigationConfig(
                    id: "about",
                    title: NSLocalizedString("About Flashcard", comment: ""),
                    iconName: "info.circle.fill",
                    subText: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                ))
            ]
        )

        var sections = [accountSection, preferencesSection, generalSection, aboutSection]

        if user != nil {
            let logoutSection = SettingSection(
                title: nil,
                items: [
                    .destructive(NavigationConfig(
                        id: "logout",
                        title: NSLocalizedString("Log Out", comment: ""),
                        iconName: "rectangle.portrait.and.arrow.right",
                        disclosure: false
                    ))
                ]
            )
            sections.append(logoutSection)
        }

        return sections
    }
}
