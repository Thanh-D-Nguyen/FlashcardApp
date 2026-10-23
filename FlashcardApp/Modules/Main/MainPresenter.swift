//
//  MainPresenter.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/14.
//  Copyright (c) 2023 ___ORGANIZATIONNAME___. All rights reserved.
//
//

import UIKit
import RxRelay
import RxSwift

protocol MainPresenterInterface: AnyObject {
    
    var createdTabbarControllerRelay: PublishRelay<MainTabbarController> { get }
    func viewDidLoad()
}

final class MainPresenter {
    
    private let interactor: MainInteractorInterface
    private let wireframe: MainWireframeInterface
    
    let createdTabbarControllerRelay = PublishRelay<MainTabbarController>()

    init(
        interactor: MainInteractorInterface,
        wireframe: MainWireframeInterface
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension MainPresenter: MainPresenterInterface {
    
    func viewDidLoad() {
        let tabbarController = createTabbar()
        createdTabbarControllerRelay.accept(tabbarController)
    }
    
    private func createTabbar() -> MainTabbarController {
        let tabbarController = MainTabbarController()
        // The first tab is Today; the levels are reached from it ("Study by level") and keep their own screen and identifiers.
        let today = TodayWireframe()
        let todayNav = BaseNavigationController(rootViewController: today.viewController)
        let card = CardWireframe()
        let cardNav = BaseNavigationController(rootViewController: card.viewController)
        let dictionary = DictionaryWireframe()
        let dictionaryNav = BaseNavigationController(rootViewController: dictionary.viewController)
        let setting = SettingWireframe()
        let settingNav = BaseNavigationController(rootViewController: setting.viewController)
        today.viewController.tabBarItem.accessibilityIdentifier = "tab_levels"
        dictionary.viewController.tabBarItem.accessibilityIdentifier = "tab_dictionary"
        card.viewController.tabBarItem.accessibilityIdentifier = "tab_cards"
        setting.viewController.tabBarItem.accessibilityIdentifier = "tab_settings"
        let viewControllers = [todayNav, dictionaryNav, cardNav, settingNav]
        tabbarController.viewControllers = viewControllers
        return tabbarController
    }
}
