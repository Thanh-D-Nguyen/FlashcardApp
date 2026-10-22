//
//  CardManagement.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//

import Foundation

class CardManagement: CardRepositoryInterface {
    static let shared = CardManagement()
    
    func add(_ card: CardEntity, toDesk desk: DeskEntity) throws {
        guard let realmDesk = DeskManagement.shared.deskFromId(desk.id) else {
            throw AppError.entityNotFound(NSLocalizedString("deck", comment: ""))
        }
        try RealmService.shared.realm.write {
            let rCard = card.toRealm()
            realmDesk.cards.append(rCard)
        }
    }
}
