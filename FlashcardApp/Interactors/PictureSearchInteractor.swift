import Foundation
import RxSwift

protocol PictureSearchInteractorInterface: AnyObject {
    var isSignedIn: Bool { get }
    /// Pictures for a search term. Errors are `LearnerAPIError`s.
    func search(_ term: String) -> Single<[PictureSuggestion]>
    /// Registers the learner's choice with the server (which also tells the picture provider, as its terms require).
    /// Emits the server asset id. Not retried: every call creates server-side state.
    func select(_ picture: PictureSuggestion) -> Single<String>
}

final class PictureSearchInteractor: PictureSearchInteractorInterface {
    private let api: BJTLearnerAPIInterface
    private let auth: AuthSession

    init(api: BJTLearnerAPIInterface = BJTLearnerAPI.shared, auth: AuthSession = .shared) {
        self.api = api
        self.auth = auth
    }

    var isSignedIn: Bool { auth.bearerToken != nil }

    func search(_ term: String) -> Single<[PictureSuggestion]> {
        api.searchImages(query: term)
            .map { $0.compactMap(PictureSuggestion.init) }
            .do(onError: { [weak self] in self?.handleSessionError($0) })
    }

    func select(_ picture: PictureSuggestion) -> Single<String> {
        api.selectImage(handle: picture.handle)
            .do(onError: { [weak self] in self?.handleSessionError($0) })
    }

    /// The server no longer accepts the stored session: let the app notice and sign out locally.
    private func handleSessionError(_ error: Error) {
        if case LearnerAPIError.signInRequired = error, auth.bearerToken != nil { _ = auth.refresh().subscribe() }
    }
}
