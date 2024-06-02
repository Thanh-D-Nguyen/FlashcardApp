//
//  DeskPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//  
//

import Foundation
import RxRelay
import RxSwift

enum NestedAdapterSection {
    case text(String)
    case horizontal(DeskEntity)
}


protocol DeskListPresenterInterface: AnyObject {
    var desksRelay: BehaviorRelay<[DeskEntity]> { get }

    func viewDidLoad()
    func dismiss()
    func updateDesk()
    func didSelectDeskAtIndex(_ index: Int)
    
    func addDesk()
}

class DeskListPresenter {
    private let interactor: DeskInteractorInterface
    private let wireframe: DeskListWireframeInterface

    private var entity: DeskEntity?
    
    let desksRelay = BehaviorRelay<[DeskEntity]>(value: [])
    
    init(interactor: DeskInteractorInterface,
        wireframe: DeskListWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension DeskListPresenter: DeskListPresenterInterface {
    func viewDidLoad() {
        updateDesk()
    }
    
    func updateDesk() {
        var result: [DeskEntity] = []
        interactor.desks.forEach({
            result.append($0)
        })
        desksRelay.accept(result)
    }
    
    func dismiss() {
        wireframe.dismiss(selectedIndex: nil)
    }
    
    func didSelectDeskAtIndex(_ index: Int) {
        wireframe.dismiss(selectedIndex: index)
    }
    
    func addDesk() {
        wireframe.openCreateDesk()
    }
}
