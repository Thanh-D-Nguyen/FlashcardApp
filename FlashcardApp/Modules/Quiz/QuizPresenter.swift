//
//  QuizPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import Foundation

protocol QuizPresenterInterface: AnyObject {
   func viewDidLoad() 
}

class QuizPresenter {
    private let interactor: QuizInteractorInterface
    private let wireframe: QuizWireframeInterface

    init(interactor: QuizInteractorInterface, 
        wireframe: QuizWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension QuizPresenter: QuizPresenterInterface {
    func viewDidLoad() {
        
    }
}
