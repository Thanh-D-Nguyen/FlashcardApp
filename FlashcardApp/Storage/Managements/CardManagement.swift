//
//  CardManagement.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//

import Foundation

class CardManagement {
    static let shared = CardManagement()
    
    func add(_ card: CardEntity, toDesk desk: DeskEntity) throws {
        guard let desk = DeskManagement.shared.deskFromId(desk.id) else { return }
        try RealmService.shared.realm.write {
            let card = card.toRealm()
            desk.cards.append(card)
        }
    }
}
