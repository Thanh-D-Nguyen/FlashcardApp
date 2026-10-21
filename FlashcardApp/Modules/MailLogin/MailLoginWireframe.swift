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
    func showMain()
}

final class MailLoginWireframe: BaseWireframe<MailLoginViewController> {

    // MARK: - Private properties -
    private let storyboard = UIStoryboard(name: "MailLogin", bundle: nil)

    // MARK: - Module setup -
    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: MailLoginViewController.self)
        super.init(viewController: moduleViewController)
        let interactor = MailLoginInteractor()
        let presenter = MailLoginPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    }
}

// MARK: - Extensions -
extension MailLoginWireframe: MailLoginWireframeInterface {
    func showMain() {
        navigationController?.setRootWireframe(MainWireframe())
    }
}
