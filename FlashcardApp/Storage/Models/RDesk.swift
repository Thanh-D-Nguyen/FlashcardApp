//
//  RDesk.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//

import Foundation
import RealmSwift

class RDesk: Object {
    @Persisted(primaryKey: true) var id: Int
    @Persisted var name: String
    @Persisted var desc: String
    @Persisted var sortingLanguage: Int
    @Persisted var imageNamed: String
    @Persisted var cards: List<RCard>
    
    @Persisted var date: Date
}

extension RDesk {
    func toEntity() -> DeskEntity {
        DeskEntity(id: id,
                   name: name,
                   description: desc,
                   imageNamed: imageNamed,
                   sortingLanguage: LanguageSortingType(rawValue: sortingLanguage) ?? .normal,
                   cards: cards.map({ $0.toEntity() }),
                   date: date)
    }
}
