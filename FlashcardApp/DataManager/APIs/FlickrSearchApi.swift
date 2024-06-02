//
//  FlickrSearchApi.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/04/01.
//

import Foundation
import RxSwift

protocol FlickrSearchApiInterface {
    func search(_ model: ImageSearchRequestModel) -> Single<[SearchPhoto]>
}

class FlickrSearchApi: FlickrSearchApiInterface, BaseApiProtocol {
    static let baseUrl = "https://api.flickr.com/services/rest"
    static let apiKey = "f229d927412e044c841570508a4daabf"
    
    private func search(_ model: ImageSearchRequestModel) -> RequestBuilder<PhotoSearchResult> {
        let urlString = FlickrSearchApi.baseUrl
        var url = URLComponents(string: urlString)
        url?.queryItems = APIHelper.mapValuesToQueryItems([
            "api_key": FlickrSearchApi.apiKey,
            "method": "flickr.photos.search",
            "text": model.query,
            "page": String(model.page),
            "per_page": String(model.perpage),
            "format": "json",
            "nojsoncallback": "1"
        ])
        let requestBuilder: RequestBuilder<PhotoSearchResult>.Type = ClientAPI.requestBuilderFactory.getBuilder()
        return requestBuilder.init(method: "GET", URLString: (url?.string ?? urlString), parameters: nil, isBody: false)
    }
    
    private func search(_ model: ImageSearchRequestModel, completion: @escaping ((_ photos: [SearchPhoto]?, _ error: Error?) -> Void)) {
        search(model).execute { response, error in
            completion(response?.body?.photos?.photo.map({ SearchPhoto(url: $0.imagePath(.large)) }), error)
        }
    }
    
    func search(_ model: ImageSearchRequestModel) -> Single<[SearchPhoto]> {
        return convertSingle { completion in
            self.search(model, completion: completion)
        }
    }
}
