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
    func showLanguagePicker()
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
            with: "Lỗi",
            message: message
        )
    }

    func showLogoutConfirmation(onConfirm: @escaping () -> Void) {
        let confirmAction = UIAlertAction(
            title: "Đăng xuất",
            style: .destructive
        ) { _ in
            onConfirm()
        }
        let cancelAction = UIAlertAction(
            title: "Huỷ",
            style: .cancel
        )
        showAlert(
            with: "Đăng xuất",
            message: "Bạn có chắc muốn đăng xuất không?",
            actions: [confirmAction, cancelAction]
        )
    }

    func showNotificationDeniedAlert() {
        let settingsAction = UIAlertAction(
            title: "Mở Cài đặt",
            style: .default
        ) { [weak self] _ in
            self?.openSystemSettings()
        }
        let cancelAction = UIAlertAction(
            title: "Huỷ",
            style: .cancel
        )
        showAlert(
            with: "Thông báo đang tắt",
            message: "Hãy bật thông báo trong Cài đặt hệ thống để nhận nhắc nhở học tập.",
            actions: [settingsAction, cancelAction]
        )
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func showLanguagePicker() {
        // The app has a single language; say so instead of offering a picker.
        showAlert(
            with: "Ngôn ngữ",
            message: "Ứng dụng hiện chỉ có tiếng Việt."
        )
    }

    func showPrivacyPolicy() {
        guard let url = URL(string: EnvironmentConfig.baseUrl())?.deletingLastPathComponent().appendingPathComponent("vi/privacy") else { return }
        let safari = SFSafariViewController(url: url)
        viewController.present(safari, animated: true)
    }

    func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let message = "Phiên bản \(version) (\(build))"
        showAlert(
            with: "Về Flashcard",
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
