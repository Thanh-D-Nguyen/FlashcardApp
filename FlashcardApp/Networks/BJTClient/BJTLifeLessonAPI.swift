import Alamofire
import Foundation
import RxSwift

protocol BJTLifeLessonAPIInterface: AnyObject {
    /// Today's weather lesson for a city of the server's fixed list. Read-only; safe to repeat.
    func weatherLesson(cityID: String) -> Single<BJTLifeLessonDTO>
}

/// Public read of the life lessons. It sends no token and no cookie: the lesson is the same for everyone, so a
/// session never has to reach this request. Disposing the subscription cancels the request.
final class BJTLifeLessonAPI: BJTLifeLessonAPIInterface {
    static let shared = BJTLifeLessonAPI()

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

    func weatherLesson(cityID: String) -> Single<BJTLifeLessonDTO> {
        // Only an id of the fixed list ever becomes a query value.
        guard LifeCity.city(id: cityID) != nil else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return Single.create { [self] observer in
            guard var components = URLComponents(string: baseURL() + "/life/lessons/weather"),
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
            request.responseData { response in
                observer(BJTLearnerAPI.result(of: response))
            }
            return Disposables.create { request.cancel() }
        }
    }
}
