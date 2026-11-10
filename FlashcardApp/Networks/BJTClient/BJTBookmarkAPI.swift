import Alamofire
import Foundation
import RxSwift

/// The learner's bookmarks on the server (`/bookmarks/...`, bearer + the API's own origin for the CSRF guard). These are the
/// account's favourites, the same list the website shows; the app keeps no second favourites system.
///
/// `POST /bookmarks/{type}/{id}` is a TOGGLE: sending it twice undoes the first call. It is therefore never retried
/// automatically, and a caller that is unsure whether it arrived reads the state again with `check` before acting.
protocol BJTBookmarkAPIInterface: AnyObject {
    func check(_ kind: DictionaryItemKind, id: String) -> Single<Bool>
    /// Flips the bookmark and returns the state the server now holds. NOT idempotent.
    func toggle(_ kind: DictionaryItemKind, id: String) -> Single<Bool>
    /// Newest first. The server has no offset: at most `limit` (1…100) rows.
    func list(_ kind: DictionaryItemKind, limit: Int) -> Single<[BJTBookmarkDTO]>
}

struct BJTBookmarkDTO: Decodable, Equatable {
    let id: String
    /// The backend id of the vocabulary entry, kanji or grammar point.
    let targetId: String
    let type: String
    let createdAt: String?
}

final class BJTBookmarkAPI: BJTBookmarkAPIInterface {
    static let shared = BJTBookmarkAPI()
    static let maximumLimit = 100

    private let learner: BJTLearnerAPI

    init(learner: BJTLearnerAPI = .shared) {
        self.learner = learner
    }

    private struct State: Decodable { let bookmarked: Bool }
    private struct Page: Decodable { let items: [BJTBookmarkDTO] }
    private struct NoBody: Encodable {}

    func check(_ kind: DictionaryItemKind, id: String) -> Single<Bool> {
        guard let type = kind.bookmarkType, UUID(uuidString: id) != nil else { return .error(LearnerAPIError.invalidRequest(nil)) }
        let state: Single<State> = learner.perform(["bookmarks", "check", type, id], method: .get, body: Optional<NoBody>.none)
        return state.map(\.bookmarked)
    }

    func toggle(_ kind: DictionaryItemKind, id: String) -> Single<Bool> {
        guard let type = kind.bookmarkType, UUID(uuidString: id) != nil else { return .error(LearnerAPIError.invalidRequest(nil)) }
        let state: Single<State> = learner.perform(["bookmarks", type, id], method: .post, body: Optional<NoBody>.none)
        return state.map(\.bookmarked)
    }

    func list(_ kind: DictionaryItemKind, limit: Int) -> Single<[BJTBookmarkDTO]> {
        let path: String
        switch kind {
        case .vocabulary: path = "words"
        case .kanji: path = "kanji"
        case .grammar: path = "grammar"
        case .sentence: return .error(LearnerAPIError.invalidRequest(nil))
        }
        let clamped = min(max(limit, 1), Self.maximumLimit)
        let page: Single<Page> = learner.perform(["bookmarks", path], method: .get, body: Optional<NoBody>.none, query: ["limit": String(clamped)])
        return page.map(\.items)
    }
}
