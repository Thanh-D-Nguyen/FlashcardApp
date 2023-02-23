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
    func notifyDeskChanged()
    func showDesk()
    
    
}

class CardPresenter {
    private let interactor: CardInteractorInterface
    private let deskInteractor: DeskInteractorInterface
    private let wireframe: CardWireframeInterface
    
    let deskDataRelay = BehaviorRelay<[DeskEntity]>(value: [])
    
    var cards: [CardEntity] {
        return selectingDesk?.cards ?? []
    }
    
    private var selectingDesk: DeskEntity? {
        return deskInteractor.desks.last
    }

    init(interactor: CardInteractorInterface, 
        wireframe: CardWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.deskInteractor = DeskInteractor()
    }
}

extension CardPresenter: CardPresenterInterface {
    func notifyDeskChanged() {
        let desks = deskInteractor.desks
        deskDataRelay.accept(desks)
    }
    
    func showDesk() {
        wireframe.showDeskWithEntity(selectingDesk)
    }
}
