//
//  RCard.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//

import Foundation
import RealmSwift

class RCard: Object {
    @Persisted(primaryKey: true) var id: String
    @Persisted var frontText: String
    @Persisted var frontExtraText: String
    @Persisted var backText: String
    @Persisted var backExtraText: String
    @Persisted var imageUrl: String
    @Persisted var videoUrl: String
    @Persisted(originProperty: "cards") var assignee: LinkingObjects<RDesk>
}

extension RCard {
    func toEntity() -> CardEntity {
        let entity = CardEntity()
        entity.id = id
        entity.frontText = frontText
        entity.frontExtraText = frontExtraText
        entity.backText = backText
        entity.backExtraText = backExtraText
        entity.imageUrl = imageUrl
        entity.videoUrl = videoUrl
        return entity
    }
}
