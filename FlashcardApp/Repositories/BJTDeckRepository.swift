//
//  BJTDeckRepository.swift
//  FlashcardApp
//
//  Created by Claude on 2026/09/07.
//

import Alamofire
import Foundation
import RxSwift

/// Remote desk repository backed by nihongo-bjt API.
/// Implements DeskRepositoryInterface for read operations; write operations
/// use BJT-specific DTOs and are not part of the local-only protocol.
final class BJTDeckRepository {

    private let authTokenManager: AuthTokenManagerInterface
    private let disposeBag = DisposeBag()

    init(authTokenManager: AuthTokenManagerInterface = KeychainAuthTokenManager.shared) {
        self.authTokenManager = authTokenManager
    }

    // MARK: - Read

    /// GET /api/flashcards/decks — fetch all decks for the current user.
    func fetchDesks() -> Single<[BJTDeckDTO]> {
        guard let token = authTokenManager.accessToken else {
            return .error(AppError.authenticationFailed("Access token not found"))
        }
        let url = "\(EnvironmentConfig.baseUrl())/flashcards/decks"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, headers: headers)
                .validate()
                .responseDecodable(of: [BJTDeckDTO].self) { response in
                    switch response.result {
                    case .success(let desks):
                        observer(.success(desks))
                    case .failure(let error):
                        observer(.failure(error))
                    }
                }
            return Disposables.create { request.cancel() }
        }
    }

    /// GET /api/decks/{id} — fetch a single deck with its cards.
    func fetchDeskDetail(id: String) -> Single<BJTDeckDetailDTO> {
        guard let token = authTokenManager.accessToken else {
            return .error(AppError.authenticationFailed("Access token not found"))
        }
        let url = "\(EnvironmentConfig.baseUrl())/decks/\(id)"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]

        return Single.create { observer in
            let request = AF.request(url, headers: headers)
                .validate()
                .responseDecodable(of: BJTDeckDetailDTO.self) { response in
                    switch response.result {
                    case .success(let detail):
                        observer(.success(detail))
                    case .failure(let error):
                        observer(.failure(error))
                    }
                }
            return Disposables.create { request.cancel() }
        }
    }

    // MARK: - Write (BJT-specific, not in DeskRepositoryInterface)

    /// POST /api/decks — create a new desk remotely.
    func createDesk(_ request: BJTCreateDeckRequestDTO) -> Single<BJTDeckDTO> {
        guard let token = authTokenManager.accessToken else {
            return .error(AppError.authenticationFailed("Access token not found"))
        }
        let url = "\(EnvironmentConfig.baseUrl())/decks"
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]

        return Single.create { observer in
            let requestTask = AF.request(url, method: .post, parameters: request, encoder: JSONParameterEncoder.default, headers: headers)
                .validate()
                .responseDecodable(of: BJTDeckDTO.self) { response in
                    switch response.result {
                    case .success(let desk):
                        observer(.success(desk))
                    case .failure(let error):
                        observer(.failure(error))
                    }
                }
            return Disposables.create { requestTask.cancel() }
        }
    }
}