//
//  BJTExampleAPI.swift
//  FlashcardApp
//
//  Created by Claude on 2026/09/06.
//

import Alamofire
import Foundation
import RxSwift

/// API client for nihongo-bjt example sentence endpoints.
final class BJTExampleAPI {

    static let shared = BJTExampleAPI()

    private var baseURL: String {
        let base = ClientAPI.basePath
        return base.isEmpty ? EnvironmentConfig.baseUrl() : base
    }

    // MARK: - List Examples

    /// GET /api/examples — canonical v15 example sentence list.
    func list(token: String, q: String? = nil, limit: Int = 20, offset: Int = 0) -> Single<[BJTExampleSentenceDTO]> {
        let url = "\(baseURL)/examples"
        var params: [String: Any] = ["limit": limit, "offset": offset]
        if let q { params["q"] = q }
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, parameters: params, headers: headers)
                .validate()
                .responseDecodable(of: [BJTExampleSentenceDTO].self) { response in
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

    // MARK: - Examples by Word

    /// GET /api/examples/by-word/{wordId} — examples linked to a dictionary word.
    func byWord(token: String, wordId: String, limit: Int = 20) -> Single<[BJTExampleSentenceDTO]> {
        let url = "\(baseURL)/examples/by-word/\(wordId)"
        let params: [String: Any] = ["limit": limit]
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, parameters: params, headers: headers)
                .validate()
                .responseDecodable(of: [BJTExampleSentenceDTO].self) { response in
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

    // MARK: - Search Examples

    /// GET /api/examples/search — canonical v15 example search.
    func search(token: String, q: String, limit: Int = 20) -> Single<[BJTExampleSentenceDTO]> {
        let url = "\(baseURL)/examples/search"
        let params: [String: Any] = ["q": q, "limit": limit]
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, parameters: params, headers: headers)
                .validate()
                .responseDecodable(of: [BJTExampleSentenceDTO].self) { response in
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