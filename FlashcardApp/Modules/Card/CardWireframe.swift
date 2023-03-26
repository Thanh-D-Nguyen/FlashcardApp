//
//  CardWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import UIKit

protocol CardWireframeInterface: AnyObject {
    func showDeskList()
    func showCreateNewCard()
    func showCreateNewDesk()
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
    
    func showCreateNewDesk() {
        let createDeskWireframe = CreateDeskWireframe()
        navigationController?.presentWireframe(createDeskWireframe)
    }
    
    func showDeskList() {
        let deskListWireFrame = DeskWireframe()
        deskListWireFrame.didSelectDeskIndex = { [weak self] index in
            if let self, let index = index {
                self.viewController.presenter.didSelectDeskAtIndex(index)
            }
        }
        navigationController?.presentWireframe(deskListWireFrame)
    }
    
    func showCreateNewCard() {
        
    }
}
