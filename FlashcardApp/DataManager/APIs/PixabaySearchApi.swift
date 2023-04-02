//
//  PixabaySearchApi.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/04/02.
//

import Foundation
import RxSwift

protocol PixabaySearchApiInterface {
    func searchImage(_ model: ImageSearchRequestModel) -> Single<[SearchPhoto]>
}

class PixabaySearchApi: PixabaySearchApiInterface, BaseApiProtocol {
    static let baseUrl = "https://pixabay.com/api"
    static let apiKey = "14898099-bcf5293d969cd2a4f38b6f2da"
    
    private func search(_ model: ImageSearchRequestModel) -> RequestBuilder<PixabayImage> {
        let urlString = PixabaySearchApi.baseUrl
        var url = URLComponents(string: urlString)
        url?.queryItems = APIHelper.mapValuesToQueryItems([
            "key": PixabaySearchApi.apiKey,
            "image_type": "photo",
            "lang": "jp",
            "q": model.query,
            "page": String(model.page),
            "per_page": String(model.perpage)
        ])
        let requestBuilder: RequestBuilder<PixabayImage>.Type = ClientAPI.requestBuilderFactory.getBuilder()
        return requestBuilder.init(method: "GET", URLString: (url?.string ?? urlString), parameters: nil, isBody: false)
    }
    
    private func search(_ model: ImageSearchRequestModel, completion: @escaping ((_ photos: [SearchPhoto]?, _ error: Error?) -> Void)) {
        search(model).execute { response, error in
            completion(response?.body?.hits?.map({ SearchPhoto(url: $0.largeImageURL ?? "") }), error)
        }
    }
    
    func searchImage(_ model: ImageSearchRequestModel) -> Single<[SearchPhoto]> {
        convertSingle { completion in
            self.search(model, completion: completion)
        }
    }
}
