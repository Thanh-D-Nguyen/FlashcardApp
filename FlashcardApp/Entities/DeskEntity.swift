//
//  DeskEntity.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//

import Foundation
import RealmSwift

struct DeskEntity {
    var id: Int
    var name: String
    var description: String
    var imageNamed: String
    var cards: [CardEntity] = []
    var date: Date
    
    var selectIndex = Constants.unknowSelectIndex
}

extension DeskEntity {
    func toRealm() -> RDesk {
        let desk = RDesk()
        desk.id = id
        desk.name = name
        desk.desc = description
        desk.imageNamed = imageNamed
        let cards = cards.compactMap({ $0.toRealm() })
        let list = List<RCard>()
        list.append(objectsIn: cards)
        desk.cards = list
        desk.date = date
        return desk
    }
}
