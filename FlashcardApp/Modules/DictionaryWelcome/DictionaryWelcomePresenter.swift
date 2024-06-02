//
//  DictionaryWelcomePresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2024/06/02.
//  
//

import Foundation

protocol DictionaryWelcomePresenterInterface: AnyObject {
   func viewDidLoad() 
}

class DictionaryWelcomePresenter {
    private let interactor: DictionaryWelcomeInteractorInterface
    private let wireframe: DictionaryWelcomeWireframeInterface

    init(interactor: DictionaryWelcomeInteractorInterface, 
        wireframe: DictionaryWelcomeWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension DictionaryWelcomePresenter: DictionaryWelcomePresenterInterface {
    func viewDidLoad() {
        
    }
}
