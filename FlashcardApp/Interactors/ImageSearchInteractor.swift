//
//  ImageSearchInteractor.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/04/02.
//

import Foundation
import RxSwift

enum SearchImageType {
    case pixabay
    case flickr
}

protocol ImageSearchInteractorInterface {
    func search(query: String, page: Int, perpage: Int) -> Single<[SearchPhoto]>
}

class ImageSearchInteractor {
    static func create(type: SearchImageType) -> ImageSearchInteractorInterface {
        switch type {
            case .pixabay:
                return PixabayImageSearchInteractor()
            case .flickr:
                return FlickrImageSearchInteractor()
        }
    }
}
