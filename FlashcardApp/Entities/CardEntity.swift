//
//  CardEntity.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//
import Foundation
import Kingfisher
import UIKit

class CardEntity: Codable {
    var id: String
    var frontText: String
    var frontExtraText: String
    var backText: String
    var backExtraText: String
    var imageUrl: String
    var videoUrl: String
    
    // At card list, to store card display state (back or front)
    var displayingFront: Bool = true
    
    init() {
        id = UUID().uuidString
        frontText = ""
        frontExtraText = ""
        backText = ""
        backExtraText = ""
        imageUrl = ""
        videoUrl = ""
    }
    
    static func empty() -> CardEntity {
        CardEntity()
    }
}

extension CardEntity {
    
    func toRealm() -> RCard {
        let card = RCard()
        card.id = id
        card.frontText = frontText
        card.frontExtraText = frontExtraText
        card.backText = backText
        card.backExtraText = backExtraText
        card.imageUrl = imageUrl
        card.videoUrl = videoUrl
        return card
    }
    
    func setImageToImageView(_ imageView: UIImageView) {
        let imageUrl = URL(string: imageUrl)
        imageView.kf.setImage(with: imageUrl)
    }
}
