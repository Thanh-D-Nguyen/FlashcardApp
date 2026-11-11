import Alamofire
import Foundation
import RxSwift

/// One card of `GET /api/daily-radar/cards` (public). Production 2026-11-11: 48 cards, every one with `metadata.seed = true`
/// (written by the team, stored through the real schema), 7 `scenario_link` cards pointing at the website's `/vi/story/arcs`
/// and most others without a `targetRoute`. Only the fields the app shows are decoded; unknown keys are ignored.
struct BJTRadarCardDTO: Decodable, Equatable {
    struct Module: Decodable, Equatable {
        let moduleKey: String
        let titleVi: String?
        let titleJa: String?
    }

    /// `japaneseExpressions` comes in two shapes on production: plain strings (`"進捗はいかがでしょうか"`) and objects
    /// `{word, reading, meaning, example, exampleReading, exampleMeaning, usageNote, jlptLevel}`.
    struct Expression: Decodable, Equatable {
        let japanese: String
        let reading: String?
        let meaning: String?
        let example: String?
        let exampleMeaning: String?

        private enum Keys: String, CodingKey { case word, reading, meaning, example, exampleMeaning }

        init(japanese: String, reading: String? = nil, meaning: String? = nil, example: String? = nil, exampleMeaning: String? = nil) {
            self.japanese = japanese
            self.reading = reading
            self.meaning = meaning
            self.example = example
            self.exampleMeaning = exampleMeaning
        }

        init(from decoder: Decoder) throws {
            if let text = try? decoder.singleValueContainer().decode(String.self) {
                self.init(japanese: text)
                return
            }
            let container = try decoder.container(keyedBy: Keys.self)
            self.init(japanese: try container.decode(String.self, forKey: .word),
                      reading: try? container.decodeIfPresent(String.self, forKey: .reading),
                      meaning: try? container.decodeIfPresent(String.self, forKey: .meaning),
                      example: try? container.decodeIfPresent(String.self, forKey: .example),
                      exampleMeaning: try? container.decodeIfPresent(String.self, forKey: .exampleMeaning))
        }
    }

    /// Free-form editorial JSON: each field is read on its own, so one odd field never drops the card (or the list).
    struct Metadata: Decodable, Equatable {
        let seed: Bool?
        let comingSoon: Bool?
        let japaneseExpressions: [Expression]
        let usageNote: String?

        private enum Keys: String, CodingKey { case seed, comingSoon, japaneseExpressions, usageNote }
        private struct Skipped: Decodable { init(from decoder: Decoder) throws {} }

        init(seed: Bool?, comingSoon: Bool?, japaneseExpressions: [Expression], usageNote: String?) {
            self.seed = seed
            self.comingSoon = comingSoon
            self.japaneseExpressions = japaneseExpressions
            self.usageNote = usageNote
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            seed = try? container.decodeIfPresent(Bool.self, forKey: .seed)
            comingSoon = try? container.decodeIfPresent(Bool.self, forKey: .comingSoon)
            usageNote = try? container.decodeIfPresent(String.self, forKey: .usageNote)
            var expressions: [Expression] = []
            if var list = try? container.nestedUnkeyedContainer(forKey: .japaneseExpressions) {
                while !list.isAtEnd {
                    if let expression = try? list.decode(Expression.self) {
                        expressions.append(expression)
                    } else {
                        _ = try? list.decode(Skipped.self)
                    }
                }
            }
            japaneseExpressions = expressions
        }
    }

    let id: String
    let slug: String
    let titleVi: String
    let titleJa: String?
    let descriptionVi: String?
    let module: Module
    let moduleType: String?
    let targetRoute: String?
    let estimatedMinutes: Int?
    let levelLabel: String?
    let recommendationReasonVi: String?
    let metadata: Metadata?

    private enum Keys: String, CodingKey {
        case id, slug, titleVi, titleJa, descriptionVi, module, moduleType, targetRoute, estimatedMinutes, levelLabel, recommendationReasonVi, metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        id = try container.decode(String.self, forKey: .id)
        slug = try container.decode(String.self, forKey: .slug)
        titleVi = try container.decode(String.self, forKey: .titleVi)
        module = try container.decode(Module.self, forKey: .module)
        titleJa = try? container.decodeIfPresent(String.self, forKey: .titleJa)
        descriptionVi = try? container.decodeIfPresent(String.self, forKey: .descriptionVi)
        moduleType = try? container.decodeIfPresent(String.self, forKey: .moduleType)
        targetRoute = try? container.decodeIfPresent(String.self, forKey: .targetRoute)
        estimatedMinutes = try? container.decodeIfPresent(Int.self, forKey: .estimatedMinutes)
        levelLabel = try? container.decodeIfPresent(String.self, forKey: .levelLabel)
        recommendationReasonVi = try? container.decodeIfPresent(String.self, forKey: .recommendationReasonVi)
        metadata = try? container.decodeIfPresent(Metadata.self, forKey: .metadata)
    }
}

protocol BJTDailyRadarAPIInterface: AnyObject {
    /// Read-only and public. The server returns at most `limit` (1…100) published cards, pinned and highest priority first.
    /// The raw bytes come back with the cards so they can be kept unchanged as the offline copy.
    func cards(limit: Int) -> Single<(cards: [BJTRadarCardDTO], data: Data)>
}

/// Anonymous: no bearer and no cookies, so the answer is the same for everyone.
final class BJTDailyRadarAPI: BJTDailyRadarAPIInterface {
    static let shared = BJTDailyRadarAPI()

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

    /// A list that is not a JSON array is an invalid answer; inside it, a card that cannot be read is skipped on its own.
    static func decode(_ data: Data) throws -> [BJTRadarCardDTO] {
        do { return try JSONDecoder().decode(LossyCards.self, from: data).cards } catch { throw LearnerAPIError.invalidResponse }
    }

    private struct LossyCards: Decodable {
        private struct Skipped: Decodable { init(from decoder: Decoder) throws {} }
        let cards: [BJTRadarCardDTO]

        init(from decoder: Decoder) throws {
            var list = try decoder.unkeyedContainer()
            var cards: [BJTRadarCardDTO] = []
            while !list.isAtEnd {
                if let card = try? list.decode(BJTRadarCardDTO.self) { cards.append(card) } else { _ = try list.decode(Skipped.self) }
            }
            self.cards = cards
        }
    }

    func cards(limit: Int) -> Single<(cards: [BJTRadarCardDTO], data: Data)> {
        guard (1...100).contains(limit) else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return Single.create { [self] observer in
            guard let base = URL(string: baseURL()), let scheme = base.scheme, ["https", "http"].contains(scheme),
                  base.host != nil, base.user == nil, base.password == nil, base.query == nil, base.fragment == nil,
                  var components = URLComponents(url: base.appendingPathComponent("daily-radar").appendingPathComponent("cards"),
                                                 resolvingAgainstBaseURL: false) else {
                observer(.failure(LearnerAPIError.server(0)))
                return Disposables.create()
            }
            components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
            guard let url = components.url else {
                observer(.failure(LearnerAPIError.server(0)))
                return Disposables.create()
            }
            let request = session.request(url, method: .get, headers: ["Accept": "application/json"], requestModifier: { $0.timeoutInterval = 30 })
            request.responseData { response in
                if let error = response.error, response.response == nil {
                    return observer(.failure(BJTLearnerAPI.transportError(error)))
                }
                guard let status = response.response?.statusCode else { return observer(.failure(LearnerAPIError.invalidResponse)) }
                let data = response.data ?? Data()
                guard (200..<300).contains(status) else { return observer(.failure(BJTLearnerAPI.statusError(status, data: data))) }
                do { observer(.success((try Self.decode(data), data))) } catch { observer(.failure(error)) }
            }
            return Disposables.create { request.cancel() }
        }
    }
}
