//
//  ReviewHistoryStore.swift
//  FlashcardApp
//
//  The learner's answered questions, in Realm on this device, per account (`ownerKey` is the signed-in account id, or ""
//  with nobody signed in; guest history stays when an account signs in and is never merged into it). Nothing here is
//  synced to the website. Main thread only, like the other Realm repositories; callers receive value copies.
//

import Foundation
import RealmSwift

enum ReviewHistoryError: Error, Equatable {
    /// The attempt lacks an id, a card or a content version, so it could not be told apart or understood later.
    case invalidAttempt
    /// An attempt with this id was already saved with different content: a retry must send the same attempt.
    case conflictingAttempt
}

protocol ReviewHistoryStoreInterface: AnyObject {
    /// Saves the attempt for this learner in one transaction. Saving the same attempt again changes nothing and returns
    /// false; a different attempt under a used id is refused and the saved one is kept.
    @discardableResult func save(_ attempt: ReviewAttempt, ownerKey: String) throws -> Bool
    /// The learner's saved attempts, oldest answer first, optionally for one card only.
    func attempts(ownerKey: String, cardId: String?) -> [ReviewAttempt]
}

/// When each card is due again for each kind of answer: what the schedule says, never a claim about what is learned.
struct ReviewSchedule: Equatable {
    let cardID: String
    let skill: ReviewSkill
    let state: ReviewState
}

protocol ReviewScheduleStoreInterface: AnyObject {
    /// Every schedule of this learner.
    func schedules(ownerKey: String) -> [ReviewSchedule]
    /// The schedules due at `date`, oldest due first, only for the wording each card has now: a schedule made for an earlier
    /// wording is not due. Cards missing from `currentVersions` (for example deleted ones) are left out.
    func dueSchedules(ownerKey: String, at date: Date, currentVersions: [String: String]) -> [ReviewSchedule]
    /// The learner's attempts answered at or after `date`, oldest first.
    func attempts(ownerKey: String, answeredSince date: Date) -> [ReviewAttempt]
    /// Rebuilds this learner's schedules by replaying their saved attempts in the order of their answer times. A replay by time
    /// is not an exact restore when answers were saved out of time order (a clock set back): it follows the times, not the saves.
    func rebuildSchedules(ownerKey: String) throws
    /// Builds the schedules when this learner has saved attempts but none, or schedules made by another algorithm (an app
    /// update, or attempts saved before schedules existed). Does nothing when the schedules are in place. Call it once when
    /// the schedules are first needed.
    func ensureSchedules(ownerKey: String) throws
}

final class RealmReviewHistoryStore: ReviewHistoryStoreInterface, ReviewScheduleStoreInterface {
    private var realm: Realm { RealmService.shared.realm }
    private let scheduler: ReviewScheduler

    init(scheduler: ReviewScheduler = ReviewScheduler()) {
        self.scheduler = scheduler
    }

    func schedules(ownerKey: String) -> [ReviewSchedule] {
        realm.objects(RReviewState.self).filter("ownerKey == %@", ownerKey)
            .sorted(by: [SortDescriptor(keyPath: "due"), SortDescriptor(keyPath: "recordId")])
            .compactMap(Self.schedule(of:))
    }

    func dueSchedules(ownerKey: String, at date: Date, currentVersions: [String: String]) -> [ReviewSchedule] {
        realm.objects(RReviewState.self).filter("ownerKey == %@ AND due <= %@ AND algorithm == %@", ownerKey, date, FSRSParameters.algorithm)
            .sorted(by: [SortDescriptor(keyPath: "due"), SortDescriptor(keyPath: "recordId")])
            .compactMap(Self.schedule(of:))
            .filter { currentVersions[$0.cardID] == $0.state.contentVersion }
    }

    func attempts(ownerKey: String, answeredSince date: Date) -> [ReviewAttempt] {
        realm.objects(RReviewAttempt.self).filter("ownerKey == %@ AND answeredAt >= %@", ownerKey, date)
            .sorted(by: [SortDescriptor(keyPath: "answeredAt"), SortDescriptor(keyPath: "attemptId")])
            .compactMap(Self.value(of:))
    }

    func ensureSchedules(ownerKey: String) throws {
        let attempted = Set(attempts(ownerKey: ownerKey, cardId: nil).map { "\($0.cardID)|\($0.skill.rawValue)" })
        guard !attempted.isEmpty else { return }
        let states = realm.objects(RReviewState.self).filter("ownerKey == %@", ownerKey)
        let scheduled = Set(states.map { "\($0.cardId)|\($0.skill)" })
        if attempted != scheduled || !states.filter("algorithm != %@", FSRSParameters.algorithm).isEmpty {
            try rebuildSchedules(ownerKey: ownerKey)
        }
    }

    func rebuildSchedules(ownerKey: String) throws {
        let attempts = attempts(ownerKey: ownerKey, cardId: nil)
        try realm.write {
            realm.delete(realm.objects(RReviewState.self).filter("ownerKey == %@", ownerKey))
            attempts.forEach { updateSchedule(for: $0, ownerKey: ownerKey) }
        }
    }

    /// Realm keeps dates with nanosecond precision and a `Date` is a double, so a saved time can come back a hair
    /// different; a retry is the same attempt when its time is the same to the millisecond.
    private static let timeTolerance: TimeInterval = 0.001

    /// `ownerKey` is an account UUID or "" and attempt ids are `<run UUID>/<n>`: neither contains "|", so the pair is unambiguous.
    private static func recordId(ownerKey: String, attemptId: String) -> String { "\(ownerKey)|\(attemptId)" }

    @discardableResult
    func save(_ attempt: ReviewAttempt, ownerKey: String) throws -> Bool {
        guard !attempt.id.isEmpty, !attempt.cardID.isEmpty, !attempt.contentVersion.isEmpty else { throw ReviewHistoryError.invalidAttempt }
        let recordId = Self.recordId(ownerKey: ownerKey, attemptId: attempt.id)
        var inserted = false
        // The lookup is part of the write transaction, so two saves of one id can never both pass it. Realm raises an
        // uncatchable exception on a duplicate primary key, hence the lookup before `add`. Throwing cancels the transaction.
        try realm.write {
            if let existing = realm.object(ofType: RReviewAttempt.self, forPrimaryKey: recordId) {
                guard Self.matches(existing, attempt) else { throw ReviewHistoryError.conflictingAttempt }
                return
            }
            let record = RReviewAttempt()
            record.recordId = recordId
            record.attemptId = attempt.id
            record.ownerKey = ownerKey
            record.cardId = attempt.cardID
            record.contentVersion = attempt.contentVersion
            record.result = attempt.result.rawValue
            record.hints.append(objectsIn: attempt.hints.map(\.rawValue).sorted())
            record.answeredAt = attempt.answeredAt
            realm.add(record)
            // The schedule moves with the attempt in this same transaction, once: a retry never reaches this line.
            updateSchedule(for: attempt, ownerKey: ownerKey)
            inserted = true
        }
        return inserted
    }

    func attempts(ownerKey: String, cardId: String?) -> [ReviewAttempt] {
        var records = realm.objects(RReviewAttempt.self).filter("ownerKey == %@", ownerKey)
        if let cardId { records = records.filter("cardId == %@", cardId) }
        let ordered = records.sorted(by: [SortDescriptor(keyPath: "answeredAt"), SortDescriptor(keyPath: "attemptId")])
        // A result written by a newer version of the app is not understood here; it is skipped, never guessed at.
        return ordered.compactMap(Self.value(of:))
    }

    // MARK: Schedules

    /// Moves the schedule of this card and kind of answer by one attempt. Call it inside a write transaction.
    private func updateSchedule(for attempt: ReviewAttempt, ownerKey: String) {
        let key = "\(ownerKey)|\(attempt.cardID)|\(attempt.skill.rawValue)"
        let existing = realm.object(ofType: RReviewState.self, forPrimaryKey: key)
        // An answer given to an earlier wording of the card that is saved only now (after the card was edited and answered again)
        // is kept as history but must not replace the schedule of the wording the card has now.
        if let existing, existing.contentVersion != attempt.contentVersion, attempt.answeredAt <= existing.lastReview { return }
        let next = scheduler.next(after: existing.map(Self.state(of:)), grade: ReviewScheduler.grade(for: attempt),
                                  contentVersion: attempt.contentVersion, at: attempt.answeredAt)
        let record = existing ?? RReviewState()
        if existing == nil {
            record.recordId = key
            record.ownerKey = ownerKey
            record.cardId = attempt.cardID
            record.skill = attempt.skill.rawValue
        }
        record.contentVersion = next.contentVersion
        record.algorithm = next.algorithm
        record.stability = next.stability
        record.difficulty = next.difficulty
        record.due = next.due
        record.lastReview = next.lastReview
        record.reviews = next.reviews
        record.lapses = next.lapses
        if existing == nil { realm.add(record) }
    }

    private static func state(of record: RReviewState) -> ReviewState {
        ReviewState(contentVersion: record.contentVersion, algorithm: record.algorithm, stability: record.stability,
                    difficulty: record.difficulty, due: record.due, lastReview: record.lastReview, reviews: record.reviews, lapses: record.lapses)
    }

    /// A schedule of a kind of answer this version does not know is skipped, never guessed at.
    private static func schedule(of record: RReviewState) -> ReviewSchedule? {
        guard let skill = ReviewSkill(rawValue: record.skill) else { return nil }
        return ReviewSchedule(cardID: record.cardId, skill: skill, state: state(of: record))
    }

    // MARK: Helpers

    private static func value(of record: RReviewAttempt) -> ReviewAttempt? {
        guard let result = ReviewResult(rawValue: record.result) else { return nil }
        return ReviewAttempt(id: record.attemptId, cardID: record.cardId, result: result,
                             hints: Set(record.hints.compactMap(ReviewHint.init(rawValue:))),
                             contentVersion: record.contentVersion, answeredAt: record.answeredAt)
    }

    private static func matches(_ record: RReviewAttempt, _ attempt: ReviewAttempt) -> Bool {
        record.cardId == attempt.cardID && record.result == attempt.result.rawValue
            && record.contentVersion == attempt.contentVersion
            && Array(record.hints) == attempt.hints.map(\.rawValue).sorted()
            && abs(record.answeredAt.timeIntervalSince(attempt.answeredAt)) < timeTolerance
    }
}
