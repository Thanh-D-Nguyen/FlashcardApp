//
//  FlickrImageSearchInteractor.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/03/26.
//

import UIKit
import RxSwift

class FlickrImageSearchInteractor: ImageSearchInteractorInterface {
    
    private let flickrSearchApi: FlickrSearchApiInterface
    
    init() {
        flickrSearchApi = FlickrSearchApi()
    }

    func search(query: String, page: Int, perpage: Int) -> Single<[SearchPhoto]> {
        let model = ImageSearchRequestModel(query: query, page: page, perpage: perpage)
        return flickrSearchApi.search(model)
    }
}
