import RxSwift
import XCTest
@testable import FlashcardApp

private final class FakePrivacyAPI: BJTPrivacyAPIInterface {
    var listResults: [Single<[BJTPrivacyRequestDTO]>] = []
    var createResult: Single<BJTPrivacyRequestDTO> = .error(LearnerAPIError.offline)
    var downloadResult: Single<Data> = .just(Data("{}".utf8))
    private(set) var lists = 0
    private(set) var creates = 0
    private(set) var downloads: [String] = []

    func privacyRequests() -> Single<[BJTPrivacyRequestDTO]> {
        lists += 1
        return listResults.isEmpty ? .just([]) : listResults.removeFirst()
    }
    func requestDataExport() -> Single<BJTPrivacyRequestDTO> { creates += 1; return createResult }
    func downloadDataExport(requestId: String) -> Single<Data> { downloads.append(requestId); return downloadResult }
}

private final class FakeExportWireframe: DataExportWireframeInterface {
    private(set) var shared: [URL] = []
    func share(file: URL) { shared.append(file) }
}

private final class SpyExportView: DataExportViewInterface {
    var renders: [DataExportState] = []
    func render(_ state: DataExportState) { renders.append(state) }
}

private let requestId = "1c38d361-dbd1-478f-b4ba-a08d87e1565c"

/// Rows in the shape production returned for the test account (2026-11-11); ids kept, user id dropped.
private func row(_ status: String, kind: String = "export", payload: String? = nil, created: String = "2026-11-11T07:36:10.203898Z") -> BJTPrivacyRequestDTO {
    BJTPrivacyRequestDTO(id: requestId, kind: kind, status: status, resultPayload: payload, createdAt: created, completedAt: nil)
}

final class DataExportPresenterTests: XCTestCase {
    private var api: FakePrivacyAPI!
    private var wireframe: FakeExportWireframe!
    private var view: SpyExportView!
    private var written: [(Data, String)] = []
    private let now = Date(timeIntervalSince1970: 1_794_373_200)   // 2026-11-11 05:00 UTC

    override func setUp() {
        super.setUp()
        api = FakePrivacyAPI()
        wireframe = FakeExportWireframe()
        view = SpyExportView()
        written = []
    }

    private func start() -> DataExportPresenter {
        let presenter = DataExportPresenter(api: api, wireframe: wireframe, now: { [now] in now }, locale: { Locale(identifier: "en_US") },
                                            writeFile: { [unowned self] data, name in
                                                written.append((data, name))
                                                return URL(fileURLWithPath: "/tmp/" + name)
                                            })
        presenter.view = view
        presenter.viewDidLoad()
        settle()
        return presenter
    }

    private func settle() {
        let drained = expectation(description: "main queue")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 2)
    }

    private var state: DataExportState { view.renders.last ?? DataExportState() }

    func test_withNoRequestTheLearnerCanAskOnceAndThenOnlyCheckAgain() {
        api.createResult = .just(row("pending"))
        let presenter = start()
        XCTAssertEqual(state.phase, .loaded)
        XCTAssertEqual(state.action, .request)
        XCTAssertFalse(state.message.isEmpty, "It says an administrator prepares it")
        presenter.performAction()
        settle()
        XCTAssertEqual(api.creates, 1)
        XCTAssertEqual(state.action, .refresh, "An open request is not requested again")
        XCTAssertNotNil(state.notice)
        presenter.performAction()
        settle()
        XCTAssertEqual(api.creates, 1)
        XCTAssertEqual(api.lists, 2, "Checking again only reads")
    }

    func test_aSecondTapWhileSendingSendsNothing() {
        let pending = PublishSubject<BJTPrivacyRequestDTO>()
        api.createResult = pending.take(1).asSingle()
        let presenter = start()
        presenter.performAction()
        presenter.performAction()
        XCTAssertTrue(state.isWorking)
        XCTAssertEqual(api.creates, 1)
    }

    func test_anUnknownOutcomeIsCheckedByReadingNotBySendingAgain() {
        api.listResults = [.just([]), .just([row("pending")])]
        api.createResult = .error(LearnerAPIError.interrupted)
        let presenter = start()
        presenter.performAction()
        settle()
        settle()   // the list is read from inside the failed send's callback
        XCTAssertEqual(api.creates, 1, "Never resent by itself")
        XCTAssertEqual(api.lists, 2)
        XCTAssertEqual(state.action, .refresh, "The list shows it arrived")
        XCTAssertNotNil(state.notice)
    }

    func test_aFailedSendKeepsTheRequestOfferedWithoutRetrying() {
        api.createResult = .error(LearnerAPIError.offline)
        let presenter = start()
        presenter.performAction()
        settle()
        XCTAssertEqual(api.creates, 1)
        XCTAssertEqual(state.action, .request)
        XCTAssertEqual(state.notice, LearnerAPIError.offline.errorDescription)
        XCTAssertFalse(state.isWorking)
    }

    func test_anOpenRequestOffersOnlyToCheckAgain() {
        for status in ["pending", "processing"] {
            api.listResults = [.just([row(status)])]
            _ = start()
            XCTAssertEqual(state.action, .refresh, status)
            XCTAssertTrue(state.message.contains("Nov 11, 2026"), state.message)
        }
    }

    func test_aReadyCopyIsDownloadedAndHandedToTheShareSheet() {
        api.listResults = [.just([row("completed", payload: #"{"reason":"ok","expiresAt":"2026-11-18T07:00:00Z"}"#)])]
        api.downloadResult = .just(Data(#"{"profile":{}}"#.utf8))
        let presenter = start()
        XCTAssertEqual(state.action, .download(requestId: requestId))
        XCTAssertTrue(state.message.contains("Nov 18, 2026"), state.message)
        presenter.performAction()
        settle()
        XCTAssertEqual(api.downloads, [requestId])
        XCTAssertEqual(written.first?.0, Data(#"{"profile":{}}"#.utf8), "The server's file, unchanged")
        XCTAssertEqual(wireframe.shared.count, 1)
    }

    func test_anExpiredOrFailedRequestCanBeAskedAgain() {
        api.listResults = [.just([row("completed", payload: #"{"expiresAt":"2026-11-01T00:00:00Z"}"#)])]
        _ = start()
        XCTAssertEqual(state.action, .request)
        api.listResults = [.just([row("failed")])]
        _ = start()
        XCTAssertEqual(state.action, .request)
    }

    func test_aCopyGoneOnTheServerReadsTheListAgain() {
        api.listResults = [.just([row("completed", payload: #"{"expiresAt":"2026-11-18T07:00:00Z"}"#)]),
                           .just([row("completed", payload: #"{"expiresAt":"2026-11-10T07:00:00Z"}"#)])]
        api.downloadResult = .error(LearnerAPIError.server(410))
        let presenter = start()
        presenter.performAction()
        settle()
        settle()   // the list is read from inside the failed download's callback
        XCTAssertEqual(api.lists, 2)
        XCTAssertEqual(state.action, .request)
        XCTAssertTrue(wireframe.shared.isEmpty)
    }

    func test_anUnreadableListAssumesNothingAndCanBeRetried() {
        api.listResults = [.error(LearnerAPIError.offline), .just([row("pending", kind: "delete")])]
        let presenter = start()
        XCTAssertEqual(state.phase, .failed)
        XCTAssertNil(state.action)
        presenter.retry()
        settle()
        XCTAssertEqual(state.phase, .loaded)
        XCTAssertEqual(state.action, .request, "An account deletion request is not an export")
    }
}
