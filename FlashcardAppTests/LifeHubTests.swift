import RxSwift
import XCTest
@testable import FlashcardApp

/// The Japanese the date lesson teaches, the lessons made on the device, the example lessons, the server feed contract and how
/// the hub puts them together. Everything the Today hub shows is decided here, not in the views.
final class JapaneseCalendarTests: XCTestCase {
    func test_numbersAreReadAsJapaneseReadThem() {
        for (n, want) in [0: "れい", 4: "よん", 7: "なな", 9: "きゅう", 10: "じゅう", 24: "にじゅうよん", 100: "ひゃく", 300: "さんびゃく", 600: "ろっぴゃく", 800: "はっぴゃく",
                          1000: "せん", 1080: "せんはちじゅう", 3000: "さんぜん", 8000: "はっせん", 9999: "きゅうせんきゅうひゃくきゅうじゅうきゅう"] {
            XCTAssertEqual(JapaneseNumbers.reading(n), want, "\(n)")
        }
        XCTAssertEqual(JapaneseNumbers.reading(-1), "-1", "A number out of range is never given a wrong reading")
        XCTAssertEqual(JapaneseNumbers.reading(10_000), "10000")
    }

    func test_daysOfTheMonthUseTheirOwnReadings() {
        for (day, want) in [1: "ついたち", 2: "ふつか", 3: "みっか", 4: "よっか", 7: "なのか", 8: "ようか", 9: "ここのか", 10: "とおか", 11: "じゅういちにち",
                            14: "じゅうよっか", 17: "じゅうしちにち", 19: "じゅうくにち", 20: "はつか", 24: "にじゅうよっか", 27: "にじゅうしちにち", 29: "にじゅうくにち", 12: "じゅうににち", 13: "じゅうさんにち", 30: "さんじゅうにち", 31: "さんじゅういちにち"] {
            XCTAssertEqual(JapaneseCalendar.dayReading(day), want, "\(day)日")
        }
        XCTAssertNil(JapaneseCalendar.dayReading(0))
        XCTAssertNil(JapaneseCalendar.dayReading(32))
    }

    func test_monthsAndWeekdays() {
        XCTAssertEqual((1...12).compactMap(JapaneseCalendar.monthReading),
                       ["いちがつ", "にがつ", "さんがつ", "しがつ", "ごがつ", "ろくがつ", "しちがつ", "はちがつ", "くがつ", "じゅうがつ", "じゅういちがつ", "じゅうにがつ"])
        XCTAssertNil(JapaneseCalendar.monthReading(13))
        XCTAssertEqual(JapaneseCalendar.weekday(1)?.japanese, "日曜日")
        XCTAssertEqual(JapaneseCalendar.weekday(7)?.reading, "どようび")
        XCTAssertNil(JapaneseCalendar.weekday(8))
    }

    func test_reiwaCountsFrom2019AndItsFirstYearIsGannen() {
        XCTAssertEqual(JapaneseCalendar.reiwa(gregorianYear: 2019)?.text, "令和元年")
        XCTAssertEqual(JapaneseCalendar.reiwa(gregorianYear: 2019)?.reading, "れいわがんねん")
        XCTAssertEqual(JapaneseCalendar.reiwa(gregorianYear: 2026)?.text, "令和8年")
        XCTAssertEqual(JapaneseCalendar.reiwa(gregorianYear: 2026)?.reading, "れいわはちねん")
        XCTAssertNil(JapaneseCalendar.reiwa(gregorianYear: 2018), "Earlier eras are not taught here")
    }

    func test_greetingAndSeasonFollowTheHourAndTheMonth() {
        XCTAssertEqual(JapaneseCalendar.greeting(hour: 8).japanese, "おはようございます")
        XCTAssertEqual(JapaneseCalendar.greeting(hour: 14).japanese, "こんにちは")
        XCTAssertEqual(JapaneseCalendar.greeting(hour: 20).japanese, "こんばんは")
        XCTAssertEqual(JapaneseCalendar.greeting(hour: 2).japanese, "こんばんは")
        XCTAssertEqual([3, 6, 9, 12, 1].map { JapaneseCalendar.season(month: $0).phrase.japanese }, ["春", "夏", "秋", "冬", "冬"])
    }
}

final class LifeDateStoryTests: XCTestCase {
    private let calendar = LifeLessonFixtures.japanCalendar

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    func test_todayIsTeachedFromTheCalendarOfTheDevice() throws {
        let lesson = try XCTUnwrap(LifeDateStory.lesson(now: date(2026, 10, 24), calendar: calendar))
        XCTAssertEqual(lesson.topic, .date)
        XCTAssertEqual(lesson.provenance, .onDevice, "Worked out here, not fetched and not an example")
        XCTAssertEqual(lesson.id, "date:2026-10-24")
        XCTAssertEqual(lesson.titleJapanese, "今日は10月24日")
        XCTAssertEqual(lesson.titleReading, "きょうはじゅうがつにじゅうよっか")
        XCTAssertEqual(lesson.sentences[0].japanese, "今日は10月24日、土曜日です。")
        XCTAssertEqual(lesson.sentences[0].reading, "きょうはじゅうがつにじゅうよっか、どようびです。")
        XCTAssertEqual(lesson.sentences[1].japanese, "今年は令和8年です。")
        XCTAssertEqual(lesson.sentences[1].reading, "ことしはれいわはちねんです。")
        XCTAssertEqual(lesson.sentences[2].japanese, "今は秋です。")
        XCTAssertEqual(lesson.sentences[3].japanese, "おはようございます。", "Nine in the morning")
        XCTAssertTrue(lesson.sentences[3].isAdvice, "The greeting is a suggestion, not a fact")
        XCTAssertEqual(lesson.scene, LifeScene.date(day: 24, weekday: "土"))
        XCTAssertNil(lesson.source.url)
        XCTAssertEqual(lesson.source.licenseStatus, .notApplicable)
        XCTAssertEqual(Set(lesson.vocabulary.map(\.id)).count, lesson.vocabulary.count)
        XCTAssertTrue(lesson.vocabulary.contains { $0.id == "date:weekday:7" && $0.japanese == "土曜日" })
        XCTAssertTrue(lesson.vocabulary.contains { $0.id == "date:day:24" && $0.reading == "にじゅうよっか" })
    }

    func test_theExercisesAskWhatTheDateTeaches() throws {
        let lesson = try XCTUnwrap(LifeDateStory.lesson(now: date(2026, 10, 24), calendar: calendar))
        guard case .recall(_, let prompt, let cue, let accepted, _) = lesson.exercises[0] else { return XCTFail("expected a recall exercise") }
        XCTAssertEqual(prompt, "今日は10月24日、＿＿曜日です。")
        XCTAssertTrue(accepted.contains("土") && accepted.contains("ど") && accepted.contains("土曜日") && accepted.contains("どようび"))
        XCTAssertFalse(prompt.contains("土"), "The prompt must not hold the answer")
        XCTAssertFalse(cue.vi.contains("土") || cue.en.contains("土"))
        guard case .choice(_, let promptJapanese, _, let choices, let correctID, _) = lesson.exercises[1] else { return XCTFail("expected a choice exercise") }
        XCTAssertEqual(promptJapanese, "24日")
        XCTAssertEqual(choices.count, 3)
        XCTAssertEqual(choices.first { $0.id == correctID }?.text, "にじゅうよっか")
        XCTAssertTrue(choices.map(\.text).contains("にじゅうよんにち"), "The plain counter reading is the mistake people make")
    }

    func test_everyDayOfTheMonthGivesAUniqueCorrectChoice() throws {
        var positions = Set<String>()
        for day in 1...31 {
            let lesson = try XCTUnwrap(LifeDateStory.lesson(now: date(2026, 12, day), calendar: calendar), "\(day)")
            guard case .choice(_, _, _, let choices, let correctID, _) = lesson.exercises[1] else { return XCTFail() }
            XCTAssertEqual(Set(choices.map(\.text)).count, choices.count, "duplicate choices for \(day)日")
            XCTAssertEqual(choices.count, 3, "\(day)")
            XCTAssertEqual(choices.first { $0.id == correctID }?.text, JapaneseCalendar.dayReading(day), "\(day)")
            positions.insert(correctID)
        }
        XCTAssertGreaterThan(positions.count, 1, "The right answer is not always in the same place")
    }

    func test_theGreetingAndTheYearFollowTheLearnersClock() throws {
        XCTAssertEqual(LifeDateStory.lesson(now: date(2026, 1, 1, hour: 20), calendar: calendar)?.sentences[3].japanese, "こんばんは。")
        XCTAssertEqual(LifeDateStory.lesson(now: date(2019, 5, 1), calendar: calendar)?.sentences[1].japanese, "今年は令和元年です。")
        XCTAssertNil(LifeDateStory.lesson(now: date(2018, 5, 1), calendar: calendar), "A year before Reiwa is not taught")
    }

    func test_theHubHeaderStatesTheSameDate() {
        let header = TodayLifeHubLoader.header(now: date(2026, 10, 24), calendar: calendar)
        XCTAssertEqual(header.dateText, "10月24日（土）")
        XCTAssertEqual(header.eraText, "令和8年")
        XCTAssertEqual(header.day, 24)
        XCTAssertEqual(header.month, 10)
        XCTAssertEqual(header.weekdayShort, "土")
        XCTAssertEqual(header.greeting, "おはようございます")
        XCTAssertEqual(header.symbol, "sun.max.fill")
        XCTAssertEqual(TodayLifeHubLoader.header(now: date(2026, 10, 24, hour: 22), calendar: calendar).symbol, "moon.stars.fill")
    }
}

final class LifeNearbyStoryTests: XCTestCase {
    private let now = LifeLessonFixtures.morning
    private let calendar = LifeLessonFixtures.japanCalendar
    private let place = LifePlace(adminArea: "東京都", locality: "港区", nearby: [.init(kind: .station, meters: 300), .init(kind: .cafe, meters: 500), .init(kind: .park, meters: 800)])

    func test_aPlaceBecomesALessonMadeOnTheDevice() throws {
        let lesson = try XCTUnwrap(LifeNearbyStory.lesson(place: place, now: now, calendar: calendar))
        XCTAssertEqual(lesson.topic, .nearby)
        XCTAssertEqual(lesson.provenance, .onDevice)
        XCTAssertEqual(lesson.sentences[0].japanese, "ここは東京都港区です。")
        XCTAssertEqual(lesson.sentences[0].reading, "", "The reading of a place name is not known, so none is invented")
        XCTAssertEqual(lesson.sentences[1].japanese, "近くに駅があります。")
        XCTAssertEqual(lesson.sentences[1].reading, "ちかくにえきがあります。")
        XCTAssertEqual(lesson.sentences[2].japanese, "駅まで約300メートルです。")
        XCTAssertEqual(lesson.sentences[2].reading, "えきまでやくさんびゃくメートルです。")
        XCTAssertEqual(lesson.chips.map(\.text), ["東京都港区", "駅 · 300m", "カフェ · 500m", "公園 · 800m"])
        XCTAssertEqual(lesson.vocabulary.map(\.japanese), ["駅", "カフェ", "公園", "近く"])
        XCTAssertEqual(lesson.scene, LifeScene.place)
    }

    func test_coordinatesNeverAppearInTheLesson() throws {
        let lesson = try XCTUnwrap(LifeNearbyStory.lesson(place: place, now: now, calendar: calendar))
        let everything = ([lesson.id, lesson.titleJapanese] + lesson.chips.map(\.text) + lesson.sentences.map(\.japanese) + lesson.vocabulary.map(\.id)).joined()
        XCTAssertNil(everything.range(of: #"\d+\.\d{3,}"#, options: .regularExpression), "No latitude/longitude digits")
    }

    func test_theExercisesAreAboutTheNearestPlace() throws {
        let lesson = try XCTUnwrap(LifeNearbyStory.lesson(place: place, now: now, calendar: calendar))
        guard case .recall(_, let prompt, _, let accepted, _) = lesson.exercises[0] else { return XCTFail() }
        XCTAssertEqual(prompt, "近くに＿＿があります。")
        XCTAssertEqual(accepted, ["駅", "えき"])
        guard case .choice(_, _, _, let choices, let correct, _) = lesson.exercises[1] else { return XCTFail() }
        XCTAssertEqual(choices.first { $0.id == correct }?.text, "ちかく")
        XCTAssertEqual(Set(choices.map(\.text)).count, 3)
    }

    func test_aKatakanaPlaceKindAcceptsTheHiraganaSpellingToo() {
        XCTAssertEqual(LifePlaceKind.cafe.acceptedAnswers, ["カフェ", "かふぇ"])
        XCTAssertEqual(LifePlaceKind.station.acceptedAnswers, ["駅", "えき"])
    }

    func test_veryNearAndFarDistancesStayInTheTaughtRange() throws {
        let near = LifePlace(adminArea: "東京都", locality: "港区", nearby: [.init(kind: .bank, meters: 0)])
        let lesson = try XCTUnwrap(LifeNearbyStory.lesson(place: near, now: now, calendar: calendar))
        XCTAssertEqual(lesson.sentences[2].japanese, "銀行まで約100メートルです。")
        XCTAssertEqual(lesson.chips[1].text, "銀行 · 100m以内")
    }

    func test_withNothingNearbyThereIsNoLesson() {
        XCTAssertNil(LifeNearbyStory.lesson(place: LifePlace(adminArea: "東京都", locality: "港区", nearby: []), now: now, calendar: calendar))
    }
}

final class SampleLifeContentTests: XCTestCase {
    private let lessons = SampleLifeContent.lessons(now: LifeLessonFixtures.morning, calendar: LifeLessonFixtures.japanCalendar)

    func test_everyTopicWithoutAServerHasALabelledExample() {
        XCTAssertEqual(lessons.map(\.topic), [.transit, .shopping, .news, .food, .culture, .money, .lottery])
        for lesson in lessons {
            XCTAssertEqual(lesson.provenance, .sample, "\(lesson.topic) must say it is an example")
            XCTAssertNil(lesson.source.url)
            XCTAssertEqual(lesson.source.licenseStatus, .notApplicable)
        }
        XCTAssertEqual(Set(lessons.map(\.id)).count, lessons.count)
    }

    func test_everyExampleIsAWholeLessonThatPassesTheSameChecksAsServerContent() {
        for lesson in lessons {
            XCTAssertGreaterThanOrEqual(lesson.sentences.count, 3, lesson.id)
            XCTAssertGreaterThanOrEqual(lesson.vocabulary.count, 4, lesson.id)
            XCTAssertEqual(Set(lesson.vocabulary.map(\.id)).count, lesson.vocabulary.count, "\(lesson.id) word ids")
            XCTAssertTrue(lesson.vocabulary.allSatisfy { !$0.japanese.isEmpty && !$0.reading.isEmpty && !$0.meaning.vi.isEmpty && !$0.meaning.en.isEmpty && !$0.example.isEmpty }, lesson.id)
            XCTAssertTrue(lesson.sentences.allSatisfy { !$0.japanese.isEmpty && !$0.reading.isEmpty && !$0.translation.vi.isEmpty && !$0.translation.en.isEmpty }, lesson.id)
            XCTAssertEqual(lesson.exercises.count, 2, lesson.id)
            XCTAssertFalse(lesson.chips.isEmpty, lesson.id)
        }
    }

    func test_theRecallPromptNeverContainsItsAnswer() {
        for lesson in lessons {
            guard case .recall(_, let prompt, let cue, let accepted, _) = lesson.exercises[0] else { return XCTFail(lesson.id) }
            XCTAssertTrue(prompt.contains("＿＿"), "\(lesson.id) has a blank")
            for answer in accepted {
                XCTAssertFalse(prompt.contains(answer), "\(lesson.id): the prompt contains \(answer)")
                XCTAssertFalse(cue.vi.contains(answer) || cue.en.contains(answer), "\(lesson.id): the cue contains \(answer)")
            }
            XCTAssertTrue(accepted.allSatisfy { LifeAnswerChecker.isCorrect($0, accepted: accepted) })
        }
    }

    func test_theChoiceHasOneRightAnswerAmongDistinctOptions() {
        for lesson in lessons {
            guard case .choice(_, _, _, let choices, let correct, _) = lesson.exercises[1] else { return XCTFail(lesson.id) }
            XCTAssertEqual(choices.count, 3, lesson.id)
            XCTAssertEqual(Set(choices.map(\.text)).count, 3, "\(lesson.id) options")
            XCTAssertEqual(choices.filter { $0.id == correct }.count, 1, lesson.id)
        }
    }

    func test_theMoneyAndLotterySamplesStayEducational() throws {
        let money = try XCTUnwrap(lessons.first { $0.topic == .money })
        let lottery = try XCTUnwrap(lessons.first { $0.topic == .lottery })
        XCTAssertTrue(money.chips.map(\.text).contains(NSLocalizedString("Not investment advice", comment: "")))
        XCTAssertTrue(lottery.chips.map(\.text).contains(NSLocalizedString("Explainer · no predictions", comment: "")))
        XCTAssertTrue(lottery.chips.map(\.text).contains(NSLocalizedString("Never a betting link", comment: "")))
        for lesson in [money, lottery] {
            XCTAssertNil(lesson.source.url, "No outbound link from a money or lottery lesson")
            XCTAssertFalse(lesson.sentences.contains { $0.japanese.contains("買") || $0.japanese.contains("予想") }, "\(lesson.id) tells nobody what to buy or predicts anything")
        }
    }

    func test_theExamplesAreSavableLikeAnyLesson() throws {
        let realm = try RealmFixture.makeInMemory()
        defer { realm.tearDown() }
        let interactor = LifeLessonInteractor(decks: DeskManagement(), cards: CardManagement.shared)
        let lesson = try XCTUnwrap(lessons.first)
        let outcome = try interactor.saveVocabulary(lesson.vocabulary, target: .newLifeDeck, language: .vietnamese)
        XCTAssertEqual(outcome.added.count, lesson.vocabulary.count)
        XCTAssertEqual(try interactor.saveVocabulary(lesson.vocabulary, target: .newLifeDeck, language: .vietnamese).added.count, 0, "Saving again adds nothing")
    }
}
