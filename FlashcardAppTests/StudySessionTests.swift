import XCTest
@testable import FlashcardApp

final class StudySessionTests: XCTestCase {
    private func cards(_ count: Int) -> [StudyCard] {
        (1...count).map { StudyCard(id: "c\($0)", front: "F\($0)", back: "B\($0)") }
    }

    /// Always picks the lowest index: a deterministic, non-identity permutation.
    private let lowest: StudyRandomSource = { $0.lowerBound }

    func test_startsOnTheFirstCardUnflipped() {
        let session = StudySession(cards: cards(3))
        XCTAssertEqual(session.current?.id, "c1")
        XCTAssertFalse(session.isFlipped)
        XCTAssertEqual(session.progress, 1.0 / 3.0, accuracy: 0.0001)
    }

    func test_flipTogglesAndMovingOnShowsTheFrontAgain() {
        var session = StudySession(cards: cards(3))
        session.flip()
        XCTAssertTrue(session.isFlipped)
        session.advance()
        XCTAssertFalse(session.isFlipped)
        XCTAssertEqual(session.current?.id, "c2")
    }

    func test_goingBackIsPossibleOnlyAfterTheFirstCard() {
        var session = StudySession(cards: cards(3))
        XCTAssertFalse(session.canGoBack)
        session.advance()
        XCTAssertTrue(session.canGoBack)
        session.goBack()
        XCTAssertEqual(session.current?.id, "c1")
    }

    func test_advancingPastTheLastCardFinishesWithFullProgress() {
        var session = StudySession(cards: cards(2))
        session.advance()
        XCTAssertTrue(session.isLastCard)
        session.advance()
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.progress, 1)
        session.advance()
        XCTAssertTrue(session.isFinished)
        XCTAssertFalse(session.canGoForward)
    }

    func test_restartReturnsToTheStartAndClearsTheScore() {
        var session = StudySession(cards: cards(3), mode: .quiz, random: lowest)
        session.select(option: session.current!.back)
        session.advance()
        session.restart()
        XCTAssertEqual(session.position, 0)
        XCTAssertEqual(session.answeredCount, 0)
        XCTAssertEqual(session.correctCount, 0)
        XCTAssertFalse(session.isFinished)
    }

    func test_shuffleReordersWithoutLosingOrDuplicatingCards() {
        let session = StudySession(cards: cards(5), shuffled: true, random: lowest)
        XCTAssertNotEqual(session.order, [0, 1, 2, 3, 4])
        XCTAssertEqual(Set(session.order), [0, 1, 2, 3, 4])
        XCTAssertEqual(session.order.count, 5)
    }

    func test_turningShuffleOffRestoresDeckOrder() {
        var session = StudySession(cards: cards(4), shuffled: true, random: lowest)
        session.setShuffled(false)
        XCTAssertEqual(session.order, [0, 1, 2, 3])
        XCTAssertEqual(session.position, 0)
    }

    func test_quizOffersTheCorrectAnswerAmongAtMostFourDistinctOptions() {
        let session = StudySession(cards: cards(8), mode: .quiz, random: lowest)
        XCTAssertEqual(session.mode, .quiz)
        XCTAssertEqual(session.options.count, 4)
        XCTAssertEqual(Set(session.options).count, 4)
        XCTAssertTrue(session.options.contains(session.current!.back))
    }

    func test_quizWithTwoCardsOffersTwoOptions() {
        let session = StudySession(cards: cards(2), mode: .quiz, random: lowest)
        XCTAssertEqual(Set(session.options), ["B1", "B2"])
    }

    func test_quizNeverRepeatsAnAnswerThatEqualsTheCorrectOne() {
        let deck = [StudyCard(id: "1", front: "a", back: "same"), StudyCard(id: "2", front: "b", back: "same"),
                    StudyCard(id: "3", front: "c", back: "other")]
        let session = StudySession(cards: deck, mode: .quiz, random: lowest)
        XCTAssertEqual(session.options.sorted(), ["other", "same"])
    }

    func test_quizFallsBackToFlipWhenAllAnswersAreIdentical() {
        let deck = [StudyCard(id: "1", front: "a", back: "x"), StudyCard(id: "2", front: "b", back: "x")]
        let session = StudySession(cards: deck, mode: .quiz)
        XCTAssertFalse(session.canQuiz)
        XCTAssertEqual(session.mode, .flip)
    }

    func test_answeringCountsOncePerQuestion() {
        var session = StudySession(cards: cards(3), mode: .quiz, random: lowest)
        let wrong = session.options.first { $0 != session.current!.back }!
        session.select(option: wrong)
        XCTAssertEqual(session.isAnswerCorrect, false)
        session.select(option: session.current!.back)
        XCTAssertEqual(session.answeredCount, 1)
        XCTAssertEqual(session.correctCount, 0)
        session.advance()
        session.select(option: session.current!.back)
        XCTAssertEqual(session.correctCount, 1)
        XCTAssertEqual(session.answeredCount, 2)
    }

    func test_optionsThatAreNotOnOfferAreIgnored() {
        var session = StudySession(cards: cards(3), mode: .quiz, random: lowest)
        session.select(option: "not offered")
        XCTAssertNil(session.selectedOption)
        XCTAssertEqual(session.answeredCount, 0)
    }

    func test_quizCannotFlipOrGoBack() {
        var session = StudySession(cards: cards(3), mode: .quiz, random: lowest)
        session.flip()
        XCTAssertFalse(session.isFlipped)
        session.advance()
        XCTAssertFalse(session.canGoBack)
    }

    // MARK: Review attempts (L01)

    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func session(_ count: Int = 3, mode: StudyMode = .flip, runIDs: [String] = ["run-1", "run-2", "run-3"]) -> StudySession {
        var ids = runIDs
        return StudySession(cards: cards(count), mode: mode, random: lowest, now: { self.fixedDate },
                            makeRunID: { ids.isEmpty ? "run-extra" : ids.removeFirst() })
    }

    func test_choosingAQuizAnswerTwiceProducesOneAttempt() {
        var session = session(mode: .quiz)
        let wrong = session.options.first { $0 != session.current!.back }!
        session.select(option: wrong)
        session.select(option: session.current!.back)
        XCTAssertEqual(session.attempts.count, 1)
        XCTAssertEqual(session.attempts.first?.result, .incorrect)
        XCTAssertEqual(session.currentAttempt, session.attempts.first)
    }

    func test_quizAttemptNamesTheCardSkillAndTime() throws {
        var session = session(mode: .quiz)
        let card = try XCTUnwrap(session.current)
        session.select(option: card.back)
        let attempt = try XCTUnwrap(session.currentAttempt)
        XCTAssertEqual(attempt.cardID, card.id)
        XCTAssertEqual(attempt.result, .correct)
        XCTAssertEqual(attempt.skill, .recognition)
        XCTAssertEqual(attempt.answeredAt, fixedDate)
        XCTAssertTrue(attempt.hints.isEmpty)
    }

    func test_flippingNavigatingAndGoingBackProduceNoAttempt() {
        var session = session()
        session.flip()
        session.advance()
        session.goBack()
        session.flip()
        session.advance()
        session.advance()
        XCTAssertTrue(session.attempts.isEmpty)
        XCTAssertNil(session.currentAttempt)
        XCTAssertEqual(session.correctCount, 0)
        XCTAssertEqual(session.answeredCount, 0)
    }

    func test_selfRatingNeedsTheAnswerToBeShown() {
        var session = session()
        session.rate(.remembered)
        XCTAssertTrue(session.attempts.isEmpty)
    }

    func test_selfRatingRecordsASelfAssessmentNotAQuizResult() throws {
        var session = session()
        session.flip()
        session.rate(.needsReview)
        let attempt = try XCTUnwrap(session.currentAttempt)
        XCTAssertEqual(attempt.result, .needsReview)
        XCTAssertEqual(attempt.skill, .selfRecall)
        XCTAssertEqual(attempt.cardID, "c1")
        XCTAssertEqual(session.answeredCount, 0, "self-ratings are not graded answers")
        XCTAssertEqual(session.correctCount, 0)
    }

    func test_ratingTheSameQuestionTwiceKeepsTheFirstAttemptEvenAfterGoingBack() throws {
        var session = session()
        session.flip()
        session.rate(.remembered)
        let first = try XCTUnwrap(session.currentAttempt)
        session.rate(.needsReview)
        session.advance()
        session.goBack()
        session.flip()
        session.rate(.needsReview)
        XCTAssertEqual(session.attempts, [first])
        XCTAssertEqual(session.currentAttempt, first)
    }

    func test_quizModeIgnoresSelfRating() {
        var session = session(mode: .quiz)
        session.rate(.remembered)
        XCTAssertTrue(session.attempts.isEmpty)
    }

    func test_attemptsAreKeptInAnsweredOrderWithDistinctIds() {
        var session = session(mode: .quiz)
        for _ in 0..<3 {
            session.select(option: session.current!.back)
            session.advance()
        }
        XCTAssertEqual(session.attempts.map(\.cardID), ["c1", "c2", "c3"])
        XCTAssertEqual(Set(session.attempts.map(\.id)).count, 3)
    }

    func test_skippingAQuestionLeavesNoAttemptForIt() {
        var session = session(mode: .quiz)
        session.advance()
        session.select(option: session.current!.back)
        XCTAssertEqual(session.attempts.map(\.cardID), ["c2"])
    }

    func test_attemptIdStaysTheSameWhenReadAgain() throws {
        var session = session(mode: .quiz)
        session.select(option: session.current!.back)
        let first = try XCTUnwrap(session.currentAttempt)
        session.select(option: session.current!.back)
        XCTAssertEqual(session.currentAttempt?.id, first.id)
        XCTAssertEqual(session.attempts.map(\.id), [first.id])
    }

    func test_restartStartsANewRunWithNewAttemptIdsAndNoAttempts() throws {
        var session = session(mode: .quiz)
        session.select(option: session.current!.back)
        let before = try XCTUnwrap(session.currentAttempt)
        session.restart()
        XCTAssertTrue(session.attempts.isEmpty)
        XCTAssertNil(session.currentAttempt)
        session.select(option: session.current!.back)
        XCTAssertNotEqual(session.currentAttempt?.id, before.id)
    }

    func test_changingModeOrShuffleStartsANewRun() throws {
        var session = session(mode: .quiz)
        session.select(option: session.current!.back)
        let first = try XCTUnwrap(session.currentAttempt)
        session.setShuffled(true)
        XCTAssertTrue(session.attempts.isEmpty)
        session.select(option: session.current!.back)
        let second = try XCTUnwrap(session.currentAttempt)
        session.setMode(.flip)
        XCTAssertTrue(session.attempts.isEmpty)
        session.flip()
        session.rate(.remembered)
        let third = try XCTUnwrap(session.currentAttempt)
        XCTAssertEqual(Set([first.id, second.id, third.id]).count, 3)
    }

    func test_hintsNotedBeforeAnsweringAreRecordedOnce() throws {
        var session = session()
        session.noteHint(.reading)
        session.noteHint(.reading)
        session.noteHint(.audio)
        session.flip()
        session.rate(.remembered)
        XCTAssertEqual(session.currentAttempt?.hints, [.reading, .audio])
    }

    func test_hintsDoNotLeakToTheNextQuestionOrChangeAnAnsweredOne() throws {
        var session = session(mode: .quiz)
        session.noteHint(.reading)
        session.select(option: session.current!.back)
        session.noteHint(.audio)
        XCTAssertEqual(session.currentAttempt?.hints, [.reading])
        session.advance()
        session.select(option: session.current!.back)
        XCTAssertEqual(session.attempts.map(\.cardID), ["c1", "c2"])
        XCTAssertEqual(session.attempts.last?.hints, [])
    }

    func test_currentHintsShowWhatIsNotedThenWhatTheAttemptRecorded() {
        var session = session()
        XCTAssertEqual(session.currentHints, [])
        session.noteHint(.reading)
        XCTAssertEqual(session.currentHints, [.reading])
        session.flip()
        session.noteHint(.audio)
        XCTAssertEqual(session.currentHints, [.reading], "Help after the answer is shown is not counted")
        session.rate(.remembered)
        XCTAssertEqual(session.currentHints, [.reading])
        session.advance()
        XCTAssertEqual(session.currentHints, [], "The next question starts without help")
        session.goBack()
        XCTAssertEqual(session.currentHints, [.reading], "Going back shows what the answered question used")
    }

    func test_hintsNotedAfterTheAnswerIsShownAreNotHints() {
        var session = session()
        session.flip()
        session.noteHint(.audio)
        session.rate(.remembered)
        XCTAssertEqual(session.currentAttempt?.hints, [])
    }

    func test_finishedOrEmptySessionsAcceptNoAttempts() {
        var empty = StudySession(cards: [])
        empty.rate(.remembered)
        empty.noteHint(.reading)
        XCTAssertTrue(empty.attempts.isEmpty)

        var finished = session(1, mode: .flip)
        finished.flip()
        finished.advance()
        XCTAssertTrue(finished.isFinished)
        finished.rate(.remembered)
        XCTAssertTrue(finished.attempts.isEmpty)
    }

    func test_existingCountersStayInStepWithQuizAttempts() {
        var session = session(mode: .quiz)
        session.select(option: session.options.first { $0 != session.current!.back }!)
        session.advance()
        session.select(option: session.current!.back)
        XCTAssertEqual(session.answeredCount, session.attempts.count)
        XCTAssertEqual(session.correctCount, session.attempts.filter { $0.result == .correct }.count)
    }

    func test_resultsKeepTheSkillTheyAreEvidenceFor() {
        // Persisted results are reinterpreted through this mapping, so it is pinned.
        XCTAssertEqual([ReviewResult.correct, .incorrect].map(\.skill), [.recognition, .recognition])
        XCTAssertEqual([ReviewResult.remembered, .needsReview].map(\.skill), [.selfRecall, .selfRecall])
        XCTAssertEqual([ReviewResult.correct, .incorrect, .remembered, .needsReview].map(\.rawValue),
                       ["correct", "incorrect", "remembered", "needsReview"])
    }

    // MARK: Content version

    func test_contentVersionIsAStableSha256OfFrontReadingAndBack() {
        // Persisted with every attempt, so the algorithm is pinned: SHA-256 of front, reading, back joined by U+001F
        // (reference values from `shasum -a 256`).
        XCTAssertEqual(StudyCard(id: "1", front: "犬", back: "con chó", reading: "いぬ").contentVersion,
                       "0ce7de02e51bf87dcc60ba26a296702008614b91279ceeff93d7f6dd88ae5cf1")
        XCTAssertEqual(StudyCard(id: "1", front: "犬", back: "con chó").contentVersion,
                       "09fa40e723020db5ef31ab3a068f193394958b36a395598d5682ba0f659501c2")
    }

    func test_contentVersionChangesWithTheWordingButNotWithTheNoteImageOrId() {
        let base = StudyCard(id: "1", front: "犬", back: "con chó", reading: "いぬ", note: "n", imageReference: "a.png")
        XCTAssertNotEqual(base.contentVersion, StudyCard(id: "1", front: "猫", back: "con chó", reading: "いぬ").contentVersion)
        XCTAssertNotEqual(base.contentVersion, StudyCard(id: "1", front: "犬", back: "chó", reading: "いぬ").contentVersion)
        XCTAssertNotEqual(base.contentVersion, StudyCard(id: "1", front: "犬", back: "con chó", reading: "いね").contentVersion)
        XCTAssertEqual(base.contentVersion, StudyCard(id: "2", front: "犬", back: "con chó", reading: "いぬ", note: "other", imageReference: "b.png").contentVersion)
    }

    func test_contentVersionKeepsTheFieldBoundaries() {
        XCTAssertNotEqual(StudyCard(id: "1", front: "ab", back: "c").contentVersion, StudyCard(id: "1", front: "a", back: "bc").contentVersion)
        XCTAssertNotEqual(StudyCard(id: "1", front: "a", back: "b", reading: "c").contentVersion,
                          StudyCard(id: "1", front: "a", back: "bc").contentVersion)
    }

    func test_anAttemptCarriesTheContentVersionOfTheCardThatWasAnswered() throws {
        var session = session(mode: .quiz)
        let card = try XCTUnwrap(session.current)
        session.select(option: card.back)
        XCTAssertEqual(session.currentAttempt?.contentVersion, card.contentVersion)
        XCTAssertFalse(card.contentVersion.isEmpty)
    }

    func test_emptyDeckIsHandled() {
        var session = StudySession(cards: [])
        XCTAssertNil(session.current)
        XCTAssertEqual(session.progress, 0)
        session.advance()
        session.flip()
        XCTAssertFalse(session.isFinished)
    }
}
