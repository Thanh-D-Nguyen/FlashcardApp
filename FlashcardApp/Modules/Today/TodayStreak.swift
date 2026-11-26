import RxSwift
import UIKit

/// One day in the 7-day streak strip (Monday–Sunday on the learner's calendar), built strictly from real recorded study days.
struct TodayWeekDayDot: Equatable {
    let dayStart: Date
    let shortLabel: String
    let accessibilityDayName: String
    let isStudied: Bool
    let isToday: Bool
    let isFuture: Bool
}

enum TodayStreakStripBuilder {
    /// Monday 00:00 of the calendar week containing `date`, in `calendar.timeZone`.
    static func currentWeekStart(for date: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay) // 1 = Sun, 2 = Mon, ... 7 = Sat
        let offsetFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -offsetFromMonday, to: startOfDay) ?? startOfDay
    }

    /// Builds the 7 dots for the current week ONLY when real per-day history exists on this device.
    /// Returns `nil` when there is no per-day history so the UI never displays fake dots.
    static func weekDots(streak: AccountStreak, studiedDaysInWeek: Set<Date>, now: Date,
                         calendar: Calendar, locale: Locale = AppLanguage.current.locale) -> [TodayWeekDayDot]? {
        guard !studiedDaysInWeek.isEmpty else { return nil }
        let weekStart = currentWeekStart(for: now, calendar: calendar)
        let todayStart = calendar.startOfDay(for: now)
        let normalizedStudied = Set(studiedDaysInWeek.map { calendar.startOfDay(for: $0) })
        let streakEnd = streak.countsToday
            ? todayStart
            : (calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart)
        let streakStart = streak.days > 0
            ? (calendar.date(byAdding: .day, value: -(streak.days - 1), to: streakEnd) ?? streakEnd)
            : nil

        let shortFormatter = DateFormatter()
        shortFormatter.locale = locale
        shortFormatter.calendar = calendar
        shortFormatter.timeZone = calendar.timeZone
        shortFormatter.setLocalizedDateFormatFromTemplate("EEEEE")

        let fullFormatter = DateFormatter()
        fullFormatter.locale = locale
        fullFormatter.calendar = calendar
        fullFormatter.timeZone = calendar.timeZone
        fullFormatter.setLocalizedDateFormatFromTemplate("EEEE")

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let dayStart = calendar.startOfDay(for: day)
            let isToday = dayStart == todayStart
            let isFuture = dayStart > todayStart
            let inServerStreak = streakStart.map { dayStart >= $0 && dayStart <= streakEnd } ?? false
            let isStudied: Bool
            if isFuture {
                isStudied = false
            } else if isToday {
                isStudied = streak.countsToday
            } else {
                isStudied = inServerStreak || normalizedStudied.contains(dayStart)
            }
            return TodayWeekDayDot(
                dayStart: dayStart,
                shortLabel: shortFormatter.string(from: dayStart),
                accessibilityDayName: fullFormatter.string(from: dayStart),
                isStudied: isStudied,
                isToday: isToday,
                isFuture: isFuture
            )
        }
    }
}

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

/// Streak strip placed directly under the "Hôm nay" header: flame icon, real streak count, studied/not-studied today badge,
/// and 7 dots for the current week when real per-day history is available on this device (otherwise no fake dots).
final class TodayStreakView: UIView {
    private let flameBox = UIView()
    private let icon = UIImageView(image: UIImage(systemName: "flame.fill"))
    private let titleLabel = UILabel()
    private let statusBadge = UIView()
    private let statusLabel = UILabel()
    private let headerRow = UIStackView()
    private let topStack = UIStackView()
    private let detailLabel = UILabel()
    private let dotsRow = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyCardSurface(radius: Design.Radius.card)

        flameBox.backgroundColor = Design.Color.statusFill(Design.Color.warning)
        flameBox.layer.cornerRadius = Design.Radius.chip
        flameBox.layer.cornerCurve = .continuous
        flameBox.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = Design.Color.warning
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        icon.translatesAutoresizingMaskIntoConstraints = false
        flameBox.addSubview(icon)
        NSLayoutConstraint.activate([
            flameBox.widthAnchor.constraint(equalToConstant: 36),
            flameBox.heightAnchor.constraint(equalToConstant: 36),
            icon.centerXAnchor.constraint(equalTo: flameBox.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: flameBox.centerYAnchor)
        ])

        titleLabel.apply(.title)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        statusBadge.layer.cornerRadius = Design.Radius.badge
        statusBadge.layer.cornerCurve = .continuous
        statusLabel.apply(.eyebrow)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusBadge.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: statusBadge.topAnchor, constant: Design.Spacing.xs),
            statusLabel.bottomAnchor.constraint(equalTo: statusBadge.bottomAnchor, constant: -Design.Spacing.xs),
            statusLabel.leadingAnchor.constraint(equalTo: statusBadge.leadingAnchor, constant: Design.Spacing.s),
            statusLabel.trailingAnchor.constraint(equalTo: statusBadge.trailingAnchor, constant: -Design.Spacing.s)
        ])
        statusBadge.setContentHuggingPriority(.required, for: .horizontal)
        statusBadge.setContentCompressionResistancePriority(.required, for: .horizontal)

        let titleAndIcon = UIStackView(arrangedSubviews: [flameBox, titleLabel])
        titleAndIcon.alignment = .center
        titleAndIcon.spacing = Design.Spacing.m

        headerRow.spacing = Design.Spacing.s
        [titleAndIcon, statusBadge].forEach(headerRow.addArrangedSubview)

        detailLabel.apply(.metadata)

        dotsRow.axis = .horizontal
        dotsRow.distribution = .fillEqually
        dotsRow.alignment = .center
        dotsRow.spacing = Design.Spacing.xs
        dotsRow.isHidden = true

        topStack.axis = .vertical
        topStack.spacing = Design.Spacing.m
        [headerRow, detailLabel, dotsRow].forEach(topStack.addArrangedSubview)
        topStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topStack)
        NSLayoutConstraint.activate([
            topStack.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.m),
            topStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.m),
            topStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.l),
            topStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.l)
        ])

        isAccessibilityElement = true
        accessibilityIdentifier = "today_account_streak"
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: TodayStreakView, _) in
            view.updateAxis()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func updateAxis() {
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        headerRow.axis = isAX ? .vertical : .horizontal
        headerRow.alignment = isAX ? .leading : .center
    }

    func configure(_ streak: TodayStreakText) {
        titleLabel.text = streak.title
        let statusTint = streak.countsToday ? Design.Color.success : Design.Color.warning
        statusLabel.text = streak.todayStatusText
        statusLabel.textColor = statusTint
        statusBadge.backgroundColor = Design.Color.statusFill(statusTint)

        if let dots = streak.weekDots, !dots.isEmpty {
            detailLabel.text = streak.detail
            detailLabel.isHidden = streak.countsToday
            dotsRow.isHidden = false
            dotsRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for dot in dots {
                dotsRow.addArrangedSubview(TodayStreakDotView(dot: dot))
            }
            let studiedNames = dots.filter(\.isStudied).map(\.accessibilityDayName).joined(separator: ", ")
            let reminder = streak.countsToday ? "" : streak.detail
            accessibilityLabel = [streak.title, streak.todayStatusText, reminder, studiedNames].filter { !$0.isEmpty }.joined(separator: ". ")
        } else {
            dotsRow.isHidden = true
            detailLabel.isHidden = false
            detailLabel.text = streak.detail
            accessibilityLabel = [streak.title, streak.todayStatusText, streak.detail].filter { !$0.isEmpty }.joined(separator: ". ")
        }
    }
}

private final class TodayStreakDotView: UIView {
    private let circle = UIView()
    private let check = UIImageView(image: UIImage(systemName: "checkmark"))
    private let dayLabel = UILabel()
    private let dot: TodayWeekDayDot

    init(dot: TodayWeekDayDot) {
        self.dot = dot
        super.init(frame: .zero)
        isAccessibilityElement = false

        circle.layer.cornerRadius = 12
        circle.translatesAutoresizingMaskIntoConstraints = false
        check.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        check.tintColor = Design.Color.onAccent
        check.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(check)

        dayLabel.font = UIFontMetrics(forTextStyle: .footnote)
            .scaledFont(for: .systemFont(ofSize: 12, weight: .medium), maximumPointSize: 18)
        dayLabel.adjustsFontForContentSizeCategory = true
        dayLabel.numberOfLines = 1
        dayLabel.adjustsFontSizeToFitWidth = true
        dayLabel.minimumScaleFactor = 0.7
        dayLabel.textAlignment = .center
        dayLabel.text = dot.shortLabel
        dayLabel.textColor = dot.isToday ? Design.Color.accent : Design.Color.textSecondary

        let column = UIStackView(arrangedSubviews: [circle, dayLabel])
        column.axis = .vertical
        column.alignment = .center
        column.spacing = Design.Spacing.xs
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)

        NSLayoutConstraint.activate([
            circle.widthAnchor.constraint(equalToConstant: 24),
            circle.heightAnchor.constraint(equalToConstant: 24),
            check.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            check.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        applyStyle()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: TodayStreakDotView, _) in
            view.applyStyle()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func applyStyle() {
        if dot.isStudied {
            circle.backgroundColor = Design.Color.warning
            circle.layer.borderWidth = 0
            circle.layer.borderColor = nil
            check.isHidden = false
            check.tintColor = .white
        } else if dot.isToday {
            circle.backgroundColor = .clear
            circle.layer.borderWidth = 2
            circle.layer.borderColor = Design.Color.accent.resolvedColor(with: traitCollection).cgColor
            check.isHidden = true
        } else {
            circle.backgroundColor = Design.Color.surfaceTint
            circle.layer.borderWidth = 0
            circle.layer.borderColor = nil
            check.isHidden = true
        }
    }
}
