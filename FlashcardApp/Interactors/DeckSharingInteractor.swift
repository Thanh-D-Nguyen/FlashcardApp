import Foundation
import RxSwift

/// Sharing the learner's own account deck by link, and copying a deck someone shared. The token is passed around only in memory.
protocol DeckSharingInteractorInterface: AnyObject {
    var isSignedIn: Bool { get }
    /// The website link of the learner's deck (the same link every time until sharing is stopped).
    func shareLink(deckId: String) -> Single<URL>
    func stopSharing(deckId: String) -> Single<Void>
    /// A pasted link or token, or `nil` when it is not a share link of this app's website.
    func link(from text: String) -> DeckShareLink?
    func preview(_ link: DeckShareLink) -> Single<BJTSharedDeckPreviewDTO>
    /// Copies the shared deck into the account; never call it twice for one tap. Emits the new deck's id.
    func copyToAccount(_ link: DeckShareLink) -> Single<String>
}

final class DeckSharingInteractor: DeckSharingInteractorInterface {
    private let api: BJTDeckShareAPIInterface
    private let auth: AuthSession
    private let apiBase: () -> String
    private let language: () -> AppLanguage

    init(api: BJTDeckShareAPIInterface = BJTLearnerAPI.shared, auth: AuthSession = .shared,
         apiBase: @escaping () -> String = { EnvironmentConfig.baseUrl() }, language: @escaping () -> AppLanguage = { .current }) {
        self.api = api
        self.auth = auth
        self.apiBase = apiBase
        self.language = language
    }

    var isSignedIn: Bool { auth.bearerToken != nil }

    func shareLink(deckId: String) -> Single<URL> {
        guard let origin = DeckShareLink.webOrigin(apiBase: apiBase()) else { return .error(LearnerAPIError.server(0)) }
        let localeCode = language().rawValue
        return api.shareDeck(id: deckId).map { token in
            guard let url = DeckShareLink(token: token).url(webOrigin: origin, localeCode: localeCode) else { throw LearnerAPIError.invalidResponse }
            return url
        }
    }

    func stopSharing(deckId: String) -> Single<Void> { api.unshareDeck(id: deckId) }

    func link(from text: String) -> DeckShareLink? {
        guard let host = DeckShareLink.webOrigin(apiBase: apiBase())?.host else { return nil }
        return DeckShareLink.parse(text, webHost: host)
    }

    func preview(_ link: DeckShareLink) -> Single<BJTSharedDeckPreviewDTO> { api.sharedDeckPreview(token: link.token) }

    func copyToAccount(_ link: DeckShareLink) -> Single<String> { api.cloneSharedDeck(token: link.token).map(\.id) }
}
