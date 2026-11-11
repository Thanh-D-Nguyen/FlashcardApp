import RealmSwift
import XCTest
@testable import FlashcardApp

/// Today's lesson slot, decided from real progress in a real in-memory Realm and the lessons saved on the device.
final class TodayLessonSlotTests: XCTestCase {
    private var store: RealmLessonProgressStore!
    private var cache: SlugCacheStub!
    private var language: AppLanguage = .vietnamese
    private var provider: TodayLessonSlotProvider!
    private let owner = "11111111-1111-1111-1111-111111111111"
    private let other = "22222222-2222-2222-2222-222222222222"
    private let day = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        RealmService.shared.realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString, objectTypes: RealmService.storedTypes))
        store = RealmLessonProgressStore()
        cache = SlugCacheStub()
        language = .vietnamese
        provider = TodayLessonSlotProvider(store: store, cache: cache, language: { [unowned self] in language })
    }

    override func tearDown() {
        RealmService.shared.realm = nil
        super.tearDown()
    }

    private func subject(_ slug: String, order: Int, level: String = "J5") -> LessonProgressSubject {
        LessonProgressSubject(slug: slug, lessonId: "id-\(slug)", levelCode: level, sortOrder: order, contentVersion: "v1", activityIds: ["\(slug)-1", "\(slug)-2"])
    }

    private func answer(_ slug: String, _ count: Int, order: Int = 1, owner: String? = nil, at date: Date? = nil) throws {
        for index in 1...count {
            try store.recordAnswer(LessonAnswer(activityId: "\(slug)-\(index)", optionKey: "A"), for: subject(slug, order: order), ownerKey: owner ?? self.owner, at: date ?? day)
        }
    }

    private func complete(_ slug: String, order: Int = 1, owner: String? = nil, at date: Date? = nil) throws {
        try answer(slug, 2, order: order, owner: owner, at: date)
        try store.markCompleted(for: subject(slug, order: order), ownerKey: owner ?? self.owner, at: date ?? day)
    }

    /// Saves a lesson as the device would have it, naming `next` as the lesson after it.
    private func saveCopy(_ slug: String, title: String, titleJa: String = "日本語", next: (slug: String, title: String)?) throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(BJTLessonFixtures.j5Lesson01JSON.utf8)) as? [String: Any])
        object["slug"] = slug
        object["titleVi"] = title
        object["titleJa"] = titleJa
        object["nextLesson"] = next.map { ["slug": $0.slug, "titleVi": $0.title, "sortOrder": 2] } ?? NSNull()
        cache.copies[slug] = try JSONDecoder().decode(BJTLessonDetailDTO.self, from: JSONSerialization.data(withJSONObject: object))
    }

    func test_nothingStartedOffersToChooseALevel() {
        XCTAssertEqual(provider.slot(ownerKey: owner), .start)
        XCTAssertEqual(provider.slot(ownerKey: ""), .start)
    }

    func test_aLessonWithAnswersButNotFinishedIsContinuedWithItsRealCount() throws {
        try saveCopy("l1", title: "Chào hỏi", next: nil)
        try answer("l1", 1)
        XCTAssertEqual(provider.slot(ownerKey: owner), .continueLesson(slug: "l1", title: "Chào hỏi", levelCode: "J5", answered: 1, total: 2))
    }

    func test_aLessonNotSavedOnThisDeviceStillContinuesWithoutATitle() throws {
        try answer("l1", 1)
        XCTAssertEqual(provider.slot(ownerKey: owner), .continueLesson(slug: "l1", title: nil, levelCode: "J5", answered: 1, total: 2))
    }

    func test_theLessonAfterTheLastFinishedOneIsOffered() throws {
        try saveCopy("l1", title: "Một", next: ("l2", "Hai"))
        try complete("l1")
        XCTAssertEqual(provider.slot(ownerKey: owner), .next(slug: "l2", title: "Hai", levelCode: "J5"))
    }

    func test_aLessonInProgressComesBeforeTheNextOne() throws {
        try saveCopy("l1", title: "Một", next: ("l2", "Hai"))
        try complete("l1", at: day)
        try answer("l3", 1, order: 3, at: day.addingTimeInterval(10))
        guard case .continueLesson(let slug, _, _, _, _)? = Optional(provider.slot(ownerKey: owner)) else { return XCTFail("expected continue") }
        XCTAssertEqual(slug, "l3")
    }

    func test_aNextLessonAlreadyFinishedIsSkippedInFavourOfAnotherFinishedLessonsNext() throws {
        try saveCopy("l1", title: "Một", next: ("l2", "Hai"))
        try saveCopy("l2", title: "Hai", next: ("l9", "Chín"))
        try complete("l1", at: day)
        try complete("l2", order: 2, at: day.addingTimeInterval(10))
        XCTAssertEqual(provider.slot(ownerKey: owner), .next(slug: "l9", title: "Chín", levelCode: "J5"))
    }

    func test_whenNoNextLessonIsKnownTheLearnerChoosesAgain() throws {
        try saveCopy("l1", title: "Một", next: nil)
        try complete("l1")
        XCTAssertEqual(provider.slot(ownerKey: owner), .finishedOpened(completed: 1), "The last lesson of a level has no next one")
        try complete("l5", order: 5, at: day.addingTimeInterval(5))
        XCTAssertEqual(provider.slot(ownerKey: owner), .finishedOpened(completed: 2), "A finished lesson not saved on this device names no next one")
    }

    func test_eachAccountAndTheGuestSeeOnlyTheirOwnProgress() throws {
        try saveCopy("l1", title: "Một", next: ("l2", "Hai"))
        try complete("l1")
        XCTAssertEqual(provider.slot(ownerKey: other), .start)
        XCTAssertEqual(provider.slot(ownerKey: ""), .start)
        try complete("g1", owner: "")
        XCTAssertEqual(provider.slot(ownerKey: ""), .finishedOpened(completed: 1))
        XCTAssertEqual(provider.slot(ownerKey: owner), .next(slug: "l2", title: "Hai", levelCode: "J5"), "Guest progress is not merged into the account")
    }

    func test_theContinuedTitleFollowsTheAppLanguage() throws {
        try saveCopy("l1", title: "Chào hỏi", titleJa: "挨拶", next: nil)
        try answer("l1", 1)
        language = .japanese
        XCTAssertEqual(provider.slot(ownerKey: owner), .continueLesson(slug: "l1", title: "挨拶", levelCode: "J5", answered: 1, total: 2))
    }
}

final class SlugCacheStub: LessonCacheInterface {
    var copies: [String: BJTLessonDetailDTO] = [:]
    func lesson(slug: String) -> BJTLessonDetailDTO? { copies[slug] }
    func store(payload: Data, slug: String) throws {}
}
