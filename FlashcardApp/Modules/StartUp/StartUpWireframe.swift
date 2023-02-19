//
//  StartUpWireframe.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/09.
//  Copyright (c) 2023 ___ORGANIZATIONNAME___. All rights reserved.
//
//

import UIKit

protocol StartUpWireframeInterface: AnyObject {
    func navigateToWelcomeSlideShow()
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

// MARK: - Extensions -
extension StartUpWireframe: StartUpWireframeInterface {
    func navigateToWelcomeSlideShow() {
        self.navigationController?.setRootWireframe(SlideShowWireframe())
    }
}
