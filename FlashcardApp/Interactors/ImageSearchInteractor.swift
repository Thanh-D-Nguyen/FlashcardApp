//
//  ImageSearchInteractor.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/04/02.
//

import Foundation
import RxSwift

enum SearchImageType: Int, CaseIterable {
    case pixabay
    case flickr
    
    var description: String {
        switch self {
            case .pixabay:
                return "Pixabay"
            case .flickr:
                return "Flickr"
        }
    }
    static func all() -> [String] {
        return self.allCases.map { $0.description }
    }
}

protocol ImageSearchInteractorInterface {
    func search(query: String, page: Int, perpage: Int) -> Single<[SearchPhoto]>
}

class ImageSearchInteractor {
    
    private var currentSearchType: SearchImageType
    private var interactor: ImageSearchInteractorInterface
        
    init(searchType: SearchImageType) {
        self.currentSearchType = searchType
        self.interactor = ImageSearchInteractor.create(type: searchType)
    }
    
    static func create(type: SearchImageType) -> ImageSearchInteractorInterface {
        switch type {
            case .pixabay:
                return PixabayImageSearchInteractor()
            case .flickr:
                return FlickrImageSearchInteractor()
        }
    }
}

extension ImageSearchInteractor: ImageSearchInteractorInterface {
    
    func search(query: String, page: Int, perpage: Int) -> Single<[SearchPhoto]> {
        interactor.search(query: query, page: page, perpage: perpage)
    }
}
 
