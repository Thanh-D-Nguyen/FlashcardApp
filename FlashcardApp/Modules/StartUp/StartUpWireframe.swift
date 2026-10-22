//
//  StartUpWireframe.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//  Copyright (c) 2023 ___ORGANIZATIONNAME___. All rights reserved.
//
//

import UIKit

protocol StartUpWireframeInterface: WireframeInterface {
    /// Replaces the start-up screen with the app. `animated` cross-fades; the default hand-off is an invisible cut.
    func navigateToMain(animated: Bool)
}

final class StartUpWireframe: BaseWireframe<StartUpViewController> {

    private let storyboard = UIStoryboard(name: "StartUp", bundle: nil)

    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: StartUpViewController.self)
        super.init(viewController: moduleViewController)
        let interactor = StartUpInteractor()
        let presenter = StartUpPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    }
}

extension StartUpWireframe: StartUpWireframeInterface {
    func navigateToMain(animated: Bool) {
        guard let navigationController else { return }
        let main = MainWireframe()
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            navigationController.setRootWireframe(main, animated: false)
            return
        }
        UIView.transition(with: navigationController.view, duration: 0.3, options: .transitionCrossDissolve) {
            navigationController.setRootWireframe(main, animated: false)
        }
    }
}
