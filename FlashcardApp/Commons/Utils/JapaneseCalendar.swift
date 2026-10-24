//
//  JapaneseCalendar.swift
//
//  Dates, numbers and seasons the way Japanese says them. Pure functions with no clock or locale inside, so what the Today
//  "date" lesson teaches can be checked line by line. The readings are written in hiragana.
//

import Foundation

enum JapaneseNumbers {
    private static let digits = ["れい", "いち", "に", "さん", "よん", "ご", "ろく", "なな", "はち", "きゅう"]
    private static let tens = ["", "じゅう", "にじゅう", "さんじゅう", "よんじゅう", "ごじゅう", "ろくじゅう", "ななじゅう", "はちじゅう", "きゅうじゅう"]
    private static let hundreds = ["", "ひゃく", "にひゃく", "さんびゃく", "よんひゃく", "ごひゃく", "ろっぴゃく", "ななひゃく", "はっぴゃく", "きゅうひゃく"]
    private static let thousands = ["", "せん", "にせん", "さんぜん", "よんせん", "ごせん", "ろくせん", "ななせん", "はっせん", "きゅうせん"]

    /// 0...9999 in hiragana. Anything else comes back as plain digits rather than a wrong reading.
    static func reading(_ n: Int) -> String {
        guard (0...9999).contains(n) else { return String(n) }
        if n == 0 { return digits[0] }
        let th = n / 1000, h = (n / 100) % 10, t = (n / 10) % 10, o = n % 10
        return thousands[th] + hundreds[h] + tens[t] + (o == 0 ? "" : digits[o])
    }
}

enum JapaneseCalendar {
    struct Phrase: Equatable {
        let japanese: String
        let reading: String
        let vi: String
        let en: String
    }

    private static let months = ["いちがつ", "にがつ", "さんがつ", "しがつ", "ごがつ", "ろくがつ", "しちがつ", "はちがつ", "くがつ", "じゅうがつ", "じゅういちがつ", "じゅうにがつ"]

    /// Reading of "n月". `nil` outside 1...12.
    static func monthReading(_ month: Int) -> String? { (1...12).contains(month) ? months[month - 1] : nil }

    private static let irregularDays: [Int: String] = [
        1: "ついたち", 2: "ふつか", 3: "みっか", 4: "よっか", 5: "いつか", 6: "むいか", 7: "なのか", 8: "ようか", 9: "ここのか", 10: "とおか",
        14: "じゅうよっか", 20: "はつか", 24: "にじゅうよっか"
    ]

    /// Reading of "n日" as a date: ついたち, ふつか … はつか … にじゅうよっか; every other day is the number plus にち.
    static func dayReading(_ day: Int) -> String? {
        guard (1...31).contains(day) else { return nil }
        if let irregular = irregularDays[day] { return irregular }
        // 17, 19, 27 and 29 take the older readings of 7 and 9 (しち, く) before にち; the others are the number plus にち.
        let tens = day / 10, ones = day % 10
        if tens > 0, ones == 7 || ones == 9 {
            let tensReading = tens == 1 ? "じゅう" : JapaneseNumbers.reading(tens * 10)
            return tensReading + (ones == 7 ? "しち" : "く") + "にち"
        }
        return JapaneseNumbers.reading(day) + "にち"
    }

    /// `weekday` follows `Calendar`: 1 = Sunday … 7 = Saturday.
    static func weekday(_ weekday: Int) -> Phrase? {
        let table: [Phrase] = [
            Phrase(japanese: "日曜日", reading: "にちようび", vi: "Chủ nhật", en: "Sunday"),
            Phrase(japanese: "月曜日", reading: "げつようび", vi: "Thứ hai", en: "Monday"),
            Phrase(japanese: "火曜日", reading: "かようび", vi: "Thứ ba", en: "Tuesday"),
            Phrase(japanese: "水曜日", reading: "すいようび", vi: "Thứ tư", en: "Wednesday"),
            Phrase(japanese: "木曜日", reading: "もくようび", vi: "Thứ năm", en: "Thursday"),
            Phrase(japanese: "金曜日", reading: "きんようび", vi: "Thứ sáu", en: "Friday"),
            Phrase(japanese: "土曜日", reading: "どようび", vi: "Thứ bảy", en: "Saturday")
        ]
        return (1...7).contains(weekday) ? table[weekday - 1] : nil
    }

    /// Reiwa started on 1 May 2019; its first year is written 元年. Earlier years are not taught here.
    static func reiwa(gregorianYear: Int) -> (text: String, reading: String)? {
        guard gregorianYear >= 2019 else { return nil }
        let n = gregorianYear - 2018
        if n == 1 { return ("令和元年", "れいわがんねん") }
        return ("令和\(n)年", "れいわ" + JapaneseNumbers.reading(n) + "ねん")
    }

    /// Greeting by hour of the learner's day.
    static func greeting(hour: Int) -> Phrase {
        switch hour {
        case 4..<11: return Phrase(japanese: "おはようございます", reading: "おはようございます", vi: "Chào buổi sáng", en: "Good morning")
        case 11..<18: return Phrase(japanese: "こんにちは", reading: "こんにちは", vi: "Xin chào (ban ngày)", en: "Hello (daytime)")
        default: return Phrase(japanese: "こんばんは", reading: "こんばんは", vi: "Chào buổi tối", en: "Good evening")
        }
    }

    enum Season: String { case spring, summer, autumn, winter }

    /// Meteorological seasons (March–May, June–August, September–November, December–February), the way a weather report counts them.
    static func season(month: Int) -> (season: Season, phrase: Phrase) {
        switch month {
        case 3...5: return (.spring, Phrase(japanese: "春", reading: "はる", vi: "mùa xuân", en: "spring"))
        case 6...8: return (.summer, Phrase(japanese: "夏", reading: "なつ", vi: "mùa hè", en: "summer"))
        case 9...11: return (.autumn, Phrase(japanese: "秋", reading: "あき", vi: "mùa thu", en: "autumn"))
        default: return (.winter, Phrase(japanese: "冬", reading: "ふゆ", vi: "mùa đông", en: "winter"))
        }
    }
}
