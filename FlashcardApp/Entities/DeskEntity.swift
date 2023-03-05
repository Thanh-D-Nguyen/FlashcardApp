//
//  DeskEntity.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//

import Foundation
import RealmSwift
import UIKit

enum LanguageSortingType: Int {
    case normal, opposite
    
    var firstImage: UIImage? {
        switch self {
            case .normal:
                return AppImage.jaFlag
            case .opposite:
                return AppImage.viFlag
        }
    }

    var secondImage: UIImage? {
        switch self {
            case .normal:
                return AppImage.viFlag
            case .opposite:
                return AppImage.jaFlag
        }
    }
}

struct DeskEntity {
    var id: Int
    var name: String
    var description: String
    var imageNamed: String
    var sortingLanguage: LanguageSortingType
    var cards: [CardEntity] = []
    var date: Date

    var selectIndex = Constants.unknowSelectIndex
    static func empty() -> DeskEntity {
        DeskEntity(id: -1, name: "", description: "", imageNamed: "", sortingLanguage: .normal, date: Date())
    }
    
}

struct CreateDeskEntity {
    var name: String
    var description: String
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
