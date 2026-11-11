import Alamofire
import RxSwift
import XCTest
@testable import FlashcardApp

private final class MemoryConsent: AnalyticsConsentStoring {
    var isSharingAllowed = false
}

private final class FakeAnalyticsAPI: BJTAnalyticsAPIInterface {
    var result: Single<Void> = .just(())
    private(set) var batches: [[AnalyticsBatchItem]] = []
    func send(_ batch: [AnalyticsBatchItem]) -> Single<Void> { batches.append(batch); return result }
}

final class AnalyticsServiceTests: XCTestCase {
    private var api: FakeAnalyticsAPI!
    private var consent: MemoryConsent!

    override func setUp() {
        super.setUp()
        api = FakeAnalyticsAPI()
        consent = MemoryConsent()
    }

    private func service() -> AnalyticsService { AnalyticsService(api: api, consent: consent, appVersion: "1.2") }

    func test_sharingIsOffUntilTheLearnerTurnsItOn() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "analytics-\(UUID().uuidString)"))
        XCTAssertFalse(UserDefaultsAnalyticsConsent(defaults: defaults).isSharingAllowed, "Off by default")
        let service = service()
        service.track(.sessionStarted)
        service.track(.lessonCompleted(levelCode: "J5"))
        service.flush()
        XCTAssertTrue(api.batches.isEmpty, "Nothing is sent, or kept for later, without consent")
        XCTAssertTrue(service.queued.isEmpty)
    }

    func test_withConsentOnlyTheFixedFieldsAreSentInOneBatch() {
        consent.isSharingAllowed = true
        let service = service()
        service.track(.sessionStarted)
        service.track(.lessonCompleted(levelCode: "J4"))
        service.track(.reviewSessionFinished(rated: 12))
        service.track(.lessonCompleted(levelCode: "../../J4"))   // not an allowed value: not sent at all
        service.flush()
        XCTAssertEqual(api.batches.count, 1)
        XCTAssertEqual(api.batches.first, [
            AnalyticsBatchItem(eventName: "ios_session_started", source: "ios-app", payload: ["schemaVersion": "1", "platform": "ios", "appVersion": "1.2"]),
            AnalyticsBatchItem(eventName: "ios_lesson_completed", source: "ios-app",
                               payload: ["schemaVersion": "1", "platform": "ios", "appVersion": "1.2", "level": "J4"]),
            AnalyticsBatchItem(eventName: "ios_review_session_finished", source: "ios-app",
                               payload: ["schemaVersion": "1", "platform": "ios", "appVersion": "1.2", "ratedBucket": "10-49"])
        ])
    }

    func test_aFullBatchIsSentAtOnceAndAFailedOneIsDroppedNotResent() {
        consent.isSharingAllowed = true
        api.result = .error(LearnerAPIError.offline)
        let service = service()
        for _ in 0..<AnalyticsService.batchSize { service.track(.sessionStarted) }
        XCTAssertEqual(api.batches.count, 1)
        XCTAssertEqual(api.batches.first?.count, 20)
        service.flush()
        XCTAssertEqual(api.batches.count, 1, "A failed batch is not sent again")
    }

    func test_turningSharingOffDropsWhatIsWaiting() {
        consent.isSharingAllowed = true
        let service = service()
        service.track(.sessionStarted)
        service.isSharingAllowed = false
        XCTAssertFalse(consent.isSharingAllowed)
        service.flush()
        XCTAssertTrue(api.batches.isEmpty)
        XCTAssertTrue(service.queued.isEmpty)
    }
}

final class BJTAnalyticsAPITests: XCTestCase {
    private var session: Session!
    private let bag = DisposeBag()

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LearnerURLProtocol.self]
        session = Session(configuration: config)
        LearnerURLProtocol.handler = nil
        LearnerURLProtocol.requests = []
    }

    override func tearDown() {
        session.session.invalidateAndCancel()
        LearnerURLProtocol.handler = nil
        super.tearDown()
    }

    func test_aBatchIsPostedAnonymouslyAsTheServerExpects() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: #"{"accepted":true}"#) }
        let api = BJTAnalyticsAPI(session: session, baseURL: { "https://api.test/api" })
        let item = AnalyticsBatchItem(eventName: "ios_session_started", source: "ios-app", payload: ["schemaVersion": "1"])
        let done = expectation(description: "sent")
        var succeeded = false
        api.send([item]).subscribe(onSuccess: { succeeded = true; done.fulfill() }, onFailure: { _ in done.fulfill() }).disposed(by: bag)
        wait(for: [done], timeout: 3)
        XCTAssertTrue(succeeded)
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.url.absoluteString, "https://api.test/api/analytics/events")
        XCTAssertNil(sent.headers["Authorization"], "Never tied to the account")
        XCTAssertNil(sent.headers["Cookie"])
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: sent.body) as? [[String: Any]])
        XCTAssertEqual(body.count, 1)
        XCTAssertEqual(Set(body[0].keys), ["eventName", "source", "payload"])
        var rejected = false
        api.send([]).subscribe(onFailure: { _ in rejected = true }).disposed(by: bag)
        XCTAssertTrue(rejected, "The server takes 1…100 events")
    }
}

final class LocalMetricsCollectorTests: XCTestCase {
    func test_reportsAreSummedOnThisDeviceOnly() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let collector = LocalMetricsCollector(directory: directory)
        XCTAssertEqual(collector.summary, .init())
        let end = Date(timeIntervalSince1970: 1_800_000_000)
        collector.record(metricReports: 1, diagnosticReports: 0, crashes: 0, hangs: 0, lastReportEnd: end)
        collector.record(metricReports: 0, diagnosticReports: 2, crashes: 1, hangs: 3, lastReportEnd: end.addingTimeInterval(-60))
        let summary = LocalMetricsCollector(directory: directory).summary
        XCTAssertEqual(summary, .init(metricReports: 1, diagnosticReports: 2, crashes: 1, hangs: 3, lastReportEnd: end))
    }
}

final class SpyAnalytics: AnalyticsTracking {
    private(set) var events: [AnalyticsEvent] = []
    func track(_ event: AnalyticsEvent) { events.append(event) }
}
