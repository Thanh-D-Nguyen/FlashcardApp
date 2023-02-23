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
    @Persisted var imageNamed: String
    @Persisted var cards: List<RCard>
}

extension RDesk {
    func toEntity() -> DeskEntity {
        DeskEntity(name: name,
                   description: desc,
                   imageNamed: imageNamed,
                   cards: cards.map({ $0.toEntity() }))
    }
}
