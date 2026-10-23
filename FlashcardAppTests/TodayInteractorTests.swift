import RealmSwift
import XCTest
@testable import FlashcardApp

/// Today's plan end to end against a real (in-memory) Realm: decks, saved attempts, schedules and the learner's choices.
final class TodayInteractorTests: XCTestCase {
    private var realm: Realm!
    private var decks: DeskManagement!
    private var store: RealmReviewHistoryStore!
    private var study: StubStudyPreferences!
    private var preferences: UserDefaultsTodayPreferences!
    private var suite = ""
    private var interactor: TodayInteractor!
    private var calendar: Calendar!
    private let owner = "11111111-1111-1111-1111-111111111111"
    private let other = "22222222-2222-2222-2222-222222222222"
    private let day: TimeInterval = 86_400
    /// 2027-01-15 12:00 in Tokyo.
    private let now = Date(timeIntervalSince1970: 1_799_982_000)

    override func setUpWithError() throws {
        realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: "today-\(UUID().uuidString)", objectTypes: RealmService.storedTypes))
        RealmService.shared.realm = realm
        decks = DeskManagement()
        store = RealmReviewHistoryStore()
        study = StubStudyPreferences()
        suite = "today-interactor-\(UUID().uuidString)"
        preferences = UserDefaultsTodayPreferences(defaults: UserDefaults(suiteName: suite)!)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        interactor = TodayInteractor(decks: decks, schedules: store, studyPreferences: study, preferences: preferences, calendar: calendar)
    }

    override func tearDownWithError() throws {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        interactor = nil
        store = nil
        decks = nil
        realm = nil
        RealmService.shared.realm = nil
    }

    // MARK: Fixtures

    @discardableResult
    private func addDeck(_ id: String, name: String? = nil, cards count: Int = 3, age: TimeInterval = 0) throws -> DeskEntity {
        let desk = DeskEntity()
        desk.id = id
        desk.name = name ?? "Deck \(id)"
        desk.date = Date(timeIntervalSince1970: 1_700_000_000 - age)
        desk.cards = (1...count).map { index in
            let card = CardEntity()
            card.id = "\(id)-c\(index)"
            card.frontText = "F\(index)"
            card.backText = "B\(index)"
            return card
        }
        try decks.add(desk)
        return desk
    }

    private func version(_ deck: String, _ index: Int) throws -> String {
        let card = try XCTUnwrap(decks.desk(withId: deck)?.cards.first { $0.id == "\(deck)-c\(index)" })
        return StudyCard(entity: card).contentVersion
    }

    private func answer(_ deck: String, _ index: Int, _ result: ReviewResult = .remembered, at date: Date, owner: String? = nil) throws {
        let attempt = ReviewAttempt(id: "\(deck)-\(index)-\(date.timeIntervalSince1970)", cardID: "\(deck)-c\(index)", result: result, hints: [],
                                    contentVersion: try version(deck, index), answeredAt: date)
        try store.save(attempt, ownerKey: owner ?? self.owner)
    }

    private func plan(at date: Date? = nil, owner: String? = nil) throws -> TodayPlan {
        try interactor.plan(ownerKey: owner ?? self.owner, now: date ?? now)
    }

    // MARK: States from real data

    func test_withNoDeckTheLearnerIsToldSoAndNothingIsInvented() throws {
        let plan = try plan()
        XCTAssertEqual(plan.kind, .noDeck)
        XCTAssertEqual([plan.dueCount, plan.cardCount, plan.progress.saved], [0, 0, 0])
        XCTAssertTrue(interactor.deckChoices().isEmpty)
    }

    func test_aDeckThatWasNeverStudiedIsPractisedWithItsFirstCards() throws {
        try addDeck("d", cards: 3)
        let plan = try plan()
        XCTAssertEqual(plan.kind, .practice)
        XCTAssertEqual(plan.sessionCardIDs, ["d-c1", "d-c2", "d-c3"])
        XCTAssertEqual(plan.dueCount, 0)
    }

    func test_answersMakeCardsDueLaterAndTheCountMatchesTheStore() throws {
        try addDeck("d", cards: 3)
        let first = now.addingTimeInterval(-5 * day)   // less than a week ago: an ordinary due, not a return after a break
        try answer("d", 1, .remembered, at: first)
        try answer("d", 2, .needsReview, at: first.addingTimeInterval(60))
        let schedules = store.schedules(ownerKey: owner)
        XCTAssertEqual(schedules.count, 2)

        let plan = try plan()
        let dueNow = store.dueSchedules(ownerKey: owner, at: now, currentVersions: ["d-c1": try version("d", 1), "d-c2": try version("d", 2), "d-c3": try version("d", 3)])
        XCTAssertEqual(plan.dueCount, dueNow.filter { $0.skill == .selfRecall }.count)
        XCTAssertGreaterThan(plan.dueCount, 0)
        XCTAssertEqual(plan.kind, .due)
        XCTAssertEqual(plan.unseenCount, 1, "Card 3 was never answered")
        XCTAssertEqual(Set(plan.sessionCardIDs), Set(dueNow.filter { $0.skill == .selfRecall }.map(\.cardID)))
    }

    func test_whatIsDueDependsOnWhichKindOfAnswerIsStudied() throws {
        try addDeck("d", cards: 3)
        try answer("d", 1, .correct, at: now.addingTimeInterval(-30 * day))   // a quiz answer: the recognition schedule

        study.mode = .quiz
        XCTAssertEqual(try plan().skill, .recognition)
        XCTAssertEqual(try plan().dueCount, 1)
        study.mode = .flip
        XCTAssertEqual(try plan().skill, .selfRecall)
        XCTAssertEqual(try plan().dueCount, 0, "Nothing was ever rated by the learner themselves")
        XCTAssertEqual(try plan().kind, .practice)
    }

    func test_todaysProgressIsCountedFromTheLearnersLocalDayNotTheLast24Hours() throws {
        try addDeck("d", cards: 3)
        // now = 12:00 on the 15th in Tokyo; the local day began at 00:00 on the 15th.
        let startOfDay = calendar.startOfDay(for: now)
        try answer("d", 1, .correct, at: startOfDay.addingTimeInterval(-60))      // 23:59 yesterday
        try answer("d", 2, .correct, at: startOfDay)                               // 00:00 today
        try answer("d", 3, .incorrect, at: now.addingTimeInterval(-3_600))
        study.mode = .quiz
        let plan = try plan(at: now.addingTimeInterval(day * 400))                 // far later: nothing today at all
        XCTAssertEqual(plan.progress.saved, 0)

        let today = try self.plan()
        XCTAssertEqual(today.progress, TodayProgress(saved: 2, quizCorrect: 1, quizIncorrect: 1, selfRated: 0))
    }

    func test_whenNothingIsDueAfterAnsweringTodayItIsDone() throws {
        try addDeck("d", cards: 2)
        try answer("d", 1, .remembered, at: now.addingTimeInterval(-3_600))
        try answer("d", 2, .remembered, at: now.addingTimeInterval(-3_000))
        let plan = try plan()
        XCTAssertEqual(plan.kind, .doneToday)
        XCTAssertEqual(plan.progress.saved, 2)
        XCTAssertEqual(plan.progress.selfRated, 2)
    }

    func test_aCardWhoseWordingWasEditedIsNewAgain() throws {
        let desk = try addDeck("d", cards: 2)
        try answer("d", 1, .remembered, at: now.addingTimeInterval(-60 * day))
        XCTAssertEqual(try plan().dueCount, 1)

        let edited = try XCTUnwrap(decks.desk(withId: "d"))
        edited.cards[0].backText = "a new meaning"
        try decks.update(edited)

        let plan = try plan()
        XCTAssertEqual(plan.dueCount, 0, "The old schedule was about the old wording")
        XCTAssertEqual(plan.unseenCount, 2)
        XCTAssertEqual(desk.id, "d")
    }

    func test_aMissingScheduleTableIsRepairedFromTheSavedAttemptsBeforePlanning() throws {
        try addDeck("d", cards: 2)
        try answer("d", 1, .remembered, at: now.addingTimeInterval(-60 * day))
        try realm.write { realm.delete(realm.objects(RReviewState.self)) }   // as after an upgrade from before schedules existed
        XCTAssertEqual(try plan().dueCount, 1)
    }

    func test_anotherLearnersAnswersAreNotThisLearnersDue() throws {
        try addDeck("d", cards: 2)
        try answer("d", 1, .remembered, at: now.addingTimeInterval(-60 * day), owner: other)
        XCTAssertEqual(try plan().dueCount, 0)
        XCTAssertEqual(try plan(owner: other).dueCount, 1)
    }

    // MARK: Choices

    func test_severalDecksAskForAChoiceAndTheChoiceIsRememberedPerLearner() throws {
        try addDeck("a", name: "Alpha", cards: 2, age: 10)
        try addDeck("b", name: "Beta", cards: 5, age: 0)
        XCTAssertEqual(try plan().kind, .chooseDeck)
        XCTAssertEqual(interactor.deckChoices(), [TodayDeckChoice(id: "b", name: "Beta", cardCount: 5), TodayDeckChoice(id: "a", name: "Alpha", cardCount: 2)],
                       "Newest first, like the library")

        interactor.selectDeck(id: "a", ownerKey: owner)
        XCTAssertEqual(try plan().deckID, "a")
        XCTAssertEqual(try plan(owner: other).kind, .chooseDeck, "Another learner has not chosen")
    }

    func test_aDeckThatWasDeletedAfterItWasChosenIsNoLongerTheChoice() throws {
        try addDeck("a", cards: 2)
        try addDeck("b", cards: 2)
        interactor.selectDeck(id: "a", ownerKey: owner)
        try decks.delete(try XCTUnwrap(decks.desk(withId: "a")))
        XCTAssertEqual(try plan().deckID, "b", "One deck is left, so it is simply that deck")
    }

    func test_theTimeBudgetLimitsTheSessionAndIsRememberedPerLearner() throws {
        try addDeck("d", cards: 40)
        try (1...40).forEach { try answer("d", $0, .remembered, at: now.addingTimeInterval(-90 * day)) }
        XCTAssertEqual(try plan().sessionCardIDs.count, 15)
        interactor.setBudgetMinutes(3, ownerKey: owner)
        let small = try plan()
        XCTAssertEqual(small.sessionCardIDs.count, 9)
        XCTAssertEqual(small.dueCount, 40)
        XCTAssertEqual(small.backlog, 31)
        XCTAssertEqual(interactor.budgetMinutes(ownerKey: owner), 3)
        XCTAssertEqual(interactor.budgetMinutes(ownerKey: other), 5)
    }

    // MARK: Errors

    func test_whenTheSavedProgressCannotBeReadPlanningFailsInsteadOfShowingZeros() throws {
        try addDeck("d")
        struct Unreadable: Error {}
        let broken = BrokenScheduleStore(error: Unreadable())
        let failing = TodayInteractor(decks: decks, schedules: broken, studyPreferences: study, preferences: preferences, calendar: calendar)
        XCTAssertThrowsError(try failing.plan(ownerKey: owner, now: now)) { XCTAssertTrue($0 is Unreadable) }
    }
}

private final class StubStudyPreferences: StudyPreferencesInterface {
    var isReadingVisible = true
    var areImagesVisible = true
    var autoSpeak = false
    var isShuffled = false
    var mode: StudyMode = .flip
    var cardStyleSlug: String?
    var areExamplesVisible = true
}

private final class BrokenScheduleStore: ReviewScheduleStoreInterface {
    let error: Error
    init(error: Error) { self.error = error }
    func schedules(ownerKey: String) -> [ReviewSchedule] { [] }
    func dueSchedules(ownerKey: String, at date: Date, currentVersions: [String: String]) -> [ReviewSchedule] { [] }
    func attempts(ownerKey: String, answeredSince date: Date) -> [ReviewAttempt] { [] }
    func rebuildSchedules(ownerKey: String) throws { throw error }
    func ensureSchedules(ownerKey: String) throws { throw error }
}
