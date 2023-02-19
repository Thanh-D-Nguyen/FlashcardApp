//
//  HomeWireframe.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/14.
//  Copyright (c) 2023 ___ORGANIZATIONNAME___. All rights reserved.
//
//

import UIKit

protocol HomeWireframeInterface: AnyObject {
    
}

final class HomeWireframe: BaseWireframe<HomeViewController> {

    private let storyboard = UIStoryboard(name: "Home", bundle: nil)

    // MARK: - Module setup -

    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: HomeViewController.self)
        super.init(viewController: moduleViewController)
        moduleViewController.title = MainTabbarName.home.title
        moduleViewController.tabBarItem = UITabBarItem(title: MainTabbarName.home.title, image: MainTabbarName.home.image, tag: MainTabbarName.home.rawValue)
        let interactor = HomeInteractor()
        let presenter = HomePresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    }

}
extension HomeWireframe: HomeWireframeInterface {
}
