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
    func showDeskList(_ desks: [DeskEntity])
    func showCreateNewCard()
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
//        let deskWireFrame = DeskWireframe(entity)
//        deskWireFrame.didDeskChange = { [weak self] index in
//            self?.viewController.presenter.didSelectDeskAtIndex(index)
//        }
//        navigationController?.presentWireframe(deskWireFrame)
        
        let createDeskWireframe = CreateDeskWireframe()
        navigationController?.presentWireframe(createDeskWireframe)

    }
    
    func showDeskList(_ desks: [DeskEntity]) {
        let deskListView = DeskListView(frame: .zero)
        self.viewController.view.fill(with: deskListView)
        deskListView.didSelectDeskAtIndex = { [weak self] index in
            guard let self else { return }
            self.viewController.presenter.didSelectDeskAtIndex(index)
            deskListView.removeFromSuperview()
        }
        deskListView.updateDesks(desks)
    }
    
    func showCreateNewCard() {
        
    }
}
