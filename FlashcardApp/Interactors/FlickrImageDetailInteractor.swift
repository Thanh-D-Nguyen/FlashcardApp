//
//  FlickrImageDetailInteractor.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/03/26.
//

import UIKit

protocol FlickrImageDetailInteractorInterface: AnyObject {
    var didCompleteLoadImage: ((UIImage?) -> Void)? { get set }

    func fetchPhoto(_ request: ImageDetailEntity.FetchPhoto.Request)
}

class FlickrImageDetailInteractor {
    private var photo: Photo?
    private let networkService: NetworkServiceProtocol

    var didCompleteLoadImage: ((UIImage?) -> Void)?
    
    init() {
        networkService = NetworkService()
    }
    
}

extension FlickrImageDetailInteractor: FlickrImageDetailInteractorInterface {
    
    func fetchPhoto(_ request: ImageDetailEntity.FetchPhoto.Request) {
        let image = FlickrRoute.photo(
            id: request.id,
            server: request.server,
            secret: request.secret,
            size: .large
        )
        networkService.fetch(route: image) { [weak self] result in
            switch result {
                case .success(let photoData):
                    if let photoData = photoData {
                        let image = UIImage(data: photoData)
                        DispatchQueue.main.async {
                            self?.didCompleteLoadImage?(image)
                        }
                    }
                case .failure(let error):
                    debugPrint(error.localizedDescription)
            }
        }
    }
}
