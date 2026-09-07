//
//  BJTDictionaryAPI.swift
//  FlashcardApp
//
//  Created by Claude on 2026/09/06.
//

import Alamofire
import Foundation
import RxSwift

/// API client for nihongo-bjt dictionary endpoints (JP→VI and VI→JP).
final class BJTDictionaryAPI {

    static let shared = BJTDictionaryAPI()

    private var baseURL: String {
        let base = ClientAPI.basePath
        return base.isEmpty ? EnvironmentConfig.baseUrl() : base
    }

    // MARK: - JP→VI Dictionary Search

    /// GET /api/dictionary/search — canonical v15 JP→VI dictionary search.
    func search(token: String, q: String, limit: Int = 20) -> Single<[BJTDictionarySearchResultDTO]> {
        let url = "\(baseURL)/dictionary/search"
        let params: [String: Any] = ["q": q, "limit": limit]
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, parameters: params, headers: headers)
                .validate()
                .responseDecodable(of: [BJTDictionarySearchResultDTO].self) { response in
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

    // MARK: - Dictionary Word Detail

    /// GET /api/dictionary/words/{id} — canonical v15 dictionary word detail.
    func wordDetail(token: String, id: String) -> Single<BJTDictionaryWordDetailDTO> {
        let url = "\(baseURL)/dictionary/words/\(id)"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, headers: headers)
                .validate()
                .responseDecodable(of: BJTDictionaryWordDetailDTO.self) { response in
                    switch response.result {
                    case .success(let item):
                        observer(.success(item))
                    case .failure(let error):
                        observer(.failure(error))
                    }
                }
            return Disposables.create { request.cancel() }
        }
    }

    // MARK: - VI→JP Reverse Search

    /// GET /api/vija/search — canonical v15 VI→JP reverse dictionary search.
    func reverseSearch(token: String, q: String, limit: Int = 20) -> Single<[BJTReverseSearchResultDTO]> {
        let url = "\(baseURL)/vija/search"
        let params: [String: Any] = ["q": q, "limit": limit]
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, parameters: params, headers: headers)
                .validate()
                .responseDecodable(of: [BJTReverseSearchResultDTO].self) { response in
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