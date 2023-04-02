//
//  PixabayImageSearchInteractor.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/04/02.
//

import Foundation
import RxSwift

class PixabayImageSearchInteractor: ImageSearchInteractorInterface {
    private let pixabaySearchApi: PixabaySearchApiInterface
    
    init() {
        pixabaySearchApi = PixabaySearchApi()
    }
    
    func search(query: String, page: Int, perpage: Int) -> Single<[SearchPhoto]> {
        let model = ImageSearchRequestModel(query: query, page: page, perpage: perpage)
        return pixabaySearchApi.searchImage(model)
    }
}
