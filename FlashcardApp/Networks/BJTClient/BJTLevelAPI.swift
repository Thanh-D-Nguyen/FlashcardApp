import Alamofire
import Foundation
import RxSwift

final class BJTLevelAPI {
    static let shared = BJTLevelAPI()
    private let session: Session
    private let baseURL: String

    init(session: Session = Session(), baseURL: String = EnvironmentConfig.baseUrl()) {
        self.session = session
        self.baseURL = baseURL
    }

    func list() -> Single<[BJTLevelDTO]> {
        Single.create { observer in
            do {
                let url = try self.endpoint(["levels"])
                let request = self.session.request(url)
                    .validate(statusCode: 200..<300)
                    .responseDecodable(of: [BJTLevelDTO].self) { response in
                        observer(response.result.mapError { $0 as Error })
                    }
                return Disposables.create { request.cancel() }
            } catch {
                observer(.failure(error))
                return Disposables.create()
            }
        }
    }

    func vocabulary(code: String, limit: Int = 30, offset: Int = 0) -> Single<[BJTLevelVocabularyItemDTO]> {
        Single.create { observer in
            do {
                let url = try self.referenceURL(code: code, kind: "vocabulary", limit: limit, offset: offset)
                let request = self.session.request(url, parameters: ["limit": limit, "offset": offset])
                    .validate(statusCode: 200..<300)
                    .responseDecodable(of: [BJTLevelVocabularyItemDTO].self) { response in
                        observer(response.result.mapError { $0 as Error })
                    }
                return Disposables.create { request.cancel() }
            } catch {
                observer(.failure(error))
                return Disposables.create()
            }
        }
    }

    func kanji(code: String, limit: Int = 30, offset: Int = 0) -> Single<[BJTLevelKanjiItemDTO]> {
        Single.create { observer in
            do {
                let url = try self.referenceURL(code: code, kind: "kanji", limit: limit, offset: offset)
                let request = self.session.request(url, parameters: ["limit": limit, "offset": offset])
                    .validate(statusCode: 200..<300)
                    .responseDecodable(of: [BJTLevelKanjiItemDTO].self) { response in
                        observer(response.result.mapError { $0 as Error })
                    }
                return Disposables.create { request.cancel() }
            } catch {
                observer(.failure(error))
                return Disposables.create()
            }
        }
    }

    func grammar(code: String, limit: Int = 30, offset: Int = 0) -> Single<[BJTLevelGrammarItemDTO]> {
        Single.create { observer in
            do {
                let url = try self.referenceURL(code: code, kind: "grammar", limit: limit, offset: offset)
                let request = self.session.request(url, parameters: ["limit": limit, "offset": offset])
                    .validate(statusCode: 200..<300)
                    .responseDecodable(of: [BJTLevelGrammarItemDTO].self) { response in
                        observer(response.result.mapError { $0 as Error })
                    }
                return Disposables.create { request.cancel() }
            } catch {
                observer(.failure(error))
                return Disposables.create()
            }
        }
    }

    private func referenceURL(code: String, kind: String, limit: Int, offset: Int) throws -> URL {
        guard ["J5", "J4", "J3", "J2", "J1", "J1+"].contains(code),
              (1...50).contains(limit), offset >= 0 else {
            throw AppError.invalidInput(NSLocalizedString("The level or page is invalid.", comment: ""))
        }
        return try endpoint(["levels", code, kind])
    }

    private func endpoint(_ components: [String]) throws -> URL {
        guard let url = URL(string: baseURL), let scheme = url.scheme,
              ["http", "https"].contains(scheme), url.host != nil else {
            throw URLError(.badURL)
        }
        return components.reduce(url) { $0.appendingPathComponent($1) }
    }
}
