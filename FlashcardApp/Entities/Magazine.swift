//
//  Magazine.swift
//
//  The website's Magazine as the app sees it: a daily feed of short Japanese-learning articles. Every article has a
//  Japanese title and a Vietnamese one, a body that depends on its kind, a small vocabulary and a quiz. The server
//  publishes no English text, so English readers see the Vietnamese translation next to the Japanese.
//
//  Loto articles (`magazine_loto*`) are number sets for a lottery. They are not part of the magazine list: they have their
//  own screen (`Modules/Loto`). An unknown kind is dropped rather than guessed at.
//

import Foundation

enum MagazineKind: String, CaseIterable, Equatable {
    case vocabulary, weather, horoscope, businessPhrase

    /// `widgetKind` of an article (`magazine_vocab`); the bare name is accepted too, as the website's own filters use it.
    init?(widgetKind: String) {
        switch widgetKind {
        case "magazine_vocab", "vocab": self = .vocabulary
        case "magazine_weather", "weather": self = .weather
        case "magazine_horoscope", "horoscope": self = .horoscope
        case "magazine_bjt_phrase", "bjt_phrase": self = .businessPhrase
        default: return nil
        }
    }

    /// Value of the `kind` query parameter.
    var apiValue: String {
        switch self {
        case .vocabulary: return "vocab"
        case .weather: return "weather"
        case .horoscope: return "horoscope"
        case .businessPhrase: return "bjt_phrase"
        }
    }

    var title: String {
        switch self {
        case .vocabulary: return NSLocalizedString("Vocabulary", comment: "")
        case .weather: return NSLocalizedString("Weather", comment: "Life topic")
        case .horoscope: return NSLocalizedString("Horoscope", comment: "Magazine kind")
        case .businessPhrase: return NSLocalizedString("Workplace Japanese", comment: "Magazine kind")
        }
    }

    /// SF Symbol that stands for the kind.
    var symbol: String {
        switch self {
        case .vocabulary: return "character.book.closed.fill"
        case .weather: return "cloud.sun.fill"
        case .horoscope: return "sparkles"
        case .businessPhrase: return "briefcase.fill"
        }
    }
}

/// A calendar day in Japan, which is how the magazine dates its articles (the server publishes at 06:00 JST).
struct MagazineDay: Equatable, Comparable {
    let year: Int
    let month: Int
    let day: Int

    /// `2026-10-26`, or an ISO instant whose first ten characters are the day.
    init?(key: String) {
        let head = key.prefix(10)
        let parts = head.split(separator: "-", omittingEmptySubsequences: false)
        guard head.count == 10, parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    static let japan: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    static func today(now: Date = Date()) -> MagazineDay {
        let parts = japan.dateComponents([.year, .month, .day], from: now)
        return MagazineDay(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    private init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    static func < (lhs: MagazineDay, rhs: MagazineDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    enum Style {
        /// "26 Oct", "26 thg 10", "10月26日".
        case short
        /// "Monday, 26 October 2026".
        case full
    }

    func formatted(_ style: Style, locale: Locale = AppLanguage.current.locale) -> String {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        guard let date = utc.date(from: DateComponents(year: year, month: month, day: day)) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = .gmt
        formatter.setLocalizedDateFormatFromTemplate(style == .short ? "MMMd" : "yMMMMEEEEd")
        return formatter.string(from: date)
    }
}

struct MagazineSummary: Equatable {
    let id: String
    let slug: String
    let kind: MagazineKind
    let titleJapanese: String
    let titleVietnamese: String
    let summary: String?
    let level: String?
    let day: MagazineDay?
    /// Headwords of the article's vocabulary, for a preview line.
    let words: [String]
}

struct MagazinePage: Equatable {
    let items: [MagazineSummary]
    let page: Int
    let hasMore: Bool
}

struct MagazineArticle: Equatable {
    struct Vocabulary: Equatable {
        let id: String
        let japanese: String
        let reading: String
        let meaning: String
        let level: String?
        let example: String?
        let exampleMeaning: String?
    }

    struct Option: Equatable {
        let text: String
        let isCorrect: Bool
    }

    struct Question: Equatable {
        let promptJapanese: String
        let prompt: String?
        let options: [Option]
        let explanationJapanese: String?
        let explanation: String?
    }

    struct DialogueLine: Equatable {
        let speaker: String?
        let japanese: String
        let meaning: String?
    }

    struct Weather: Equatable {
        let city: String?
        let descriptionJapanese: String
        let description: String?
        let symbol: String
        let highC: Int?
        let lowC: Int?
        let humidityPercent: Int?
        let uvIndex: Int?
        let adviceJapanese: String?
        let advice: String?
    }

    struct Fortune: Equatable {
        let sign: String
        let signMeaning: String?
        let reading: String?
        let fortune: String?
        let fortuneMeaning: String?
        let message: String?
        let messageMeaning: String?
        let luckyColor: String?
        let luckyNumber: Int?
    }

    struct Situation: Equatable {
        let japanese: String
        let meaning: String?
    }

    enum Formality: Equatable {
        case polite, casual, formal, humble
    }

    /// A part of the body, in the order it is read.
    enum Block: Equatable {
        case phrase(japanese: String, reading: String?, literalMeaning: String?, formality: Formality?)
        case weather(Weather)
        case passage(japanese: String?, meaning: String?)
        case dialogue([DialogueLine])
        case usage(japanese: String?, meaning: String?)
        case situations([Situation])
        case horoscope([Fortune])
    }

    let id: String
    let slug: String
    let kind: MagazineKind
    let titleJapanese: String
    let titleVietnamese: String
    let summaryJapanese: String?
    let summaryVietnamese: String?
    let level: String?
    let blocks: [Block]
    let vocabulary: [Vocabulary]
    let questions: [Question]
}
