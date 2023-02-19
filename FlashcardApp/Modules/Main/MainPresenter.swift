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
        let home = HomeWireframe()
        let quiz = QuizWireframe()
        let quizNav = BaseNavigationController(rootViewController: quiz.viewController)
        let card = CardWireframe()
        let dictionary = DictionaryWireframe()
        let setting = SettingWireframe()
        let viewControllers = [home.viewController, quizNav, card.viewController, dictionary.viewController, setting.viewController]
        tabbarController.viewControllers = viewControllers
        return tabbarController
    }
}
