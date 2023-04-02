//
//  FlickrPhoto.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/04/01.
//

import Foundation

struct PhotoSearchResult: Codable {
    let photos: PagedPhotoSearchResult?
    let stat: String
}

struct PagedPhotoSearchResult: Codable {
    let photo: [FlickrPhoto]
    let page: Int
    let pages: Int
    let perpage: Int
    let total: Int
}

struct FlickrPhoto: Codable {
    let id: String
    let title: String
    let secret: String
    let server: String
    
    
    func imagePath(_ size: PhotoSize) -> String {
        return "https://live.staticflickr.com/\(server)/\(id)_\(secret)_\(size.rawValue).jpg"
    }
}
