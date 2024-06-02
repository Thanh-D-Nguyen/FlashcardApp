//
//  VocabularyWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/10/01.
//  
//

import UIKit

protocol VocabularyWireframeInterface: AnyObject {

}

final class VocabularyWireframe: BaseWireframe<VocabularyViewController> {

    private let storyboard = UIStoryboard(name: "Vocabulary", bundle: nil)

    init() {
        let moduleViewController = storyboard.instantiateViewController(ofType: VocabularyViewController.self)
        super.init(viewController: moduleViewController)
        let interactor = VocabularyInteractor() 
        let presenter = VocabularyPresenter(interactor: interactor, wireframe: self)
        moduleViewController.presenter = presenter
    } 
}

extension VocabularyWireframe: VocabularyWireframeInterface {

}
