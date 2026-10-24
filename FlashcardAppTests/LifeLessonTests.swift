import Alamofire
import RxSwift
import XCTest
@testable import FlashcardApp

/// The lesson contract (a payload captured from the real backend), its validation, the answer comparison, the city choice
/// and the public request. Everything the lesson screens rely on is decided here, not in the views.
final class LifeLessonTests: XCTestCase {

    // MARK: Contract

    func test_theRealPayloadBecomesALessonWithFactsAndTemplateTextKeptApart() throws {
        let lesson = try LifeLessonFixtures.lesson()
        XCTAssertEqual(lesson.id, "weather:tokyo:2026-10-24")
        XCTAssertEqual(lesson.cityID, "tokyo")
        XCTAssertEqual(lesson.titleJapanese, "今日の東京の天気")
        XCTAssertEqual(lesson.facts?.date, "2026-10-24")
        XCTAssertEqual(lesson.facts?.temperatureMaxC, 16, "15.8 is shown as 16, like the lesson sentence")
        XCTAssertEqual(lesson.facts?.temperatureMinC, 14)
        XCTAssertEqual(lesson.facts?.precipitationProbabilityPercent, 80)
        XCTAssertEqual(lesson.source.providerName, "Open-Meteo")
        XCTAssertEqual(lesson.source.licenseStatus, .nonCommercialDevOnly)
        XCTAssertEqual(lesson.source.freshness, .live)
        XCTAssertEqual(lesson.source.url?.absoluteString, "https://open-meteo.com/")
        XCTAssertEqual(lesson.sentences.map(\.id), ["weather", "temperature", "precipitation", "umbrella"])
        XCTAssertEqual(lesson.sentences.map(\.isAdvice), [false, false, false, true], "Only the umbrella line is template advice")
        XCTAssertEqual(lesson.sentences[0].japanese, "今日の東京の天気は雨です。")
        XCTAssertEqual(lesson.vocabulary.first?.id, "weather:rain")
        XCTAssertEqual(lesson.exercises.count, 2)
    }

    func test_timesKeepTheirOffsetAndTheMomentTheServerMeant() throws {
        let lesson = try LifeLessonFixtures.lesson()
        // observedAt "2026-10-24T08:15:00+09:00" is 23:15:00 UTC on the 23rd.
        XCTAssertEqual(lesson.source.observedAt.timeIntervalSince1970, 1_792_797_300)
        XCTAssertGreaterThan(lesson.source.expiresAt, lesson.source.fetchedAt, "fractional seconds were parsed")
        XCTAssertNotNil(LifeLessonInteractor.parseDate("2026-10-24T08:28:52.262537+09:00"))
        XCTAssertNotNil(LifeLessonInteractor.parseDate("2026-10-24T08:28:52+09:00"))
        XCTAssertNil(LifeLessonInteractor.parseDate("2026-10-24 08:28"))
    }

    func test_aLessonForAnotherCityThanAskedIsRefused() throws {
        let dto = try LifeLessonFixtures.dto()
        XCTAssertThrowsError(try LifeLessonInteractor.lesson(from: dto, requestedCityID: "osaka")) {
            XCTAssertEqual($0 as? LearnerAPIError, .invalidResponse, "A late answer for the previous city must not be shown as the new one")
        }
    }

    func test_aPayloadThatBreaksTheContractIsInvalid() throws {
        let breakages: [(String, (inout [String: Any]) -> Void)] = [
            ("another schema version", { $0["schemaVersion"] = 2 }),
            ("another topic", { $0["topic"] = "news" }),
            ("text not made by the template", { var l = $0["lesson"] as! [String: Any]; l["generatedBy"] = "llm"; $0["lesson"] = l }),
            ("a source link that is not https", { var s = $0["source"] as! [String: Any]; s["url"] = "http://open-meteo.com/"; $0["source"] = s }),
            ("an unknown licence status", { var s = $0["source"] as! [String: Any]; s["licenseStatus"] = "free-for-all"; $0["source"] = s }),
            ("an unreadable time", { var s = $0["source"] as! [String: Any]; s["observedAt"] = "yesterday"; $0["source"] = s }),
            ("no sentences", { var l = $0["lesson"] as! [String: Any]; l["sentences"] = []; $0["lesson"] = l }),
            ("no exercises", { var l = $0["lesson"] as! [String: Any]; l["exercises"] = []; $0["lesson"] = l }),
            ("a recall exercise without an answer", { var l = $0["lesson"] as! [String: Any]; var e = l["exercises"] as! [[String: Any]]; e[0]["acceptedAnswers"] = []; l["exercises"] = e; $0["lesson"] = l }),
            ("a correct choice that is not offered", { var l = $0["lesson"] as! [String: Any]; var e = l["exercises"] as! [[String: Any]]; e[1]["correctChoiceId"] = "z"; l["exercises"] = e; $0["lesson"] = l }),
            ("an unknown exercise kind", { var l = $0["lesson"] as! [String: Any]; var e = l["exercises"] as! [[String: Any]]; e[0]["kind"] = "speak"; l["exercises"] = e; $0["lesson"] = l })
        ]
        for (name, change) in breakages {
            XCTAssertThrowsError(try LifeLessonFixtures.lesson(change), name) {
                XCTAssertEqual($0 as? LearnerAPIError, .invalidResponse, name)
            }
        }
    }

    func test_anImpossibleTemperatureIsInvalidInsteadOfTrapping() throws {
        for huge in [1e300, -1e300, 1000.0] {
            XCTAssertThrowsError(try LifeLessonFixtures.lesson { var f = $0["facts"] as! [String: Any]; f["temperatureMaxC"] = huge; $0["facts"] = f }) {
                XCTAssertEqual($0 as? LearnerAPIError, .invalidResponse, "\(huge)")
            }
        }
    }

    func test_aMissingRequiredFieldFailsToDecode() throws {
        XCTAssertThrowsError(try LifeLessonFixtures.dto { $0.removeValue(forKey: "facts") })
    }

    func test_optionalFactsMayBeAbsent() throws {
        let lesson = try LifeLessonFixtures.lesson { var f = $0["facts"] as! [String: Any]; f.removeValue(forKey: "precipitationProbabilityMaxPercent"); $0["facts"] = f }
        XCTAssertNil(lesson.facts?.precipitationProbabilityPercent)
    }

    func test_theTextFollowsTheAppLanguageAndJapaneseShowsEnglish() {
        let text = LifeText(vi: "mưa", en: "rain")
        XCTAssertEqual(text.resolved(.vietnamese), "mưa")
        XCTAssertEqual(text.resolved(.english), "rain")
        XCTAssertEqual(text.resolved(.japanese), "rain", "The server has no third language")
    }

    // MARK: Answers

    func test_aTypedAnswerMatchesAnyAcceptedSpellingAfterTidying() {
        let accepted = ["雨", "あめ"]
        for answer in ["雨", "あめ", " あめ ", "雨。", "あ め"] {
            XCTAssertTrue(LifeAnswerChecker.isCorrect(answer, accepted: accepted), answer)
        }
        for answer in ["", "   ", "ゆき", "雪", "あ", "あめです"] {
            XCTAssertFalse(LifeAnswerChecker.isCorrect(answer, accepted: accepted), answer)
        }
        XCTAssertTrue(LifeAnswerChecker.isCorrect("ＡＢ", accepted: ["ab"]), "Full-width letters fold to ASCII")
        XCTAssertFalse(LifeAnswerChecker.isCorrect("。", accepted: ["。"]), "A bare full stop is not an answer")
    }

    // MARK: Cities and preferences

    func test_theCitiesAreExactlyTheServersFixedList() {
        XCTAssertEqual(LifeCity.all.map(\.id), ["tokyo", "yokohama", "osaka", "nagoya", "kyoto", "sapporo", "sendai", "hiroshima", "fukuoka", "naha"])
        XCTAssertEqual(LifeCity.city(id: "tokyo")?.displayName(.japanese), "東京")
        XCTAssertEqual(LifeCity.city(id: "tokyo")?.displayName(.vietnamese), "Tokyo")
        XCTAssertNil(LifeCity.city(id: "paris"))
    }

    func test_theChosenCityIsPerLearnerAndOnlyFromTheList() {
        let defaults = UserDefaults(suiteName: "life-prefs-\(UUID().uuidString)")!
        let preferences = UserDefaultsLifeLessonPreferences(defaults: defaults)
        XCTAssertEqual(preferences.selectedCityID(ownerKey: "a"), "tokyo", "Tokyo until the learner chooses")
        preferences.setSelectedCityID("osaka", ownerKey: "a")
        XCTAssertEqual(preferences.selectedCityID(ownerKey: "a"), "osaka")
        XCTAssertEqual(preferences.selectedCityID(ownerKey: "b"), "tokyo", "Another learner keeps their own choice")
        preferences.setSelectedCityID("../etc", ownerKey: "a")
        XCTAssertEqual(preferences.selectedCityID(ownerKey: "a"), "osaka", "A value outside the list is ignored")
        defaults.set("atlantis", forKey: "com.flashcardapp.life.city.c")
        XCTAssertEqual(preferences.selectedCityID(ownerKey: "c"), "tokyo", "A stored value outside the list falls back")
    }
}

/// The public request: no session, no cookie, only an id of the fixed list.
final class BJTLifeLessonAPITests: XCTestCase {
    private var session: Session!
    private var api: BJTLifeLessonAPI!
    private var bag: DisposeBag!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LearnerURLProtocol.self]
        session = Session(configuration: config)
        api = BJTLifeLessonAPI(session: session, baseURL: { "https://api.test/api" })
        bag = DisposeBag()
        LearnerURLProtocol.handler = nil
        LearnerURLProtocol.onStop = nil
        LearnerURLProtocol.requests = []
    }

    override func tearDown() {
        bag = nil
        session.session.invalidateAndCancel()
        LearnerURLProtocol.handler = nil
        LearnerURLProtocol.onStop = nil
        super.tearDown()
    }

    private func result(_ single: Single<BJTLifeLessonDTO>) -> Result<BJTLifeLessonDTO, Error> {
        var outcome: Result<BJTLifeLessonDTO, Error>?
        let done = expectation(description: "request")
        single.subscribe(onSuccess: { outcome = .success($0); done.fulfill() }, onFailure: { outcome = .failure($0); done.fulfill() }).disposed(by: bag)
        wait(for: [done], timeout: 3)
        return outcome ?? .failure(LearnerAPIError.invalidResponse)
    }

    func test_itReadsTheLessonWithoutSendingAnyCredentials() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: LifeLessonFixtures.tokyoJSON) }
        let dto = try result(api.weatherLesson(cityID: "tokyo")).get()
        XCTAssertEqual(dto.id, "weather:tokyo:2026-10-24")
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.method, "GET")
        XCTAssertEqual(sent.url.path, "/api/life/lessons/weather")
        XCTAssertEqual(URLComponents(url: sent.url, resolvingAgainstBaseURL: false)?.queryItems, [URLQueryItem(name: "city", value: "tokyo")])
        XCTAssertNil(sent.headers["Authorization"], "The lesson is public: no token ever goes with it")
        XCTAssertNil(sent.headers["Cookie"])
        XCTAssertEqual(sent.headers["Accept"], "application/json")
    }

    func test_aCityOutsideTheListNeverReachesTheNetwork() {
        let outcome = result(api.weatherLesson(cityID: "35.6,139.7"))
        guard case .failure(let error) = outcome else { return XCTFail("expected a failure") }
        XCTAssertEqual(error as? LearnerAPIError, .invalidRequest(nil))
        XCTAssertTrue(LearnerURLProtocol.requests.isEmpty)
    }

    func test_statusesMapToTheLearnerErrors() {
        for (status, expected) in [(404, LearnerAPIError.notFound), (400, .invalidRequest(nil)), (429, .rateLimited),
                                   (503, .serviceUnavailable("weather lesson unavailable")), (500, .server(500))] {
            LearnerURLProtocol.handler = { _, proto in proto.respond(status: status, json: #"{"error":"weather lesson unavailable"}"#) }
            guard case .failure(let error) = result(api.weatherLesson(cityID: "tokyo")) else { return XCTFail("\(status) should fail") }
            XCTAssertEqual(error as? LearnerAPIError, expected, "HTTP \(status)")
        }
    }

    func test_aBodyThatIsNotALessonIsAnInvalidResponse() {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: #"{"hello":"world"}"#) }
        guard case .failure(let error) = result(api.weatherLesson(cityID: "tokyo")) else { return XCTFail("expected a failure") }
        XCTAssertEqual(error as? LearnerAPIError, .invalidResponse)
    }

    func test_noConnectionIsOffline() {
        LearnerURLProtocol.handler = { _, proto in proto.fail(URLError(.notConnectedToInternet)) }
        guard case .failure(let error) = result(api.weatherLesson(cityID: "tokyo")) else { return XCTFail("expected a failure") }
        XCTAssertEqual(error as? LearnerAPIError, .offline)
    }

    func test_disposingTheSubscriptionCancelsTheRequest() {
        let stopped = expectation(description: "request cancelled")
        LearnerURLProtocol.handler = { _, _ in }   // never answers
        LearnerURLProtocol.onStop = { stopped.fulfill() }
        let subscription = api.weatherLesson(cityID: "tokyo").subscribe(onSuccess: { _ in }, onFailure: { _ in })
        let started = expectation(description: "request started")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { started.fulfill() }
        wait(for: [started], timeout: 2)
        subscription.dispose()
        wait(for: [stopped], timeout: 3)
    }
}
