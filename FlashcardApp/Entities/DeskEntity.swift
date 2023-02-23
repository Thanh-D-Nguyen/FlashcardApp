//
//  DeskEntity.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//

import Foundation

struct DeskEntity {
    var name: String
    var description: String
    var imageNamed: String
    var cards: [CardEntity] = [CardEntity(frontText: "楽しい", frontExtraText: "たのしい", backText: "Vui vẻ", backExtraText: "", imageUrl: "https://vancouverjapaneselesson.files.wordpress.com/2010/12/tanoshii.jpg", videoUrl: "")]
}
