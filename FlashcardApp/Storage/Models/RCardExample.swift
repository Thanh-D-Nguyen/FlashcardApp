import Foundation
import RealmSwift

/// The learner's own changes to a card's example sentences, kept on this device for one account.
/// The sentences the server offers are not stored; this holds only what the learner did to them:
/// - `custom`: a sentence the learner wrote (`id` is its identity, `serverExampleId` is empty);
/// - `edited`: the learner's text shown in place of the server sentence `serverExampleId`;
/// - `hidden`: the server sentence `serverExampleId` removed for this account (text fields are empty).
/// `ownerKey` is the signed-in account's id, or "" when nobody is signed in.
final class RCardExample: Object {
    enum Kind: String { case custom, edited, hidden }

    @Persisted(primaryKey: true) var id: String
    @Persisted(indexed: true) var cardId: String
    @Persisted var ownerKey: String
    @Persisted var kind: String
    @Persisted var serverExampleId: String
    @Persisted var japanese: String
    @Persisted var reading: String
    @Persisted var translation: String
    @Persisted var createdAt: Date
    @Persisted var updatedAt: Date
}

extension Realm {
    /// Removes the learner's sentence changes for cards that no longer exist. Call it inside the write transaction that
    /// deletes the cards, so a deleted card never leaves sentences behind (for any account).
    func deleteExamples(forCards cardIds: [String]) {
        guard !cardIds.isEmpty else { return }
        delete(objects(RCardExample.self).filter("cardId IN %@", cardIds))
    }
}
