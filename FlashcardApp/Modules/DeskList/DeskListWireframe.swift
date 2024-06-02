//
//  DeskListWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//  
//

import UIKit

protocol DeskListWireframeInterface: AnyObject {
    func dismiss(selectedIndex index: Int?)
    
    func openCreateDesk()
}

final class DeskListWireframe: BaseWireframe<DeskListViewController> {

    private let storyboard = UIStoryboard(name: "DeskList", bundle: nil)
    var didSelectDeskIndex: ((Int?) -> Void)?

    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: DeskListViewController.self)
        super.init(viewController: moduleViewController)
        moduleViewController.title = MainTabbarName.desk.title
        moduleViewController.tabBarItem = UITabBarItem(title: MainTabbarName.desk.title, image: MainTabbarName.desk.image, tag: MainTabbarName.desk.rawValue)
        let interactor = DeskInteractor()
        let presenter = DeskListPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    } 
}

extension DeskListWireframe: DeskListWireframeInterface {
    func dismiss(selectedIndex index: Int?) {
        didSelectDeskIndex?(index)
        self.viewController.dismiss(animated: true)
    }
    
    func openCreateDesk() {
        let createDeskView = CreateDeskWireframe()
        self.viewController.present(createDeskView.viewController, animated: true)
    }
}
