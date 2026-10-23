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

final class RealmReviewHistoryStore: ReviewHistoryStoreInterface {
    private var realm: Realm { RealmService.shared.realm }

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
