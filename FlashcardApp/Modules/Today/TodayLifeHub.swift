//
//  TodayLifeHub.swift
//
//  The life hub of Today: the date header and the cards of daily life. Where each card comes from, in this order of preference:
//
//    1. the server's `/api/life/feed` when it offers one (the app is ready for it; see docs/plans/today-life-hub-server-needs.md);
//    2. facts the device can work out itself: the date and, when the learner asks, the place they are in;
//    3. the weather lesson from the server's weather route;
//    4. clearly labelled example lessons for the topics nobody provides yet.
//
//  The review block of Today never waits for any of this and is never changed by it.
//

import Foundation
import RxSwift

struct TodayDateHeader: Equatable {
    let greeting: String
    let greetingReading: String
    /// "10月24日（土）"
    let dateText: String
    let eraText: String
    let day: Int
    let month: Int
    let weekdayShort: String
    /// SF Symbol for the part of the day.
    let symbol: String
    let accessibilityLabel: String
}

struct TodayHubSection: Equatable {
    var header: TodayDateHeader
    var cityName: String
    var cards: [LifeFeedCard]
}

protocol TodayLifeHubLoading: AnyObject {
    var section: TodayHubSection? { get }
    var cityID: String { get }
    var onChange: (() -> Void)? { get set }
    /// The lesson a ready card opens.
    func lesson(forCard id: String) -> LifeLesson?
    /// Rebuilds what can be rebuilt now and asks the server only when its answer is missing or old.
    func refresh()
    func retry()
    func selectCity(_ id: String)
    /// The learner tapped "use my location": the only place the position is ever read.
    func requestLocation()
}

protocol LifeHubPreferencesInterface: AnyObject {
    /// Example lessons for topics nobody provides yet. On unless switched off (`-com.flashcardapp.life.samples NO`).
    var showsSamples: Bool { get }
    /// The learner has asked for "near you" before: next time, if the system already allows it, it is read without asking again.
    func nearbyOptedIn(ownerKey: String) -> Bool
    func setNearbyOptedIn(_ value: Bool, ownerKey: String)
}

final class UserDefaultsLifeHubPreferences: LifeHubPreferencesInterface {
    static let shared = UserDefaultsLifeHubPreferences()
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var showsSamples: Bool { defaults.object(forKey: "com.flashcardapp.life.samples") as? Bool ?? true }
    func nearbyOptedIn(ownerKey: String) -> Bool { defaults.bool(forKey: "com.flashcardapp.life.nearby.\(ownerKey)") }
    func setNearbyOptedIn(_ value: Bool, ownerKey: String) { defaults.set(value, forKey: "com.flashcardapp.life.nearby.\(ownerKey)") }
}

final class TodayLifeHubLoader: TodayLifeHubLoading {
    private enum PlaceState: Equatable {
        case notAsked, locating, ready(LifePlace), failed(LifePlaceError)
    }

    private enum RemoteState {
        case unknown, loading, available
        case unavailable(until: Date)
    }

    private let weather: TodayLifeLoading
    private let remote: BJTLifeFeedAPIInterface
    private let places: LifePlaceProviding
    private let preferences: LifeHubPreferencesInterface
    private let ownerKey: () -> String
    private let now: () -> Date
    private let calendar: Calendar
    private let language: () -> AppLanguage

    private(set) var section: TodayHubSection?
    var onChange: (() -> Void)?

    private var place: PlaceState = .notAsked
    private var remoteCards: [LifeFeedCard] = []
    private var remoteState: RemoteState = .unknown
    private var remoteCityID: String?
    private var remoteDay: String?
    private var lessons: [String: LifeLesson] = [:]
    private let placeRequest = SerialDisposable()
    private let remoteRequest = SerialDisposable()

    init(weather: TodayLifeLoading, remote: BJTLifeFeedAPIInterface = BJTLifeFeedAPI.shared, places: LifePlaceProviding = CoreLocationPlaceProvider.shared,
         preferences: LifeHubPreferencesInterface = UserDefaultsLifeHubPreferences.shared,
         ownerKey: @escaping () -> String = { AuthSession.shared.currentUser?.id ?? "" },
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current, language: @escaping () -> AppLanguage = { AppLanguage.current }) {
        self.weather = weather
        self.remote = remote
        self.places = places
        self.preferences = preferences
        self.ownerKey = ownerKey
        self.now = now
        self.calendar = calendar
        self.language = language
        weather.onChange = { [weak self] in self?.rebuild() }
    }

    deinit {
        placeRequest.dispose()
        remoteRequest.dispose()
    }

    var cityID: String { weather.cityID }

    func lesson(forCard id: String) -> LifeLesson? { lessons[id] }

    private static func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    // MARK: Refresh

    func refresh() {
        loadRemoteIfNeeded()
        // Asked before and still allowed by the system: read the place again without a second question. Never a first-time prompt.
        if place == .notAsked, preferences.nearbyOptedIn(ownerKey: ownerKey()), places.authorization == .authorized { startLocating() }
        weather.refresh()   // calls back into `rebuild`
        rebuild()
    }

    func retry() {
        remoteState = .unknown
        remoteRequest.disposable = Disposables.create()
        remoteCityID = nil
        if case .failed(let error) = place, error != .denied { startLocating() }
        weather.retry()
        loadRemoteIfNeeded()
        rebuild()
    }

    func selectCity(_ id: String) {
        remoteCards = []
        remoteState = .unknown
        remoteRequest.disposable = Disposables.create()
        remoteCityID = nil
        weather.selectCity(id)
        loadRemoteIfNeeded()
        rebuild()
    }

    func requestLocation() {
        preferences.setNearbyOptedIn(true, ownerKey: ownerKey())
        startLocating()
        rebuild()
    }

    private func startLocating() {
        if place == .locating { return }
        place = .locating
        placeRequest.disposable = places.currentPlace()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] found in
                self?.place = .ready(found)
                self?.rebuild()
            }, onFailure: { [weak self] error in
                self?.place = .failed(error as? LifePlaceError ?? .unavailable)
                self?.rebuild()
            })
    }

    // MARK: Server feed

    private func dayKey() -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: now())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private func loadRemoteIfNeeded() {
        let city = cityID
        if case .unavailable(let until) = remoteState, now() < until { return }
        if case .loading = remoteState, remoteCityID == city { return }
        if case .available = remoteState, remoteCityID == city, remoteDay == dayKey() { return }
        remoteState = .loading
        remoteCityID = city
        remoteRequest.disposable = remote.feed(cityID: city)
            .map { try LifeFeedMapper.cards(from: $0, requestedCityID: city, language: AppLanguage.current) }
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] cards in
                guard let self, self.remoteCityID == city else { return }
                self.remoteCards = cards
                self.remoteState = cards.isEmpty ? .unavailable(until: self.now().addingTimeInterval(300)) : .available
                self.remoteDay = self.dayKey()
                self.rebuild()
            }, onFailure: { [weak self] error in
                guard let self, self.remoteCityID == city else { return }
                // 404: this server has no feed (yet): ask again in an hour. Anything else: soon.
                let pause: TimeInterval
                if case LearnerAPIError.notFound = error { pause = 3600 } else { pause = 60 }
                self.remoteCards = []
                self.remoteState = .unavailable(until: self.now().addingTimeInterval(pause))
                self.rebuild()
            })
    }

    // MARK: Cards

    private func rebuild() {
        let language = language()
        let current = now()
        var cards: [LifeFeedCard] = []
        let serverCards = remoteCards
        var serverHasFeed = false
        if case .available = remoteState { serverHasFeed = true }
        func server(_ topic: LifeTopic) -> LifeFeedCard? { serverHasFeed ? serverCards.first { $0.topic == topic } : nil }

        // Date: the server's (it can know holidays) or the calendar of this device.
        if let card = server(.date) {
            cards.append(card)
        } else if let lesson = LifeDateStory.lesson(now: current, calendar: calendar) {
            cards.append(LifeFeedMapper.card(for: lesson, language: language))
        }
        // Weather: the server's feed or the weather route.
        if let card = server(.weather) {
            cards.append(card)
        } else if let card = weatherCard(language: language) {
            cards.append(card)
        }
        // Near you is always worked out on the device: where the learner is never goes to the server.
        cards.append(nearbyCard(now: current, language: language))
        // The rest: the server's list in its order, or labelled examples.
        if serverHasFeed {
            let known: Set<LifeTopic> = [.date, .weather, .nearby]
            cards += serverCards.filter { !known.contains($0.topic) }
        } else if preferences.showsSamples {
            cards += SampleLifeContent.lessons(now: current, calendar: calendar).map { LifeFeedMapper.card(for: $0, language: language) }
        }

        lessons = [:]
        for card in cards { if let lesson = card.lesson { lessons[card.id] = lesson } }
        let city = LifeCity.city(id: cityID)?.displayName(language) ?? cityID
        section = TodayHubSection(header: Self.header(now: current, calendar: calendar), cityName: city, cards: cards)
        onChange?()
    }

    private func weatherCard(language: AppLanguage) -> LifeFeedCard? {
        guard let section = weather.section else { return nil }
        switch section.content {
        case .loaded:
            guard let lesson = weather.lesson else { return nil }
            return LifeFeedMapper.card(for: lesson, language: language)
        case .loading:
            return placeholder(topic: .weather, id: "weather:loading", headline: "今日の天気", reading: "きょうのてんき", status: .loading,
                               summary: Self.text("Loading today's weather lesson…"), cta: "")
        case .failed(_, let message):
            return placeholder(topic: .weather, id: "weather:failed", headline: "今日の天気", reading: "きょうのてんき", status: .failed(message: message),
                               summary: message, cta: Self.text("Try again"))
        }
    }

    private func nearbyCard(now: Date, language: AppLanguage) -> LifeFeedCard {
        let headline = "近くの場所", reading = "ちかくのばしょ"
        switch place {
        case .notAsked:
            return placeholder(topic: .nearby, id: "nearby:ask", headline: headline, reading: reading, status: .needsLocation,
                               summary: Self.text("Learn the Japanese for the places around you."), cta: Self.text("Use my location"),
                               meta: Self.text("Asked once, only when you tap. Nothing is stored or sent."))
        case .locating:
            return placeholder(topic: .nearby, id: "nearby:locating", headline: headline, reading: reading, status: .locating,
                               summary: Self.text("Finding the places around you…"), cta: "")
        case .ready(let found):
            if let lesson = LifeNearbyStory.lesson(place: found, now: now, calendar: calendar) { return LifeFeedMapper.card(for: lesson, language: language) }
            return placeholder(topic: .nearby, id: "nearby:empty", headline: headline, reading: reading, status: .failed(message: LifePlaceError.nothingNearby.errorDescription ?? ""),
                               summary: LifePlaceError.nothingNearby.errorDescription ?? "", cta: Self.text("Try again"))
        case .failed(let error):
            let message = error.errorDescription ?? ""
            return placeholder(topic: .nearby, id: "nearby:failed", headline: headline, reading: reading,
                               status: error == .denied ? .locationDenied : .failed(message: message), summary: message,
                               cta: error == .denied ? Self.text("Open Settings") : Self.text("Try again"))
        }
    }

    private func placeholder(topic: LifeTopic, id: String, headline: String, reading: String, status: LifeFeedCard.Status, summary: String, cta: String,
                             meta: String = "") -> LifeFeedCard {
        LifeFeedCard(id: id, topic: topic, status: status, provenance: topic == .weather ? .live : .onDevice, eyebrow: topic.title.uppercased(),
                     headlineJapanese: headline, reading: reading, summary: summary, chips: [], meta: meta,
                     scene: topic == .nearby ? .place : .weather(.cloudy, temperatureC: nil), ctaTitle: cta, lesson: nil)
    }

    // MARK: Header

    static func header(now: Date, calendar: Calendar) -> TodayDateHeader {
        let c = calendar.dateComponents([.year, .month, .day, .weekday, .hour], from: now)
        let weekday = JapaneseCalendar.weekday(c.weekday ?? 1) ?? JapaneseCalendar.Phrase(japanese: "日曜日", reading: "にちようび", vi: "", en: "")
        let greeting = JapaneseCalendar.greeting(hour: c.hour ?? 12)
        let short = String(weekday.japanese.prefix(1))
        let dateText = "\(c.month ?? 1)月\(c.day ?? 1)日（\(short)）"
        let era = JapaneseCalendar.reiwa(gregorianYear: c.year ?? 2026)?.text ?? ""
        let hour = c.hour ?? 12
        let symbol = (6..<17).contains(hour) ? "sun.max.fill" : (17..<19).contains(hour) ? "sunset.fill" : "moon.stars.fill"
        return TodayDateHeader(greeting: greeting.japanese, greetingReading: greeting.reading, dateText: dateText, eraText: era,
                               day: c.day ?? 1, month: c.month ?? 1, weekdayShort: short, symbol: symbol,
                               accessibilityLabel: "\(greeting.japanese). \(dateText) \(weekday.japanese), \(era)")
    }
}
