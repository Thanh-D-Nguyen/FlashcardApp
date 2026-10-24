//
//  LifeDateStory.swift
//
//  "Today's date": a lesson worked out from the learner's own calendar, on the device. Nothing here comes from a server and
//  nothing is made up: the date, the weekday, the Reiwa year, the season and the greeting are all exact. What a server could
//  add later (public holidays, "what is today", events) is listed in docs/plans/today-life-hub-server-needs.md.
//

import Foundation

enum LifeDateStory {
    /// The learner's day in their own time zone (this is "today" for them, unlike the weather, which describes Japan).
    static func lesson(now: Date, calendar: Calendar = .current) -> LifeLesson? {
        let parts = calendar.dateComponents([.year, .month, .day, .weekday, .hour], from: now)
        guard let year = parts.year, let month = parts.month, let day = parts.day, let weekdayNumber = parts.weekday, let hour = parts.hour,
              let monthReading = JapaneseCalendar.monthReading(month), let dayReading = JapaneseCalendar.dayReading(day),
              let weekday = JapaneseCalendar.weekday(weekdayNumber), let era = JapaneseCalendar.reiwa(gregorianYear: year) else { return nil }
        let season = JapaneseCalendar.season(month: month)
        let greeting = JapaneseCalendar.greeting(hour: hour)
        let key = String(format: "%04d-%02d-%02d", year, month, day)
        let dateText = "\(month)月\(day)日"
        let dateReading = monthReading + dayReading
        let weekdayShort = String(weekday.japanese.prefix(1))
        let dayEnd = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)

        let sentenceDate = "今日は\(dateText)、\(weekday.japanese)です。"
        let draft = LifeLessonDraft(
            id: "date:\(key)", topic: .date, provenance: .onDevice,
            titleJapanese: "今日は\(dateText)", titleReading: "きょうは" + dateReading,
            titleVi: "Hôm nay là ngày \(day) tháng \(month)", titleEn: "Today is \(weekday.en), \(month)/\(day)",
            providerName: NSLocalizedString("Your calendar", comment: "Source of the date lesson"),
            chips: [
                LifeChip(symbol: "calendar", text: "\(weekday.japanese) · \(dateText)"),
                LifeChip(symbol: "seal.fill", text: era.text),
                LifeChip(symbol: season.season == .winter ? "snowflake" : season.season == .summer ? "sun.max.fill" : season.season == .autumn ? "leaf.fill" : "camera.macro",
                         text: season.phrase.japanese)
            ],
            scene: .date(day: day, weekday: weekdayShort),
            sentences: [
                .init(id: "date", japanese: sentenceDate, reading: "きょうは" + dateReading + "、" + weekday.reading + "です。",
                      vi: "Hôm nay là ngày \(day) tháng \(month), \(weekday.vi.lowercased()).", en: "Today is \(weekday.en), \(month)/\(day).",
                      explanationVi: "Ngày trong tháng có cách đọc riêng (ついたち, ふつか, みっか…, はつか, にじゅうよっか); còn lại là số + にち.",
                      explanationEn: "Days of the month have their own readings (ついたち, ふつか, みっか … はつか, にじゅうよっか); the rest are number + にち."),
                .init(id: "era", japanese: "今年は\(era.text)です。", reading: "ことしは\(era.reading)です。",
                      vi: "Năm nay là năm \(era.text).", en: "This year is \(era.text).",
                      explanationVi: "Nhật Bản đếm năm theo niên hiệu; Reiwa (令和) bắt đầu từ năm 2019, năm đầu gọi là 元年.",
                      explanationEn: "Japan counts years by era; Reiwa (令和) began in 2019 and its first year is called 元年."),
                .init(id: "season", japanese: "今は\(season.phrase.japanese)です。", reading: "いまは\(season.phrase.reading)です。",
                      vi: "Bây giờ là \(season.phrase.vi).", en: "It is \(season.phrase.en) now.",
                      explanationVi: "Mùa tính theo cách của bản tin thời tiết: 3–5 xuân, 6–8 hè, 9–11 thu, 12–2 đông.",
                      explanationEn: "Seasons as a weather report counts them: Mar–May spring, Jun–Aug summer, Sep–Nov autumn, Dec–Feb winter."),
                .init(id: "greeting", japanese: "\(greeting.japanese)。", reading: "\(greeting.reading)。",
                      vi: "\(greeting.vi).", en: "\(greeting.en).",
                      explanationVi: "Lời chào đổi theo giờ trong ngày của bạn.", explanationEn: "The greeting changes with the hour of your day.",
                      isAdvice: true)
            ],
            words: [
                .init(id: "date:weekday:\(weekdayNumber)", japanese: weekday.japanese, reading: weekday.reading, vi: weekday.vi.lowercased(), en: weekday.en.lowercased(), example: sentenceDate),
                .init(id: "date:day:\(day)", japanese: "\(day)日", reading: dayReading, vi: "ngày \(day) trong tháng", en: "day \(day) of the month", example: sentenceDate),
                .init(id: "date:month:\(month)", japanese: "\(month)月", reading: monthReading, vi: "tháng \(month)", en: "month \(month)", example: sentenceDate),
                .init(id: "date:season:\(season.season.rawValue)", japanese: season.phrase.japanese, reading: season.phrase.reading, vi: season.phrase.vi, en: season.phrase.en,
                      example: "今は\(season.phrase.japanese)です。"),
                .init(id: "date:today", japanese: "今日", reading: "きょう", vi: "hôm nay", en: "today", example: sentenceDate)
            ],
            recall: .init(
                promptJapanese: "今日は\(dateText)、＿＿曜日です。",
                cueVi: "Gõ chữ Hán hoặc cách đọc của “\(weekday.vi.lowercased())” (không cần “曜日”).",
                cueEn: "Type the kanji or reading for “\(weekday.en)” (without 曜日).",
                accepted: [weekdayShort, String(weekday.reading.prefix(while: { $0 != "よ" })), weekday.japanese, weekday.reading],
                explanationVi: "Đáp án: \(weekdayShort) (\(String(weekday.reading.prefix(while: { $0 != "よ" })))) — \(weekday.japanese).",
                explanationEn: "Answer: \(weekdayShort) (\(String(weekday.reading.prefix(while: { $0 != "よ" })))) — \(weekday.japanese)."),
            choice: choice(day: day, dayReading: dayReading),
            level: "N5", minutes: 2)
        return draft.build(now: now, expiresAt: dayEnd)
    }

    /// "How do you read 24日?" with the readings people actually confuse: the date reading, the plain counter and the neighbour.
    private static func choice(day: Int, dayReading: String) -> LifeLessonDraft.Choice {
        let plain = JapaneseNumbers.reading(day) + "にち"
        let neighbour = JapaneseCalendar.dayReading(day == 31 ? 30 : day + 1) ?? plain
        var options: [String] = []
        for candidate in [dayReading, plain, neighbour] where !options.contains(candidate) { options.append(candidate) }
        var filler = JapaneseCalendar.dayReading(day == 1 ? 3 : day - 1) ?? ""
        if options.count < 3, !options.contains(filler) { options.append(filler) }
        filler = JapaneseCalendar.dayReading(day <= 15 ? day + 5 : day - 5) ?? ""
        if options.count < 3, !options.contains(filler) { options.append(filler) }
        // The right answer moves with the day so it is not always the first one.
        let position = day % options.count
        options.remove(at: 0)
        options.insert(dayReading, at: position)
        return .init(promptJapanese: "\(day)日", promptVi: "Ngày “\(day)日” trong tháng đọc là gì?", promptEn: "How is “\(day)日” read as a date?",
                     options: options, correct: position,
                     explanationVi: "\(day)日 (ngày trong tháng) đọc là \(dayReading).", explanationEn: "\(day)日 as a date is read \(dayReading).")
    }
}
