//
//  CardWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import UIKit

protocol CardWireframeInterface: AnyObject {
    func showDeskWithEntity(_ entity: DeskEntity?)
}

final class CardWireframe: BaseWireframe<CardViewController> {

    private let storyboard = UIStoryboard(name: "Card", bundle: nil)

    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: CardViewController.self)
        super.init(viewController: moduleViewController)
        moduleViewController.title = MainTabbarName.card.title
        moduleViewController.tabBarItem = UITabBarItem(title: MainTabbarName.card.title, image: MainTabbarName.card.image, tag: MainTabbarName.card.rawValue)
        let interactor = CardInteractor() 
        let presenter = CardPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    } 
}

extension CardWireframe: CardWireframeInterface {
    func showDeskWithEntity(_ entity: DeskEntity?) {
        let deskWireFrame = DeskWireframe(entity)
        navigationController?.presentWireframe(deskWireFrame)
    }
}
