//
//  DeskDataModel.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/03/06.
//

import UIKit
import RxRelay

struct DeskDataModel {
    let uuid = UUID().uuidString
    let deskNameRelay: BehaviorRelay<String>
    var deskName: String {
        return deskNameRelay.value
    }
    let deskDescRelay: BehaviorRelay<String>
    var deskDesc: String {
        return deskDescRelay.value
    }
    let sortingLanguageRelay: BehaviorRelay<LanguageSortingType>
    var sortingLang: LanguageSortingType {
        return sortingLanguageRelay.value
    }
    var cards: [CardDataModel]
    
    init(name: String = "", desc: String = "", language: LanguageSortingType = .normal, cards: [CardDataModel] = []) {
        self.deskNameRelay = BehaviorRelay(value: name)
        self.deskDescRelay = BehaviorRelay(value: desc)
        self.sortingLanguageRelay = BehaviorRelay(value: language)
        self.cards = cards
    }
}

struct CardDataModel {
    let uuid = UUID().uuidString
    
    let frontRelay: BehaviorRelay<String>
    var front: String {
        return frontRelay.value
    }
    let backRelay: BehaviorRelay<String>
    var back: String {
        return backRelay.value
    }
    let imageRelay: BehaviorRelay<String>
    var imageUrl: String {
        return imageRelay.value
    }
    
    init(front: String = "", back: String = "", imageUrl: String = "") {
        self.frontRelay = BehaviorRelay(value: front)
        self.backRelay = BehaviorRelay(value: back)
        self.imageRelay = BehaviorRelay(value: imageUrl)
    }
    
    static func ==(lhs: CardDataModel, rhs: CardDataModel) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}
