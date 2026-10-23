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
        try realm.write { realm.deleteReviewHistory(forCards: ["gone"]) }
        XCTAssertEqual(store.attempts(ownerKey: owner, cardId: nil).map(\.cardID), ["kept"])
        XCTAssertTrue(store.attempts(ownerKey: other, cardId: nil).isEmpty)
        try realm.write { realm.deleteReviewHistory(forCards: []) }
        XCTAssertEqual(rows, 1)
    }

    // MARK: Schedules (L04)

    private let day: TimeInterval = 86_400
    private let scheduler = ReviewScheduler()

    private func schedule(card: String = "card-1", skill: ReviewSkill = .recognition, owner: String? = nil) -> ReviewSchedule? {
        store.schedules(ownerKey: owner ?? self.owner).first { $0.cardID == card && $0.skill == skill }
    }

    func test_savingAnAttemptSchedulesTheCardForThatKindOfAnswerExactlyAsTheSchedulerSays() throws {
        let saved = attempt(result: .correct, version: "v1")
        try store.save(saved, ownerKey: owner)
        let expected = scheduler.next(after: nil, grade: .good, contentVersion: "v1", at: saved.answeredAt)
        let found = try XCTUnwrap(schedule())
        XCTAssertEqual(found.state, expected)
        XCTAssertEqual(found.state.reviews, 1)
        XCTAssertNil(schedule(skill: .selfRecall), "Another kind of answer has no schedule")
    }

    func test_theScheduleSurvivesClosingAndOpeningTheStoreAgain() throws {
        try store.save(attempt(result: .remembered), ownerKey: owner)
        let before = try XCTUnwrap(schedule(skill: .selfRecall))
        try openStore()
        XCTAssertEqual(schedule(skill: .selfRecall), before)
    }

    func test_savingTheSameAttemptAgainDoesNotMoveTheDueDateAgain() throws {
        let saved = attempt("run/0", result: .correct, at: 1_700_000_000)
        try store.save(saved, ownerKey: owner)
        let first = try XCTUnwrap(schedule())
        try store.save(saved, ownerKey: owner)
        try store.save(saved, ownerKey: owner)
        XCTAssertEqual(schedule(), first)
        XCTAssertEqual(first.state.reviews, 1)
    }

    func test_aRefusedAttemptLeavesTheScheduleUntouched() throws {
        try store.save(attempt("run/0", result: .correct), ownerKey: owner)
        let before = schedule()
        XCTAssertThrowsError(try store.save(attempt("run/0", result: .incorrect), ownerKey: owner))
        XCTAssertThrowsError(try store.save(attempt("run/1", version: ""), ownerKey: owner))
        XCTAssertEqual(schedule(), before)
    }

    func test_eachKindOfAnswerHasItsOwnScheduleAndNeverMovesTheOther() throws {
        try store.save(attempt("a/0", result: .correct, at: 1_700_000_000), ownerKey: owner)
        let recognition = schedule(skill: .recognition)
        try store.save(attempt("a/1", result: .needsReview, at: 1_700_000_100), ownerKey: owner)
        XCTAssertEqual(schedule(skill: .recognition), recognition)
        XCTAssertEqual(try XCTUnwrap(schedule(skill: .selfRecall)).state.reviews, 1)
        XCTAssertEqual(store.schedules(ownerKey: owner).count, 2)
    }

    func test_anAnswerThatNeededHelpGrowsTheIntervalLessThanAnUnaidedOne() throws {
        let start: TimeInterval = 1_700_000_000
        for (card, hints) in [("plain", Set<ReviewHint>()), ("helped", [.reading])] {
            try store.save(attempt("\(card)/0", card: card, result: .remembered, hints: hints, at: start), ownerKey: owner)
            let due = try XCTUnwrap(schedule(card: card, skill: .selfRecall)).state.due
            try store.save(attempt("\(card)/1", card: card, result: .remembered, hints: hints, at: due.timeIntervalSince1970), ownerKey: owner)
        }
        let plain = try XCTUnwrap(schedule(card: "plain", skill: .selfRecall)).state
        let helped = try XCTUnwrap(schedule(card: "helped", skill: .selfRecall)).state
        XCTAssertLessThan(helped.stability, plain.stability)
    }

    func test_aLaterAnswerBuildsOnTheEarlierSchedule() throws {
        try store.save(attempt("a/0", result: .correct, at: 1_700_000_000), ownerKey: owner)
        let first = try XCTUnwrap(schedule()).state
        try store.save(attempt("a/1", result: .correct, at: first.due.timeIntervalSince1970), ownerKey: owner)
        let second = try XCTUnwrap(schedule()).state
        XCTAssertEqual(second, scheduler.next(after: first, grade: .good, contentVersion: "v1", at: first.due))
        XCTAssertEqual(second.reviews, 2)
        XCTAssertGreaterThan(second.stability, first.stability)
    }

    func test_eachLearnerAndTheGuestHaveSeparateSchedules() throws {
        try store.save(attempt("a/0", result: .correct), ownerKey: owner)
        try store.save(attempt("b/0", result: .incorrect), ownerKey: other)
        try store.save(attempt("g/0", result: .correct), ownerKey: "")
        XCTAssertEqual(store.schedules(ownerKey: owner).count, 1)
        XCTAssertEqual(try XCTUnwrap(schedule(owner: other)).state.lapses, 0)
        XCTAssertEqual(try XCTUnwrap(schedule(owner: other)).state.reviews, 1)
        XCTAssertEqual(store.schedules(ownerKey: "").count, 1)
        XCTAssertNotEqual(schedule(owner: other)?.state.stability, schedule()?.state.stability, "A wrong answer is graded apart")
    }

    func test_whatIsDueIsOldestFirstAndOnlyAsFromTheDueInstant() throws {
        try store.save(attempt("a/0", card: "later", result: .correct, at: 1_700_000_000), ownerKey: owner)
        try store.save(attempt("b/0", card: "sooner", result: .incorrect, at: 1_700_000_000), ownerKey: owner)
        let versions = ["later": "v1", "sooner": "v1"]
        let sooner = try XCTUnwrap(schedule(card: "sooner")).state.due
        let later = try XCTUnwrap(schedule(card: "later")).state.due
        XCTAssertLessThan(sooner, later)

        XCTAssertTrue(store.dueSchedules(ownerKey: owner, at: sooner.addingTimeInterval(-1), currentVersions: versions).isEmpty)
        XCTAssertEqual(store.dueSchedules(ownerKey: owner, at: sooner, currentVersions: versions).map(\.cardID), ["sooner"])
        XCTAssertEqual(store.dueSchedules(ownerKey: owner, at: later.addingTimeInterval(400 * day), currentVersions: versions).map(\.cardID),
                       ["sooner", "later"])
        XCTAssertTrue(store.dueSchedules(ownerKey: other, at: later, currentVersions: versions).isEmpty)
    }

    func test_aCardWhoseWordingChangedIsNoLongerDueAndItsNextAnswerStartsOver() throws {
        try store.save(attempt("a/0", result: .correct, version: "old", at: 1_700_000_000), ownerKey: owner)
        let due = try XCTUnwrap(schedule()).state.due
        let farLater = due.addingTimeInterval(100 * day)

        XCTAssertEqual(store.dueSchedules(ownerKey: owner, at: farLater, currentVersions: ["card-1": "old"]).count, 1)
        XCTAssertTrue(store.dueSchedules(ownerKey: owner, at: farLater, currentVersions: ["card-1": "new"]).isEmpty, "The old schedule is not about this wording")
        XCTAssertTrue(store.dueSchedules(ownerKey: owner, at: farLater, currentVersions: [:]).isEmpty, "A card that is gone is not due")

        try store.save(attempt("a/1", result: .correct, version: "new", at: farLater.timeIntervalSince1970), ownerKey: owner)
        XCTAssertEqual(try XCTUnwrap(schedule()).state.reviews, 1, "A new schedule, not a continuation")
        XCTAssertEqual(try XCTUnwrap(schedule()).state.contentVersion, "new")
        XCTAssertEqual(store.attempts(ownerKey: owner, cardId: "card-1").map(\.contentVersion), ["old", "new"], "The history keeps both")
    }

    func test_deletingCardsDeletesTheirSchedulesForEveryLearnerAndNoOthers() throws {
        try store.save(attempt("a/0", card: "gone"), ownerKey: owner)
        try store.save(attempt("b/0", card: "gone"), ownerKey: other)
        try store.save(attempt("a/1", card: "kept"), ownerKey: owner)
        let realm = RealmService.shared.realm!
        try realm.write { realm.deleteReviewHistory(forCards: ["gone"]) }
        XCTAssertEqual(store.schedules(ownerKey: owner).map(\.cardID), ["kept"])
        XCTAssertTrue(store.schedules(ownerKey: other).isEmpty)
    }

    func test_replayingTheSavedAttemptsRebuildsTheSameSchedules() throws {
        var time: TimeInterval = 1_700_000_000
        for (index, result) in [ReviewResult.correct, .correct, .incorrect, .correct].enumerated() {
            try store.save(attempt("r/\(index)", card: "card-1", result: result, at: time), ownerKey: owner)
            try store.save(attempt("s/\(index)", card: "card-2", result: .remembered, hints: index == 1 ? [.audio] : [], at: time + 60), ownerKey: owner)
            time += Double(index + 1) * 3 * day
        }
        let before = store.schedules(ownerKey: owner)
        XCTAssertEqual(before.count, 2)

        let realm = RealmService.shared.realm!
        try realm.write { realm.delete(realm.objects(RReviewState.self)) }
        XCTAssertTrue(store.schedules(ownerKey: owner).isEmpty)
        try store.rebuildSchedules(ownerKey: owner)

        XCTAssertEqual(store.schedules(ownerKey: owner), before)
    }

    func test_rebuildingOneLearnersSchedulesLeavesTheOthersAlone() throws {
        try store.save(attempt("a/0", result: .correct), ownerKey: owner)
        try store.save(attempt("b/0", result: .correct), ownerKey: other)
        let others = store.schedules(ownerKey: other)
        try store.rebuildSchedules(ownerKey: owner)
        XCTAssertEqual(store.schedules(ownerKey: other), others)
        XCTAssertEqual(store.schedules(ownerKey: owner).count, 1)
    }

    func test_anAnswerForAnEarlierWordingArrivingLateDoesNotReplaceTheNewerSchedule() throws {
        try store.save(attempt("a/0", result: .correct, version: "old", at: 1_700_000_000), ownerKey: owner)
        try store.save(attempt("a/1", result: .correct, version: "new", at: 1_700_000_000 + 10 * day), ownerKey: owner)
        let newer = try XCTUnwrap(schedule())

        // A save of an answer given to the old wording before the card was edited, arriving only now.
        XCTAssertTrue(try store.save(attempt("a/late", result: .incorrect, version: "old", at: 1_700_000_000 + 5 * day), ownerKey: owner))

        XCTAssertEqual(schedule(), newer, "The schedule of the current wording stays")
        XCTAssertEqual(store.attempts(ownerKey: owner, cardId: "card-1").count, 3, "The answer itself is still kept")
        let before = store.schedules(ownerKey: owner)
        try store.rebuildSchedules(ownerKey: owner)
        XCTAssertEqual(store.schedules(ownerKey: owner), before, "A replay by time agrees")
    }

    func test_aScheduleMadeByAnotherAlgorithmIsNotDue() throws {
        try store.save(attempt("a/0", result: .incorrect, at: 1_700_000_000), ownerKey: owner)
        let realm = RealmService.shared.realm!
        try realm.write { realm.objects(RReviewState.self).first?.algorithm = "some-other-algorithm" }
        let far = Date(timeIntervalSince1970: 1_700_000_000 + 400 * day)
        XCTAssertTrue(store.dueSchedules(ownerKey: owner, at: far, currentVersions: ["card-1": "v1"]).isEmpty)
        XCTAssertEqual(store.schedules(ownerKey: owner).count, 1, "It is still listed, which is why callers ask for what is due")
    }

    func test_schedulesAreBuiltForAttemptsThatHaveNoneAndLeftAloneWhenInPlace() throws {
        try store.save(attempt("a/0", card: "card-1", result: .correct, at: 1_700_000_000), ownerKey: owner)
        try store.save(attempt("a/1", card: "card-2", result: .incorrect, at: 1_700_000_100), ownerKey: owner)
        let inPlace = store.schedules(ownerKey: owner)
        let realm = RealmService.shared.realm!

        try store.ensureSchedules(ownerKey: owner)
        XCTAssertEqual(store.schedules(ownerKey: owner), inPlace, "Nothing to do when they exist")

        try realm.write { realm.delete(realm.objects(RReviewState.self)) }   // as after an upgrade from before schedules existed
        try store.ensureSchedules(ownerKey: owner)
        XCTAssertEqual(store.schedules(ownerKey: owner), inPlace)

        try realm.write { realm.objects(RReviewState.self).forEach { $0.algorithm = "old-algorithm" } }
        try store.ensureSchedules(ownerKey: owner)
        XCTAssertEqual(store.schedules(ownerKey: owner), inPlace, "Schedules of another algorithm are rebuilt")
    }

    func test_ensuringSchedulesForALearnerWithNoAttemptsCreatesNothing() throws {
        try store.ensureSchedules(ownerKey: owner)
        try store.save(attempt("g/0"), ownerKey: "")
        try store.ensureSchedules(ownerKey: owner)
        XCTAssertTrue(store.schedules(ownerKey: owner).isEmpty)
        XCTAssertEqual(store.schedules(ownerKey: "").count, 1, "And never touches another learner's")
    }
}
