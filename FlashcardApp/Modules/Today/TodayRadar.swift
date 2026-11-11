import RxSwift
import UIKit

/// The Daily Radar card of Today. It never blocks or replaces anything: while it loads, when it fails with no recent copy, or
/// when no card is usable, it is simply not shown.
protocol TodayRadarLoading: AnyObject {
    var item: DailyRadarItem? { get }
    var onChange: (() -> Void)? { get set }
    func refresh()
}

final class TodayRadarLoader: TodayRadarLoading {
    /// Enough for a choice; about 26 KB instead of the full 156 KB list (production, 2026-11-11).
    static let limit = 20
    /// The list is editorial and changes rarely; it is asked again at most twice a day.
    static let maxAge: TimeInterval = 12 * 3600
    /// Beyond this an offline copy is too old to show.
    static let maxStaleAge: TimeInterval = 7 * 24 * 3600

    private(set) var item: DailyRadarItem?
    var onChange: (() -> Void)?

    private let api: BJTDailyRadarAPIInterface
    private let cache: DailyRadarCacheInterface
    private let now: () -> Date
    private let calendar: () -> Calendar
    private let language: () -> AppLanguage
    private let request = SerialDisposable()
    private var isAsking = false

    init(api: BJTDailyRadarAPIInterface = BJTDailyRadarAPI.shared, cache: DailyRadarCacheInterface = FileDailyRadarCache.shared,
         now: @escaping () -> Date = Date.init, calendar: @escaping () -> Calendar = { Calendar.current },
         language: @escaping () -> AppLanguage = { .current }) {
        self.api = api
        self.cache = cache
        self.now = now
        self.calendar = calendar
        self.language = language
    }

    deinit { request.dispose() }

    private func set(_ value: DailyRadarItem?) {
        guard value != item else { return }
        item = value
        onChange?()
    }

    private func show(_ data: Data) {
        guard let cards = try? BJTDailyRadarAPI.decode(data) else { return set(nil) }
        set(DailyRadarPicker.pick(cards, on: now(), calendar: calendar(), language: language()))
    }

    func refresh() {
        let date = now()
        let cached = cache.load()
        let age = cached.map { date.timeIntervalSince($0.savedAt) }
        if let cached, let age, age >= 0, age < Self.maxStaleAge { show(cached.data) }
        if let age, age >= 0, age < Self.maxAge { return }
        guard !isAsking else { return }
        isAsking = true
        request.disposable = api.cards(limit: Self.limit)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] answer in
                guard let self else { return }
                self.isAsking = false
                do { try self.cache.save(answer.data, at: self.now()) } catch {
                    logger.error("Saving the Daily Radar copy failed: \(error.localizedDescription)")
                }
                self.show(answer.data)
            }, onFailure: { [weak self] error in
                guard let self else { return }
                self.isAsking = false
                logger.error("Reading the Daily Radar failed: \(error.localizedDescription)")
                // A recent copy stays on screen; without one there is nothing to show.
                if cached == nil || (age ?? .infinity) >= Self.maxStaleAge { self.set(nil) }
            })
    }
}
