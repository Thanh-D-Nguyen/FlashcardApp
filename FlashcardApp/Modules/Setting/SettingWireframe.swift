//
//  SettingWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import UIKit

protocol SettingWireframeInterface: AnyObject {

}

final class SettingWireframe: BaseWireframe<SettingViewController> {

    private let storyboard = UIStoryboard(name: "Setting", bundle: nil)

    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: SettingViewController.self)
        super.init(viewController: moduleViewController)
        moduleViewController.title = MainTabbarName.setting.title
        moduleViewController.tabBarItem = UITabBarItem(title: MainTabbarName.setting.title, image: MainTabbarName.setting.image, tag: MainTabbarName.setting.rawValue)
        let interactor = SettingInteractor() 
        let presenter = SettingPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    } 
}

extension SettingWireframe: SettingWireframeInterface {

}
