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
    
    func addDeskName(_ name: String?, description: String?, sortingLanguage: Int)
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
    func addDeskName(_ name: String?, description: String?, sortingLanguage: Int) {
        let newId = deskCount + 1
        let choiceName: String
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            choiceName = name
        } else {
            choiceName = "Desk \(newId)"
        }
        let desk = DeskEntity(id: newId, name: choiceName, description: description ?? "", imageNamed: "", sortingLanguage: LanguageSortingType(rawValue: sortingLanguage) ?? .normal, date: Date())
        try! DeskManagement.shared.add(desk)
    }
    
    func updateDesk(_ desk: DeskEntity) {
        try! DeskManagement.shared.update(desk)
    }
}
