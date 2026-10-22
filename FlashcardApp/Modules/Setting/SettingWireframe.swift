//
//  SettingWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import UIKit
import SafariServices

protocol SettingWireframeInterface: AnyObject {
    func showLogoutConfirmation(onConfirm: @escaping () -> Void)
    func navigateToWelcome()
    func showError(message: String)
    func showNotificationDeniedAlert()
    func openSystemSettings()
    func showPrivacyPolicy()
    func showAbout()
}

final class SettingWireframe: BaseWireframe<SettingViewController> {

    private let storyboard = UIStoryboard(name: "Setting", bundle: nil)

    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: SettingViewController.self)
        super.init(viewController: moduleViewController)
        moduleViewController.title = MainTabbarName.setting.title
        moduleViewController.tabBarItem = MainTabbarName.setting.tabBarItem

        let interactor = SettingInteractor(
            preferences: UserDefaultsPreferences.shared
        )
        let presenter = SettingPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    }
}

extension SettingWireframe: SettingWireframeInterface {

    func showError(message: String) {
        showAlert(
            with: NSLocalizedString("Error", comment: ""),
            message: message
        )
    }

    func showLogoutConfirmation(onConfirm: @escaping () -> Void) {
        let confirmAction = UIAlertAction(
            title: NSLocalizedString("Log Out", comment: ""),
            style: .destructive
        ) { _ in
            onConfirm()
        }
        let cancelAction = UIAlertAction(
            title: NSLocalizedString("Cancel", comment: ""),
            style: .cancel
        )
        showAlert(
            with: NSLocalizedString("Log Out", comment: ""),
            message: NSLocalizedString("Are you sure you want to log out?", comment: ""),
            actions: [confirmAction, cancelAction]
        )
    }

    func showNotificationDeniedAlert() {
        let settingsAction = UIAlertAction(
            title: NSLocalizedString("Open Settings", comment: ""),
            style: .default
        ) { [weak self] _ in
            self?.openSystemSettings()
        }
        let cancelAction = UIAlertAction(
            title: NSLocalizedString("Cancel", comment: ""),
            style: .cancel
        )
        showAlert(
            with: NSLocalizedString("Notifications Are Off", comment: ""),
            message: NSLocalizedString("Turn on notifications in System Settings to receive study reminders.", comment: ""),
            actions: [settingsAction, cancelAction]
        )
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func showPrivacyPolicy() {
        guard let url = URL(string: EnvironmentConfig.baseUrl())?.deletingLastPathComponent().appendingPathComponent("\(AppLanguage.current.rawValue)/privacy") else { return }
        let safari = SFSafariViewController(url: url)
        viewController.present(safari, animated: true)
    }

    func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let message = String(format: NSLocalizedString("Version %1$@ (%2$@)", comment: ""), version, build)
        showAlert(
            with: NSLocalizedString("About Flashcard", comment: ""),
            message: message
        )
    }

    func navigateToWelcome() {
        // Settings sits in its own navigation controller inside the tab bar; the login screen replaces the
        // app-level root (which hosts the tab bar), exactly as before the tab got its own navigation stack.
        let appRoot = navigationController?.navigationController ?? navigationController
        appRoot?.setRootWireframe(MailLoginWireframe())
    }
}
