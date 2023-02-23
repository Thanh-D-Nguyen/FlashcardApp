//
//  CardPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import Foundation
import RxRelay

protocol CardPresenterInterface: AnyObject {
    var deskDataRelay: BehaviorRelay<[DeskEntity]> { get }
    
    var cards: [CardEntity] { get }
    func viewDidLoad()
    func showDesk()
}

class CardPresenter {
    private let interactor: CardInteractorInterface
    private let wireframe: CardWireframeInterface
    
    let deskDataRelay = BehaviorRelay<[DeskEntity]>(value: [])
    
    var cards: [CardEntity] {
        return selectingDesk?.cards ?? []
    }
    private var selectingDesk: DeskEntity? {
        return deskDataRelay.value.last
    }

    init(interactor: CardInteractorInterface, 
        wireframe: CardWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension CardPresenter: CardPresenterInterface {
    func viewDidLoad() {
        deskDataRelay.accept([])
    }
    
    func showDesk() {
        wireframe.showDeskWithEntity(selectingDesk)
    }
}
