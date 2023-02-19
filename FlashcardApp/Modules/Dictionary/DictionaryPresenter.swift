//
//  DictionaryPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import Foundation

protocol DictionaryPresenterInterface: AnyObject {
   func viewDidLoad() 
}

class DictionaryPresenter {
    private let interactor: DictionaryInteractorInterface
    private let wireframe: DictionaryWireframeInterface

    init(interactor: DictionaryInteractorInterface, 
        wireframe: DictionaryWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension DictionaryPresenter: DictionaryPresenterInterface {
    func viewDidLoad() {
        
    }
}
