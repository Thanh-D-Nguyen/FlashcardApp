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

/// Tabs in the order `createTabbar` adds them.
enum MainTab: Int {
    case today
    case dictionary
    case cards
    case discover
    case settings
}

final class MainPresenter {

    private let interactor: MainInteractorInterface
    private let wireframe: MainWireframeInterface
    private let selectedTab: MainTab

    let createdTabbarControllerRelay = PublishRelay<MainTabbarController>()

    init(
        interactor: MainInteractorInterface,
        wireframe: MainWireframeInterface,
        selectedTab: MainTab = .today
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.selectedTab = selectedTab
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
        let discover = DiscoverWireframe()
        let discoverNav = BaseNavigationController(rootViewController: discover.viewController)
        let dictionary = DictionaryWireframe()
        let dictionaryNav = BaseNavigationController(rootViewController: dictionary.viewController)
        let setting = SettingWireframe()
        let settingNav = BaseNavigationController(rootViewController: setting.viewController)
        today.viewController.tabBarItem.accessibilityIdentifier = "tab_levels"
        dictionary.viewController.tabBarItem.accessibilityIdentifier = "tab_dictionary"
        card.viewController.tabBarItem.accessibilityIdentifier = "tab_cards"
        discover.viewController.tabBarItem.accessibilityIdentifier = "tab_discover"
        setting.viewController.tabBarItem.accessibilityIdentifier = "tab_settings"
        let viewControllers = [todayNav, dictionaryNav, cardNav, discoverNav, settingNav]
        tabbarController.viewControllers = viewControllers
        tabbarController.selectedIndex = selectedTab.rawValue
        #if DEBUG
        // `-InitialTab <0…4>` opens a tab at launch, for screenshots and UI tests of a single screen.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-InitialTab"), index + 1 < arguments.count, let tab = Int(arguments[index + 1]),
           viewControllers.indices.contains(tab) {
            tabbarController.selectedIndex = tab
        }
        #endif
        return tabbarController
    }
}
