import Alamofire
import RxSwift
import XCTest
@testable import FlashcardApp

private final class FakeStreakAPI: BJTStreakAPIInterface {
    var streaksResult: Single<[BJTStreakDTO]> = .just([])
    var recordResult: Single<Void> = .just(())
    private(set) var streakReads = 0
    private(set) var records: [(StreakActivity, TimeZone?)] = []

    func streaks() -> Single<[BJTStreakDTO]> { streakReads += 1; return streaksResult }
    func recordStreakActivity(_ activity: StreakActivity, timeZone: TimeZone?) -> Single<Void> {
        records.append((activity, timeZone))
        return recordResult
    }
}

private func streak(_ type: String, days: Int, last: String?) -> BJTStreakDTO {
    BJTStreakDTO(configId: UUID().uuidString, activityType: type, currentStreak: days, longestStreak: days, lastActiveDate: last)
}

private func hanoiCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
    return calendar
}

/// 2026-11-11 06:00 in Hanoi (2026-11-10 23:00 UTC): a learner day the server clock would still call the 10th.
private let hanoiMorning = Date(timeIntervalSince1970: 1_794_351_600)

final class AccountStreakTests: XCTestCase {
    func test_theAnyStreakIsShownWhileItsLastDayIsTodayOrYesterdayOnTheLearnersCalendar() {
        let calendar = hanoiCalendar()
        let rows = [streak("review", days: 9, last: "2026-11-11"), streak("any", days: 4, last: "2026-11-11")]
        XCTAssertEqual(AccountStreak.current(from: rows, now: hanoiMorning, calendar: calendar), AccountStreak(days: 4, countsToday: true))
        XCTAssertEqual(AccountStreak.current(from: [streak("any", days: 4, last: "2026-11-10")], now: hanoiMorning, calendar: calendar),
                       AccountStreak(days: 4, countsToday: false), "Yesterday still counts: the learner can keep it today")
    }

    func test_aBrokenZeroOrMissingStreakIsNotShown() {
        let calendar = hanoiCalendar()
        XCTAssertNil(AccountStreak.current(from: [streak("any", days: 6, last: "2026-11-09")], now: hanoiMorning, calendar: calendar),
                     "The server keeps a broken streak's old count until the next activity")
        XCTAssertNil(AccountStreak.current(from: [streak("any", days: 0, last: nil)], now: hanoiMorning, calendar: calendar))
        XCTAssertNil(AccountStreak.current(from: [streak("review", days: 3, last: "2026-11-11")], now: hanoiMorning, calendar: calendar),
                     "Only the streak of any activity is shown")
        XCTAssertNil(AccountStreak.current(from: [streak("any", days: 3, last: "11/11/2026")], now: hanoiMorning, calendar: calendar))
        XCTAssertNil(AccountStreak.current(from: [], now: hanoiMorning, calendar: calendar))
    }

    func test_aServerDayAheadOfTheLearnerCountsAsToday() {
        // An older server records on its own clock, which can be a day ahead of a learner west of it.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertEqual(AccountStreak.current(from: [streak("any", days: 2, last: "2026-11-11")], now: hanoiMorning, calendar: calendar),
                       AccountStreak(days: 2, countsToday: true))
        XCTAssertNil(AccountStreak.current(from: [streak("any", days: 2, last: "2026-11-13")], now: hanoiMorning, calendar: calendar),
                     "A date two days ahead is not a real learner day")
    }
}

final class AccountStreakRecorderTests: XCTestCase {
    private var api: FakeStreakAPI!
    private var defaults: UserDefaults!
    private var center: NotificationCenter!
    private var account: String? = "learner-1"
    private var now = hanoiMorning

    override func setUp() {
        super.setUp()
        api = FakeStreakAPI()
        defaults = UserDefaults(suiteName: "streak-\(UUID().uuidString)")
        center = NotificationCenter()
        account = "learner-1"
        now = hanoiMorning
    }

    private func recorder() -> AccountStreakRecorder {
        AccountStreakRecorder(api: api, accountId: { [unowned self] in account }, now: { [unowned self] in now },
                              calendar: { hanoiCalendar() }, defaults: defaults, notificationCenter: center)
    }

    func test_aDayIsRecordedOnceWithTheLearnersTimeZoneAndAnnounced() {
        let recorder = recorder()
        let announced = expectation(forNotification: AccountStreakRecorder.didRecord, object: nil, notificationCenter: center)
        recorder.recordReview()
        recorder.recordReview()
        wait(for: [announced], timeout: 2)
        XCTAssertEqual(api.records.count, 1, "Once per learner day")
        XCTAssertEqual(api.records.first?.0, .review)
        XCTAssertEqual(api.records.first?.1?.identifier, "Asia/Ho_Chi_Minh")
        now = now.addingTimeInterval(18 * 3600)   // 2026-11-12 00:00 in Hanoi
        recorder.recordReview()
        XCTAssertEqual(api.records.count, 2, "A new learner day is recorded again")
    }

    func test_guestsAndOtherAccountsAreKeptApart() {
        account = nil
        let recorder = recorder()
        recorder.recordReview()
        XCTAssertTrue(api.records.isEmpty, "A guest has no account streak")
        account = "learner-1"
        recorder.recordReview()
        account = "learner-2"
        recorder.recordReview()
        XCTAssertEqual(api.records.count, 2, "The day of one account does not count for another")
    }

    func test_aFailureIsNotRetriedButTheNextReviewTriesAgain() {
        api.recordResult = .error(LearnerAPIError.offline)
        let recorder = recorder()
        recorder.recordReview()
        XCTAssertEqual(api.records.count, 1)
        let drained = expectation(description: "main queue")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 2)
        XCTAssertEqual(api.records.count, 1, "Nothing is sent again by itself")
        api.recordResult = .just(())
        recorder.recordReview()
        XCTAssertEqual(api.records.count, 2, "The day was not recorded, so the next confirmed review sends it")
    }
}

final class TodayStreakLoaderTests: XCTestCase {
    private var api: FakeStreakAPI!
    private var center: NotificationCenter!
    private var account: String? = "learner-1"
    private var now = hanoiMorning

    override func setUp() {
        super.setUp()
        api = FakeStreakAPI()
        center = NotificationCenter()
        account = "learner-1"
        now = hanoiMorning
    }

    private func loader() -> TodayStreakLoader {
        TodayStreakLoader(api: api, accountId: { [unowned self] in account }, now: { [unowned self] in now },
                          calendar: { hanoiCalendar() }, notificationCenter: center)
    }

    private func settle() {
        let drained = expectation(description: "main queue")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 2)
    }

    func test_aGuestNeverAsksTheServerAndSeesNoStreak() {
        account = nil
        let loader = loader()
        loader.refresh()
        settle()
        XCTAssertNil(loader.streak)
        XCTAssertEqual(api.streakReads, 0)
    }

    func test_theAccountStreakIsLoadedOnceAndReloadedAfterARecordOrADayChange() {
        api.streaksResult = .just([streak("any", days: 3, last: "2026-11-11")])
        let loader = loader()
        var changes = 0
        loader.onChange = { changes += 1 }
        loader.refresh()
        settle()
        XCTAssertEqual(loader.streak, AccountStreak(days: 3, countsToday: true))
        XCTAssertGreaterThan(changes, 0)
        loader.refresh()
        settle()
        XCTAssertEqual(api.streakReads, 1, "A fresh answer is reused")
        center.post(name: AccountStreakRecorder.didRecord, object: nil)
        loader.refresh()
        settle()
        XCTAssertEqual(api.streakReads, 2, "A recorded day makes it old")
        now = now.addingTimeInterval(18 * 3600)
        loader.refresh()
        settle()
        XCTAssertEqual(api.streakReads, 3, "So does a new learner day")
    }

    func test_aFailureHidesTheLineAndAnAnswerForAnotherAccountIsDropped() {
        api.streaksResult = .error(LearnerAPIError.offline)
        let loader = loader()
        loader.refresh()
        settle()
        XCTAssertNil(loader.streak, "No number rather than a wrong one")

        let pending = PublishSubject<[BJTStreakDTO]>()
        api.streaksResult = pending.take(1).asSingle()
        loader.refresh()
        account = "learner-2"
        pending.onNext([streak("any", days: 8, last: "2026-11-11")])
        settle()
        XCTAssertNil(loader.streak, "The answer belongs to the account that asked")

        account = nil
        loader.refresh()
        settle()
        XCTAssertNil(loader.streak)
    }
}

/// The request shape of the two streak calls.
final class BJTGamificationAPITests: XCTestCase {
    private var session: Session!
    private var bag = DisposeBag()

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [LearnerURLProtocol.self]
        session = Session(configuration: config)
        LearnerURLProtocol.handler = nil
        LearnerURLProtocol.onStop = nil
        LearnerURLProtocol.requests = []
    }

    override func tearDown() {
        session.session.invalidateAndCancel()
        LearnerURLProtocol.handler = nil
        super.tearDown()
    }

    private var api: BJTLearnerAPI { BJTLearnerAPI(session: session, baseURL: { "https://api.test/api" }, token: { "opaque" }) }

    private func result<T>(_ single: Single<T>) -> Result<T, Error> {
        var outcome: Result<T, Error>?
        let done = expectation(description: "request")
        single.subscribe(onSuccess: { outcome = .success($0); done.fulfill() }, onFailure: { outcome = .failure($0); done.fulfill() }).disposed(by: bag)
        wait(for: [done], timeout: 3)
        return outcome ?? .failure(LearnerAPIError.invalidResponse)
    }

    func test_streaksDecodeTheProductionShape() throws {
        // Shape of the production answer for a new test account (2026-11-11), ids replaced.
        let json = #"{"streaks":[{"configId":"c1","name":"Daily Review Streak","activityType":"review","currentStreak":1,"longestStreak":1,"lastActiveDate":"2026-11-11","freezesUsed":0,"freezesAllowed":2,"updatedAt":"2026-11-11T07:36:10.015961Z"},{"configId":"c2","name":"Daily Study Streak","activityType":"any","currentStreak":0,"longestStreak":0,"freezesUsed":0,"freezesAllowed":3,"updatedAt":"0001-01-01T00:00:00Z"}]}"#
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: json) }
        let rows = try result(api.streaks()).get()
        XCTAssertEqual(rows.map(\.activityType), ["review", "any"])
        XCTAssertEqual(rows.first?.lastActiveDate, "2026-11-11")
        XCTAssertNil(rows.last?.lastActiveDate)
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.url.absoluteString, "https://api.test/api/gamification/streaks")
        XCTAssertEqual(sent.headers["Authorization"], "Bearer opaque")
    }

    func test_recordSendsTheActivityTheOriginAndOnlyAKnownTimeZone() throws {
        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: #"{"success":true}"#) }
        XCTAssertNoThrow(try result(api.recordStreakActivity(.review, timeZone: TimeZone(identifier: "Asia/Ho_Chi_Minh"))).get())
        let sent = try XCTUnwrap(LearnerURLProtocol.requests.first)
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.url.absoluteString, "https://api.test/api/gamification/streaks/record?activityType=review&timeZone=Asia/Ho_Chi_Minh")
        XCTAssertEqual(sent.headers["Origin"], "https://api.test")

        LearnerURLProtocol.requests = []
        XCTAssertNoThrow(try result(api.recordStreakActivity(.review, timeZone: TimeZone(secondsFromGMT: 7 * 3600))).get())
        XCTAssertEqual(LearnerURLProtocol.requests.first?.url.absoluteString, "https://api.test/api/gamification/streaks/record?activityType=review",
                       "A fixed offset is not a zone the server can load: it decides the day itself")

        LearnerURLProtocol.handler = { _, proto in proto.respond(status: 200, json: #"{"success":false}"#) }
        if case .success = result(api.recordStreakActivity(.review, timeZone: nil)) { XCTFail("An unconfirmed record is not a success") }
    }
}
