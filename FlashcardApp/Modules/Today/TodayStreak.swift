import RxSwift
import UIKit

/// The account streak line of Today. Hidden for guests, while loading, on any failure and when there is no current streak: it never
/// blocks or replaces anything else on Today.
protocol TodayStreakLoading: AnyObject {
    var streak: AccountStreak? { get }
    var onChange: (() -> Void)? { get set }
    /// Asks the server only when the account, the day or a recorded activity made the last answer old.
    func refresh()
}

final class TodayStreakLoader: TodayStreakLoading {
    /// A streak changes at most once a day, plus when this device records one (`AccountStreakRecorder.didRecord`).
    static let maxAge: TimeInterval = 15 * 60

    private(set) var streak: AccountStreak?
    var onChange: (() -> Void)?

    private let api: BJTStreakAPIInterface
    private let accountId: () -> String?
    private let now: () -> Date
    private let calendar: () -> Calendar
    private let request = SerialDisposable()
    private var observer: NSObjectProtocol?

    init(api: BJTStreakAPIInterface = BJTLearnerAPI.shared,
         accountId: @escaping () -> String? = { AuthSession.shared.bearerToken == nil ? nil : AuthSession.shared.currentUser?.id },
         now: @escaping () -> Date = Date.init,
         calendar: @escaping () -> Calendar = { Calendar.current },
         notificationCenter: NotificationCenter = .default) {
        self.api = api
        self.accountId = accountId
        self.now = now
        self.calendar = calendar
        self.notificationCenter = notificationCenter
        observer = notificationCenter.addObserver(forName: AccountStreakRecorder.didRecord, object: nil, queue: nil) { [weak self] _ in
            // Old, but still the right account: it stays on screen until the new answer replaces it.
            self?.loaded?.at = .distantPast
        }
    }

    deinit {
        request.dispose()
        if let observer { notificationCenter.removeObserver(observer) }
    }

    private let notificationCenter: NotificationCenter
    /// Whose answer `streak` is, for which learner day, and when it arrived.
    private var loaded: (account: String, day: String, at: Date)?
    private var asking: String?

    private func set(_ value: AccountStreak?) {
        guard value != streak else { return }
        streak = value
        onChange?()
    }

    func refresh() {
        guard let account = accountId() else {
            request.disposable = Disposables.create()
            asking = nil
            loaded = nil
            return set(nil)
        }
        let calendar = calendar()
        let date = now()
        let day = AccountStreak.dayKey(date, calendar: calendar)
        if let loaded, loaded.account == account, loaded.day == day, date.timeIntervalSince(loaded.at) < Self.maxAge { return }
        if loaded?.account != account { set(nil) }
        let marker = account + "|" + day
        guard asking != marker else { return }
        asking = marker
        request.disposable = api.streaks()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] rows in
                guard let self, self.asking == marker else { return }
                self.asking = nil
                // An answer that arrives after a sign-out or an account switch is not this learner's.
                guard self.accountId() == account else { return }
                self.loaded = (account, day, self.now())
                self.set(AccountStreak.current(from: rows, now: self.now(), calendar: self.calendar()))
            }, onFailure: { [weak self] error in
                guard let self, self.asking == marker else { return }
                self.asking = nil
                logger.error("Reading the account streak failed: \(error.localizedDescription)")
                guard self.accountId() == account else { return }
                self.set(nil)
            })
    }
}

/// One quiet line under the day's progress: a flame, the server's count and whether today already counts.
final class TodayStreakView: UIView {
    private let icon = UIImageView(image: UIImage(systemName: "flame.fill"))
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        icon.tintColor = Design.Color.warning
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.isAccessibilityElement = false
        titleLabel.apply(.meaning)
        titleLabel.numberOfLines = 0
        detailLabel.apply(.metadata)
        detailLabel.numberOfLines = 0
        let text = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        text.axis = .vertical
        text.spacing = Design.Spacing.xs
        let row = UIStackView(arrangedSubviews: [icon, text])
        row.alignment = .firstBaseline
        row.spacing = Design.Spacing.s
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        isAccessibilityElement = true
        accessibilityIdentifier = "today_account_streak"
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(_ streak: TodayStreakText) {
        titleLabel.text = streak.title
        detailLabel.text = streak.detail
        accessibilityLabel = streak.title + ". " + streak.detail
    }
}
