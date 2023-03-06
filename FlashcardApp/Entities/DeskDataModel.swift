//
//  DeskDataModel.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/03/06.
//

import UIKit
import RxRelay

struct DeskDataModel {
    var entity: DeskEntity
    
    let deskNameRelay: BehaviorRelay<String>
    let deskDescRelay: BehaviorRelay<String>
    
    let cardsRelay: BehaviorRelay<[CardDataModel]>
    
    init(entity: DeskEntity) {
        self.entity = entity
        self.deskNameRelay = BehaviorRelay(value: entity.name)
        self.deskDescRelay = BehaviorRelay(value: entity.description)
        cardsRelay = BehaviorRelay(value: entity.cards.map({ CardDataModel(entity: $0) }))
    }
}

struct CardDataModel {
    var entity: CardEntity
    
    let frontRelay: BehaviorRelay<String>
    let backRelay: BehaviorRelay<String>
    let imageRelay: BehaviorRelay<String>
    
    init(entity: CardEntity) {
        self.entity = entity
        self.frontRelay = BehaviorRelay(value: entity.frontText)
        self.backRelay = BehaviorRelay(value: entity.backText)
        self.imageRelay = BehaviorRelay(value: entity.imageUrl)
    }
}
