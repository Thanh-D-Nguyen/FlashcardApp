import Foundation
import RxSwift

/// The account's study streak as the server keeps it, read on the learner's own calendar. Only the `any` streak is shown: it counts a
/// day with any activity on the account, which is what "a streak" means to the learner. Guests have no streak: nothing is computed on
/// the device and nothing local is added to the server's number.
struct AccountStreak: Equatable {
    static let activityType = "any"

    let days: Int
    /// The server already counted today, so the learner does not have to do anything to keep it.
    let countsToday: Bool

    /// `nil` when there is nothing true to show: no `any` streak, zero days, an unreadable day, or a last active day before yesterday.
    /// The server keeps the old count of a broken streak until the next activity, so that count is not shown as current.
    static func current(from streaks: [BJTStreakDTO], now: Date, calendar: Calendar) -> AccountStreak? {
        guard let row = streaks.first(where: { $0.activityType == activityType }), row.currentStreak > 0,
              let last = row.lastActiveDate, let lastDay = day(last, calendar: calendar) else { return nil }
        let today = calendar.startOfDay(for: now)
        guard let distance = calendar.dateComponents([.day], from: lastDay, to: today).day else { return nil }
        // 1: yesterday, still keepable today. 0: today. -1: a server clock a day ahead of the learner (older servers record on their
        // own clock), which is today for the learner too. Anything else is a broken streak or not a real day.
        switch distance {
        case 0, -1: return AccountStreak(days: row.currentStreak, countsToday: true)
        case 1: return AccountStreak(days: row.currentStreak, countsToday: false)
        default: return nil
        }
    }

    /// `yyyy-MM-dd` as the start of that day on the learner's calendar.
    static func day(_ text: String, calendar: Calendar) -> Date? {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let dayOfMonth = Int(parts[2]) else { return nil }
        let components = DateComponents(year: year, month: month, day: dayOfMonth)
        guard components.isValidDate(in: calendar), let date = calendar.date(from: components) else { return nil }
        return date
    }

    /// The learner's day as the server stores it.
    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

protocol AccountStreakRecording: AnyObject {
    /// A review was confirmed by the server: count the learner's day on the account streak.
    func recordReview()
}

/// Sends `streaks/record` at most once per learner day and account. The call is idempotent on the server, but it is still never retried
/// by itself: a failure leaves the day unrecorded and the next confirmed review tries again.
final class AccountStreakRecorder: AccountStreakRecording {
    static let shared = AccountStreakRecorder()
    /// Posted on the main queue after the server recorded a day; readers of the streak refresh.
    static let didRecord = Notification.Name("AccountStreakRecorder.didRecord")

    private let api: BJTStreakAPIInterface
    private let accountId: () -> String?
    private let now: () -> Date
    private let calendar: () -> Calendar
    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter

    init(api: BJTStreakAPIInterface = BJTLearnerAPI.shared,
         accountId: @escaping () -> String? = { AuthSession.shared.bearerToken == nil ? nil : AuthSession.shared.currentUser?.id },
         now: @escaping () -> Date = Date.init,
         calendar: @escaping () -> Calendar = { Calendar.current },
         defaults: UserDefaults = .standard,
         notificationCenter: NotificationCenter = .default) {
        self.api = api
        self.accountId = accountId
        self.now = now
        self.calendar = calendar
        self.defaults = defaults
        self.notificationCenter = notificationCenter
    }

    private var inFlight: String?
    private let request = SerialDisposable()

    private func key(_ account: String) -> String { "account.streak.recordedDay.\(account)" }

    func recordReview() {
        guard Thread.isMainThread else { return DispatchQueue.main.async { self.recordReview() } }
        guard let account = accountId() else { return }
        let calendar = calendar()
        let day = AccountStreak.dayKey(now(), calendar: calendar)
        let marker = account + "|" + day
        guard defaults.string(forKey: key(account)) != day, inFlight != marker else { return }
        inFlight = marker
        request.disposable = api.recordStreakActivity(.review, timeZone: calendar.timeZone)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                guard let self else { return }
                if self.inFlight == marker { self.inFlight = nil }
                self.defaults.set(day, forKey: self.key(account))
                self.notificationCenter.post(name: Self.didRecord, object: nil)
            }, onFailure: { [weak self] error in
                guard let self else { return }
                if self.inFlight == marker { self.inFlight = nil }
                logger.error("Recording the account streak failed: \(error.localizedDescription)")
            })
    }
}
