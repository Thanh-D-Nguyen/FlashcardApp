import Foundation
import RxSwift

/// What the learner can do on the data export screen.
enum DataExportAction: Equatable {
    case request
    /// Ask the server again (the request is being prepared, or the outcome of a send is unknown).
    case refresh
    case download(requestId: String)
}

struct DataExportState: Equatable {
    enum Phase: Equatable {
        case loading
        case loaded
        /// The list could not be read: nothing is assumed about existing requests.
        case failed
    }

    var phase: Phase = .loading
    var title = ""
    var message = ""
    var action: DataExportAction?
    var actionTitle: String?
    /// A request or a download is running: the button is disabled.
    var isWorking = false
    /// The outcome of the last action (sent, could not be sent, unknown).
    var notice: String?
}

protocol DataExportViewInterface: AnyObject {
    func render(_ state: DataExportState)
}

protocol DataExportPresenterInterface: AnyObject {
    func viewDidLoad()
    func performAction()
    func retry()
}

protocol DataExportWireframeInterface: AnyObject {
    /// Offers the file to the learner (share sheet: save to Files, AirDrop…).
    func share(file: URL)
}

/// The learner asks for a copy of their account data; an administrator prepares it (production has no automatic export), and the
/// file is downloaded here once ready. A new request is offered only when none is open, the request is sent once per tap and never
/// again by itself, and an unknown outcome is resolved by reading the list, not by sending again.
final class DataExportPresenter: DataExportPresenterInterface {
    private let api: BJTPrivacyAPIInterface
    private let wireframe: DataExportWireframeInterface
    private let now: () -> Date
    private let locale: () -> Locale
    private let writeFile: (Data, String) throws -> URL
    /// Reading the list and the learner's action are kept apart: an action whose answer arrives at once starts a list read from its
    /// callback, before its own subscription is stored, and must not cancel that read.
    private let listRequest = SerialDisposable()
    private let actionRequest = SerialDisposable()
    weak var view: DataExportViewInterface?

    private(set) var state = DataExportState()

    init(api: BJTPrivacyAPIInterface = BJTLearnerAPI.shared, wireframe: DataExportWireframeInterface,
         now: @escaping () -> Date = Date.init, locale: @escaping () -> Locale = { AppLanguage.current.locale },
         writeFile: @escaping (Data, String) throws -> URL = DataExportPresenter.temporaryFile) {
        self.api = api
        self.wireframe = wireframe
        self.now = now
        self.locale = locale
        self.writeFile = writeFile
    }

    deinit {
        listRequest.dispose()
        actionRequest.dispose()
    }

    /// The export goes to a private temporary file that the share sheet hands on; it is not kept by the app.
    static func temporaryFile(_ data: Data, name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DataExport", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    private static func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    private func publish() { view?.render(state) }

    func viewDidLoad() { load(notice: nil) }

    func retry() { load(notice: nil) }

    private func load(notice: String?) {
        state.phase = state.phase == .loaded ? .loaded : .loading
        state.isWorking = true
        state.notice = notice
        publish()
        listRequest.disposable = api.privacyRequests()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] rows in
                guard let self else { return }
                self.apply(rows, notice: notice)
            }, onFailure: { [weak self] error in
                guard let self else { return }
                self.state = DataExportState(phase: .failed, title: Self.text("Couldn't check your data requests"),
                                             message: Self.message(error), action: nil, actionTitle: nil, isWorking: false, notice: nil)
                self.publish()
            })
    }

    func performAction() {
        guard !state.isWorking, let action = state.action else { return }
        switch action {
        case .refresh: load(notice: nil)
        case .request: send()
        case .download(let id): download(id)
        }
    }

    private func send() {
        state.isWorking = true
        state.notice = nil
        publish()
        actionRequest.disposable = api.requestDataExport()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] row in
                guard let self else { return }
                self.apply([row], notice: Self.text("Request sent. An administrator will prepare your copy."))
            }, onFailure: { [weak self] error in
                guard let self else { return }
                if case LearnerAPIError.interrupted = error {
                    // It may have arrived: read the list instead of sending a second request.
                    return self.load(notice: Self.text("We couldn't confirm the request, so we checked your requests again."))
                }
                self.state.isWorking = false
                self.state.notice = Self.message(error)
                self.publish()
            })
    }

    private func download(_ id: String) {
        state.isWorking = true
        state.notice = nil
        publish()
        actionRequest.disposable = api.downloadDataExport(requestId: id)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] data in
                guard let self else { return }
                self.state.isWorking = false
                do {
                    let url = try self.writeFile(data, "kiokoto-data-export-\(id.prefix(8)).json")
                    self.publish()
                    self.wireframe.share(file: url)
                } catch {
                    self.state.notice = Self.text("The copy could not be saved on this device.")
                    self.publish()
                }
            }, onFailure: { [weak self] error in
                guard let self else { return }
                switch error as? LearnerAPIError {
                case .notFound?, .server(410)?:
                    // Expired or withdrawn: the list says what is possible now.
                    self.load(notice: Self.text("This copy is no longer available."))
                default:
                    self.state.isWorking = false
                    self.state.notice = Self.message(error)
                    self.publish()
                }
            })
    }

    // MARK: State from the server's rows

    private func apply(_ rows: [BJTPrivacyRequestDTO], notice: String?) {
        var next = DataExportState(phase: .loaded, isWorking: false, notice: notice)
        let exports = rows.filter { $0.kind == "export" }.sorted { $0.createdAt > $1.createdAt }
        guard let latest = exports.first else {
            next.title = Self.text("Get a copy of your data")
            next.message = Self.text("You can ask for a copy of the data your Kiokoto account keeps. An administrator prepares it by hand, which can take several days. When it is ready you can download it here.")
            next.action = .request
            next.actionTitle = Self.text("Request a copy")
            return show(next)
        }
        let requested = Self.day(latest.createdAt, locale: locale())
        switch latest.status {
        case "pending", "processing":
            next.title = Self.text("Your copy is being prepared")
            next.message = String(format: Self.text("Requested on %@. An administrator prepares the copy; this can take several days. Come back here to download it."), requested)
            next.action = .refresh
            next.actionTitle = Self.text("Check again")
        case "completed":
            if let expiry = Self.expiry(of: latest), expiry > now() {
                next.title = Self.text("Your copy is ready")
                next.message = String(format: Self.text("You can download it until %@. The file is in JSON format."), Self.day(expiry, locale: locale()))
                next.action = .download(requestId: latest.id)
                next.actionTitle = Self.text("Download")
            } else {
                next.title = Self.text("Your last copy has expired")
                next.message = Self.text("Copies can be downloaded for a limited time. You can ask for a new one.")
                next.action = .request
                next.actionTitle = Self.text("Request a new copy")
            }
        default:
            next.title = Self.text("Your last request was not completed")
            next.message = Self.text("The administrator could not prepare it. You can ask again, or contact support.")
            next.action = .request
            next.actionTitle = Self.text("Request a copy")
        }
        show(next)
    }

    private func show(_ next: DataExportState) {
        state = next
        publish()
    }

    static func expiry(of row: BJTPrivacyRequestDTO) -> Date? {
        guard let raw = row.resultPayload?.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
              let text = payload["expiresAt"] as? String else { return nil }
        return parse(text)
    }

    static func parse(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    private static func day(_ text: String, locale: Locale) -> String {
        parse(text).map { day($0, locale: locale) } ?? text
    }

    private static func day(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func message(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
