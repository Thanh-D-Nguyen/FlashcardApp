//
//  BJTSearchAPI.swift
//  FlashcardApp
//
//  Created by Claude on 2026/09/06.
//

import Alamofire
import Foundation
import RxSwift

/// API client for nihongo-bjt Meilisearch-backed search endpoints.
final class BJTSearchAPI {

    static let shared = BJTSearchAPI()

    private var baseURL: String {
        let base = ClientAPI.basePath
        return base.isEmpty ? EnvironmentConfig.baseUrl() : base
    }

    // MARK: - Search

    /// GET /api/search — Meilisearch projection (read-only copy of indexed content).
    func search(token: String, q: String, limit: Int = 10, scope: String? = nil, level: String? = nil) -> Single<[BJTSearchResultDTO]> {
        let url = "\(baseURL)/search"
        var params: [String: Any] = ["q": q, "limit": limit]
        if let scope { params["scope"] = scope }
        if let level { params["level"] = level }
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, parameters: params, headers: headers)
                .validate()
                .responseDecodable(of: [BJTSearchResultDTO].self) { response in
                    switch response.result {
                    case .success(let items):
                        observer(.success(items))
                    case .failure(let error):
                        observer(.failure(error))
                    }
                }
            return Disposables.create { request.cancel() }
        }
    }

    // MARK: - Suggest

    /// GET /api/search/suggest — lightweight prefix-search suggestions for autocomplete.
    func suggest(token: String, q: String, limit: Int = 6) -> Single<[BJTSearchSuggestDTO]> {
        let url = "\(baseURL)/search/suggest"
        let params: [String: Any] = ["q": q, "limit": limit]
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, parameters: params, headers: headers)
                .validate()
                .responseDecodable(of: [BJTSearchSuggestDTO].self) { response in
                    switch response.result {
                    case .success(let items):
                        observer(.success(items))
                    case .failure(let error):
                        observer(.failure(error))
                    }
                }
            return Disposables.create { request.cancel() }
        }
    }
}