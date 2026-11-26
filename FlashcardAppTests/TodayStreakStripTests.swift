import RealmSwift
import XCTest
@testable import FlashcardApp

final class TodayStreakStripTests: XCTestCase {
    private var calendar: Calendar!
    /// Thursday 2026-11-26 12:00 in Tokyo (Monday of this week is 2026-11-23).
    private let thursday = Date(timeIntervalSince1970: 1_795_662_000)

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    }

    private func dayOffset(_ daysFromMonday: Int) -> Date {
        let monday = TodayStreakStripBuilder.currentWeekStart(for: thursday, calendar: calendar)
        return calendar.date(byAdding: .day, value: daysFromMonday, to: monday)!
    }

    func test_currentWeekStartAlwaysResolvesToMonday() {
        let monday = TodayStreakStripBuilder.currentWeekStart(for: thursday, calendar: calendar)
        XCTAssertEqual(calendar.component(.weekday, from: monday), 2, "Monday is weekday 2 in Gregorian")
        XCTAssertEqual(AccountStreak.dayKey(monday, calendar: calendar), "2026-11-23")

        // Sunday 2026-11-29 belongs to the same Monday 2026-11-23 week
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday)!
        XCTAssertEqual(AccountStreak.dayKey(TodayStreakStripBuilder.currentWeekStart(for: sunday, calendar: calendar), calendar: calendar), "2026-11-23")
    }

    func test_withoutPerDayHistoryReturnsNilWeekDotsAndShowsStudiedOrNotStudiedStatus() {
        let notYet = TodayPresenter.streakText(
            AccountStreak(days: 5, countsToday: false),
            studiedDaysInWeek: [],
            now: thursday,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(notYet.days, 5)
        XCTAssertFalse(notYet.countsToday)
        XCTAssertNil(notYet.weekDots, "Never invent fake 7 dots when no per-day history exists")
        XCTAssertEqual(notYet.todayStatusText, NSLocalizedString("Not studied today", comment: ""))

        let done = TodayPresenter.streakText(
            AccountStreak(days: 6, countsToday: true),
            studiedDaysInWeek: [],
            now: thursday,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(done.days, 6)
        XCTAssertTrue(done.countsToday)
        XCTAssertNil(done.weekDots)
        XCTAssertEqual(done.todayStatusText, NSLocalizedString("Studied today", comment: ""))
    }

    func test_withRealPerDayHistoryBuildsSevenWeekDotsMarkedAccurately() throws {
        let monday = dayOffset(0)
        let wednesday = dayOffset(2)
        let model = TodayPresenter.streakText(
            AccountStreak(days: 2, countsToday: true),
            studiedDaysInWeek: [monday, wednesday],
            now: thursday,
            calendar: calendar,
            locale: Locale(identifier: "en")
        )

        let dots = try XCTUnwrap(model.weekDots)
        XCTAssertEqual(dots.count, 7)
        // Mon(0) studied, Tue(1) not, Wed(2) studied, Thu(3) today + countsToday -> studied, Fri-Sun(4..6) future
        XCTAssertEqual(dots.map(\.isStudied), [true, false, true, true, false, false, false])
        XCTAssertEqual(dots.map(\.isToday), [false, false, false, true, false, false, false])
        XCTAssertEqual(dots.map(\.isFuture), [false, false, false, false, true, true, true])
    }

    func test_interactorReadsRealStudiedDaysInCurrentWeekFromRealmAttemptsAndLessons() throws {
        let previousRealm = RealmService.shared.realm
        let realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: "streak-\(UUID().uuidString)", objectTypes: RealmService.storedTypes))
        RealmService.shared.realm = realm
        defer { RealmService.shared.realm = previousRealm }

        let decks = DeskManagement()
        let history = RealmReviewHistoryStore()
        let lessons = RealmLessonProgressStore()
        let suite = "streak-prefs-\(UUID().uuidString)"
        let prefs = UserDefaultsTodayPreferences(defaults: UserDefaults(suiteName: suite)!)
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }

        let interactor = TodayInteractor(decks: decks, schedules: history, lessonProgress: lessons, preferences: prefs, calendar: calendar)

        // Monday review attempt for owner "u1"
        let monday = dayOffset(0).addingTimeInterval(3600)
        let tuesday = dayOffset(1).addingTimeInterval(3600)
        let lastWeek = dayOffset(-2)
        let attemptMon = ReviewAttempt(id: "a1", cardID: "c1", result: .remembered, hints: [], contentVersion: "v1", answeredAt: monday)
        let attemptOld = ReviewAttempt(id: "a2", cardID: "c1", result: .remembered, hints: [], contentVersion: "v1", answeredAt: lastWeek)
        let attemptOther = ReviewAttempt(id: "a3", cardID: "c1", result: .remembered, hints: [], contentVersion: "v1", answeredAt: dayOffset(2))
        try history.save(attemptMon, ownerKey: "u1")
        try history.save(attemptOld, ownerKey: "u1")
        try history.save(attemptOther, ownerKey: "u2")

        // Tuesday completed lesson for owner "u1"
        let subject = LessonProgressSubject(slug: "j5-01", lessonId: "l1", levelCode: "J5", sortOrder: 1, contentVersion: "v1", activityIds: ["act1"])
        _ = try lessons.recordAnswer(LessonAnswer(activityId: "act1", optionKey: "A"), for: subject, ownerKey: "u1", at: tuesday)
        _ = try lessons.markCompleted(for: subject, ownerKey: "u1", at: tuesday)

        let studied = interactor.studiedDaysInCurrentWeek(ownerKey: "u1", now: thursday)
        XCTAssertEqual(studied, Set([dayOffset(0), dayOffset(1)]))
    }
}
