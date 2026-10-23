import RealmSwift
import XCTest
@testable import FlashcardApp

/// The learner's answered questions against a real Realm: what is stored, for whom, that a retry never counts twice,
/// and that nothing is left behind or lost.
final class ReviewHistoryStoreTests: XCTestCase {
    private var store: RealmReviewHistoryStore!
    private var folder: URL!
    private var fileURL: URL!
    private let owner = "11111111-1111-1111-1111-111111111111"
    private let other = "22222222-2222-2222-2222-222222222222"

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("flash_card.realm")
        try openStore()
    }

    override func tearDownWithError() throws {
        store = nil
        RealmService.shared.realm = nil
        try FileManager.default.removeItem(at: folder)
    }

    /// Opens the on-disk store as the app does, releasing a previous handle first so the file is really reopened.
    private func openStore() throws {
        store = nil
        RealmService.shared.realm = nil
        RealmService.shared.realm = try Realm(configuration: RealmService.makeConfiguration(fileURL: fileURL))
        store = RealmReviewHistoryStore()
    }

    private var rows: Int { RealmService.shared.realm.objects(RReviewAttempt.self).count }

    private func attempt(_ id: String = "run-1/0", card: String = "card-1", result: ReviewResult = .correct,
                         hints: Set<ReviewHint> = [], version: String = "v1", at seconds: TimeInterval = 1_700_000_000) -> ReviewAttempt {
        ReviewAttempt(id: id, cardID: card, result: result, hints: hints, contentVersion: version,
                      answeredAt: Date(timeIntervalSince1970: seconds))
    }

    // MARK: Saving and reading back

    func test_anAttemptComesBackWithEveryFieldAfterTheStoreIsClosedAndOpenedAgain() throws {
        let saved = attempt(result: .needsReview, hints: [.reading, .audio], version: "abc", at: 1_700_000_000.123456)
        XCTAssertTrue(try store.save(saved, ownerKey: owner))

        try openStore()

        let read = store.attempts(ownerKey: owner, cardId: nil)
        XCTAssertEqual(read.count, 1)
        XCTAssertEqual(read[0].id, saved.id)
        XCTAssertEqual(read[0].cardID, "card-1")
        XCTAssertEqual(read[0].result, .needsReview)
        XCTAssertEqual(read[0].skill, .selfRecall)
        XCTAssertEqual(read[0].hints, [.reading, .audio])
        XCTAssertEqual(read[0].contentVersion, "abc")
        XCTAssertEqual(read[0].answeredAt.timeIntervalSince1970, saved.answeredAt.timeIntervalSince1970, accuracy: 0.001)
    }

    func test_everyResultIsStoredAndKeepsItsSkill() throws {
        let results: [ReviewResult] = [.correct, .incorrect, .remembered, .needsReview]
        for (index, result) in results.enumerated() {
            try store.save(attempt("run-1/\(index)", result: result, at: 1_700_000_000 + Double(index)), ownerKey: owner)
        }
        XCTAssertEqual(store.attempts(ownerKey: owner, cardId: nil).map(\.result), results)
        XCTAssertEqual(store.attempts(ownerKey: owner, cardId: nil).map(\.skill), [.recognition, .recognition, .selfRecall, .selfRecall])
    }

    func test_attemptsComeOldestAnswerFirstAndCanBeLimitedToACard() throws {
        try store.save(attempt("run-1/2", card: "card-1", at: 1_700_000_300), ownerKey: owner)
        try store.save(attempt("run-1/0", card: "card-2", at: 1_700_000_100), ownerKey: owner)
        try store.save(attempt("run-1/1", card: "card-1", at: 1_700_000_200), ownerKey: owner)

        XCTAssertEqual(store.attempts(ownerKey: owner, cardId: nil).map(\.id), ["run-1/0", "run-1/1", "run-1/2"])
        XCTAssertEqual(store.attempts(ownerKey: owner, cardId: "card-1").map(\.id), ["run-1/1", "run-1/2"])
        XCTAssertTrue(store.attempts(ownerKey: owner, cardId: "nope").isEmpty)
    }

    func test_whatIsReadIsACopyThatSurvivesTheRecordBeingDeleted() throws {
        try store.save(attempt(), ownerKey: owner)
        let read = store.attempts(ownerKey: owner, cardId: nil)
        let realm = RealmService.shared.realm!
        try realm.write { realm.delete(realm.objects(RReviewAttempt.self)) }
        XCTAssertEqual(rows, 0)
        XCTAssertEqual(read.first?.id, "run-1/0", "Values, never live Realm objects, cross the store boundary")
    }

    // MARK: Retries and conflicts

    func test_savingTheSameAttemptAgainKeepsOneRecord() throws {
        let saved = attempt(hints: [.reading], at: 1_700_000_000.987654321)
        XCTAssertTrue(try store.save(saved, ownerKey: owner))
        XCTAssertFalse(try store.save(saved, ownerKey: owner), "A retry is recognised even though Realm rounds the time")
        XCTAssertFalse(try store.save(saved, ownerKey: owner))
        XCTAssertEqual(rows, 1)
    }

    func test_aRetryAfterTheStoreWasReopenedStillKeepsOneRecord() throws {
        let saved = attempt()
        try store.save(saved, ownerKey: owner)
        try openStore()
        XCTAssertFalse(try store.save(saved, ownerKey: owner))
        XCTAssertEqual(rows, 1)
    }

    func test_aDifferentAttemptUnderAUsedIdIsRefusedAndTheSavedOneIsKept() throws {
        try store.save(attempt(result: .correct), ownerKey: owner)
        XCTAssertThrowsError(try store.save(attempt(result: .incorrect), ownerKey: owner)) {
            XCTAssertEqual($0 as? ReviewHistoryError, .conflictingAttempt)
        }
        XCTAssertThrowsError(try store.save(attempt(hints: [.audio]), ownerKey: owner))
        XCTAssertThrowsError(try store.save(attempt(version: "other"), ownerKey: owner))
        XCTAssertEqual(store.attempts(ownerKey: owner, cardId: nil).map(\.result), [.correct])
        XCTAssertEqual(rows, 1)
    }

    func test_anAttemptThatCannotBeUnderstoodLaterIsRefusedAndNothingIsWritten() {
        for invalid in [attempt("", card: "card-1"), attempt("run/0", card: ""), attempt("run/0", version: "")] {
            XCTAssertThrowsError(try store.save(invalid, ownerKey: owner)) {
                XCTAssertEqual($0 as? ReviewHistoryError, .invalidAttempt)
            }
        }
        XCTAssertEqual(rows, 0)
    }

    // MARK: Whose history it is

    func test_eachLearnerSeesOnlyTheirOwnAttempts() throws {
        try store.save(attempt("run-1/0", result: .correct), ownerKey: owner)
        try store.save(attempt("run-2/0", result: .incorrect), ownerKey: other)
        XCTAssertEqual(store.attempts(ownerKey: owner, cardId: nil).map(\.result), [.correct])
        XCTAssertEqual(store.attempts(ownerKey: other, cardId: nil).map(\.result), [.incorrect])
    }

    func test_theGuestHistoryStaysSeparateAndIsStillThereAfterAnAccountSignsInAndOut() throws {
        try store.save(attempt("guest-run/0"), ownerKey: "")
        try store.save(attempt("account-run/0"), ownerKey: owner)

        XCTAssertEqual(store.attempts(ownerKey: owner, cardId: nil).map(\.id), ["account-run/0"], "Not merged into the account")
        XCTAssertEqual(store.attempts(ownerKey: "", cardId: nil).map(\.id), ["guest-run/0"], "Kept for the guest")
        try openStore()
        XCTAssertEqual(store.attempts(ownerKey: "", cardId: nil).map(\.id), ["guest-run/0"])
    }

    func test_theSameAttemptIdForTwoLearnersIsTwoRecords() throws {
        XCTAssertTrue(try store.save(attempt("run/0"), ownerKey: owner))
        XCTAssertTrue(try store.save(attempt("run/0", result: .incorrect), ownerKey: other))
        XCTAssertEqual(rows, 2)
        XCTAssertEqual(store.attempts(ownerKey: owner, cardId: nil).first?.result, .correct)
    }

    // MARK: Cards that go away or change

    func test_deletingCardsRemovesTheirAttemptsForEveryLearnerAndNoOthers() throws {
        try store.save(attempt("a/0", card: "gone"), ownerKey: owner)
        try store.save(attempt("b/0", card: "gone"), ownerKey: other)
        try store.save(attempt("a/1", card: "kept"), ownerKey: owner)
        let realm = RealmService.shared.realm!
        try realm.write { realm.deleteReviewAttempts(forCards: ["gone"]) }
        XCTAssertEqual(store.attempts(ownerKey: owner, cardId: nil).map(\.cardID), ["kept"])
        XCTAssertTrue(store.attempts(ownerKey: other, cardId: nil).isEmpty)
        try realm.write { realm.deleteReviewAttempts(forCards: []) }
        XCTAssertEqual(rows, 1)
    }
}
