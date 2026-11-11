import Alamofire
import Foundation
import MetricKit
import RxSwift

/// The only events the app can send, with the only fields each may carry. No user or device identifier, no token, no words looked up,
/// no deck or card text, no free text: every value is one of a fixed set or a small count.
enum AnalyticsEvent: Equatable {
    /// The app came to the foreground.
    case sessionStarted
    /// A lesson was finished on this device (`levelCode` is one of J5…J1).
    case lessonCompleted(levelCode: String)
    /// A review of account cards ended; `rated` is how many ratings the server confirmed, in buckets.
    case reviewSessionFinished(rated: Int)

    static let schemaVersion = 1

    var name: String {
        switch self {
        case .sessionStarted: return "ios_session_started"
        case .lessonCompleted: return "ios_lesson_completed"
        case .reviewSessionFinished: return "ios_review_session_finished"
        }
    }

    /// `nil` when a field is not in its allowed set: such an event is not sent at all.
    func payload(appVersion: String) -> [String: String]? {
        var payload = ["schemaVersion": String(Self.schemaVersion), "platform": "ios", "appVersion": appVersion]
        switch self {
        case .sessionStarted:
            break
        case .lessonCompleted(let level):
            guard BJTLessonAPI.levelCodes.contains(level) else { return nil }
            payload["level"] = level
        case .reviewSessionFinished(let rated):
            guard rated >= 0 else { return nil }
            payload["ratedBucket"] = rated == 0 ? "0" : rated < 10 ? "1-9" : rated < 50 ? "10-49" : "50+"
        }
        return payload
    }
}

protocol AnalyticsTracking: AnyObject {
    func track(_ event: AnalyticsEvent)
}

protocol AnalyticsConsentStoring: AnyObject {
    /// Off until the learner turns it on in Settings.
    var isSharingAllowed: Bool { get set }
}

final class UserDefaultsAnalyticsConsent: AnalyticsConsentStoring {
    static let shared = UserDefaultsAnalyticsConsent()
    static let key = "analytics.shareUsage"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var isSharingAllowed: Bool {
        get { defaults.bool(forKey: Self.key) }
        set { defaults.set(newValue, forKey: Self.key) }
    }
}

struct AnalyticsBatchItem: Encodable, Equatable {
    let eventName: String
    let source: String
    let payload: [String: String]
}

protocol BJTAnalyticsAPIInterface: AnyObject {
    /// `POST /api/analytics/events` (public, 1…100 events, answers `{"accepted":true}`). Not idempotent: a batch is sent once.
    func send(_ batch: [AnalyticsBatchItem]) -> Single<Void>
}

/// Anonymous on purpose: no bearer, no cookie, so an event can never be tied to the account.
final class BJTAnalyticsAPI: BJTAnalyticsAPIInterface {
    static let shared = BJTAnalyticsAPI()
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

    private struct Accepted: Decodable { let accepted: Bool }

    func send(_ batch: [AnalyticsBatchItem]) -> Single<Void> {
        guard (1...100).contains(batch.count) else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return Single.create { [self] observer in
            guard let base = URL(string: baseURL()), let scheme = base.scheme, ["https", "http"].contains(scheme), base.host != nil else {
                observer(.failure(LearnerAPIError.server(0)))
                return Disposables.create()
            }
            let url = base.appendingPathComponent("analytics").appendingPathComponent("events")
            let request = session.request(url, method: .post, parameters: batch, encoder: JSONParameterEncoder.default,
                                          headers: ["Accept": "application/json"], requestModifier: { $0.timeoutInterval = 20 })
            request.responseData { response in
                let result: Result<Accepted, Error> = BJTLearnerAPI.result(of: response)
                switch result {
                case .success(let answer): observer(answer.accepted ? .success(()) : .failure(LearnerAPIError.invalidResponse))
                case .failure(let error): observer(.failure(error))
                }
            }
            return Disposables.create { request.cancel() }
        }
    }
}

/// Usage counts, only with the learner's consent. Events are kept in memory (nothing is written to disk), sent in one batch when
/// 20 are waiting or the app leaves the foreground, and dropped — never resent — if that send fails, so no event is counted twice.
/// Turning sharing off drops whatever is waiting.
final class AnalyticsService: AnalyticsTracking {
    static let shared = AnalyticsService()
    static let source = "ios-app"
    static let batchSize = 20
    static let maxQueued = 100

    private let api: BJTAnalyticsAPIInterface
    private let consent: AnalyticsConsentStoring
    private let appVersion: String
    private let disposeBag = DisposeBag()
    private(set) var queued: [AnalyticsBatchItem] = []

    init(api: BJTAnalyticsAPIInterface = BJTAnalyticsAPI.shared, consent: AnalyticsConsentStoring = UserDefaultsAnalyticsConsent.shared,
         appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0") {
        self.api = api
        self.consent = consent
        self.appVersion = appVersion
    }

    var isSharingAllowed: Bool {
        get { consent.isSharingAllowed }
        set {
            consent.isSharingAllowed = newValue
            if !newValue { queued.removeAll() }
        }
    }

    func track(_ event: AnalyticsEvent) {
        guard Thread.isMainThread else { return DispatchQueue.main.async { self.track(event) } }
        guard consent.isSharingAllowed, let payload = event.payload(appVersion: appVersion) else { return }
        queued.append(AnalyticsBatchItem(eventName: event.name, source: Self.source, payload: payload))
        if queued.count > Self.maxQueued { queued.removeFirst(queued.count - Self.maxQueued) }
        if queued.count >= Self.batchSize { flush() }
    }

    func flush() {
        guard Thread.isMainThread else { return DispatchQueue.main.async { self.flush() } }
        guard consent.isSharingAllowed else { return queued.removeAll() }
        guard !queued.isEmpty else { return }
        let batch = queued
        queued.removeAll()
        api.send(batch).subscribe(onFailure: { error in
            logger.error("Sending \(batch.count) usage events failed; they are dropped: \(error.localizedDescription)")
        }).disposed(by: disposeBag)
    }
}

/// MetricKit's daily performance and diagnostic reports, kept on this device only (a small summary file); nothing is sent.
/// MetricKit delivers reports on real devices only, about once a day.
final class LocalMetricsCollector: NSObject, MXMetricManagerSubscriber {
    static let shared = LocalMetricsCollector()

    struct Summary: Codable, Equatable {
        var metricReports = 0
        var diagnosticReports = 0
        var crashes = 0
        var hangs = 0
        var lastReportEnd: Date?
    }

    private let url: URL

    init(directory: URL? = nil) {
        let base = directory ?? (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
        url = base.appendingPathComponent("Metrics", isDirectory: true).appendingPathComponent("summary.json")
    }

    func start() { MXMetricManager.shared.add(self) }

    var summary: Summary {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Summary.self, from: $0) } ?? Summary()
    }

    func record(metricReports: Int, diagnosticReports: Int, crashes: Int, hangs: Int, lastReportEnd: Date?) {
        var current = summary
        current.metricReports += metricReports
        current.diagnosticReports += diagnosticReports
        current.crashes += crashes
        current.hangs += hangs
        if let lastReportEnd { current.lastReportEnd = max(current.lastReportEnd ?? lastReportEnd, lastReportEnd) }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(current).write(to: url, options: [.atomic])
        } catch {
            logger.error("Saving the local metrics summary failed: \(error.localizedDescription)")
        }
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        record(metricReports: payloads.count, diagnosticReports: 0, crashes: 0, hangs: 0, lastReportEnd: payloads.map(\.timeStampEnd).max())
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        record(metricReports: 0, diagnosticReports: payloads.count,
               crashes: payloads.reduce(0) { $0 + ($1.crashDiagnostics?.count ?? 0) },
               hangs: payloads.reduce(0) { $0 + ($1.hangDiagnostics?.count ?? 0) },
               lastReportEnd: payloads.map(\.timeStampEnd).max())
    }
}
