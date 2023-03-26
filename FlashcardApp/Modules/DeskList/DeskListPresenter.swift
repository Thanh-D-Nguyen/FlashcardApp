//
//  DeskPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//  
//

import Foundation
import RxRelay

protocol DeskListPresenterInterface: AnyObject {
    var desksRelay: BehaviorRelay<[DeskEntity]> { get }
    
    func viewDidLoad()
    func dismiss()
    
    func didSelectDeskAtIndex(_ index: Int)
}

class DeskListPresenter {
    private let interactor: DeskInteractorInterface
    private let wireframe: DeskWireframeInterface

    private var entity: DeskEntity?
    
    let desksRelay = BehaviorRelay<[DeskEntity]>(value: [])

    init(interactor: DeskInteractorInterface, 
        wireframe: DeskWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension DeskListPresenter: DeskListPresenterInterface {
    func viewDidLoad() {
        let desks = interactor.desks
        desksRelay.accept(desks)
    }
    
    func dismiss() {
        wireframe.dismiss(selectedIndex: nil)
    }
    
    func didSelectDeskAtIndex(_ index: Int) {
        wireframe.dismiss(selectedIndex: index)
    }
}
