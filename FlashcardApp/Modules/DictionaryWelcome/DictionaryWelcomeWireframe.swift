//
//  DictionaryWelcomeWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2024/06/02.
//  
//

import UIKit

protocol DictionaryWelcomeWireframeInterface: AnyObject {

}

final class DictionaryWelcomeWireframe: BaseWireframe<DictionaryWelcomeViewController> {

    private let storyboard = UIStoryboard(name: "DictionaryWelcome", bundle: nil)

    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: DictionaryWelcomeViewController.self)
        super.init(viewController: moduleViewController)
        let interactor = DictionaryWelcomeInteractor() 
        let presenter = DictionaryWelcomePresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    } 
}

extension DictionaryWelcomeWireframe: DictionaryWelcomeWireframeInterface {

}
