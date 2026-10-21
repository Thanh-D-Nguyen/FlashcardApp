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
    func showCreateNewDesk()
}

final class CardWireframe: BaseWireframe<CardViewController> {

    private let storyboard = UIStoryboard(name: "Card", bundle: nil)

    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: CardViewController.self)
        super.init(viewController: moduleViewController)
        moduleViewController.title = MainTabbarName.card.title
        moduleViewController.tabBarItem = MainTabbarName.card.tabBarItem
        let interactor = CardInteractor()
        let deskInteractor = DeskInteractor()
        let presenter = CardPresenter(interactor: interactor, deskInteractor: deskInteractor, wireframe: self)
        presenter.view = moduleViewController
        moduleViewController.presenter = presenter
    } 
}

extension CardWireframe: CardWireframeInterface {
    
    func showCreateNewDesk() {
        let createDeskWireframe = CreateDeskWireframe()
        navigationController?.presentWireframe(createDeskWireframe)
    }
    
    func showDeskList() {
        let deskListWireFrame = DeskListWireframe()
        deskListWireFrame.didSelectDeskIndex = { [weak self] index in
            if let self, let index = index {
                self.viewController.presenter.didSelectDeskAtIndex(index)
            }
        }
        navigationController?.presentWireframe(deskListWireFrame)
    }
    
}
