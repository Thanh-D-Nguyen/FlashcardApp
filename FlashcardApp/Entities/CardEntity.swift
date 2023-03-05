//
//  CardEntity.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//
import Foundation
import Kingfisher
import UIKit

struct CardEntity: Codable {
    var id: Int
    var frontText: String
    var frontExtraText: String
    var backText: String
    var backExtraText: String
    var imageUrl: String
    var videoUrl: String
    
    // At card list, to store card display state (back or front)
    var displayingFront: Bool = true
    
    static func empty() -> CardEntity {
        CardEntity(id: -1,
                   frontText: "",
                   frontExtraText: "",
                   backText: "",
                   backExtraText: "",
                   imageUrl: "",
                   videoUrl: "")
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
