import RxSwift
import XCTest
@testable import FlashcardApp

/// Opt-in contract checks of the app's own API classes against the real server. They run only when a session token of a throw-away
/// test account is in `tokenFile` (never in the repository); otherwise they are skipped, so normal runs never touch production.
/// Reads, one idempotent PUT of lesson progress; no rating is sent.
final class LiveProductionContractTests: XCTestCase {
    private static let tokenFile = "/private/tmp/kiokoto-live-token.txt"
    private var api: BJTLearnerAPI!
    private var bag: DisposeBag!

    override func setUpWithError() throws {
        let token = (try? String(contentsOfFile: Self.tokenFile, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        try XCTSkipIf(token.isEmpty, "opt-in: no live token file, so production is not touched")
        api = BJTLearnerAPI(baseURL: { "https://kiokoto.com/api" }, token: { token })
        bag = DisposeBag()
    }

    private func value<T>(_ single: Single<T>, timeout: TimeInterval = 20) throws -> T {
        var outcome: Result<T, Error>?
        let done = expectation(description: "request")
        single.subscribe(onSuccess: { outcome = .success($0); done.fulfill() }, onFailure: { outcome = .failure($0); done.fulfill() }).disposed(by: bag)
        wait(for: [done], timeout: timeout)
        return try XCTUnwrap(outcome).get()
    }

    func test_lessonProgressPutIsAcceptedAndEchoedByTheRealServer() throws {
        XCTAssertNoThrow(try value(api.markLessonCompleted(slug: "j5-01-greetings-intro")))
    }

    func test_dueCardsDecodeAndTheirDistractorsAreDistinctWrongAnswers() throws {
        let due = try value(api.dueCards(limit: 10)).compactMap(ServerDeckMapper.dueCard(from:))
        let card = try XCTUnwrap(due.first, "the test account has cards due")
        let wrong = try value(api.distractors(userFlashcardId: card.id, count: 3))
        XCTAssertGreaterThanOrEqual(wrong.count, 2)
        XCTAssertEqual(Set(wrong).count, wrong.count, "Distinct")
        XCTAssertFalse(wrong.contains(card.back), "Never the right answer")
    }

    func test_anUnknownCardIsNotFound() {
        XCTAssertThrowsError(try value(api.distractors(userFlashcardId: "00000000-0000-4000-8000-000000000000", count: 3))) {
            XCTAssertEqual($0 as? LearnerAPIError, .notFound)
        }
    }

    func test_theAccountStreakIsReadAndADayIsRecordedOnTheRealServer() throws {
        XCTAssertNoThrow(try value(api.recordStreakActivity(.review, timeZone: TimeZone(identifier: "Asia/Ho_Chi_Minh"))))
        let rows = try value(api.streaks())
        XCTAssertTrue(rows.contains { $0.activityType == AccountStreak.activityType }, "Production has the streak of any activity")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        XCTAssertNotNil(AccountStreak.current(from: rows, now: Date(), calendar: calendar), "A day was just recorded")
    }

    /// Reads only: the test account already has one export request (created once by the contract probe; not sent again here).
    func test_privacyRequestsDecodeAndAnUnpreparedExportIsNotFound() throws {
        let rows = try value(api.privacyRequests())
        let export = try XCTUnwrap(rows.first { $0.kind == "export" }, "The probe's export request")
        XCTAssertTrue(["pending", "processing"].contains(export.status))
        XCTAssertNotNil(DataExportPresenter.parse(export.createdAt))
        XCTAssertThrowsError(try value(api.downloadDataExport(requestId: export.id))) { XCTAssertEqual($0 as? LearnerAPIError, .notFound) }
    }
}
