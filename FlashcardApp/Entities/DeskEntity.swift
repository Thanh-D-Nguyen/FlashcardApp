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
                return AppImages.jaFlag
            case .opposite:
                return AppImages.viFlag
        }
    }

    var secondImage: UIImage? {
        switch self {
            case .normal:
                return AppImages.viFlag
            case .opposite:
                return AppImages.jaFlag
        }
    }
}

class DeskEntity {
    var id: String
    var name: String
    var description: String
    var imageNamed: String
    var sortingLanguage: LanguageSortingType
    var cards: [CardEntity]
    var date: Date

    var selectIndex = Constants.unknowSelectIndex
    
    init() {
        id = UUID().uuidString
        name = ""
        description = ""
        imageNamed = ""
        sortingLanguage = .normal
        cards = []
        date = Date()
    }
    
    static func empty() -> DeskEntity {
        DeskEntity()
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
