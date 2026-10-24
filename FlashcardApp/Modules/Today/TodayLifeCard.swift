import Foundation
import RxSwift

/// "Learn from Life" on Today: one lesson offer under the review area. It loads on its own, so a slow or failed request never
/// changes what the review block says, and the review block never waits for it.
struct TodayLifeCard: Equatable {
    let eyebrow: String
    let headline: String
    let reading: String
    /// The first sentence of the lesson in the learner's language: one real fact.
    let summary: String
    let facts: String
    let meta: String
    let tags: [String]
    let ctaTitle: String
}

struct TodayLifeSection: Equatable {
    enum Content: Equatable {
        case loading
        case loaded(TodayLifeCard)
        case failed(title: String, message: String)
    }

    var content: Content
    /// Value of the "Explore topics" row: the topic and the city the learner picked.
    var exploreValue: String
}

protocol TodayLifeLoading: AnyObject {
    /// `nil` when nothing is offered (the server does not provide the lesson): the section is then hidden.
    var section: TodayLifeSection? { get }
    var lesson: LifeLesson? { get }
    var cityID: String { get }
    var onChange: (() -> Void)? { get set }
    /// Shows the lesson already held while it is current; otherwise asks the server once.
    func refresh()
    func retry()
    func selectCity(_ id: String)
}

final class TodayLifeLoader: TodayLifeLoading {
    private let interactor: LifeLessonInteractorInterface
    private let ownerKey: () -> String
    private let now: () -> Date
    private let language: () -> AppLanguage

    private(set) var section: TodayLifeSection?
    private(set) var lesson: LifeLesson?
    var onChange: (() -> Void)?

    private var loadingCityID: String?
    private var notOfferedUntil: Date?
    /// After a failure the server is left alone for a moment: opening Today again must not hammer a rate-limited or broken
    /// server. The learner's own "Try again" is never held back.
    private var retryNotBefore: Date?
    private static let retryPause: TimeInterval = 60
    private let request = SerialDisposable()

    init(interactor: LifeLessonInteractorInterface = LifeLessonInteractor(),
         ownerKey: @escaping () -> String = { AuthSession.shared.currentUser?.id ?? "" },
         now: @escaping () -> Date = Date.init,
         language: @escaping () -> AppLanguage = { AppLanguage.current }) {
        self.interactor = interactor
        self.ownerKey = ownerKey
        self.now = now
        self.language = language
    }

    deinit { request.dispose() }

    var cityID: String { interactor.selectedCityID(ownerKey: ownerKey()) }

    private static func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    /// The Japan calendar day: the lesson describes it, wherever the learner is.
    static func japanDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func isToday(_ lesson: LifeLesson) -> Bool { lesson.facts?.date == Self.japanDay(now()) }

    private func isCurrent(_ lesson: LifeLesson, city: String) -> Bool {
        lesson.cityID == city && isToday(lesson) && now() < lesson.source.expiresAt
    }

    private func exploreValue(_ city: String) -> String {
        let name = LifeCity.city(id: city)?.displayName(language()) ?? city
        return "\(Self.text("Weather")) · \(name)"
    }

    func refresh() {
        let city = cityID
        if let until = notOfferedUntil, now() < until {
            section = nil
            onChange?()
            return
        }
        if let lesson, isCurrent(lesson, city: city) {
            section = TodayLifeSection(content: .loaded(Self.card(for: lesson, language: language())), exploreValue: exploreValue(city))
            onChange?()
            return
        }
        guard loadingCityID != city else { return }
        if let until = retryNotBefore, now() < until, section != nil {
            onChange?()
            return
        }
        loadingCityID = city
        // A lesson of the same city and the same Japan day stays on screen while it refreshes.
        if let held = lesson, held.cityID == city, isToday(held) {
            section = TodayLifeSection(content: .loaded(Self.card(for: held, language: language())), exploreValue: exploreValue(city))
        } else {
            lesson = nil
            section = TodayLifeSection(content: .loading, exploreValue: exploreValue(city))
        }
        onChange?()
        request.disposable = interactor.loadWeather(cityID: city)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] lesson in
                guard let self, self.loadingCityID == city else { return }
                self.loadingCityID = nil
                // A lesson of another Japan day must never be offered as today's, whatever the server believes.
                guard lesson.facts?.date == Self.japanDay(self.now()) else { return self.fail(LearnerAPIError.invalidResponse, city: city) }
                self.notOfferedUntil = nil
                self.retryNotBefore = nil
                self.lesson = lesson
                self.section = TodayLifeSection(content: .loaded(Self.card(for: lesson, language: self.language())), exploreValue: self.exploreValue(city))
                self.onChange?()
            }, onFailure: { [weak self] error in
                guard let self, self.loadingCityID == city else { return }
                self.loadingCityID = nil
                self.fail(error, city: city)
            })
    }

    private func fail(_ error: Error, city: String) {
        retryNotBefore = now().addingTimeInterval(Self.retryPause)
        if case LearnerAPIError.notFound = error {
            // The server does not offer weather lessons (no data licence configured): hide the section, ask again later.
            notOfferedUntil = now().addingTimeInterval(3600)
            section = nil
        } else if let held = lesson, held.cityID == city, isToday(held) {
            // The refresh failed but today's lesson is still right: keep it.
            section = TodayLifeSection(content: .loaded(Self.card(for: held, language: language())), exploreValue: exploreValue(city))
        } else {
            logger.error("Loading the weather lesson failed: \(error.localizedDescription)")
            section = TodayLifeSection(content: .failed(title: Self.text("Today's lesson isn't available"),
                                                        message: LifeLessonPresenter.message(for: error) + " " + Self.text("Your reviews are not affected.")),
                                       exploreValue: exploreValue(city))
        }
        onChange?()
    }

    func retry() {
        notOfferedUntil = nil
        retryNotBefore = nil
        loadingCityID = nil
        request.disposable = Disposables.create()
        refresh()
    }

    func selectCity(_ id: String) {
        guard LifeCity.city(id: id) != nil, id != cityID else { return }
        interactor.setSelectedCityID(id, ownerKey: ownerKey())
        // A request for the previous city is cancelled; its answer must not replace this one.
        loadingCityID = nil
        retryNotBefore = nil
        request.disposable = Disposables.create()
        refresh()
    }

    // MARK: Card

    static func card(for lesson: LifeLesson, language: AppLanguage) -> TodayLifeCard {
        let summary = (lesson.sentences.first { $0.id == "weather" } ?? lesson.sentences[0]).translation.resolved(language)
        let facts = lesson.chips.map(\.text)
        let time = LifeLessonPresenter.timeText(lesson.source.observedAt, language: language)
        var tags: [String] = []
        if lesson.source.freshness == .stale { tags.append(text("Not the latest")) }
        if lesson.source.licenseStatus == .nonCommercialDevOnly { tags.append(text("Development source")) }
        let minutes = String.localizedStringWithFormat(text("About %lld minutes"), lesson.estimatedMinutes)
        return TodayLifeCard(
            eyebrow: text("LEARN FROM LIFE"), headline: lesson.titleJapanese, reading: lesson.titleReading,
            summary: summary, facts: facts.joined(separator: " · "),
            meta: String(format: text("%1$@ · observed %2$@ (Japan time)"), lesson.source.providerName, time) + " · " + minutes + " · " + lesson.level,
            tags: tags, ctaTitle: text("Learn this lesson"))
    }
}
