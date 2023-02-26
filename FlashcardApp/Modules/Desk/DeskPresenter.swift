//
//  DeskPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//  
//

import Foundation
import RxRelay

enum DeskScreenType {
    case create, update
}

protocol DeskPresenterInterface: AnyObject {
    var deskRelay: BehaviorRelay<DeskEntity?> { get }
    
    func viewDidLoad()
    func addDeskName(_ name: String?, description: String?)
    func dismiss()
}

class DeskPresenter {
    private let interactor: DeskInteractorInterface
    private let wireframe: DeskWireframeInterface

    private var entity: DeskEntity?
    private var screenType: DeskScreenType = .create
    
    let deskRelay = BehaviorRelay<DeskEntity?>(value: nil)

    init(interactor: DeskInteractorInterface, 
        wireframe: DeskWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    func setDeskEntity(_ entity: DeskEntity?) {
        self.entity = entity
        self.screenType = entity == nil ? .create : .update
    }
    
    func notifyDeskChanged() {
        deskRelay.accept(self.entity)
    }
}

extension DeskPresenter: DeskPresenterInterface {
    func viewDidLoad() {
        notifyDeskChanged()
    }
    
    func addDeskName(_ name: String?, description: String?) {
        var changeIndex = 0
        if screenType == .create {
            interactor.addDeskName(name, description: description)
        } else {
            if let desk = entity {
                changeIndex = desk.selectIndex
                interactor.updateDesk(desk)
            }
        }
        wireframe.dismiss(notifyDataChangedAtIndex: changeIndex)
    }
    
    func dismiss() {
        wireframe.dismiss(notifyDataChangedAtIndex: nil)
    }
}
