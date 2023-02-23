//
//  DeskWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//  
//

import UIKit

protocol DeskWireframeInterface: AnyObject {
    func dismiss()
}

final class DeskWireframe: BaseWireframe<DeskViewController> {

    private let storyboard = UIStoryboard(name: "Desk", bundle: nil)

    init(_ deskEntity: DeskEntity?) {
        let moduleViewController = storyboard.instantiateViewController(ofType: DeskViewController.self)
        super.init(viewController: moduleViewController)
        let interactor = DeskInteractor() 
        let presenter = DeskPresenter(interactor: interactor, wireframe: self)
        presenter.setDeskEntity(deskEntity)
        moduleViewController.presenter = presenter
    } 
}

extension DeskWireframe: DeskWireframeInterface {
    func dismiss() {
        self.viewController.dismiss(animated: true)
    }
}
