//
//  DeskWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//  
//

import UIKit

protocol DeskWireframeInterface: AnyObject {
    func dismiss(selectedIndex index: Int?)
}

final class DeskWireframe: BaseWireframe<DeskListViewController> {

    private let storyboard = UIStoryboard(name: "DeskList", bundle: nil)
    var didSelectDeskIndex: ((Int?) -> Void)?

    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: DeskListViewController.self)
        super.init(viewController: moduleViewController)
        let interactor = DeskInteractor() 
        let presenter = DeskListPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    } 
}

extension DeskWireframe: DeskWireframeInterface {
    func dismiss(selectedIndex index: Int?) {
        didSelectDeskIndex?(index)
        self.viewController.dismiss(animated: true)
    }
}
