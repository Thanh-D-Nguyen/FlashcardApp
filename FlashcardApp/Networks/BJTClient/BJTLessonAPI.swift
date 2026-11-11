import Alamofire
import Foundation
import RxSwift

protocol BJTLessonAPIInterface: AnyObject {
    /// Read-only and public; safe to repeat. The server returns every lesson of the level in order (84 for J5), unpaginated.
    func lessons(levelCode: String) -> Single<[BJTLessonSummaryDTO]>
    /// Read-only and public; safe to repeat.
    func lesson(slug: String) -> Single<BJTLessonDetailDTO>
    /// The lesson together with the exact bytes the server sent, so an offline copy can keep them unchanged.
    func lessonPayload(slug: String) -> Single<BJTLessonPayload>
}

struct BJTLessonPayload {
    let lesson: BJTLessonDetailDTO
    let data: Data
}

/// The structured lessons of a level. Reads are anonymous: no bearer, no cookies, so the answer never depends on who is
/// signed in (and `isCompleted` is always `false`; the account's progress is not read here). Failures use `LearnerAPIError`
/// so the status mapping stays the same as the other learner calls.
final class BJTLessonAPI: BJTLessonAPIInterface {
    static let shared = BJTLessonAPI()

    /// `GET /levels/{code}/lessons` answers 404 for `J1+`, so only these five levels are valid here.
    static let levelCodes = ["J5", "J4", "J3", "J2", "J1"]

    private let session: Session
    private let baseURL: () -> String

    init(session: Session? = nil, baseURL: @escaping () -> String = { EnvironmentConfig.baseUrl() }) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        self.session = session ?? Session(configuration: configuration)
        self.baseURL = baseURL
    }

    func lessons(levelCode: String) -> Single<[BJTLessonSummaryDTO]> {
        guard Self.levelCodes.contains(levelCode) else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return get(["levels", levelCode, "lessons"])
    }

    func lesson(slug: String) -> Single<BJTLessonDetailDTO> {
        lessonPayload(slug: slug).map(\.lesson)
    }

    func lessonPayload(slug: String) -> Single<BJTLessonPayload> {
        guard Self.isValid(slug: slug) else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return getData(["levels", "lessons", slug]).map { data in
            guard let lesson = try? JSONDecoder().decode(BJTLessonDetailDTO.self, from: data) else { throw LearnerAPIError.invalidResponse }
            return BJTLessonPayload(lesson: lesson, data: data)
        }
    }

    /// Lowercase letters, digits and hyphens (`j5-01-greetings-intro`, `j5-w01-review`). Anything else could change the route.
    static func isValid(slug: String) -> Bool {
        guard (1...128).contains(slug.utf8.count), let first = slug.unicodeScalars.first else { return false }
        let allowed = { (s: Unicode.Scalar) in ("a"..."z").contains(s) || ("0"..."9").contains(s) }
        return allowed(first) && slug.unicodeScalars.allSatisfy { allowed($0) || $0 == "-" }
    }

    private func get<Response: Decodable>(_ path: [String]) -> Single<Response> {
        getData(path).map { data in
            guard let value = try? JSONDecoder().decode(Response.self, from: data) else { throw LearnerAPIError.invalidResponse }
            return value
        }
    }

    /// The body of a 2xx answer. Status and transport failures use the same mapping as the other learner calls.
    private func getData(_ path: [String]) -> Single<Data> {
        Single.create { [self] observer in
            guard let base = URL(string: baseURL()), let scheme = base.scheme, ["https", "http"].contains(scheme),
                  base.host != nil, base.user == nil, base.password == nil, base.query == nil, base.fragment == nil else {
                observer(.failure(LearnerAPIError.server(0)))
                return Disposables.create()
            }
            let url = path.reduce(base) { $0.appendingPathComponent($1) }
            let request = session.request(url, method: .get, headers: ["Accept": "application/json"],
                                          requestModifier: { $0.timeoutInterval = 30 })
            request.responseData { response in
                if let error = response.error, response.response == nil {
                    return observer(.failure(BJTLearnerAPI.transportError(error)))
                }
                guard let status = response.response?.statusCode else { return observer(.failure(LearnerAPIError.invalidResponse)) }
                let data = response.data ?? Data()
                guard (200..<300).contains(status) else { return observer(.failure(BJTLearnerAPI.statusError(status, data: data))) }
                observer(.success(data))
            }
            return Disposables.create { request.cancel() }
        }
    }
}

protocol BJTLessonProgressAPIInterface: AnyObject {
    /// Marks a lesson complete on the account. The server inserts with `ON CONFLICT DO NOTHING`, so repeating it is harmless,
    /// but the app still never retries on its own: after `.interrupted` the caller must tell the learner the result is unknown.
    func markLessonCompleted(slug: String) -> Single<Void>
}

extension BJTLearnerAPI: BJTLessonProgressAPIInterface {
    private struct CompletedBody: Encodable { let completed: Bool }

    /// Only `completed: true` is exposed: un-completing a lesson is not a learner action in this app.
    func markLessonCompleted(slug: String) -> Single<Void> {
        guard BJTLessonAPI.isValid(slug: slug) else { return .error(LearnerAPIError.invalidRequest(nil)) }
        let response: Single<BJTLessonProgressDTO> = perform(["levels", "lessons", slug, "progress"], method: .put,
                                                               body: CompletedBody(completed: true))
        return response.map { progress in
            // The server echoes the stored value; anything else means the write did not do what was asked.
            guard progress.isCompleted else { throw LearnerAPIError.invalidResponse }
        }
    }
}
