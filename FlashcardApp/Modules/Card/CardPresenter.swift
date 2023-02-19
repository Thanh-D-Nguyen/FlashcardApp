//
//  CardPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import Foundation

protocol CardPresenterInterface: AnyObject {
   func viewDidLoad() 
}

class CardPresenter {
    private let interactor: CardInteractorInterface
    private let wireframe: CardWireframeInterface

    init(interactor: CardInteractorInterface, 
        wireframe: CardWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension CardPresenter: CardPresenterInterface {
    func viewDidLoad() {
        
    }
}
