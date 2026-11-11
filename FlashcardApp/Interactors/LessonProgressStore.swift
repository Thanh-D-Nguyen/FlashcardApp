import Foundation
import RealmSwift

struct LessonAnswer: Equatable {
    let activityId: String
    let optionKey: String
}

/// Which lesson a progress record belongs to, with the activities it is made of.
struct LessonProgressSubject: Equatable {
    let slug: String
    let lessonId: String
    let levelCode: String
    let sortOrder: Int
    let contentVersion: String
    let activityIds: [String]
}

struct LessonProgress: Equatable {
    let slug: String
    let lessonId: String
    let levelCode: String
    let sortOrder: Int
    let contentVersion: String
    let activityTotal: Int
    let answers: [LessonAnswer]
    let startedAt: Date
    let completedAt: Date?
    let serverConfirmedAt: Date?

    var isCompletedLocally: Bool { completedAt != nil }
    var isServerConfirmed: Bool { serverConfirmedAt != nil }
    func optionKey(for activityId: String) -> String? { answers.first { $0.activityId == activityId }?.optionKey }
}

enum LessonProgressError: Error, Equatable {
    /// The activity is not one of this lesson's activities.
    case unknownActivity
    /// Completing needs every activity answered.
    case notFinished
    /// There is no completed progress to confirm.
    case notFound
}

protocol LessonProgressStoreInterface: AnyObject {
    func progress(slug: String, ownerKey: String) -> LessonProgress?
    /// Slugs this learner finished on this device.
    func completedSlugs(ownerKey: String) -> Set<String>
    /// Saves a choice. The first choice for an activity is final: a later one changes nothing and the saved progress is returned.
    @discardableResult func recordAnswer(_ answer: LessonAnswer, for lesson: LessonProgressSubject, ownerKey: String, at date: Date) throws -> LessonProgress
    /// Marks the lesson finished on this device once every activity is answered. Repeating it changes nothing.
    @discardableResult func markCompleted(for lesson: LessonProgressSubject, ownerKey: String, at date: Date) throws -> LessonProgress
    /// Records that the server confirmed completion for this account. Only a locally completed lesson can be confirmed.
    func markServerConfirmed(slug: String, ownerKey: String, at date: Date) throws
}

/// Main thread only, like the other Realm repositories; callers receive value copies.
final class RealmLessonProgressStore: LessonProgressStoreInterface {
    static let shared = RealmLessonProgressStore()
    private var realm: Realm { RealmService.shared.realm }

    private static func recordId(_ ownerKey: String, _ slug: String) -> String { "\(ownerKey)|\(slug)" }
    private static let separator: Character = "|"

    func progress(slug: String, ownerKey: String) -> LessonProgress? {
        realm.object(ofType: RLessonProgress.self, forPrimaryKey: Self.recordId(ownerKey, slug)).map(Self.value)
    }

    func completedSlugs(ownerKey: String) -> Set<String> {
        Set(realm.objects(RLessonProgress.self).filter("ownerKey == %@ AND completedAt != nil", ownerKey).map(\.slug))
    }

    func recordAnswer(_ answer: LessonAnswer, for lesson: LessonProgressSubject, ownerKey: String, at date: Date) throws -> LessonProgress {
        guard lesson.activityIds.contains(answer.activityId) else { throw LessonProgressError.unknownActivity }
        let id = Self.recordId(ownerKey, lesson.slug)
        var saved: LessonProgress?
        try realm.write {
            let record = realm.object(ofType: RLessonProgress.self, forPrimaryKey: id) ?? makeRecord(id: id, lesson: lesson, ownerKey: ownerKey, at: date)
            let alreadyAnswered = record.answers.contains { $0.hasPrefix(answer.activityId + String(Self.separator)) }
            if !alreadyAnswered { record.answers.append(answer.activityId + String(Self.separator) + answer.optionKey) }
            saved = Self.value(record)
        }
        return try unwrapped(saved)
    }

    func markCompleted(for lesson: LessonProgressSubject, ownerKey: String, at date: Date) throws -> LessonProgress {
        guard let record = realm.object(ofType: RLessonProgress.self, forPrimaryKey: Self.recordId(ownerKey, lesson.slug)) else {
            throw LessonProgressError.notFinished
        }
        let answered = Set(Self.value(record).answers.map(\.activityId))
        guard lesson.activityIds.allSatisfy(answered.contains) else { throw LessonProgressError.notFinished }
        var saved: LessonProgress?
        try realm.write {
            if record.completedAt == nil { record.completedAt = date }
            saved = Self.value(record)
        }
        return try unwrapped(saved)
    }

    func markServerConfirmed(slug: String, ownerKey: String, at date: Date) throws {
        guard let record = realm.object(ofType: RLessonProgress.self, forPrimaryKey: Self.recordId(ownerKey, slug)),
              record.completedAt != nil else { throw LessonProgressError.notFound }
        try realm.write { if record.serverConfirmedAt == nil { record.serverConfirmedAt = date } }
    }

    private func makeRecord(id: String, lesson: LessonProgressSubject, ownerKey: String, at date: Date) -> RLessonProgress {
        let record = RLessonProgress()
        record.recordId = id
        record.ownerKey = ownerKey
        record.slug = lesson.slug
        record.lessonId = lesson.lessonId
        record.levelCode = lesson.levelCode
        record.sortOrder = lesson.sortOrder
        record.contentVersion = lesson.contentVersion
        record.activityTotal = lesson.activityIds.count
        record.startedAt = date
        realm.add(record)
        return record
    }

    private func unwrapped(_ value: LessonProgress?) throws -> LessonProgress {
        guard let value else { throw LessonProgressError.notFound }
        return value
    }

    private static func value(_ record: RLessonProgress) -> LessonProgress {
        let answers = Array(record.answers).compactMap { entry -> LessonAnswer? in
            guard let split = entry.lastIndex(of: separator) else { return nil }
            return LessonAnswer(activityId: String(entry[..<split]), optionKey: String(entry[entry.index(after: split)...]))
        }
        return LessonProgress(slug: record.slug, lessonId: record.lessonId, levelCode: record.levelCode, sortOrder: record.sortOrder,
                              contentVersion: record.contentVersion, activityTotal: record.activityTotal, answers: answers,
                              startedAt: record.startedAt, completedAt: record.completedAt, serverConfirmedAt: record.serverConfirmedAt)
    }
}
