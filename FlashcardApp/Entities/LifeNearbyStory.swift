//
//  LifeNearbyStory.swift
//
//  "Near you": a lesson about the place the learner is in, worked out on the device from the place names and the kinds of places
//  Apple Maps knows around them. The learner asks for it with a tap; only names and kinds of places are kept (never coordinates)
//  and nothing is sent to our server. See `LifePlaceProvider` for how the place is read.
//

import Foundation

/// A kind of place with the Japanese word for it.
enum LifePlaceKind: String, CaseIterable, Equatable {
    case station, restaurant, cafe, supermarket, shop, bank, hospital, pharmacy, park, postOffice, school, library

    var japanese: String {
        switch self {
        case .station: return "駅"
        case .restaurant: return "レストラン"
        case .cafe: return "カフェ"
        case .supermarket: return "スーパー"
        case .shop: return "店"
        case .bank: return "銀行"
        case .hospital: return "病院"
        case .pharmacy: return "薬局"
        case .park: return "公園"
        case .postOffice: return "郵便局"
        case .school: return "学校"
        case .library: return "図書館"
        }
    }

    var reading: String {
        switch self {
        case .station: return "えき"
        case .restaurant: return "レストラン"
        case .cafe: return "カフェ"
        case .supermarket: return "スーパー"
        case .shop: return "みせ"
        case .bank: return "ぎんこう"
        case .hospital: return "びょういん"
        case .pharmacy: return "やっきょく"
        case .park: return "こうえん"
        case .postOffice: return "ゆうびんきょく"
        case .school: return "がっこう"
        case .library: return "としょかん"
        }
    }

    var vi: String {
        switch self {
        case .station: return "ga tàu"
        case .restaurant: return "nhà hàng"
        case .cafe: return "quán cà phê"
        case .supermarket: return "siêu thị"
        case .shop: return "cửa hàng"
        case .bank: return "ngân hàng"
        case .hospital: return "bệnh viện"
        case .pharmacy: return "hiệu thuốc"
        case .park: return "công viên"
        case .postOffice: return "bưu điện"
        case .school: return "trường học"
        case .library: return "thư viện"
        }
    }

    var en: String {
        switch self {
        case .station: return "station"
        case .restaurant: return "restaurant"
        case .cafe: return "café"
        case .supermarket: return "supermarket"
        case .shop: return "shop"
        case .bank: return "bank"
        case .hospital: return "hospital"
        case .pharmacy: return "pharmacy"
        case .park: return "park"
        case .postOffice: return "post office"
        case .school: return "school"
        case .library: return "library"
        }
    }

    var symbol: String {
        switch self {
        case .station: return "tram.fill"
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer.fill"
        case .supermarket: return "cart.fill"
        case .shop: return "bag.fill"
        case .bank: return "building.columns.fill"
        case .hospital: return "cross.case.fill"
        case .pharmacy: return "pills.fill"
        case .park: return "tree.fill"
        case .postOffice: return "envelope.fill"
        case .school: return "graduationcap.fill"
        case .library: return "books.vertical.fill"
        }
    }

    /// Spellings a learner may type for the word: the word, its reading, and the reading in hiragana for katakana words.
    var acceptedAnswers: [String] {
        var answers = [japanese]
        if reading != japanese { answers.append(reading) }
        if let hiragana = reading.applyingTransform(.hiraganaToKatakana, reverse: true), !answers.contains(hiragana) { answers.append(hiragana) }
        return answers
    }
}

/// What the device could tell about where the learner is: names and kinds of places, never coordinates.
struct LifePlace: Equatable {
    struct Nearby: Equatable {
        let kind: LifePlaceKind
        /// Distance to the nearest one, rounded to 100 m.
        let meters: Int
    }

    let adminArea: String
    let locality: String
    let nearby: [Nearby]
}

enum LifeNearbyStory {
    /// `nil` when nothing notable was found nearby: there is nothing true to teach then.
    static func lesson(place: LifePlace, now: Date, calendar: Calendar = .current) -> LifeLesson? {
        guard let first = place.nearby.first else { return nil }
        let dayEnd = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        let key = String(format: "%04d-%02d-%02d", calendar.component(.year, from: now), calendar.component(.month, from: now), calendar.component(.day, from: now))
        let name = place.adminArea + place.locality
        let distance = max(100, min(900, (first.meters / 100) * 100))
        let sentenceHere = "ここは\(name)です。"
        let sentenceNear = "近くに\(first.kind.japanese)があります。"
        let sentenceDistance = "\(first.kind.japanese)まで約\(distance)メートルです。"
        let nearReadings = ["ちかくに\(first.kind.reading)があります。", "\(first.kind.reading)までやく\(JapaneseNumbers.reading(distance))メートルです。"]

        var sentences: [LifeLessonDraft.Sentence] = [
            .init(id: "here", japanese: sentenceHere, reading: "",
                  vi: "Đây là \(name).", en: "This is \(name).",
                  explanationVi: "「ここは〜です」 nghĩa là “đây là…”. Cách đọc tên địa danh không có sẵn trên máy nên không hiển thị.",
                  explanationEn: "“ここは〜です” means “this is …”. The reading of place names is not available on the device, so none is shown."),
            .init(id: "near", japanese: sentenceNear, reading: nearReadings[0],
                  vi: "Gần đây có \(first.kind.vi).", en: "There is a \(first.kind.en) nearby.",
                  explanationVi: "「近くに〜があります」 nghĩa là “gần đây có…” (có một vật/địa điểm: あります).",
                  explanationEn: "“近くに〜があります” means “there is … nearby” (あります for things and places).")
        ]
        sentences.append(.init(id: "distance", japanese: sentenceDistance, reading: nearReadings[1],
                               vi: "Đến \(first.kind.vi) khoảng \(distance) mét.", en: "It is about \(distance) metres to the \(first.kind.en).",
                               explanationVi: "約 là “khoảng”; メートル là mét. Khoảng cách được làm tròn đến 100 m.",
                               explanationEn: "約 means “about”; メートル is metres. The distance is rounded to 100 m."))

        var words: [LifeLessonDraft.Word] = place.nearby.prefix(3).map {
            .init(id: "nearby:kind:\($0.kind.rawValue)", japanese: $0.kind.japanese, reading: $0.kind.reading, vi: $0.kind.vi, en: $0.kind.en,
                  example: "近くに\($0.kind.japanese)があります。")
        }
        words.append(.init(id: "nearby:near", japanese: "近く", reading: "ちかく", vi: "gần đây", en: "nearby", example: sentenceNear))

        // The recognition exercise: how 近く is read, with the readings it is mistaken for; the answer's place depends on the place name.
        let position = place.locality.count % 3
        var options = ["きんく", "ちがく"]
        options.insert("ちかく", at: position)

        let chips = place.nearby.prefix(3).map {
            LifeChip(symbol: $0.kind.symbol, text: $0.meters < 100 ? "\($0.kind.japanese) · 100m以内" : "\($0.kind.japanese) · \($0.meters)m")
        }
        let draft = LifeLessonDraft(
            id: "nearby:\(key):\(name)", topic: .nearby, provenance: .onDevice,
            titleJapanese: "近くの場所", titleReading: "ちかくのばしょ", titleVi: "Nơi quanh bạn", titleEn: "Places near you",
            providerName: NSLocalizedString("Your location and Apple Maps", comment: "Source of the nearby lesson"),
            chips: [LifeChip(symbol: "mappin.and.ellipse", text: name)] + chips,
            scene: .place, sentences: sentences, words: words,
            recall: .init(promptJapanese: "近くに＿＿があります。",
                          cueVi: "Gõ từ tiếng Nhật chỉ “\(first.kind.vi)”.", cueEn: "Type the Japanese word for “\(first.kind.en)”.",
                          accepted: first.kind.acceptedAnswers,
                          explanationVi: "Đáp án: \(first.kind.japanese) (\(first.kind.reading)) — \(first.kind.vi).",
                          explanationEn: "Answer: \(first.kind.japanese) (\(first.kind.reading)) — \(first.kind.en)."),
            choice: .init(promptJapanese: "近く", promptVi: "“近く” đọc là gì?", promptEn: "How do you read “近く”?",
                          options: options, correct: position,
                          explanationVi: "近く đọc là ちかく (gần đây).", explanationEn: "近く is read ちかく (nearby)."),
            level: "N5", minutes: 2)
        return draft.build(now: now, expiresAt: dayEnd)
    }
}
