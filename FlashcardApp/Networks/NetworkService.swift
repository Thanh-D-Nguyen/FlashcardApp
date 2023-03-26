//
//  NetworkService.swift
//  ImageSearchApp
//
//  Created by Rodion Artyukhin on 13.12.2022.
//

import Foundation
import Alamofire

protocol NetworkServiceProtocol {
    func fetch(route: RouteType, completion: @escaping (Result<Data?, Error>) -> Void)
}

final class NetworkService: NetworkServiceProtocol {
    
    // MARK: - Properties
    private let session = AF
    
    // MARK: - NetworkServiceProtocol
    func fetch(route: RouteType, completion: @escaping (Result<Data?, Error>) -> Void) {
        guard let request = getRequest(for: route) else {
            completion(.failure(NetworkError.invalidRequest))
            return
        }
        session.request(request).response(completionHandler: { response in
            switch response.result {
                case .success(let data):
                    completion(.success(data))
                case .failure(let error):
                    completion(.failure(error))
            }
        })
    }
}

// MARK: - Methods
private extension NetworkService {
    func getRequest(for route: RouteType) -> URLRequest? {
        guard let requestURL = route.requestURL else { return nil }
        var request = URLRequest(url: requestURL)
        request.allHTTPHeaderFields = route.headers
        return request
    }
}
