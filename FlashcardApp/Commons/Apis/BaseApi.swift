//
//  BaseApi.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/01/08.
//
import RxSwift

protocol BaseApiProtocol { }

extension BaseApiProtocol {
    func convertSingle<T: Codable>(function: String = #function, executeApi: @escaping (_ completion: @escaping ((_ data: T?, _ error: Error?) -> Void)) -> Void) -> Single<T> {
        return Single<T>.create { observer -> Disposable in
            executeApi { response, error in
                if let apiError = APIErrorFilter.filter(response, error) {
                    observer(.failure(apiError))
                } else {
                    if let response = response {
                        observer(.success(response))
                    } else {
                        observer(.failure(APIError(status: -1, message: "??")))
                    }
                }
                
            }
            return Disposables.create()
        }
    }
}
