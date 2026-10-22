import Foundation
import RxSwift

protocol PictureSearchInteractorInterface: AnyObject {
    var isSignedIn: Bool { get }
    /// Pictures for a search term. Errors are `LearnerAPIError`s.
    func search(_ term: String) -> Single<[PictureSuggestion]>
}

final class PictureSearchInteractor: PictureSearchInteractorInterface {
    static let resultLimit = 12

    private let api: BJTLearnerAPIInterface
    private let auth: AuthSession

    init(api: BJTLearnerAPIInterface = BJTLearnerAPI.shared, auth: AuthSession = .shared) {
        self.api = api
        self.auth = auth
    }

    var isSignedIn: Bool { auth.bearerToken != nil }

    func search(_ term: String) -> Single<[PictureSuggestion]> {
        api.searchImages(query: term, limit: Self.resultLimit)
            .map { $0.compactMap(PictureSuggestion.init) }
            .do(onError: { [auth] error in
                // The server no longer accepts the stored session: let the app notice and sign out locally.
                if case LearnerAPIError.signInRequired = error, auth.bearerToken != nil { _ = auth.refresh().subscribe() }
            })
    }
}
