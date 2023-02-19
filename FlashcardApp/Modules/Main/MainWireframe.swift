//
//  MainWireframe.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/14.
//  Copyright (c) 2023 ___ORGANIZATIONNAME___. All rights reserved.
//
//

import UIKit

protocol MainWireframeInterface: AnyObject {
    
}

final class MainWireframe: BaseWireframe<MainViewController> {

    private let storyboard = UIStoryboard(name: "Main", bundle: nil)

    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: MainViewController.self)
        super.init(viewController: moduleViewController)
        let interactor = MainInteractor()
        let presenter = MainPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    }

}

extension MainWireframe: MainWireframeInterface {
}
