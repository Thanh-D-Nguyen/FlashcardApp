//
//  DeskPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//  
//

import Foundation

enum DeskScreenType {
    case create, update
}

protocol DeskPresenterInterface: AnyObject {
    func viewDidLoad()
    func addDeskName(_ name: String?, description: String?)
    func dismiss()
}

class DeskPresenter {
    private let interactor: DeskInteractorInterface
    private let wireframe: DeskWireframeInterface
    
    private var entity: DeskEntity?
    private var screenType: DeskScreenType = .create

    init(interactor: DeskInteractorInterface, 
        wireframe: DeskWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    func setDeskEntity(_ entity: DeskEntity?) {
        self.entity = entity
        self.screenType = entity == nil ? .create : .update
    }
}

extension DeskPresenter: DeskPresenterInterface {
    func viewDidLoad() {
        
    }
    
    func addDeskName(_ name: String?, description: String?) {
        let defaultName = name ?? "Desk 1"
    }
    
    func dismiss() {
        wireframe.dismiss()
    }
}
