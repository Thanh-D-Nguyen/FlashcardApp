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

    func addDeskName(_ name: String?, description: String?, sortingLanguage: Int) throws
    func updateDesk(_ desk: DeskEntity) throws
}

class DeskInteractor {
    private let repository: DeskRepositoryInterface

    init(repository: DeskRepositoryInterface = DeskManagement.shared) {
        self.repository = repository
    }

    var desks: [DeskEntity] {
        return repository.getAll()
    }

    private var deskCount: Int {
        return desks.count
    }
}

extension DeskInteractor: DeskInteractorInterface {
    func addDeskName(_ name: String?, description: String?, sortingLanguage: Int) throws {
        let newId = deskCount + 1
        let choiceName: String
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            choiceName = name
        } else {
            choiceName = "Desk \(newId)"
        }
        let desk = DeskEntity()
        desk.id = UUID().uuidString
        desk.name = choiceName
        desk.description = description ?? ""
        desk.imageNamed = ""
        desk.sortingLanguage = LanguageSortingType(rawValue: sortingLanguage) ?? .normal
        desk.cards = []
        desk.date = Date()
        do {
            try repository.add(desk)
        } catch {
            throw AppError.databaseWriteFailed(error.localizedDescription)
        }
    }

    func updateDesk(_ desk: DeskEntity) throws {
        do {
            try repository.update(desk)
        } catch {
            throw AppError.databaseWriteFailed(error.localizedDescription)
        }
    }
}
