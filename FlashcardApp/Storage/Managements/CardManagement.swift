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

    func add(_ cards: [CardEntity], toDesk desk: DeskEntity) throws {
        guard let realmDesk = DeskManagement.shared.deskFromId(desk.id) else {
            throw AppError.entityNotFound(NSLocalizedString("deck", comment: ""))
        }
        let realm = RealmService.shared.realm!
        // Realm raises an uncatchable exception for a duplicate primary key, so ids are checked first.
        guard Set(cards.map(\.id)).count == cards.count,
              !cards.contains(where: { realm.object(ofType: RCard.self, forPrimaryKey: $0.id) != nil }) else {
            throw AppError.invalidInput(NSLocalizedString("A card in this deck already belongs to another deck.", comment: ""))
        }
        try realm.write {
            realmDesk.cards.append(objectsIn: cards.map { $0.toRealm() })
        }
    }
}
