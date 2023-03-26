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
    
    var selectingDesk: DeskEntity? { get }
    var cards: [CardEntity] { get }
    
    func loadDesks()
    func didSelectDeskAtIndex(_ index: Int)
    func createNewCard()
    func showDeskList()
    func createNewDesk()
    
}

class CardPresenter {
    private let interactor: CardInteractorInterface
    private let deskInteractor: DeskInteractorInterface
    private let wireframe: CardWireframeInterface
    
    let deskDataRelay = BehaviorRelay<[DeskEntity]>(value: [])
    
    var selectingDesk: DeskEntity?
    var cards: [CardEntity] {
        return selectingDesk?.cards ?? []
    }

    init(interactor: CardInteractorInterface, 
        wireframe: CardWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.deskInteractor = DeskInteractor()
    }
}

extension CardPresenter: CardPresenterInterface {
    
    func loadDesks() {
        let desks = deskInteractor.desks
        if selectingDesk == nil {
            selectingDesk = desks.first
        }
        deskDataRelay.accept(desks)
    }
    
    func didSelectDeskAtIndex(_ index: Int) {
        if deskDataRelay.value.indices.contains(index) {
            self.selectingDesk = deskDataRelay.value[index]
        }
        loadDesks()
    }
    
    func showDeskList() {
        wireframe.showDeskList()
    }
    
    func createNewCard() {
        wireframe.showCreateNewCard()
    }
    
    func createNewDesk() {
        wireframe.showCreateNewDesk()
    }
}
