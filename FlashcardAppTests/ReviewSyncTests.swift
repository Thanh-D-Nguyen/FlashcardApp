import RxSwift
import XCTest
@testable import FlashcardApp

private let now = Date(timeIntervalSince1970: 1_794_373_200)
private let cardA = "aaaaaaaa-0000-4000-8000-000000000001"
private let cardB = "aaaaaaaa-0000-4000-8000-000000000002"
private let otherDeckCard = "bbbbbbbb-0000-4000-8000-000000000009"

private func attempt(_ id: String, _ card: String, _ result: ReviewResult, minutesAgo: Double, hints: Set<ReviewHint> = []) -> ReviewAttempt {
    ReviewAttempt(id: id, cardID: card, result: result, hints: hints, contentVersion: "v", answeredAt: now.addingTimeInterval(-minutesAgo * 60))
}

final class ReviewSyncPlannerTests: XCTestCase {
    func test_onlyTheLearnersOwnRatingsOfThisDeckAreSentOldestFirstOnce() {
        let attempts = [
            attempt("run/2", cardA, .needsReview, minutesAgo: 5),
            attempt("run/1", cardA, .remembered, minutesAgo: 10),
            attempt("run/3", cardB, .remembered, minutesAgo: 3, hints: [.reading]),
            attempt("run/4", cardB, .correct, minutesAgo: 2),          // a quiz pick is not a recall rating
            attempt("run/5", cardB, .typedCorrect, minutesAgo: 2),     // neither is a typed answer
            attempt("run/6", otherDeckCard, .remembered, minutesAgo: 1),
            attempt("run/7", cardA, .remembered, minutesAgo: 60 * 24 * 31),   // older than the server accepts
            attempt("run/8", cardA, .remembered, minutesAgo: 20)
        ]
        let items = ReviewSyncPlanner.items(attempts: attempts, deckCardIds: [cardA, cardB], done: ["run/8"], now: now, maxAgeDays: 30)
        XCTAssertEqual(items.map(\.clientMutationId), ["run/1", "run/2", "run/3"])
        XCTAssertEqual(items.map(\.rating), ["good", "again", "hard"], "Help in view counts as hard, as in the local schedule")
        XCTAssertEqual(items.first?.deckCardId, cardA)
        XCTAssertEqual(items.first?.reviewedAt, BJTReviewSyncItem.timestamp(now.addingTimeInterval(-600)))
    }
}

private final class FakeSyncAPI: BJTReviewSyncAPIInterface {
    var capabilities: Single<BJTReviewSyncCapabilitiesDTO> = .just(.init(idempotentBatch: true, deckCardIdentity: true, maxItems: 2, maxAgeDays: 30))
    var answer: ([BJTReviewSyncItem]) -> Single<[BJTReviewSyncResultDTO]> = { items in
        .just(items.map { BJTReviewSyncResultDTO(clientMutationId: $0.clientMutationId, ok: true, status: "applied", error: nil) })
    }
    private(set) var batches: [[BJTReviewSyncItem]] = []
    private(set) var capabilityReads = 0
    func reviewSyncCapabilities() -> Single<BJTReviewSyncCapabilitiesDTO> { capabilityReads += 1; return capabilities }
    func syncReviews(_ items: [BJTReviewSyncItem]) -> Single<[BJTReviewSyncResultDTO]> { batches.append(items); return answer(items) }
}

private final class FakeHistory: ReviewHistoryStoreInterface {
    var stored: [ReviewAttempt] = []
    var owners: [String] = []
    func save(_ attempt: ReviewAttempt, ownerKey: String) throws -> Bool { stored.append(attempt); return true }
    func attempts(ownerKey: String, cardId: String?) -> [ReviewAttempt] { owners.append(ownerKey); return ownerKey == "account-1" ? stored : [] }
}

private final class MemoryLedger: ReviewSyncLedgerInterface {
    var ids: [String: Set<String>] = [:]
    func done(account: String) -> Set<String> { ids[account] ?? [] }
    func markDone(_ new: [String], account: String) throws { ids[account, default: []].formUnion(new) }
}

final class ReviewSyncInteractorTests: XCTestCase {
    private var api: FakeSyncAPI!
    private var history: FakeHistory!
    private var ledger: MemoryLedger!
    private var account: String? = "account-1"

    override func setUp() {
        super.setUp()
        api = FakeSyncAPI()
        history = FakeHistory()
        ledger = MemoryLedger()
        account = "account-1"
        history.stored = [attempt("r/1", cardA, .remembered, minutesAgo: 30), attempt("r/2", cardB, .needsReview, minutesAgo: 20),
                          attempt("r/3", cardA, .remembered, minutesAgo: 10)]
    }

    private func interactor() -> ReviewSyncInteractor {
        ReviewSyncInteractor(api: api, history: history, ledger: ledger, deckCardIds: { _ in [cardA, cardB] },
                             accountId: { [unowned self] in account }, now: { now })
    }

    private func value<T>(_ single: Single<T>) throws -> T {
        var outcome: Result<T, Error>?
        _ = single.subscribe(onSuccess: { outcome = .success($0) }, onFailure: { outcome = .failure($0) })
        return try XCTUnwrap(outcome).get()
    }

    func test_aServerWithoutTheIdempotentBatchGetsNothing() throws {
        api.capabilities = .error(LearnerAPIError.notFound)   // production on 2026-11-11
        let sync = interactor()
        XCTAssertFalse(try value(sync.isSupported()))
        XCTAssertThrowsError(try value(sync.send(deckId: "d")))
        XCTAssertTrue(api.batches.isEmpty)
        XCTAssertEqual(sync.pendingCount(deckId: "d"), 3, "Counted on the device only")
    }

    func test_pendingRatingsAreSentInAllowedBatchesAndNeverAgain() throws {
        api.answer = { items in
            .just(items.map { item in
                switch item.clientMutationId {
                case "r/2": return BJTReviewSyncResultDTO(clientMutationId: item.clientMutationId, ok: true, status: "superseded", error: nil)
                case "r/3": return BJTReviewSyncResultDTO(clientMutationId: item.clientMutationId, ok: true, status: "duplicate", error: nil)
                default: return BJTReviewSyncResultDTO(clientMutationId: item.clientMutationId, ok: true, status: "applied", error: nil)
                }
            })
        }
        let sync = interactor()
        let report = try value(sync.send(deckId: "d"))
        XCTAssertEqual(api.batches.map { $0.map(\.clientMutationId) }, [["r/1", "r/2"], ["r/3"]], "maxItems from the server")
        XCTAssertEqual(report, ReviewSyncReport(applied: 1, alreadyThere: 1, superseded: 1, refused: 0))
        XCTAssertEqual(sync.pendingCount(deckId: "d"), 0)
        _ = try value(sync.send(deckId: "d"))
        XCTAssertEqual(api.batches.count, 2, "Nothing left to send")
    }

    func test_aFailedBatchMarksNothingAndAServerErrorItemStaysPending() throws {
        api.answer = { _ in .error(LearnerAPIError.interrupted) }
        let sync = interactor()
        XCTAssertThrowsError(try value(sync.send(deckId: "d")))
        XCTAssertEqual(sync.pendingCount(deckId: "d"), 3, "Unknown outcome: the server de-duplicates a later send")
        api.answer = { items in
            .just(items.map { BJTReviewSyncResultDTO(clientMutationId: $0.clientMutationId, ok: false, status: nil, error: "internal error") })
        }
        let report = try value(sync.send(deckId: "d"))
        XCTAssertEqual(report.refused, 3)
        XCTAssertEqual(sync.pendingCount(deckId: "d"), 3)
    }

    func test_aGuestOrAnotherAccountHasNothingToSend() {
        account = nil
        XCTAssertEqual(interactor().pendingCount(deckId: "d"), 0)
        account = "account-2"
        XCTAssertEqual(interactor().pendingCount(deckId: "d"), 0, "Another account's ratings are not this account's")
    }
}

final class FileReviewSyncLedgerTests: XCTestCase {
    func test_theLedgerSurvivesAndKeepsAccountsApart() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileReviewSyncLedger(directory: directory).markDone(["r/1", "r/2"], account: "a")
        XCTAssertEqual(FileReviewSyncLedger(directory: directory).done(account: "a"), ["r/1", "r/2"])
        XCTAssertTrue(FileReviewSyncLedger(directory: directory).done(account: "b").isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("ReviewSync").path)
        XCTAssertFalse(files.contains { $0.contains("a.json") }, "The file name does not reveal the account")
    }
}

/// Opt-in end to end against a local backend of branch `ios/kiokoto-k10-k18` (task IOSK-18): the app's own classes send device
/// self-ratings to the real server code. Runs only when /private/tmp/kiokoto-local-k18.json (base URL, token, deck card ids of a
/// throw-away local account) exists; skipped otherwise, so ordinary runs never need a server.
final class LocalBackendReviewSyncTests: XCTestCase {
    private struct Setup: Decodable { let base: String; let token: String; let deckCardIds: [String] }

    func test_deviceRatingsAreAppliedOnceAndTheAccountKeepsItsNewerReview() throws {
        let raw = try? Data(contentsOf: URL(fileURLWithPath: "/private/tmp/kiokoto-local-k18.json"))
        guard let setup = raw.flatMap({ try? JSONDecoder().decode(Setup.self, from: $0) }), setup.deckCardIds.count >= 2 else {
            throw XCTSkip("opt-in: no local IOSK-18 backend set up")
        }
        let api = BJTLearnerAPI(baseURL: { setup.base }, token: { setup.token })
        let history = FakeHistory()
        let run = UUID().uuidString
        let now = Date()
        history.stored = [ReviewAttempt(id: "\(run)/0", cardID: setup.deckCardIds[0], result: .remembered, hints: [], contentVersion: "v", answeredAt: now.addingTimeInterval(-120)),
                          ReviewAttempt(id: "\(run)/1", cardID: setup.deckCardIds[1], result: .needsReview, hints: [], contentVersion: "v", answeredAt: now.addingTimeInterval(-60))]
        let ledger = MemoryLedger()
        let sync = ReviewSyncInteractor(api: api, history: history, ledger: ledger, deckCardIds: { _ in Set(setup.deckCardIds) },
                                        accountId: { "account-1" }, now: { now })
        func value<T>(_ single: Single<T>) throws -> T {
            var outcome: Result<T, Error>?
            let done = expectation(description: "server")
            _ = single.subscribe(onSuccess: { outcome = .success($0); done.fulfill() }, onFailure: { outcome = .failure($0); done.fulfill() })
            wait(for: [done], timeout: 20)
            return try XCTUnwrap(outcome).get()
        }
        XCTAssertTrue(try value(sync.isSupported()))
        XCTAssertEqual(try value(sync.send(deckId: "d")), ReviewSyncReport(applied: 2, alreadyThere: 0, superseded: 0, refused: 0))
        // The same ratings again (a lost ledger): the server applies nothing twice.
        ledger.ids = [:]
        XCTAssertEqual(try value(sync.send(deckId: "d")), ReviewSyncReport(applied: 0, alreadyThere: 2, superseded: 0, refused: 0))
        // An older rating than the account's latest review of the card is kept out.
        history.stored.append(ReviewAttempt(id: "\(run)/2", cardID: setup.deckCardIds[0], result: .needsReview, hints: [], contentVersion: "v",
                                            answeredAt: now.addingTimeInterval(-600)))
        XCTAssertEqual(try value(sync.send(deckId: "d")).superseded, 1)
    }
}
