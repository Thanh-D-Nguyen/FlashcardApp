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
        case .system: return "Theo hệ thống"
        case .light: return "Sáng"
        case .dark: return "Tối"
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
    func didSelectItem(at indexPath: IndexPath)
    func toggleDarkMode(to value: Bool)
    func toggleNotification(to value: Bool)
    func toggleSound(to value: Bool)
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
        guard value else {
            interactor.setNotificationEnabled(false)
            reloadSections()
            return
        }
        interactor.requestNotificationPermission { [weak self] granted in
            guard let self else { return }
            self.interactor.setNotificationAuthorizationStatus(granted ? .authorized : .denied)
            self.interactor.setNotificationEnabled(granted)
            if !granted {
                self.wireframe.showNotificationDeniedAlert()
            }
            self.reloadSections()
        }
    }

    func toggleSound(to value: Bool) {
        interactor.setSoundEnabled(value)
        reloadSections()
    }

    func selectChoice(id: String, optionID: String) {
        guard id == "appearance", let option = AppearanceOption(rawValue: optionID) else { return }
        interactor.setAppearance(option.rawValue)
        applyAppearance(option)
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
            title: "Giao diện",
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
            notificationSubtitle = "Bật để cấp quyền thông báo"
            notificationIsEnabled = true
        case .denied:
            notificationSubtitle = "Đã tắt trong Cài đặt hệ thống"
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
            title: "Thông báo",
            iconName: "bell",
            isOn: notificationEnabled,
            isEnabled: notificationIsEnabled,
            subtitle: notificationSubtitle
        )))

        if notificationStatus == .denied {
            preferencesItems.append(.navigation(NavigationConfig(
                id: "notifications_system",
                title: "Mở Cài đặt hệ thống",
                iconName: "gearshape"
            )))
        }

        preferencesItems.append(.toggle(ToggleConfig(
            id: "sound",
            title: "Âm thanh và rung",
            iconName: "speaker.wave.2",
            isOn: interactor.getSoundEnabled()
        )))

        let preferencesSection = SettingSection(title: "Tuỳ chọn", items: preferencesItems)

        let generalSection = SettingSection(
            title: "Chung",
            items: [
                .navigation(NavigationConfig(
                    id: "language",
                    title: "Ngôn ngữ",
                    iconName: "globe",
                    subText: "Tiếng Việt"
                )),
                .navigation(NavigationConfig(
                    id: "privacy",
                    title: "Chính sách quyền riêng tư",
                    iconName: "hand.raised"
                ))
            ]
        )

        let aboutSection = SettingSection(
            title: "Giới thiệu",
            items: [
                .navigation(NavigationConfig(
                    id: "about",
                    title: "Về Flashcard",
                    iconName: "info.circle",
                    subText: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                ))
            ]
        )

        var sections = [accountSection, preferencesSection, generalSection, aboutSection]

        if user != nil {
            sections.append(SettingSection(
                title: nil,
                items: [
                    .destructive(NavigationConfig(
                        id: "logout",
                        title: "Đăng xuất",
                        iconName: "rectangle.portrait.and.arrow.right",
                        disclosure: false
                    ))
                ]
            ))
        }

        return sections
    }
}
