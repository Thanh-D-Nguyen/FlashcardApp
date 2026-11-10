import Alamofire
import Foundation
import RxSwift

protocol BJTMagazineAPIInterface: AnyObject {
    /// One page of articles, newest first. `kind` nil means every kind. Read-only; safe to repeat.
    func articles(kind: MagazineKind?, page: Int, limit: Int) -> Single<BJTMagazineListDTO>
    /// One article with its vocabulary and quiz. Read-only; safe to repeat.
    func article(slug: String) -> Single<BJTMagazineArticleDTO>
}

/// Public read of the magazine. It sends no token and no cookie: the articles are the same for everyone, so a session
/// never has to reach these requests. Disposing the subscription cancels the request.
final class BJTMagazineAPI: BJTMagazineAPIInterface {
    static let shared = BJTMagazineAPI()

    static let pageSizeRange = 1...50
    fileprivate static let slugPattern = try! NSRegularExpression(pattern: "^[A-Za-z0-9][A-Za-z0-9_.-]{0,199}$")

    private let session: Session
    private let baseURL: () -> String

    init(session: Session? = nil, baseURL: @escaping () -> String = { EnvironmentConfig.baseUrl() }) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        self.session = session ?? Session(configuration: configuration)
        self.baseURL = baseURL
    }

    func articles(kind: MagazineKind?, page: Int, limit: Int) -> Single<BJTMagazineListDTO> {
        guard page >= 1, Self.pageSizeRange.contains(limit) else { return .error(LearnerAPIError.invalidRequest(nil)) }
        var query = [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "limit", value: String(limit))]
        if let kind { query.append(URLQueryItem(name: "kind", value: kind.apiValue)) }
        return get(path: ["magazine"], query: query)
    }

    func article(slug: String) -> Single<BJTMagazineArticleDTO> {
        // The slug becomes a path segment: accept only the characters the server generates so nothing can alter the route.
        let range = NSRange(slug.startIndex..., in: slug)
        guard Self.slugPattern.firstMatch(in: slug, range: range) != nil else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return get(path: ["magazine", slug], query: [])
    }

    fileprivate func get<Response: Decodable>(path: [String], query: [URLQueryItem]) -> Single<Response> {
        Single.create { [self] observer in
            guard let base = URL(string: baseURL()), let scheme = base.scheme, ["https", "http"].contains(scheme), base.host != nil,
                  base.user == nil, base.password == nil, base.query == nil, base.fragment == nil,
                  var components = URLComponents(url: path.reduce(base) { $0.appendingPathComponent($1) }, resolvingAgainstBaseURL: false) else {
                observer(.failure(LearnerAPIError.server(0)))
                return Disposables.create()
            }
            if !query.isEmpty { components.queryItems = query }
            guard let url = components.url else {
                observer(.failure(LearnerAPIError.server(0)))
                return Disposables.create()
            }
            let request = session.request(url, headers: ["Accept": "application/json"], requestModifier: { $0.timeoutInterval = 15 })
            request.responseData { response in
                observer(BJTLearnerAPI.result(of: response))
            }
            return Disposables.create { request.cancel() }
        }
    }
}

protocol BJTLotoAPIInterface: AnyObject {
    /// The Loto articles (both games), newest draw first. Read-only; safe to repeat.
    func lotoArticles(page: Int, limit: Int) -> Single<BJTMagazineListDTO>
    /// One Loto article with its number sets. Read-only; safe to repeat.
    func lotoArticle(slug: String) -> Single<BJTLotoArticleDTO>
}

extension BJTMagazineAPI: BJTLotoAPIInterface {
    func lotoArticles(page: Int, limit: Int) -> Single<BJTMagazineListDTO> {
        guard page >= 1, Self.pageSizeRange.contains(limit) else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return get(path: ["magazine"], query: [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "limit", value: String(limit)),
                                               URLQueryItem(name: "kind", value: "loto")])
    }

    func lotoArticle(slug: String) -> Single<BJTLotoArticleDTO> {
        let range = NSRange(slug.startIndex..., in: slug)
        guard Self.slugPattern.firstMatch(in: slug, range: range) != nil else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return get(path: ["magazine", slug], query: [])
    }
}
