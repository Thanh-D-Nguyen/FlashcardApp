//
//  CreateDeskWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//  
//

import UIKit

protocol CreateDeskWireframeInterface: BaseWireframe<CreateDeskViewController> {
    func showImageSearch()
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

    func showImageSearch() {
        let imageSearchView = ImageSearchWireframe()
        self.viewController.show(imageSearchView.viewController, sender: nil)
    }
}
