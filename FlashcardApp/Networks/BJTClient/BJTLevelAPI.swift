//
//  BJTLevelAPI.swift
//  FlashcardApp
//
//  Created by Claude on 2026/09/06.
//

import Alamofire
import Foundation
import RxSwift

/// API client for nihongo-bjt BJT level endpoints.
final class BJTLevelAPI {

    static let shared = BJTLevelAPI()

    private var baseURL: String {
        let base = ClientAPI.basePath
        return base.isEmpty ? EnvironmentConfig.baseUrl() : base
    }

    // MARK: - List Levels

    /// GET /api/levels — list all BJT levels (J5 → J1+) with content counts.
    func list(token: String) -> Single<[BJTLevelDTO]> {
        let url = "\(baseURL)/levels"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, headers: headers)
                .validate()
                .responseDecodable(of: [BJTLevelDTO].self) { response in
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

    // MARK: - Level Detail

    /// GET /api/levels/{code} — get a single BJT level definition.
    func detail(token: String, code: String) -> Single<BJTLevelDetailDTO> {
        let url = "\(baseURL)/levels/\(code)"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, headers: headers)
                .validate()
                .responseDecodable(of: BJTLevelDetailDTO.self) { response in
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

    // MARK: - Lessons for Level

    /// GET /api/levels/{code}/lessons — list lessons for a BJT level.
    func lessons(token: String, code: String) -> Single<[BJTLevelLessonSummaryDTO]> {
        let url = "\(baseURL)/levels/\(code)/lessons"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, headers: headers)
                .validate()
                .responseDecodable(of: [BJTLevelLessonSummaryDTO].self) { response in
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

    // MARK: - Lesson Detail

    /// GET /api/levels/lessons/{slug} — get lesson detail with all content items.
    func lessonDetail(token: String, slug: String) -> Single<BJTLevelLessonDetailDTO> {
        let url = "\(baseURL)/levels/lessons/\(slug)"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, headers: headers)
                .validate()
                .responseDecodable(of: BJTLevelLessonDetailDTO.self) { response in
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

    // MARK: - Vocabulary for Level

    /// GET /api/levels/{code}/vocabulary — list vocabulary for a BJT level.
    func vocabulary(token: String, code: String, q: String? = nil, limit: Int = 30, offset: Int = 0) -> Single<[BJTLevelVocabularyItemDTO]> {
        let url = "\(baseURL)/levels/\(code)/vocabulary"
        var params: [String: Any] = ["limit": min(limit, 50), "offset": offset]
        if let q { params["q"] = q }
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, parameters: params, headers: headers)
                .validate()
                .responseDecodable(of: [BJTLevelVocabularyItemDTO].self) { response in
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

    // MARK: - Kanji for Level

    /// GET /api/levels/{code}/kanji — list kanji for a BJT level.
    func kanji(token: String, code: String, q: String? = nil, limit: Int = 30, offset: Int = 0) -> Single<[BJTLevelKanjiItemDTO]> {
        let url = "\(baseURL)/levels/\(code)/kanji"
        var params: [String: Any] = ["limit": min(limit, 50), "offset": offset]
        if let q { params["q"] = q }
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, parameters: params, headers: headers)
                .validate()
                .responseDecodable(of: [BJTLevelKanjiItemDTO].self) { response in
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

    // MARK: - Grammar for Level

    /// GET /api/levels/{code}/grammar — list grammar points for a BJT level.
    func grammar(token: String, code: String, q: String? = nil, limit: Int = 30, offset: Int = 0) -> Single<[BJTLevelGrammarItemDTO]> {
        let url = "\(baseURL)/levels/\(code)/grammar"
        var params: [String: Any] = ["limit": min(limit, 50), "offset": offset]
        if let q { params["q"] = q }
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, parameters: params, headers: headers)
                .validate()
                .responseDecodable(of: [BJTLevelGrammarItemDTO].self) { response in
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