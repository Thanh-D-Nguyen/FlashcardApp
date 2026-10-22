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

    func desk(withId id: String) -> DeskEntity?
    func deleteDesk(withId id: String) throws
}

class DeskInteractor {
    private let repository: DeskRepositoryInterface
    private let maintenance: CardMediaMaintenance
    private let drafts: DeckDraftStoreInterface

    init(repository: DeskRepositoryInterface = DeskManagement.shared,
         maintenance: CardMediaMaintenance = CardMediaMaintenance(),
         drafts: DeckDraftStoreInterface = DeckDraftStore.shared) {
        self.repository = repository
        self.maintenance = maintenance
        self.drafts = drafts
    }

    var desks: [DeskEntity] {
        return repository.getAll()
    }
}

extension DeskInteractor: DeskInteractorInterface {
    func desk(withId id: String) -> DeskEntity? {
        repository.desk(withId: id)
    }

    func deleteDesk(withId id: String) throws {
        guard let desk = repository.desk(withId: id) else {
            throw AppError.entityNotFound(NSLocalizedString("deck", comment: ""))
        }
        do {
            try repository.delete(desk)
        } catch {
            throw AppError.databaseWriteFailed(error.localizedDescription)
        }
        // Unsaved edits of a deck that no longer exists can never be restored; drop them so their pictures are collected too.
        drafts.discard(forDeckId: id)
        maintenance.collectGarbage()
    }
}
