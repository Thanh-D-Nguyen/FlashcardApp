//
//  PixabayImage.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/04/02.
//

import Foundation

struct PixabayImage: Codable {
    var total, totalHits: Int?
    var hits: [PixabayImageItem]?
}

struct PixabayImageItem: Codable {
    var id: Int?
    var pageURL: String?
    var type, tags: String?
    var previewURL: String?
    var previewWidth, previewHeight: Int?
    var webformatURL: String?
    var webformatWidth, webformatHeight: Int?
    var largeImageURL, fullHDURL, imageURL: String?
    var imageWidth, imageHeight, imageSize, views: Int?
    var downloads, likes, comments, userID: Int?
    var user: String?
    var userImageURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id, pageURL, type, tags, previewURL, previewWidth, previewHeight, webformatURL, webformatWidth, webformatHeight, largeImageURL, fullHDURL, imageURL, imageWidth, imageHeight, imageSize, views, downloads, likes, comments
        case userID
        case user, userImageURL
    }
}
