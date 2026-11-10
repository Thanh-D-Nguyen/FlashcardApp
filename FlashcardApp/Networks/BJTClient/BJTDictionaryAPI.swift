import Alamofire
import Foundation
import RxSwift

/// The public, read-only detail endpoints behind the dictionary (no login). Every request carries a UUID or one kanji as
/// its only variable part, and anything else is refused before it reaches the network. Failures use `LearnerAPIError`, so
/// "offline", "not found" and "server error" read the same everywhere in the app. Disposing a subscription cancels the request.
protocol BJTDictionaryAPIInterface: AnyObject {
    func lexeme(id: String) -> Single<BJTLexemeDetailDTO>
    func grammar(id: String) -> Single<BJTGrammarDetailDTO>
    func kanji(id: String) -> Single<BJTKanjiDetailDTO>
    /// The kanji row for exactly this character, or `nil` when the dictionary has none (components such as 𠆢 often have no entry).
    func kanji(character: String) -> Single<BJTKanjiSummaryDTO?>
    func kanjiWords(kanjiID: String) -> Single<[BJTKanjiWordDTO]>
    func kanjiForWord(lexemeID: String) -> Single<[BJTKanjiReferenceDTO]>
    /// The stroke-order drawing as SVG text (KanjiVG), size- and type-checked.
    func strokeSVG(kanjiID: String) -> Single<String>
}

final class BJTDictionaryAPI: BJTDictionaryAPIInterface {
    static let shared = BJTDictionaryAPI()
    /// A KanjiVG drawing is a few KB; anything much larger is not one.
    static let maximumStrokeBytes = 128 * 1024

    private let session: Session
    private let baseURL: String

    init(session: Session = .default, baseURL: String = EnvironmentConfig.baseUrl()) {
        self.session = session
        self.baseURL = baseURL
    }

    func lexeme(id: String) -> Single<BJTLexemeDetailDTO> { json(["content", "lexemes"], id: id) }
    func grammar(id: String) -> Single<BJTGrammarDetailDTO> { json(["content", "grammar"], id: id) }
    func kanji(id: String) -> Single<BJTKanjiDetailDTO> { json(["kanji"], id: id) }

    func kanji(character: String) -> Single<BJTKanjiSummaryDTO?> {
        guard character.count == 1 else { return .error(LearnerAPIError.invalidRequest(nil)) }
        // A component that is not a kanji (a radical form such as ⺅, a stroke like ノ) has no entry: that is an answer, not an error.
        // `isIdeographic` also covers the rare CJK extension blocks that `JapaneseText` leaves out (𠆢).
        guard character.unicodeScalars.allSatisfy({ $0.properties.isIdeographic }) else { return .just(nil) }
        let rows: Single<[BJTKanjiSummaryDTO]> = fetch(["kanji"], query: ["q": character, "limit": "20"])
        return rows.map { $0.first { $0.character == character } }
    }

    func kanjiWords(kanjiID: String) -> Single<[BJTKanjiWordDTO]> { json(["kanji", "words"], id: kanjiID) }

    func kanjiForWord(lexemeID: String) -> Single<[BJTKanjiReferenceDTO]> { json(["kanji", "by-word"], id: lexemeID) }

    func strokeSVG(kanjiID: String) -> Single<String> {
        guard UUID(uuidString: kanjiID) != nil else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return Single.create { [self] observer in
            guard let url = url(["kanji", kanjiID, "stroke"]) else {
                observer(.failure(LearnerAPIError.server(0)))
                return Disposables.create()
            }
            let request = session.request(url, headers: ["Accept": "image/svg+xml"], requestModifier: { $0.timeoutInterval = 20 })
                .responseData { response in
                    if let failure = Self.failure(of: response) { return observer(.failure(failure)) }
                    let type = response.response?.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
                    guard type.hasPrefix("image/svg+xml"), let data = response.data, data.count <= Self.maximumStrokeBytes,
                          let text = String(data: data, encoding: .utf8) else {
                        return observer(.failure(LearnerAPIError.invalidResponse))
                    }
                    observer(.success(text))
                }
            return Disposables.create { request.cancel() }
        }
    }

    // MARK: Transport

    private func json<Response: Decodable>(_ path: [String], id: String) -> Single<Response> {
        // The id becomes a path segment: accept only a UUID so nothing can alter the route.
        guard UUID(uuidString: id) != nil else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return fetch(path + [id])
    }

    private func fetch<Response: Decodable>(_ path: [String], query: [String: String] = [:]) -> Single<Response> {
        Single.create { [self] observer in
            guard let url = url(path) else {
                observer(.failure(LearnerAPIError.server(0)))
                return Disposables.create()
            }
            let request = session.request(url, parameters: query.isEmpty ? nil : query, headers: ["Accept": "application/json"],
                                          requestModifier: { $0.timeoutInterval = 20 })
                .responseData { response in
                    if let failure = Self.failure(of: response) { return observer(.failure(failure)) }
                    do {
                        observer(.success(try JSONDecoder().decode(Response.self, from: response.data ?? Data())))
                    } catch {
                        observer(.failure(LearnerAPIError.invalidResponse))
                    }
                }
            return Disposables.create { request.cancel() }
        }
    }

    private func url(_ path: [String]) -> URL? {
        guard let base = URL(string: baseURL), let scheme = base.scheme, ["http", "https"].contains(scheme), base.host != nil else { return nil }
        return path.reduce(base) { $0.appendingPathComponent($1) }
    }

    /// `nil` for a 2xx answer; otherwise the error the learner can act on.
    private static func failure(of response: AFDataResponse<Data>) -> LearnerAPIError? {
        if let error = response.error, response.response == nil { return BJTLearnerAPI.transportError(error) }
        guard let status = response.response?.statusCode else { return .invalidResponse }
        guard (200..<300).contains(status) else { return BJTLearnerAPI.statusError(status, data: response.data ?? Data()) }
        return nil
    }
}
