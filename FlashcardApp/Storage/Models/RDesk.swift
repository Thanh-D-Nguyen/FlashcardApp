//
//  RDesk.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//

import Foundation
import RealmSwift

class RDesk: Object {
    @Persisted(primaryKey: true) var id: String
    @Persisted var name: String
    @Persisted var desc: String
    @Persisted var sortingLanguage: Int
    @Persisted var imageNamed: String
    @Persisted var cards: List<RCard>
    
    @Persisted var date: Date
}

extension RDesk {
    func toEntity() -> DeskEntity {
        let desk = DeskEntity()
        desk.id = id
        desk.name = name
        desk.description = desc
        desk.imageNamed = imageNamed
        desk.sortingLanguage = LanguageSortingType(rawValue: sortingLanguage) ?? .normal
        desk.cards = cards.map({ $0.toEntity() })
        desk.date = date
        return desk
    }
}
