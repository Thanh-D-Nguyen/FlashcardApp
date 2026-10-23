import Foundation
import RealmSwift

/// One answered question of a study session, kept on this device for one learner (`ownerKey` is the signed-in
/// account's id, or "" when nobody is signed in). Each attempt is written once; it is never edited afterwards.
/// `recordId` is `ownerKey|attemptId`, so saving the same attempt again (a retry) finds the record it already made,
/// and two accounts can never overwrite each other. `contentVersion` is the card's wording when it was answered.
final class RReviewAttempt: Object {
    @Persisted(primaryKey: true) var recordId: String
    @Persisted var attemptId: String
    @Persisted(indexed: true) var ownerKey: String
    @Persisted(indexed: true) var cardId: String
    @Persisted var contentVersion: String
    @Persisted var result: String
    /// `ReviewHint` raw values, sorted, so the same attempt always stores the same list.
    @Persisted var hints: List<String>
    @Persisted(indexed: true) var answeredAt: Date
}

extension Realm {
    /// Removes the review history of cards that no longer exist, for every account. Call it inside the write transaction
    /// that deletes the cards, so a deleted card never leaves attempts behind. Editing a card does not call this: its
    /// attempts stay, tagged with the wording they were answered against.
    func deleteReviewAttempts(forCards cardIds: [String]) {
        guard !cardIds.isEmpty else { return }
        delete(objects(RReviewAttempt.self).filter("cardId IN %@", cardIds))
    }
}
