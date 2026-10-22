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

    func test_emptyDeckIsHandled() {
        var session = StudySession(cards: [])
        XCTAssertNil(session.current)
        XCTAssertEqual(session.progress, 0)
        session.advance()
        session.flip()
        XCTAssertFalse(session.isFinished)
    }
}
