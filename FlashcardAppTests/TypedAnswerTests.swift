import XCTest
@testable import FlashcardApp

/// K-09: typing the reading of a card in kana.
final class KanaAnswerTests: XCTestCase {
    func test_theSameHiraganaMatches() {
        XCTAssertTrue(KanaAnswer.matches(typed: "たべる", expected: "たべる"))
    }

    func test_katakanaTypedForAHiraganaReadingAndTheOtherWayRoundMatch() {
        XCTAssertTrue(KanaAnswer.matches(typed: "タベル", expected: "たべる"))
        XCTAssertTrue(KanaAnswer.matches(typed: "らーめん", expected: "ラーメン"))
    }

    func test_halfWidthKatakanaAndSeparateDakutenMatch() {
        XCTAssertTrue(KanaAnswer.matches(typed: "ﾀﾞｲｶﾞｸ", expected: "だいがく"))
        XCTAssertTrue(KanaAnswer.matches(typed: "か\u{3099}くせい", expected: "がくせい"))
    }

    func test_spacesAndMiddleDotsBetweenPartsAreIgnored() {
        XCTAssertTrue(KanaAnswer.matches(typed: " ほん を\u{3000}よむ ", expected: "ほんをよむ"))
        XCTAssertTrue(KanaAnswer.matches(typed: "ほんをよむ", expected: "ほん・を・よむ"))
    }

    func test_aDifferentReadingDoesNotMatch() {
        XCTAssertFalse(KanaAnswer.matches(typed: "たべた", expected: "たべる"))
        XCTAssertFalse(KanaAnswer.matches(typed: "たべ", expected: "たべる"))
    }

    func test_aLongVowelMarkIsNotAVowel() {
        XCTAssertFalse(KanaAnswer.matches(typed: "らあめん", expected: "らーめん"))
    }

    func test_romajiAndKanjiAreNotKana() {
        XCTAssertFalse(KanaAnswer.matches(typed: "taberu", expected: "たべる"))
        XCTAssertFalse(KanaAnswer.matches(typed: "食べる", expected: "たべる"))
    }

    func test_nothingTypedIsNeverACorrectAnswer() {
        XCTAssertFalse(KanaAnswer.matches(typed: "  ", expected: ""))
        XCTAssertFalse(KanaAnswer.matches(typed: "", expected: "たべる"))
    }

    func test_onlyAPureKanaReadingCanBeAsked() {
        XCTAssertTrue(KanaAnswer.isKana("たべる"))
        XCTAssertTrue(KanaAnswer.isKana("ラーメン"))
        XCTAssertTrue(KanaAnswer.isKana("ほん を よむ"))
        XCTAssertFalse(KanaAnswer.isKana(""))
        XCTAssertFalse(KanaAnswer.isKana("  "))
        XCTAssertFalse(KanaAnswer.isKana("食べる"))
        XCTAssertFalse(KanaAnswer.isKana("taberu"))
        XCTAssertFalse(KanaAnswer.isKana("たべる (to eat)"))
    }
}

final class TypedAnswerSessionTests: XCTestCase {
    private func cards(_ count: Int = 3, readingOf: (Int) -> String = { ["たべる", "のむ", "いく", "くる"][$0 - 1] }) -> [StudyCard] {
        (1...count).map { StudyCard(id: "c\($0)", front: "漢\($0)", back: "nghĩa \($0)", reading: readingOf($0)) }
    }

    private func session(_ cards: [StudyCard]) -> StudySession {
        var ids = (1...20).map { "run-\($0)" }.makeIterator()
        return StudySession(cards: cards, mode: .type, now: { Date(timeIntervalSince1970: 1_700_000_000) }, makeRunID: { ids.next() ?? "x" })
    }

    func test_typingNeedsAKanaReadingOnEveryCard() {
        XCTAssertTrue(StudySession.canType(cards()))
        XCTAssertFalse(StudySession.canType(cards(readingOf: { $0 == 2 ? "" : "たべる" })))
        XCTAssertFalse(StudySession.canType(cards(readingOf: { $0 == 2 ? "taberu" : "たべる" })))
        XCTAssertFalse(StudySession.canType([]))
    }

    func test_aCardWhoseFrontIsNotJapaneseOrIsJustItsReadingIsNotAsked() {
        XCTAssertNotNil(StudyCard(id: "a", front: "食べる", back: "ăn", reading: "たべる").typedAnswer)
        XCTAssertNil(StudyCard(id: "b", front: "to eat", back: "ăn", reading: "たべる").typedAnswer, "The reading belongs to the front: a Vietnamese front has none to type")
        XCTAssertNil(StudyCard(id: "c", front: "たべる", back: "ăn", reading: "タベル").typedAnswer, "A kana word would only be copied")
        XCTAssertNil(StudyCard(id: "d", front: "食べる", back: "ăn", reading: "").typedAnswer)
    }

    func test_theModeIsKeptOnlyWhenEveryCardCanBeTyped() {
        XCTAssertEqual(session(cards()).mode, .type)
        XCTAssertEqual(session(cards(readingOf: { $0 == 2 ? "" : "たべる" })).mode, .flip)
        var mixed = session(cards())
        mixed.setMode(.flip)
        mixed.setMode(.type)
        XCTAssertEqual(mixed.mode, .type)
    }

    func test_aRightReadingIsRecordedAsTypedCorrectWithTheTypedText() throws {
        var s = session(cards())
        s.submit(typed: "タベル")
        let attempt = try XCTUnwrap(s.currentAttempt)
        XCTAssertEqual(attempt.result, .typedCorrect)
        XCTAssertEqual(attempt.skill, .typedRecall)
        XCTAssertEqual(attempt.cardID, "c1")
        XCTAssertEqual(s.typedAnswer, "タベル")
        XCTAssertEqual(s.isAnswerCorrect, true)
        XCTAssertEqual(s.correctCount, 1)
        XCTAssertEqual(s.answeredCount, 1)
    }

    func test_aWrongReadingIsRecordedAsTypedIncorrect() throws {
        var s = session(cards())
        s.submit(typed: "たべた")
        XCTAssertEqual(s.currentAttempt?.result, .typedIncorrect)
        XCTAssertEqual(s.isAnswerCorrect, false)
        XCTAssertEqual(s.correctCount, 0)
        XCTAssertEqual(s.answeredCount, 1)
    }

    func test_aBlankAnswerIsNotRecordedAndCanBeRetried() {
        var s = session(cards())
        s.submit(typed: "   ")
        XCTAssertNil(s.currentAttempt)
        XCTAssertNil(s.typedAnswer)
        s.submit(typed: "たべる")
        XCTAssertEqual(s.currentAttempt?.result, .typedCorrect)
    }

    func test_aQuestionIsAnsweredOnceAndTheNextOneStartsClean() {
        var s = session(cards())
        s.submit(typed: "たべる")
        s.submit(typed: "ちがう")
        XCTAssertEqual(s.attempts.count, 1)
        XCTAssertEqual(s.currentAttempt?.result, .typedCorrect, "The first answer stands")
        s.advance()
        XCTAssertNil(s.typedAnswer)
        XCTAssertNil(s.currentAttempt)
        s.submit(typed: "ちがう")
        XCTAssertEqual(s.attempts.map(\.result), [.typedCorrect, .typedIncorrect])
        XCTAssertEqual(s.attempts.map(\.cardID), ["c1", "c2"])
    }

    func test_typingIsIgnoredInTheOtherModes() {
        var s = StudySession(cards: cards(), mode: .flip)
        s.submit(typed: "たべる")
        XCTAssertTrue(s.attempts.isEmpty)
    }

    func test_audioHeardBeforeTheAnswerIsRecordedAsAHint() {
        var s = session(cards())
        s.noteHint(.audio)
        s.submit(typed: "たべる")
        XCTAssertEqual(s.currentAttempt?.hints, [.audio])
    }

    func test_thereIsNoGoingBackInTypingLikeInAQuiz() {
        var s = session(cards())
        s.submit(typed: "たべる")
        s.advance()
        XCTAssertFalse(s.canGoBack)
    }

    func test_restartingClearsTheTypedAnswer() {
        var s = session(cards())
        s.submit(typed: "たべる")
        s.restart()
        XCTAssertNil(s.typedAnswer)
        XCTAssertTrue(s.attempts.isEmpty)
    }
}

final class TypedAnswerSchedulingTests: XCTestCase {
    private func attempt(_ result: ReviewResult, hints: Set<ReviewHint> = []) -> ReviewAttempt {
        ReviewAttempt(id: "a", cardID: "c", result: result, hints: hints, contentVersion: "v", answeredAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    func test_typedResultsAreAKindOfAnswerOfTheirOwn() {
        XCTAssertEqual(ReviewResult.typedCorrect.skill, .typedRecall)
        XCTAssertEqual(ReviewResult.typedIncorrect.skill, .typedRecall)
        XCTAssertNotEqual(ReviewSkill.typedRecall, .recognition)
        XCTAssertNotEqual(ReviewSkill.typedRecall, .selfRecall)
    }

    func test_aWrongTypedAnswerIsAgainAndAHelpedRightOneIsHard() {
        XCTAssertEqual(ReviewScheduler.grade(for: attempt(.typedIncorrect)), .again)
        XCTAssertEqual(ReviewScheduler.grade(for: attempt(.typedCorrect)), .good)
        XCTAssertEqual(ReviewScheduler.grade(for: attempt(.typedCorrect, hints: [.audio])), .hard)
    }

    func test_todayPlansTheTypedKindOfAnswerOnlyForADeckThatCanBeTyped() {
        func plan(canType: Bool) -> TodayPlan {
            let deck = TodayDeck(id: "d", name: "D", cards: [TodayCard(id: "c1", version: "v1")], canQuiz: false, canType: canType)
            return TodayPlanner.plan(decks: [deck], selectedDeckID: "d", mode: .type, schedules: [], attemptsToday: [], budget: TodayBudget(minutes: 5),
                                     now: Date(timeIntervalSince1970: 1_700_000_000))
        }
        XCTAssertEqual(plan(canType: true).skill, .typedRecall)
        XCTAssertEqual(plan(canType: false).skill, .selfRecall, "Same fallback as the session: a deck that cannot be typed is flipped")
    }

    func test_typedAnswersAreCountedAsCheckedAnswersOnToday() {
        let deck = TodayDeck(id: "d", name: "D", cards: [TodayCard(id: "c", version: "v")], canQuiz: false, canType: true)
        let plan = TodayPlanner.plan(decks: [deck], selectedDeckID: "d", mode: .type, schedules: [],
                                     attemptsToday: [attempt(.typedCorrect), attempt(.typedIncorrect)], budget: TodayBudget(minutes: 5),
                                     now: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(plan.progress.quizCorrect, 1)
        XCTAssertEqual(plan.progress.quizIncorrect, 1)
        XCTAssertEqual(plan.progress.saved, 2)
    }
}
