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
    var frontText: String
    var frontExtraText: String
    var backText: String
    var backExtraText: String
    var imageUrl: String
    var videoUrl: String
    
    var displayingFront: Bool = true
}

extension CardEntity {
    func setImageToImageView(_ imageView: UIImageView) {
        let imageUrl = URL(string: imageUrl)
        imageView.kf.setImage(with: imageUrl)
    }
}
