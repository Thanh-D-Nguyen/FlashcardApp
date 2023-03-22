//
//  CreateDeskWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//  
//

import UIKit

protocol CreateDeskWireframeInterface: AnyObject {
    func close()
}

final class CreateDeskWireframe: BaseWireframe<CreateDeskViewController> {

    private let storyboard = UIStoryboard(name: "CreateDesk", bundle: nil)

    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: CreateDeskViewController.self)
        super.init(viewController: moduleViewController)
        let interactor = CreateDeskInteractor() 
        let presenter = CreateDeskPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    } 
}

extension CreateDeskWireframe: CreateDeskWireframeInterface {
    func close() {
        self.viewController.dismiss(animated: true)
    }
}
