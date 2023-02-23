//
//  DeskInteractor.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//  
//

import Foundation

protocol DeskInteractorInterface: AnyObject {
    
    var desks: [DeskEntity] { get }
    
    func addDeskName(_ name: String?, description: String?)
    func updateDesk(_ desk: DeskEntity)
}

class DeskInteractor {
    
    var desks: [DeskEntity] {
        return DeskManagement.shared.getAll()
    }
    
    private var deskCount: Int {
        return desks.count
    }
}

extension DeskInteractor: DeskInteractorInterface {
    func addDeskName(_ name: String?, description: String?) {
        let newId = deskCount + 1
        let choiceName = name ?? "Desk \(newId)"
        var desk = DeskEntity(name: choiceName, description: description ?? "", imageNamed: "")
        desk.id = newId
        try! DeskManagement.shared.add(desk)
    }
    
    func updateDesk(_ desk: DeskEntity) {
        try! DeskManagement.shared.update(desk)
    }
}
