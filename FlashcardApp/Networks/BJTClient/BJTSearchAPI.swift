import Alamofire
import Foundation
import RxSwift

enum DictionarySearchType: Int, CaseIterable {
    case vocabulary, kanji, grammar, sentence
    var title: String { ["Từ vựng", "Hán tự", "Ngữ pháp", "Câu"][rawValue] }
    var scope: String { ["lexeme", "kanji", "grammar", "example"][rawValue] }
}

final class BJTSearchAPI {
    static let shared = BJTSearchAPI()
    private let session: Session
    private let baseURL: String

    init(session: Session = .default, baseURL: String = EnvironmentConfig.baseUrl()) {
        self.session = session
        self.baseURL = baseURL
    }

    func search(q: String, scope: DictionarySearchType) -> Single<[BJTSearchResultDTO]> {
        let query = q.trimmingCharacters(in: .whitespacesAndNewlines)
        // Go validates bytes: one Japanese character already meets the minimum.
        guard (2...200).contains(query.utf8.count) else {
            return .error(AppError.invalidInput("Nhập từ khóa dài từ 2 đến 200 byte."))
        }
        return Single.create { observer in
            let request = self.session.request("\(self.baseURL)/search", parameters: [
                "q": query, "scope": scope.scope, "limit": "30"
            ])
            .validate(statusCode: 200..<300)
            .responseDecodable(of: [BJTSearchResultDTO].self) { response in
                observer(response.result.mapError { $0 as Error })
            }
            return Disposables.create { request.cancel() }
        }
    }
}
