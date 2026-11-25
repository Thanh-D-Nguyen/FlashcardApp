import RealmSwift
import XCTest
@testable import FlashcardApp

/// Lesson progress against a real on-disk Realm: what is saved, for whom, that the first answer is final, and that
/// finishing here and being confirmed by the server stay separate facts.
final class LessonProgressStoreTests: XCTestCase {
    private var store: RealmLessonProgressStore!
    private var folder: URL!
    private var fileURL: URL!
    private let owner = "11111111-1111-1111-1111-111111111111"
    private let other = "22222222-2222-2222-2222-222222222222"
    private let day = Date(timeIntervalSince1970: 1_800_000_000)
    private let lesson = LessonProgressSubject(slug: "j5-01-greetings-intro", lessonId: "bdf97bd4-6318-409c-991b-b076526d6c28", levelCode: "J5",
                                               sortOrder: 1, contentVersion: "v1", activityIds: ["a1", "a2"])

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

    private func openStore() throws {
        store = nil
        RealmService.shared.realm = nil
        RealmService.shared.realm = try Realm(configuration: RealmService.makeConfiguration(fileURL: fileURL))
        store = RealmLessonProgressStore()
    }

    func test_nothingIsSavedUntilTheLearnerAnswers() {
        XCTAssertNil(store.progress(slug: lesson.slug, ownerKey: owner))
        XCTAssertTrue(store.completedSlugs(ownerKey: owner).isEmpty)
    }

    func test_anAnswerIsSavedWithTheLessonsBackendIdentityAndSurvivesReopening() throws {
        let saved = try store.recordAnswer(LessonAnswer(activityId: "a1", optionKey: "B"), for: lesson, ownerKey: owner, at: day)
        XCTAssertEqual(saved.lessonId, "bdf97bd4-6318-409c-991b-b076526d6c28", "The backend UUID is kept as sent")
        XCTAssertEqual([saved.levelCode, saved.contentVersion], ["J5", "v1"])
        XCTAssertEqual(saved.sortOrder, 1)
        XCTAssertEqual(saved.activityTotal, 2)
        XCTAssertEqual(saved.answers, [LessonAnswer(activityId: "a1", optionKey: "B")])
        XCTAssertEqual(saved.startedAt, day)
        XCTAssertFalse(saved.isCompletedLocally)
        try openStore()
        XCTAssertEqual(store.progress(slug: lesson.slug, ownerKey: owner), saved)
    }

    func test_theFirstAnswerIsFinal() throws {
        _ = try store.recordAnswer(LessonAnswer(activityId: "a1", optionKey: "B"), for: lesson, ownerKey: owner, at: day)
        let again = try store.recordAnswer(LessonAnswer(activityId: "a1", optionKey: "A"), for: lesson, ownerKey: owner, at: day.addingTimeInterval(60))
        XCTAssertEqual(again.answers, [LessonAnswer(activityId: "a1", optionKey: "B")])
        XCTAssertEqual(again.startedAt, day)
    }

    func test_anActivityOfAnotherLessonIsRefused() {
        XCTAssertThrowsError(try store.recordAnswer(LessonAnswer(activityId: "zzz", optionKey: "A"), for: lesson, ownerKey: owner, at: day)) {
            XCTAssertEqual($0 as? LessonProgressError, .unknownActivity)
        }
        XCTAssertNil(store.progress(slug: lesson.slug, ownerKey: owner), "A refused answer leaves no record behind")
    }

    func test_aLessonIsCompletedOnlyWhenEveryActivityIsAnswered() throws {
        _ = try store.recordAnswer(LessonAnswer(activityId: "a1", optionKey: "A"), for: lesson, ownerKey: owner, at: day)
        XCTAssertThrowsError(try store.markCompleted(for: lesson, ownerKey: owner, at: day)) {
            XCTAssertEqual($0 as? LessonProgressError, .notFinished)
        }
        XCTAssertTrue(store.completedSlugs(ownerKey: owner).isEmpty)
        _ = try store.recordAnswer(LessonAnswer(activityId: "a2", optionKey: "C"), for: lesson, ownerKey: owner, at: day)
        let done = try store.markCompleted(for: lesson, ownerKey: owner, at: day.addingTimeInterval(120))
        XCTAssertEqual(done.completedAt, day.addingTimeInterval(120))
        XCTAssertEqual(store.completedSlugs(ownerKey: owner), [lesson.slug])
        let repeated = try store.markCompleted(for: lesson, ownerKey: owner, at: day.addingTimeInterval(999))
        XCTAssertEqual(repeated.completedAt, day.addingTimeInterval(120), "Completing again keeps the first time")
    }

    func test_serverConfirmationIsSeparateFromLocalCompletion() throws {
        XCTAssertThrowsError(try store.markServerConfirmed(slug: lesson.slug, ownerKey: owner, at: day)) {
            XCTAssertEqual($0 as? LessonProgressError, .notFound)
        }
        _ = try store.recordAnswer(LessonAnswer(activityId: "a1", optionKey: "A"), for: lesson, ownerKey: owner, at: day)
        _ = try store.recordAnswer(LessonAnswer(activityId: "a2", optionKey: "A"), for: lesson, ownerKey: owner, at: day)
        XCTAssertThrowsError(try store.markServerConfirmed(slug: lesson.slug, ownerKey: owner, at: day), "Not completed yet") {
            XCTAssertEqual($0 as? LessonProgressError, .notFound)
        }
        _ = try store.markCompleted(for: lesson, ownerKey: owner, at: day)
        XCTAssertFalse(try XCTUnwrap(store.progress(slug: lesson.slug, ownerKey: owner)).isServerConfirmed, "Done here is not saved to the account")
        try store.markServerConfirmed(slug: lesson.slug, ownerKey: owner, at: day.addingTimeInterval(5))
        let progress = try XCTUnwrap(store.progress(slug: lesson.slug, ownerKey: owner))
        XCTAssertEqual(progress.serverConfirmedAt, day.addingTimeInterval(5))
        XCTAssertTrue(progress.isCompletedLocally)
    }

    func test_eachAccountAndTheGuestKeepTheirOwnProgress() throws {
        _ = try store.recordAnswer(LessonAnswer(activityId: "a1", optionKey: "A"), for: lesson, ownerKey: "", at: day)
        _ = try store.recordAnswer(LessonAnswer(activityId: "a1", optionKey: "D"), for: lesson, ownerKey: owner, at: day)
        XCTAssertEqual(store.progress(slug: lesson.slug, ownerKey: "")?.answers.first?.optionKey, "A")
        XCTAssertEqual(store.progress(slug: lesson.slug, ownerKey: owner)?.answers.first?.optionKey, "D")
        XCTAssertNil(store.progress(slug: lesson.slug, ownerKey: other), "Another account sees nothing of it")
    }
}
