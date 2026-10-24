import Alamofire
import Foundation
import RxSwift

protocol BJTLifeFeedAPIInterface: AnyObject {
    /// The life hub for a city. Read-only; safe to repeat. `LearnerAPIError.notFound` means the server does not offer a feed.
    func feed(cityID: String) -> Single<BJTLifeFeedDTO>
}

/// Public read of the life feed: no token, no cookie, only an id of the fixed city list. Disposing cancels the request.
final class BJTLifeFeedAPI: BJTLifeFeedAPIInterface {
    static let shared = BJTLifeFeedAPI()

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

    func feed(cityID: String) -> Single<BJTLifeFeedDTO> {
        guard LifeCity.city(id: cityID) != nil else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return Single.create { [self] observer in
            guard var components = URLComponents(string: baseURL() + "/life/feed"),
                  components.scheme == "https" || components.scheme == "http", components.host != nil else {
                observer(.failure(LearnerAPIError.server(0)))
                return Disposables.create()
            }
            components.queryItems = [URLQueryItem(name: "city", value: cityID)]
            guard let url = components.url else {
                observer(.failure(LearnerAPIError.server(0)))
                return Disposables.create()
            }
            let request = session.request(url, headers: ["Accept": "application/json"], requestModifier: { $0.timeoutInterval = 15 })
            request.responseData { response in observer(BJTLearnerAPI.result(of: response)) }
            return Disposables.create { request.cancel() }
        }
    }
}
