//
//  LifeFeed.swift
//
//  What the Today "life hub" shows: a short list of cards, each one a topic from daily life that opens the same lesson journey
//  (story → exercises → save words → done). A card says where its facts come from: `live` (a provider through our server),
//  `onDevice` (computed on this device, e.g. the calendar or the learner's own place) or `sample` (written example content
//  shown until the server provides that topic). A sample is never presented as live data.
//

import Foundation

enum LifeTopic: String, CaseIterable, Equatable {
    case date, weather, nearby, transit, shopping, news, food, culture, money, lottery

    /// Topics in the order they are offered when the server does not choose one.
    static let defaultOrder: [LifeTopic] = [.date, .weather, .nearby, .transit, .shopping, .news, .food, .culture, .money, .lottery]

    var title: String {
        switch self {
        case .date: return NSLocalizedString("Today's date", comment: "Life topic")
        case .weather: return NSLocalizedString("Weather", comment: "Life topic")
        case .nearby: return NSLocalizedString("Near you", comment: "Life topic")
        case .transit: return NSLocalizedString("Trains", comment: "Life topic")
        case .shopping: return NSLocalizedString("Shopping", comment: "Life topic")
        case .news: return NSLocalizedString("News", comment: "Life topic")
        case .food: return NSLocalizedString("Food", comment: "Life topic")
        case .culture: return NSLocalizedString("Seasons & culture", comment: "Life topic")
        case .money: return NSLocalizedString("Money", comment: "Life topic")
        case .lottery: return NSLocalizedString("Lottery", comment: "Life topic")
        }
    }

    /// SF Symbol that stands for the topic.
    var symbol: String {
        switch self {
        case .date: return "calendar"
        case .weather: return "cloud.sun.fill"
        case .nearby: return "location.fill"
        case .transit: return "tram.fill"
        case .shopping: return "cart.fill"
        case .news: return "newspaper.fill"
        case .food: return "fork.knife"
        case .culture: return "leaf.fill"
        case .money: return "yensign.circle.fill"
        case .lottery: return "ticket.fill"
        }
    }
}

enum LifeProvenance: String, Equatable {
    case live, onDevice, sample
}

/// One short fact on a card or in a story: an optional SF Symbol and the text.
struct LifeChip: Equatable {
    let symbol: String?
    let text: String
}

enum LifeWeatherKind: String, Equatable {
    case sunny, partlyCloudy, cloudy, fog, drizzle, rain, heavyRain, showers, snow, thunderstorm

    /// From a WMO weather interpretation code (the code the server sends in `facts.weatherCode`).
    init(wmoCode: Int) {
        switch wmoCode {
        case 0, 1: self = .sunny
        case 2: self = .partlyCloudy
        case 3: self = .cloudy
        case 45, 48: self = .fog
        case 51, 53, 55, 56, 57: self = .drizzle
        case 61, 63, 66: self = .rain
        case 65, 67, 82: self = .heavyRain
        case 80, 81: self = .showers
        case 71, 73, 75, 77, 85, 86: self = .snow
        case 95, 96, 97, 99: self = .thunderstorm
        default: self = .cloudy
        }
    }
}

/// The animated picture at the top of a card and of a story.
enum LifeScene: Equatable {
    case weather(LifeWeatherKind, temperatureC: Int?)
    case date(day: Int, weekday: String)
    case place
    case transit, shopping, news, food, culture, money, lottery
}

struct LifeFeedCard: Equatable {
    enum Status: Equatable {
        case ready
        case loading
        case failed(message: String)
        /// The nearby card before the learner asked for it: nothing is read from the device until they tap.
        case needsLocation
        case locating
        case locationDenied
    }

    let id: String
    let topic: LifeTopic
    var status: Status
    let provenance: LifeProvenance
    let eyebrow: String
    let headlineJapanese: String
    let reading: String
    let summary: String
    let chips: [LifeChip]
    let meta: String
    let scene: LifeScene
    let ctaTitle: String
    /// Present when `status` is `.ready`: the lesson this card opens.
    let lesson: LifeLesson?
}
