import XCTest
@testable import FlashcardApp

/// The schedule is FSRS-6 as the reference library computes it (see FSRSReferenceVectors.swift), plus the few rules that are
/// the app's own: how an answer becomes a grade, what a changed card or a backwards clock does, and that nothing depends on
/// the time zone.
final class ReviewSchedulerTests: XCTestCase {
    private let origin = Date(timeIntervalSince1970: 1_767_225_600)   // 2026-01-01T00:00:00Z, the reference vectors' origin
    private let version = "v1"

    private func scheduler(retention: Double = 0.9, cap: Int = 36_500) -> ReviewScheduler {
        ReviewScheduler(parameters: FSRSParameters(weights: FSRSParameters.defaultWeights, desiredRetention: retention, maximumInterval: cap))
    }

    private func at(_ seconds: TimeInterval) -> Date { origin.addingTimeInterval(seconds) }

    // MARK: Against the reference library

    func test_everyReferenceVectorGivesTheSameStabilityDifficultyAndDueDate() throws {
        XCTAssertGreaterThanOrEqual(fsrsReferenceVectors.count, 11)
        for vector in fsrsReferenceVectors {
            let scheduler = scheduler(retention: vector.desiredRetention, cap: vector.maximumInterval)
            var state: ReviewState?
            for (index, step) in vector.steps.enumerated() {
                let grade = try XCTUnwrap(ReviewGrade(rawValue: step.grade))
                let next = scheduler.next(after: state, grade: grade, contentVersion: version, at: at(step.at))
                let label = "\(vector.name), review \(index + 1)"
                XCTAssertEqual(next.stability, step.stability, accuracy: abs(step.stability) * 1e-9, "stability: \(label)")
                XCTAssertEqual(next.difficulty, step.difficulty, accuracy: 1e-9, "difficulty: \(label)")
                XCTAssertEqual(next.due.timeIntervalSince(origin), step.due, accuracy: 0.001, "due: \(label)")
                XCTAssertEqual(step.state, 2, "the reference always ends in the review state without steps")
                XCTAssertEqual(next.reviews, index + 1, label)
                state = next
            }
        }
    }

    func test_theDefaultParametersAreTheReferenceLibrariesTwentyOne() {
        XCTAssertEqual(FSRSParameters.defaultWeights.count, 21)
        XCTAssertEqual(FSRSParameters.defaultWeights.first, 0.212)
        XCTAssertEqual(FSRSParameters.defaultWeights[3], 8.2956)
        XCTAssertEqual(FSRSParameters.defaultWeights.last, 0.1542)
        XCTAssertEqual(FSRSParameters().desiredRetention, 0.9)
        XCTAssertEqual(FSRSParameters().maximumInterval, 36_500)
    }

    // MARK: Turning an answer into a grade

    private func attempt(_ result: ReviewResult, hints: Set<ReviewHint> = []) -> ReviewAttempt {
        ReviewAttempt(id: "run/0", cardID: "c1", result: result, hints: hints, contentVersion: version, answeredAt: origin)
    }

    func test_aWrongAnswerOrNeedsReviewIsAgainWhateverHelpWasUsed() {
        for result in [ReviewResult.incorrect, .needsReview] {
            XCTAssertEqual(ReviewScheduler.grade(for: attempt(result)), .again)
            XCTAssertEqual(ReviewScheduler.grade(for: attempt(result, hints: [.reading, .audio])), .again)
        }
    }

    func test_aRightAnswerIsGoodUnlessHelpWasInViewThenItIsHard() {
        for result in [ReviewResult.correct, .remembered] {
            XCTAssertEqual(ReviewScheduler.grade(for: attempt(result)), .good)
            XCTAssertEqual(ReviewScheduler.grade(for: attempt(result, hints: [.reading])), .hard)
            XCTAssertEqual(ReviewScheduler.grade(for: attempt(result, hints: [.audio])), .hard)
        }
    }

    func test_theAppNeverGradesAnAnswerEasy() {
        let hintSets: [Set<ReviewHint>] = [[], [.reading], [.audio], [.reading, .audio]]
        for result in [ReviewResult.correct, .incorrect, .remembered, .needsReview] {
            for hints in hintSets { XCTAssertNotEqual(ReviewScheduler.grade(for: attempt(result, hints: hints)), .easy) }
        }
    }

    func test_helpedAnswersGrowTheIntervalLessThanUnaidedOnes() {
        let scheduler = scheduler()
        let first = scheduler.next(after: nil, grade: .good, contentVersion: version, at: origin)
        let unaided = scheduler.next(after: first, grade: .good, contentVersion: version, at: first.due)
        let helped = scheduler.next(after: first, grade: .hard, contentVersion: version, at: first.due)
        XCTAssertLessThan(helped.stability, unaided.stability)
        XCTAssertLessThan(helped.due, unaided.due)
    }

    // MARK: Whole days, never in the past, nothing random

    func test_everyIntervalIsAtLeastOneWholeDayAndAtMostTheCap() {
        let scheduler = scheduler(cap: 30)
        var state: ReviewState?
        for grade in [ReviewGrade.again, .again] + Array(repeating: ReviewGrade.good, count: 10) {
            let next = scheduler.next(after: state, grade: grade, contentVersion: version, at: state?.due ?? origin)
            let days = next.due.timeIntervalSince(next.lastReview) / ReviewScheduler.secondsPerDay
            XCTAssertEqual(days, days.rounded(), "whole days")
            XCTAssertGreaterThanOrEqual(days, 1)
            XCTAssertLessThanOrEqual(days, 30)
            state = next
        }
        XCTAssertEqual(state!.due.timeIntervalSince(state!.lastReview), 30 * ReviewScheduler.secondsPerDay, "the cap is reached")
    }

    func test_theSameInputAlwaysGivesTheSameSchedule() {
        let scheduler = scheduler()
        let first = scheduler.next(after: nil, grade: .good, contentVersion: version, at: origin)
        let a = scheduler.next(after: first, grade: .good, contentVersion: version, at: at(5 * 86_400))
        let b = scheduler.next(after: first, grade: .good, contentVersion: version, at: at(5 * 86_400))
        XCTAssertEqual(a, b, "No fuzzing")
    }

    func test_countersCountReviewsAndLapses() {
        let scheduler = scheduler()
        var state = scheduler.next(after: nil, grade: .again, contentVersion: version, at: origin)
        XCTAssertEqual([state.reviews, state.lapses], [1, 0], "Failing a card the first time is not a lapse")
        state = scheduler.next(after: state, grade: .good, contentVersion: version, at: state.due)
        state = scheduler.next(after: state, grade: .again, contentVersion: version, at: state.due)
        state = scheduler.next(after: state, grade: .hard, contentVersion: version, at: state.due)
        XCTAssertEqual([state.reviews, state.lapses], [4, 1])
    }

    // MARK: Due

    func test_aScheduleIsDueFromItsDueInstantOnAndNotBefore() {
        let scheduler = scheduler()
        let state = scheduler.next(after: nil, grade: .good, contentVersion: version, at: origin)
        XCTAssertFalse(scheduler.isDue(state, at: state.due.addingTimeInterval(-1)))
        XCTAssertTrue(scheduler.isDue(state, at: state.due))
        XCTAssertTrue(scheduler.isDue(state, at: state.due.addingTimeInterval(1)))
        XCTAssertTrue(scheduler.isDue(state, at: state.due.addingTimeInterval(400 * 86_400)), "A long break leaves it due")
    }

    // MARK: Time

    func test_aLongBreakIsScheduledFromTheLateReviewNotFromTheDueDate() {
        let scheduler = scheduler()
        let first = scheduler.next(after: nil, grade: .good, contentVersion: version, at: origin)
        let late = first.due.addingTimeInterval(1_000 * 86_400)
        let next = scheduler.next(after: first, grade: .good, contentVersion: version, at: late)
        XCTAssertEqual(next.lastReview, late)
        XCTAssertGreaterThan(next.due, late)
        XCTAssertGreaterThan(next.stability, first.stability, "Remembering after a long gap still strengthens it")
    }

    func test_aReviewDatedBeforeThePreviousOneIsScheduledAsIfMadeAtThePreviousOne() {
        let scheduler = scheduler()
        let first = scheduler.next(after: nil, grade: .good, contentVersion: version, at: origin)
        let second = scheduler.next(after: first, grade: .good, contentVersion: version, at: first.due)
        let clockWentBack = scheduler.next(after: second, grade: .good, contentVersion: version, at: second.lastReview.addingTimeInterval(-30 * 86_400))

        XCTAssertEqual(clockWentBack.lastReview, second.lastReview, "The history never moves backwards")
        XCTAssertGreaterThanOrEqual(clockWentBack.due, second.lastReview.addingTimeInterval(86_400), "The due date is never in the past")
        let sameMomentAgain = scheduler.next(after: second, grade: .good, contentVersion: version, at: second.lastReview)
        XCTAssertEqual(clockWentBack, sameMomentAgain, "Same as a second answer at the very same moment")
    }

    func test_twoAnswersWithinADayUseTheShortTermRuleAndStillScheduleAtLeastADay() {
        let scheduler = scheduler()
        let first = scheduler.next(after: nil, grade: .good, contentVersion: version, at: origin)
        let again = scheduler.next(after: first, grade: .good, contentVersion: version, at: at(3_600))
        XCTAssertGreaterThanOrEqual(again.stability, first.stability)
        XCTAssertGreaterThanOrEqual(again.due.timeIntervalSince(again.lastReview), 86_400)
    }

    func test_theDueInstantIsAnExactNumberOfDaysEvenAcrossAClockChangeOfTheLocalTimeZone() throws {
        // 2026-03-07 23:00 in New York; summer time starts on the 8th, so a "calendar day" there is 23 hours long.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let evening = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23)))
        let scheduler = scheduler()
        let state = scheduler.next(after: nil, grade: .good, contentVersion: version, at: evening)
        let seconds = state.due.timeIntervalSince(evening)
        XCTAssertEqual(seconds.truncatingRemainder(dividingBy: 86_400), 0, "Instants, not calendar days: no hour is lost or gained")
        XCTAssertEqual(seconds, 2 * 86_400)
    }

    // MARK: A card that changed, an algorithm that changed

    func test_aCardWhoseWordingChangedStartsANewSchedule() {
        let scheduler = scheduler()
        var old = scheduler.next(after: nil, grade: .good, contentVersion: "old", at: origin)
        old = scheduler.next(after: old, grade: .good, contentVersion: "old", at: old.due)
        let renewed = scheduler.next(after: old, grade: .good, contentVersion: "new", at: old.due)
        let fresh = scheduler.next(after: nil, grade: .good, contentVersion: "new", at: old.due)
        XCTAssertEqual(renewed, fresh)
        XCTAssertEqual(renewed.reviews, 1)
        XCTAssertEqual(renewed.contentVersion, "new")
    }

    func test_aScheduleMadeByAnotherAlgorithmIsNotCarriedOver() {
        let scheduler = scheduler()
        var foreign = scheduler.next(after: nil, grade: .good, contentVersion: version, at: origin)
        foreign.algorithm = "something-else"
        let next = scheduler.next(after: foreign, grade: .good, contentVersion: version, at: foreign.due)
        XCTAssertEqual(next.reviews, 1)
        XCTAssertEqual(next.algorithm, FSRSParameters.algorithm)
    }
}
