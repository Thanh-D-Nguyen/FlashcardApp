import XCTest
@testable import FlashcardApp

final class LessonCacheTests: XCTestCase {
    private var directory: URL!
    private let slug = "j5-01-greetings-intro"
    private var payload: Data { Data(BJTLessonFixtures.j5Lesson01JSON.utf8) }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("lesson-cache-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func test_aStoredLessonIsReadBackIdenticallyEvenByANewInstance() throws {
        let cache = LessonCache(directory: directory)
        XCTAssertNil(cache.lesson(slug: slug), "Nothing stored yet")
        try cache.store(payload: payload, slug: slug)
        let expected = try JSONDecoder().decode(BJTLessonDetailDTO.self, from: payload)
        XCTAssertEqual(cache.lesson(slug: slug), expected)
        XCTAssertEqual(LessonCache(directory: directory).lesson(slug: slug), expected, "Survives an app restart")
    }

    func test_storingAgainReplacesTheCopy() throws {
        let cache = LessonCache(directory: directory)
        try cache.store(payload: payload, slug: slug)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        object["titleVi"] = "Tiêu đề mới"
        try cache.store(payload: JSONSerialization.data(withJSONObject: object), slug: slug)
        XCTAssertEqual(cache.lesson(slug: slug)?.titleVi, "Tiêu đề mới")
    }

    func test_aPayloadThatIsNotThatLessonIsNeverStored() throws {
        let cache = LessonCache(directory: directory)
        XCTAssertThrowsError(try cache.store(payload: Data("{not json".utf8), slug: slug)) {
            XCTAssertEqual($0 as? LessonCacheError, .invalidPayload)
        }
        XCTAssertThrowsError(try cache.store(payload: payload, slug: "j5-02-office-daily")) {
            XCTAssertEqual($0 as? LessonCacheError, .invalidPayload, "The payload is lesson j5-01, not j5-02")
        }
        for bad in ["", "../x", "a/b", "A", "x y"] {
            XCTAssertThrowsError(try cache.store(payload: payload, slug: bad)) { XCTAssertEqual($0 as? LessonCacheError, .invalidSlug) }
            XCTAssertNil(cache.lesson(slug: bad))
        }
        XCTAssertNil(cache.lesson(slug: slug))
    }

    func test_aDamagedOrForeignFileIsAMissNotACrash() throws {
        let cache = LessonCache(directory: directory)
        try cache.store(payload: payload, slug: slug)
        let file = try XCTUnwrap(try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first)
        try Data("garbage".utf8).write(to: file)
        XCTAssertNil(cache.lesson(slug: slug))
        // A future envelope version is not guessed at.
        try Data(#"{"version":99,"slug":"\#(slug)","payload":""}"#.utf8).write(to: file)
        XCTAssertNil(cache.lesson(slug: slug))
        // After a miss the lesson can be stored again.
        try cache.store(payload: payload, slug: slug)
        XCTAssertNotNil(cache.lesson(slug: slug))
    }

    func test_aFileNamedForOneLessonButHoldingAnotherIsRejected() throws {
        let cache = LessonCache(directory: directory)
        try cache.store(payload: payload, slug: slug)
        let file = try XCTUnwrap(try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first)
        try FileManager.default.moveItem(at: file, to: directory.appendingPathComponent("j5-02-office-daily.json"))
        XCTAssertNil(cache.lesson(slug: "j5-02-office-daily"))
    }
}
