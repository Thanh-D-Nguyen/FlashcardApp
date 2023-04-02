//
//  ImageSearchPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/04/02.
//  
//

import Foundation

protocol ImageSearchPresenterInterface: AnyObject {
    func viewDidLoad()
}

class ImageSearchPresenter {
    private let interactor: ImageSearchInteractorInterface
    private let wireframe: ImageSearchWireframeInterface
    
    init(interactor: ImageSearchInteractorInterface, 
         wireframe: ImageSearchWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ImageSearchPresenter: ImageSearchPresenterInterface {
    func viewDidLoad() {
        
    }
}
