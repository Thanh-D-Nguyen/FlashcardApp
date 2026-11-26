import RealmSwift
import UIKit
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

    func test_weekDotsIncludeAllServerStreakDaysAndNeverMarkTodayStudiedWhenAccountCountsTodayIsFalse() throws {
        // Case 1: 5-day consecutive account streak including today (Thu) -> Sat..Thu were active on account,
        // so Mon, Tue, Wed, Thu in this week must ALL be marked studied even if local device only recorded Mon.
        let fiveDayDone = TodayPresenter.streakText(
            AccountStreak(days: 5, countsToday: true),
            studiedDaysInWeek: [dayOffset(0)],
            now: thursday,
            calendar: calendar,
            locale: Locale(identifier: "vi_VN")
        )
        let doneDots = try XCTUnwrap(fiveDayDone.weekDots)
        XCTAssertEqual(doneDots.map(\.isStudied), [true, true, true, true, false, false, false])

        // Case 2: 3-day consecutive account streak ending yesterday (Mon, Tue, Wed), NOT studied on account today (Thu),
        // even though learner answered an offline local card on Thursday. Today's dot must NOT be checked while badge says "Not studied today".
        let threeDayAtRisk = TodayPresenter.streakText(
            AccountStreak(days: 3, countsToday: false),
            studiedDaysInWeek: [dayOffset(3)],
            now: thursday,
            calendar: calendar,
            locale: Locale(identifier: "vi_VN")
        )
        let riskDots = try XCTUnwrap(threeDayAtRisk.weekDots)
        XCTAssertEqual(riskDots.map(\.isStudied), [true, true, true, false, false, false, false])

        let streakView = TodayStreakView(frame: CGRect(x: 0, y: 0, width: 343, height: 140))
        streakView.configure(threeDayAtRisk)
        streakView.layoutIfNeeded()
        XCTAssertTrue(streakView.accessibilityLabel?.contains(threeDayAtRisk.detail) == true,
                      "When today is not yet counted on the account, the reminder to review an account card must remain exposed")
    }

    func test_streakViewDotLabelsStaySingleLineWithoutVerticalWrappingAtAccessibilityXXL() throws {
        let model = TodayPresenter.streakText(
            AccountStreak(days: 4, countsToday: true),
            studiedDaysInWeek: [dayOffset(0)],
            now: thursday,
            calendar: calendar,
            locale: Locale(identifier: "vi_VN")
        )
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
            .map(UIWindow.init(windowScene:))
        let host = UIViewController()
        host.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraLarge
        window?.rootViewController = host
        window?.frame = CGRect(x: 0, y: 0, width: 375, height: 600)
        window?.makeKeyAndVisible()
        defer { window?.isHidden = true; window?.rootViewController = nil }
        host.loadViewIfNeeded()
        host.view.frame = CGRect(x: 0, y: 0, width: 375, height: 600)
        let streakView = TodayStreakView()
        let resumeView = TodayResumeCardView()
        streakView.translatesAutoresizingMaskIntoConstraints = false
        resumeView.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(streakView)
        host.view.addSubview(resumeView)
        NSLayoutConstraint.activate([
            streakView.topAnchor.constraint(equalTo: host.view.topAnchor),
            streakView.leadingAnchor.constraint(equalTo: host.view.leadingAnchor, constant: 16),
            streakView.trailingAnchor.constraint(equalTo: host.view.trailingAnchor, constant: -16),
            resumeView.topAnchor.constraint(equalTo: streakView.bottomAnchor, constant: 12),
            resumeView.leadingAnchor.constraint(equalTo: host.view.leadingAnchor, constant: 16),
            resumeView.trailingAnchor.constraint(equalTo: host.view.trailingAnchor, constant: -16)
        ])
        streakView.configure(model)
        if let resume = TodayPresenter.resumeCard(from: .continueLesson(slug: "j5-01", title: "Chào hỏi", levelCode: "J5", answered: 3, total: 5)) {
            resumeView.configure(resume)
        }
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        func allLabels(in root: UIView) -> [UILabel] {
            var result: [UILabel] = []
            for sub in root.subviews {
                if let label = sub as? UILabel { result.append(label) }
                result.append(contentsOf: allLabels(in: sub))
            }
            return result
        }
        let dayLabels = allLabels(in: streakView).filter { ["T2", "T3", "T4", "T5", "T6", "T7", "CN"].contains($0.text ?? "") }
        XCTAssertEqual(dayLabels.count, 7)
        for label in dayLabels {
            XCTAssertLessThanOrEqual(label.bounds.height, 26, "Day label '\(label.text ?? "")' wrapped vertically at AX-XXL")
        }
    }
}
