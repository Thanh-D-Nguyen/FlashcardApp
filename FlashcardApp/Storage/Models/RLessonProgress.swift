import Foundation
import RealmSwift

/// A learner's progress through one structured lesson, kept on this device for one account (`ownerKey` is the signed-in
/// account's id, or "" with nobody signed in; guest progress stays when an account signs in and is never merged into it).
/// `recordId` is `ownerKey|slug`. `lessonId` is the backend's UUID of the lesson and is kept as sent.
/// `answers` holds `activityId|optionKey` in the order the learner chose, one per activity (the first choice is final).
/// `completedAt` is the local fact "every activity answered and finished"; `serverConfirmedAt` is set only after the server
/// answered the progress write for this account, so "done here" and "saved to the account" never get mixed up.
final class RLessonProgress: Object {
    @Persisted(primaryKey: true) var recordId: String
    @Persisted(indexed: true) var ownerKey: String
    @Persisted var slug: String
    @Persisted var lessonId: String
    @Persisted var levelCode: String
    @Persisted var sortOrder: Int
    @Persisted var contentVersion: String
    @Persisted var activityTotal: Int
    @Persisted var answers: List<String>
    @Persisted var startedAt: Date
    @Persisted var completedAt: Date?
    @Persisted var serverConfirmedAt: Date?
}
