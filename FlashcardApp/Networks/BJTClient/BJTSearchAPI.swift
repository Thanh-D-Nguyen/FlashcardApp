import Alamofire
import Foundation
import RxSwift

enum DictionarySearchType: Int, CaseIterable {
    case vocabulary, kanji, grammar, sentence
    var title: String {
        switch self {
        case .vocabulary: return NSLocalizedString("Vocabulary", comment: "")
        case .kanji: return NSLocalizedString("Kanji", comment: "")
        case .grammar: return NSLocalizedString("Grammar", comment: "")
        case .sentence: return NSLocalizedString("Sentences", comment: "")
        }
    }
    var scope: String { ["lexeme", "kanji", "grammar", "example"][rawValue] }
}

final class BJTSearchAPI {
    #if DEBUG
    nonisolated(unsafe) private static var failedOnce = false
    #endif
    static let shared = BJTSearchAPI()
    private let session: Session
    private let baseURL: String

    init(session: Session = .default, baseURL: String = EnvironmentConfig.baseUrl()) {
        self.session = session
        self.baseURL = baseURL
    }

    /// `GET /search`. The server counts bytes (2…200) and clamps `limit` to 100; results past the first page come with `offset`.
    /// Failures use `LearnerAPIError`, so offline, rate limiting and server errors read the same everywhere.
    func search(q: String, scope: DictionarySearchType, limit: Int = 30, offset: Int = 0) -> Single<[BJTSearchResultDTO]> {
        let query = q.trimmingCharacters(in: .whitespacesAndNewlines)
        // Go validates bytes: one Japanese character already meets the minimum.
        guard (DictionaryQuery.minimumBytes...DictionaryQuery.maximumBytes).contains(query.utf8.count) else {
            return .error(AppError.invalidInput(NSLocalizedString("Enter a keyword between 2 and 200 bytes.", comment: "")))
        }
        #if DEBUG
        // `-FailFirstSearch`: the first search of the run fails as if offline, so UI tests can check the error and the retry.
        if ProcessInfo.processInfo.arguments.contains("-FailFirstSearch"), !Self.failedOnce {
            Self.failedOnce = true
            return .error(LearnerAPIError.offline)
        }
        #endif
        return Single.create { observer in
            let request = self.session.request("\(self.baseURL)/search", parameters: [
                "q": query, "scope": scope.scope, "limit": String(min(max(limit, 1), 50)), "offset": String(max(offset, 0))
            ], requestModifier: { $0.timeoutInterval = 20 })
            .validate(statusCode: 200..<300)
            .responseDecodable(of: [BJTSearchResultDTO].self) { response in
                switch response.result {
                case .success(let rows): observer(.success(rows))
                case .failure(let error):
                    if case .responseValidationFailed(.unacceptableStatusCode(let status)) = error {
                        observer(.failure(BJTLearnerAPI.statusError(status, data: response.data ?? Data())))
                    } else if response.response == nil {
                        observer(.failure(BJTLearnerAPI.transportError(error)))
                    } else {
                        observer(.failure(LearnerAPIError.invalidResponse))
                    }
                }
            }
            return Disposables.create { request.cancel() }
        }
    }
}
