//
//  MailLoginWireframe.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/14.
//  Copyright (c) 2023 ___ORGANIZATIONNAME___. All rights reserved.
//
//

import UIKit

protocol MailLoginWireframeInterface: AnyObject {
    /// The screen Google's account sheet is presented over.
    var presentingViewController: UIViewController { get }
    func showMain()
}

final class MailLoginWireframe: BaseWireframe<MailLoginViewController> {
    /// Set when the screen is presented over another one (a feature that needs an account): leaving it then dismisses it
    /// and tells the caller, instead of replacing the app's root with the main tabs.
    private let onFinish: (() -> Void)?

    // MARK: - Module setup -
    init(onFinish: (() -> Void)? = nil) {
        self.onFinish = onFinish
        let moduleViewController = MailLoginViewController()
        super.init(viewController: moduleViewController)
        let interactor = MailLoginInteractor()
        let presenter = MailLoginPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    }
}

// MARK: - Extensions -
extension MailLoginWireframe: MailLoginWireframeInterface {
    var presentingViewController: UIViewController { viewController }

    func showMain() {
        if let onFinish {
            viewController.dismiss(animated: true) { onFinish() }
            return
        }
        navigationController?.setRootWireframe(MainWireframe())
    }
}
