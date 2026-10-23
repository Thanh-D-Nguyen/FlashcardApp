import XCTest
@testable import FlashcardApp

/// What Today offers, from decks, schedules and today's saved attempts only.
final class TodayPlannerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day = ReviewScheduler.secondsPerDay
    private let budget = TodayBudget(minutes: 5)   // 15 items

    private func deck(_ id: String = "deck", name: String? = nil, cards count: Int = 4, canQuiz: Bool = true) -> TodayDeck {
        TodayDeck(id: id, name: name ?? "Deck \(id)", cards: (1...max(count, 1)).prefix(count).map { TodayCard(id: "\(id)-c\($0)", version: "v1") }, canQuiz: canQuiz)
    }

    private func schedule(_ card: String, skill: ReviewSkill = .selfRecall, version: String = "v1", algorithm: String = FSRSParameters.algorithm,
                          dueIn days: Double, lastReviewedAgo ago: Double = 3) -> ReviewSchedule {
        ReviewSchedule(cardID: card, skill: skill, state: ReviewState(
            contentVersion: version, algorithm: algorithm, stability: 3, difficulty: 5,
            due: now.addingTimeInterval(days * day), lastReview: now.addingTimeInterval(-ago * day), reviews: 2, lapses: 0))
    }

    private func attempt(_ card: String, _ result: ReviewResult) -> ReviewAttempt {
        ReviewAttempt(id: "a-\(card)-\(result.rawValue)", cardID: card, result: result, hints: [], contentVersion: "v1", answeredAt: now)
    }

    private func plan(_ decks: [TodayDeck], selected: String? = nil, mode: StudyMode = .flip, schedules: [ReviewSchedule] = [],
                      today: [ReviewAttempt] = [], minutes: Int = 5) -> TodayPlan {
        TodayPlanner.plan(decks: decks, selectedDeckID: selected, mode: mode, schedules: schedules, attemptsToday: today,
                          budget: TodayBudget(minutes: minutes), now: now)
    }

    // MARK: Which deck

    func test_withNoDeckThereIsNothingToStudyAndNoInventedNumbers() {
        let plan = plan([])
        XCTAssertEqual(plan.kind, .noDeck)
        XCTAssertNil(plan.deckID)
        XCTAssertEqual([plan.dueCount, plan.unseenCount, plan.cardCount], [0, 0, 0])
        XCTAssertTrue(plan.sessionCardIDs.isEmpty)
        XCTAssertNil(plan.estimatedMinutes)
    }

    func test_aSingleDeckIsTheOneStudiedWithoutChoosing() {
        let plan = plan([deck("only")])
        XCTAssertEqual(plan.deckID, "only")
        XCTAssertNotEqual(plan.kind, .chooseDeck)
    }

    func test_severalDecksAndNoChoiceAsksToChooseOne() {
        let plan = plan([deck("a"), deck("b")])
        XCTAssertEqual(plan.kind, .chooseDeck)
        XCTAssertNil(plan.deckID)
        XCTAssertTrue(plan.sessionCardIDs.isEmpty)
    }

    func test_aChoiceOfADeckThatIsGoneAsksAgainInsteadOfUsingABrokenId() {
        XCTAssertEqual(plan([deck("a"), deck("b")], selected: "deleted").kind, .chooseDeck)
        XCTAssertEqual(plan([deck("a")], selected: "deleted").deckID, "a", "With one deck left it is simply that deck")
    }

    func test_theChosenDeckIsTheOneThatIsPlanned() {
        let plan = plan([deck("a", name: "Alpha"), deck("b", name: "Beta", cards: 7)], selected: "b")
        XCTAssertEqual([plan.deckID, plan.deckName], ["b", "Beta"])
        XCTAssertEqual(plan.cardCount, 7)
    }

    func test_aDeckWithoutCardsCannotBeStudiedSoTheLearnerIsAskedToChoose() {
        XCTAssertEqual(plan([TodayDeck(id: "e", name: "Empty", cards: [], canQuiz: false)]).kind, .chooseDeck)
    }

    // MARK: Nothing answered yet

    func test_aDeckNeverPractisedIsPractisedNotDueAndNothingIsCalledForgotten() {
        let plan = plan([deck(cards: 20)])
        XCTAssertEqual(plan.kind, .practice)
        XCTAssertEqual(plan.dueCount, 0)
        XCTAssertEqual(plan.unseenCount, 20)
        XCTAssertEqual(plan.sessionCardIDs, (1...15).map { "deck-c\($0)" }, "The first cards, up to the budget, in deck order")
        XCTAssertEqual(plan.estimatedMinutes, 5)
    }

    func test_aSmallDeckPractisedInOneSessionEstimatesFewerMinutes() {
        let plan = plan([deck(cards: 3)])
        XCTAssertEqual(plan.sessionCardIDs.count, 3)
        XCTAssertEqual(plan.estimatedMinutes, 1)
    }

    // MARK: Due

    func test_dueCardsAreCountedFromTheSchedulesAndStudiedOldestFirst() {
        let schedules = [schedule("deck-c3", dueIn: -1), schedule("deck-c1", dueIn: -4), schedule("deck-c2", dueIn: 2), schedule("deck-c4", dueIn: -2)]
        let plan = plan([deck()], schedules: schedules)
        XCTAssertEqual(plan.kind, .due)
        XCTAssertEqual(plan.dueCount, 3)
        XCTAssertEqual(plan.sessionCardIDs, ["deck-c1", "deck-c4", "deck-c3"])
        XCTAssertEqual(plan.unseenCount, 0)
        XCTAssertEqual(plan.backlog, 0)
    }

    func test_aCardIsDueFromItsDueInstantOn() {
        XCTAssertEqual(plan([deck()], schedules: [schedule("deck-c1", dueIn: 0)]).dueCount, 1)
        XCTAssertEqual(plan([deck()], schedules: [schedule("deck-c1", dueIn: 1 / day)]).dueCount, 0, "One second early")
    }

    func test_theSessionIsLimitedByTheTimeBudgetAndTheRestIsShownAsBacklog() {
        let cards = 40
        let schedules = (1...cards).map { schedule("deck-c\($0)", dueIn: -Double($0)) }
        let three = plan([deck(cards: cards)], schedules: schedules, minutes: 3)
        XCTAssertEqual([three.dueCount, three.sessionCardIDs.count, three.backlog], [40, 9, 31])
        let ten = plan([deck(cards: cards)], schedules: schedules, minutes: 10)
        XCTAssertEqual([ten.dueCount, ten.sessionCardIDs.count, ten.backlog], [40, 30, 10])
        XCTAssertEqual(ten.sessionCardIDs.first, "deck-c40", "The one overdue longest comes first")
        XCTAssertEqual(ten.estimatedMinutes, 10)
        XCTAssertEqual(ten.budgetMinutes, 10)
    }

    func test_onlyTheKindOfAnswerStudiedDecidesWhatIsDue() {
        let schedules = [schedule("deck-c1", skill: .recognition, dueIn: -1), schedule("deck-c2", skill: .selfRecall, dueIn: -1)]
        let flip = plan([deck()], mode: .flip, schedules: schedules)
        XCTAssertEqual(flip.skill, .selfRecall)
        XCTAssertEqual(flip.dueCount, 1)
        XCTAssertEqual(flip.sessionCardIDs, ["deck-c2"])
        let quiz = plan([deck()], mode: .quiz, schedules: schedules)
        XCTAssertEqual(quiz.skill, .recognition)
        XCTAssertEqual(quiz.dueCount, 1)
        XCTAssertEqual(quiz.sessionCardIDs, ["deck-c1"])
    }

    func test_aDeckThatCannotMakeAQuizIsPlannedForSelfRatingEvenInQuizMode() {
        let plan = plan([deck(canQuiz: false)], mode: .quiz, schedules: [schedule("deck-c1", skill: .selfRecall, dueIn: -1)])
        XCTAssertEqual(plan.skill, .selfRecall)
        XCTAssertEqual(plan.dueCount, 1)
    }

    func test_aScheduleMadeForAnEarlierWordingOfTheCardCountsAsNothing() {
        let stale = schedule("deck-c1", version: "old", dueIn: -5)
        let plan = plan([deck(cards: 2)], schedules: [stale, schedule("deck-c2", dueIn: 3)])
        XCTAssertEqual(plan.dueCount, 0)
        XCTAssertEqual(plan.unseenCount, 1, "The edited card is new again")
    }

    func test_schedulesOfOtherDecksAndOfDeletedCardsAreIgnored() {
        let plan = plan([deck("a", cards: 2), deck("b", cards: 2)], selected: "a",
                        schedules: [schedule("b-c1", dueIn: -1), schedule("a-gone", dueIn: -1), schedule("a-c1", dueIn: -1)])
        XCTAssertEqual(plan.dueCount, 1)
        XCTAssertEqual(plan.sessionCardIDs, ["a-c1"])
    }

    func test_aScheduleOfAnotherAlgorithmIsIgnored() {
        XCTAssertEqual(plan([deck()], schedules: [schedule("deck-c1", algorithm: "something-else", dueIn: -3)]).dueCount, 0)
    }

    func test_unseenCardsAreThoseWithoutAScheduleForThisKindOfAnswer() {
        let schedules = [schedule("deck-c1", dueIn: 5), schedule("deck-c2", skill: .recognition, dueIn: 5)]
        let plan = plan([deck(cards: 4)], schedules: schedules)
        XCTAssertEqual(plan.unseenCount, 3, "c2 is only known for the other kind of answer")
    }

    // MARK: Coming back and finishing

    func test_dueAfterALongBreakIsASmallSessionThatStillShowsTheWholeBacklog() {
        let schedules = (1...30).map { schedule("deck-c\($0)", dueIn: -20, lastReviewedAgo: 40) }
        let plan = plan([deck(cards: 30)], schedules: schedules)
        XCTAssertEqual(plan.kind, .returning)
        XCTAssertEqual(plan.dueCount, 30)
        XCTAssertEqual(plan.sessionCardIDs.count, 15)
        XCTAssertEqual(plan.backlog, 15)
    }

    func test_aBreakShorterThanAWeekIsOrdinaryDue() {
        let plan = plan([deck()], schedules: [schedule("deck-c1", dueIn: -1, lastReviewedAgo: 6.5)])
        XCTAssertEqual(plan.kind, .due)
    }

    func test_nothingDueAndNothingSavedTodayIsNothingDueNotDone() {
        let plan = plan([deck()], schedules: [schedule("deck-c1", dueIn: 2)])
        XCTAssertEqual(plan.kind, .nothingDue)
        XCTAssertTrue(plan.sessionCardIDs.isEmpty)
        XCTAssertNil(plan.estimatedMinutes)
        XCTAssertEqual(plan.progress, TodayProgress())
    }

    func test_nothingDueAfterAnsweringTodayIsDoneAndTheProgressIsTheSavedAnswersOnly() {
        let today = [attempt("deck-c1", .correct), attempt("deck-c2", .incorrect), attempt("deck-c3", .remembered), attempt("deck-c4", .needsReview)]
        let plan = plan([deck()], schedules: (1...4).map { schedule("deck-c\($0)", dueIn: 2) }, today: today)
        XCTAssertEqual(plan.kind, .doneToday)
        XCTAssertEqual(plan.progress, TodayProgress(saved: 4, quizCorrect: 1, quizIncorrect: 1, selfRated: 2))
    }

    func test_todaysAnswersForOtherDecksAreNotThisDecksProgress() {
        let today = [attempt("deck-c1", .correct), attempt("elsewhere-c1", .correct)]
        let plan = plan([deck(), deck("elsewhere")], selected: "deck", schedules: [schedule("deck-c1", dueIn: 2)], today: today)
        XCTAssertEqual(plan.progress.saved, 1)
    }

    func test_dueItemsStayDueAfterSomethingWasSavedToday() {
        let plan = plan([deck()], schedules: [schedule("deck-c1", dueIn: -1)], today: [attempt("deck-c2", .correct)])
        XCTAssertEqual(plan.kind, .due, "Saved today is shown as progress; it never hides what is still due")
        XCTAssertEqual(plan.progress.saved, 1)
    }

    // MARK: The budget

    func test_theBudgetOnlyAllowsTheOfferedMinutesAndFallsBackToTheDefault() {
        XCTAssertEqual(TodayBudget(minutes: 3).itemLimit, 9)
        XCTAssertEqual(TodayBudget(minutes: 5).itemLimit, 15)
        XCTAssertEqual(TodayBudget(minutes: 10).itemLimit, 30)
        XCTAssertEqual(TodayBudget(minutes: 7).minutes, 5)
        XCTAssertEqual(TodayBudget(minutes: 0).minutes, 5)
        XCTAssertEqual(TodayBudget.estimatedMinutes(forItems: 1), 1)
        XCTAssertEqual(TodayBudget.estimatedMinutes(forItems: 4), 2)
        XCTAssertEqual(TodayBudget.estimatedMinutes(forItems: 9), 3)
    }
}
