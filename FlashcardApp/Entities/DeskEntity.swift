//
//  DeskEntity.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//

import Foundation
import RealmSwift

struct DeskEntity {
    var id: Int = -1
    var name: String
    var description: String
    var imageNamed: String
    var cards: [CardEntity] = [CardEntity(frontText: "楽しい", frontExtraText: "たのしい", backText: "Vui vẻ", backExtraText: "", imageUrl: "https://vancouverjapaneselesson.files.wordpress.com/2010/12/tanoshii.jpg", videoUrl: "")]
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
        return desk
    }
}
