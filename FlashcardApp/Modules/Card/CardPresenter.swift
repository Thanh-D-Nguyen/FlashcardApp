//
//  CardPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import Foundation
import RxRelay

protocol CardViewInterface: AnyObject {
    func didUpdateDesks()
}

protocol CardPresenterInterface: AnyObject {
    var deskDataRelay: BehaviorRelay<[DeskEntity]> { get }

    var selectingDesk: DeskEntity? { get }
    var cards: [CardEntity] { get }

    func loadDesks()
    func didSelectDeskAtIndex(_ index: Int)
    func showDeskList()
    func createNewDesk()

}

class CardPresenter {
    private let interactor: CardInteractorInterface
    private let deskInteractor: DeskInteractorInterface
    private let wireframe: CardWireframeInterface
    weak var view: CardViewInterface?

    let deskDataRelay = BehaviorRelay<[DeskEntity]>(value: [])
    
    var selectingDesk: DeskEntity?
    var cards: [CardEntity] {
        return selectingDesk?.cards ?? []
    }

    init(interactor: CardInteractorInterface,
         deskInteractor: DeskInteractorInterface,
         wireframe: CardWireframeInterface) {
        self.interactor = interactor
        self.deskInteractor = deskInteractor
        self.wireframe = wireframe
    }
}

extension CardPresenter: CardPresenterInterface {
    
    func loadDesks() {
        let desks = deskInteractor.desks
        if selectingDesk == nil {
            selectingDesk = desks.first
        }
        deskDataRelay.accept(desks)
        view?.didUpdateDesks()
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
    
    
    func createNewDesk() {
        wireframe.showCreateNewDesk()
    }
}
