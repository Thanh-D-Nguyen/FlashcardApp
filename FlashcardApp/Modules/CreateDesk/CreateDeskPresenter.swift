//
//  CreateDeskPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//  
//

import Foundation
import RxRelay

enum CreateDeskTableSection: Int {
    case desk
    case cards
    
    static let sectionCount = 2
}

protocol CreateDeskPresenterInterface: AnyObject {
    
    var cardsRelay: BehaviorRelay<[CardEntity]> { get }
    func viewDidLoad()
}

class CreateDeskPresenter {
    private let interactor: CreateDeskInteractorInterface
    private let wireframe: CreateDeskWireframeInterface
    let cardsRelay = BehaviorRelay<[CardEntity]>(value: [])
    
    init(interactor: CreateDeskInteractorInterface, 
        wireframe: CreateDeskWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension CreateDeskPresenter: CreateDeskPresenterInterface {
    func viewDidLoad() {
        
    }
}
