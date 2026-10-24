import RxSwift
import XCTest
@testable import FlashcardApp

/// When Today asks the server for the lesson, and what it shows meanwhile. Few requests, the right city, never a wrong day.
final class TodayLifeCardTests: XCTestCase {
    private var interactor: FakeLifeInteractor!
    private var loader: TodayLifeLoader!
    private var now = LifeLessonFixtures.morning
    private var lesson: LifeLesson!
    private var changes = 0

    override func setUpWithError() throws {
        interactor = FakeLifeInteractor()
        lesson = try LifeLessonFixtures.lesson()
        interactor.loadResult = { [unowned self] _ in .just(lesson) }
        makeLoader()
    }

    private func makeLoader() {
        loader = TodayLifeLoader(interactor: interactor, ownerKey: { "owner" }, now: { [unowned self] in now }, language: { .vietnamese })
        loader.onChange = { [unowned self] in changes += 1 }
    }

    private func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    private func laterThanTheLessonExpires() -> Date { lesson.source.expiresAt.addingTimeInterval(60) }

    func test_theFirstRefreshAsksTheServerOnceAndShowsTheLesson() throws {
        loader.refresh()
        XCTAssertEqual(interactor.loadedCities, ["tokyo"])
        guard case .loaded(let card)? = loader.section?.content else { return XCTFail("expected a loaded card, got \(String(describing: loader.section))") }
        XCTAssertEqual(card.headline, "今日の東京の天気")
        XCTAssertEqual(card.summary, "Hôm nay thời tiết ở Tokyo là mưa.")
        XCTAssertTrue(card.facts.contains("16") && card.facts.contains("80"))
        XCTAssertTrue(card.meta.contains("Open-Meteo") && card.meta.contains("N4"))
        XCTAssertEqual(card.tags, [text("Development source")])
        XCTAssertEqual(loader.section?.exploreValue, "\(text("Weather")) · Tokyo")
        XCTAssertEqual(loader.lesson?.id, lesson.id)
    }

    func test_openingTodayAgainWhileTheLessonIsCurrentDoesNotAskAgain() {
        loader.refresh()
        now = now.addingTimeInterval(10 * 60)
        loader.refresh()
        loader.refresh()
        XCTAssertEqual(interactor.loadedCities.count, 1)
    }

    func test_anExpiredLessonIsAskedForAgainButStaysVisibleWhileItRefreshes() {
        let pending = PublishSubject<LifeLesson>()
        loader.refresh()
        now = laterThanTheLessonExpires()
        interactor.loadResult = { _ in pending.asSingle() }
        loader.refresh()
        XCTAssertEqual(interactor.loadedCities.count, 2)
        guard case .loaded? = loader.section?.content else { return XCTFail("today's lesson should stay while refreshing") }
    }

    func test_aNewJapanDayAsksAgainAndNeverShowsYesterdayAsToday() throws {
        loader.refresh()
        now = now.addingTimeInterval(24 * 3600)   // the lesson is also expired, but the day alone must matter
        let pending = PublishSubject<LifeLesson>()
        interactor.loadResult = { _ in pending.asSingle() }
        loader.refresh()
        XCTAssertEqual(interactor.loadedCities.count, 2)
        XCTAssertEqual(loader.section?.content, .loading, "Yesterday's lesson is not kept on screen as today's")
        XCTAssertNil(loader.lesson)
    }

    func test_twoRefreshesWhileARequestIsRunningShareIt() {
        let pending = PublishSubject<LifeLesson>()
        interactor.loadResult = { _ in pending.asSingle() }
        loader.refresh()
        loader.refresh()
        XCTAssertEqual(interactor.loadedCities.count, 1)
        XCTAssertEqual(loader.section?.content, .loading)
        pending.onNext(lesson)
        pending.onCompleted()
        guard case .loaded? = loader.section?.content else { return XCTFail("expected loaded") }
    }

    func test_choosingAnotherCityAsksForThatCityAndIgnoresALateAnswerForTheOldOne() throws {
        let tokyo = PublishSubject<LifeLesson>()
        interactor.loadResult = { _ in tokyo.asSingle() }
        loader.refresh()
        let osaka = try LifeLessonInteractor.lesson(from: try LifeLessonFixtures.dto { object in
            object["id"] = "weather:osaka:2026-10-24"
            var city = object["city"] as! [String: Any]; city["id"] = "osaka"; city["nameJa"] = "大阪"; city["nameEn"] = "Osaka"; object["city"] = city
        }, requestedCityID: "osaka")
        let osakaSubject = PublishSubject<LifeLesson>()
        interactor.loadResult = { _ in osakaSubject.asSingle() }
        loader.selectCity("osaka")
        XCTAssertEqual(interactor.city, "osaka", "The choice is stored")
        XCTAssertEqual(interactor.loadedCities, ["tokyo", "osaka"])
        tokyo.onNext(lesson)           // too late: that request was cancelled
        tokyo.onCompleted()
        XCTAssertEqual(loader.section?.content, .loading)
        osakaSubject.onNext(osaka)
        osakaSubject.onCompleted()
        XCTAssertEqual(loader.lesson?.cityID, "osaka")
        XCTAssertEqual(loader.section?.exploreValue, "\(text("Weather")) · Osaka")
    }

    func test_aCityOutsideTheListIsIgnoredAndTheSameCityIsNotReloaded() {
        loader.refresh()
        loader.selectCity("paris")
        loader.selectCity("tokyo")
        XCTAssertEqual(interactor.loadedCities.count, 1)
        XCTAssertEqual(interactor.city, "tokyo")
    }

    func test_aServerWithoutWeatherLessonsHidesTheSectionAndIsNotAskedAgainForAnHour() {
        interactor.loadResult = { _ in .error(LearnerAPIError.notFound) }
        loader.refresh()
        XCTAssertNil(loader.section)
        loader.refresh()
        XCTAssertEqual(interactor.loadedCities.count, 1)
        now = now.addingTimeInterval(3601)
        interactor.loadResult = { [unowned self] _ in .just(lesson) }
        loader.refresh()
        XCTAssertEqual(interactor.loadedCities.count, 2)
        XCTAssertNotNil(loader.section)
    }

    func test_aFailureWithNothingToShowOffersARetryAndReassuresTheReviews() {
        interactor.loadResult = { _ in .error(LearnerAPIError.offline) }
        loader.refresh()
        guard case .failed(let title, let message)? = loader.section?.content else { return XCTFail("expected a failure") }
        XCTAssertEqual(title, text("Today's lesson isn't available"))
        XCTAssertTrue(message.contains(LearnerAPIError.offline.errorDescription ?? "?"))
        XCTAssertTrue(message.contains(text("Your reviews are not affected.")))

        interactor.loadResult = { [unowned self] _ in .just(lesson) }
        loader.retry()
        guard case .loaded? = loader.section?.content else { return XCTFail("retry should load") }
        XCTAssertEqual(interactor.loadedCities.count, 2)
    }

    func test_aFailedRefreshKeepsTodaysLessonThatIsStillRight() {
        loader.refresh()
        now = laterThanTheLessonExpires()
        interactor.loadResult = { _ in .error(LearnerAPIError.serviceUnavailable(nil)) }
        loader.refresh()
        guard case .loaded? = loader.section?.content else { return XCTFail("today's lesson is still right: keep it") }
    }

    func test_aFailedRefreshOnANewDayDoesNotKeepYesterdaysLesson() {
        loader.refresh()
        now = now.addingTimeInterval(24 * 3600)
        interactor.loadResult = { _ in .error(LearnerAPIError.offline) }
        loader.refresh()
        guard case .failed? = loader.section?.content else { return XCTFail("expected a failure, got \(String(describing: loader.section))") }
    }

    func test_aLessonForAnotherDayThanTodayIsNotShownAsToday() throws {
        now = now.addingTimeInterval(24 * 3600)      // the fixture describes the 24th; the learner's Japan day is the 25th
        loader.refresh()
        guard case .failed? = loader.section?.content else { return XCTFail("a lesson of another day must not be offered as today's: \(String(describing: loader.section))") }
        XCTAssertNil(loader.lesson)
    }

    func test_afterAFailureTheServerIsNotAskedAgainEveryTimeTodayAppears() {
        interactor.loadResult = { _ in .error(LearnerAPIError.rateLimited) }
        loader.refresh()
        loader.refresh()
        loader.refresh()
        XCTAssertEqual(interactor.loadedCities.count, 1, "Opening Today again must not hammer a rate-limited server")
        guard case .failed? = loader.section?.content else { return XCTFail("the failure stays on the card") }
        now = now.addingTimeInterval(61)
        loader.refresh()
        XCTAssertEqual(interactor.loadedCities.count, 2, "After the pause it asks again")
    }

    func test_theLearnersRetryIsNeverHeldBack() {
        interactor.loadResult = { _ in .error(LearnerAPIError.serviceUnavailable(nil)) }
        loader.refresh()
        loader.retry()
        XCTAssertEqual(interactor.loadedCities.count, 2)
    }

    func test_aFailedRequestForOneCityDoesNotHoldBackAnother() {
        interactor.loadResult = { _ in .error(LearnerAPIError.offline) }
        loader.refresh()
        loader.selectCity("osaka")
        XCTAssertEqual(interactor.loadedCities, ["tokyo", "osaka"])
    }

    func test_aStaleLessonFromTheServerIsLabelled() throws {
        let stale = try LifeLessonFixtures.lesson { var s = $0["source"] as! [String: Any]; s["freshness"] = "stale"; $0["source"] = s }
        let card = TodayLifeLoader.card(for: stale, language: .vietnamese)
        XCTAssertTrue(card.tags.contains(text("Not the latest")))
    }

    func test_theJapanDayIsNotTheDevicesDay() {
        // 2026-10-24 23:30 UTC is already the 25th in Japan.
        XCTAssertEqual(TodayLifeLoader.japanDay(Date(timeIntervalSince1970: 1_792_884_600)), "2026-10-25")
        XCTAssertEqual(TodayLifeLoader.japanDay(LifeLessonFixtures.morning), "2026-10-24")
    }
}
