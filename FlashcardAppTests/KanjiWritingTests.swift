import RxSwift
import XCTest
@testable import FlashcardApp

final class KanjiWritingQuestionsTests: XCTestCase {
    func test_eachKanjiOfAJapaneseWordIsAskedOnceWithTheOthersShown() {
        let cards = [StudyCard(id: "a", front: "会議", back: "cuộc họp", reading: "かいぎ"),
                     StudyCard(id: "b", front: "すし", back: "sushi", reading: "すし"),
                     StudyCard(id: "c", front: "人々", back: "mọi người", reading: "ひとびと"),
                     StudyCard(id: "d", front: "dog", back: "chó"),
                     StudyCard(id: "e", front: "国際連合安全保障", back: "too long"),
                     StudyCard(id: "f", front: "鬱", back: "u uất", reading: "うつ")]
        let questions = KanjiWritingQuestions.make(from: cards, canCheck: { $0 != "鬱" })
        XCTAssertEqual(questions.map(\.target), ["会", "議", "人"], "Kana, the iteration mark, Latin, long words and unchecked kanji are left out")
        XCTAssertEqual(questions.map(\.maskedWord), ["□議", "会□", "□々"])
        XCTAssertEqual(questions.first?.reading, "かいぎ")
        XCTAssertEqual(questions.first?.meaning, "cuộc họp")
    }

    func test_aDrawingIsRightWhenTheTargetIsAmongTheBestFewGuesses() {
        XCTAssertTrue(KanjiWritingQuestions.isRight(target: "末", candidates: ["未", "末", "本"]))
        XCTAssertFalse(KanjiWritingQuestions.isRight(target: "末", candidates: ["一", "二", "三", "四", "五", "末"]))
        XCTAssertFalse(KanjiWritingQuestions.isRight(target: "末", candidates: []))
    }
}

private final class FakeRecognizer: HandwritingRecognizing {
    var result: Single<[String]> = .just([])
    private(set) var calls = 0
    func candidates(for ink: HandwritingInk) -> Single<[String]> { calls += 1; return result }
}

private final class SpyWritingView: KanjiWritingViewInterface {
    var states: [KanjiWritingState] = []
    var clears = 0
    func render(_ state: KanjiWritingState) { states.append(state) }
    func clearCanvas() { clears += 1 }
}

final class KanjiWritingPresenterTests: XCTestCase {
    private let questions = [KanjiWritingQuestion(cardID: "a", target: "会", maskedWord: "□議", reading: "かいぎ", meaning: "cuộc họp"),
                             KanjiWritingQuestion(cardID: "a", target: "議", maskedWord: "会□", reading: "かいぎ", meaning: "cuộc họp")]
    private let stroke = HandwritingInk(strokes: [[InkPoint(location: .zero), InkPoint(location: CGPoint(x: 10, y: 0))]])

    func test_aDrawingIsCheckedOnceThenTheNextKanjiStartsOnAnEmptyCanvas() {
        let recognizer = FakeRecognizer()
        recognizer.result = .just(["会", "合"])
        let view = SpyWritingView()
        let presenter = KanjiWritingPresenter(questions: questions, recognizer: recognizer)
        presenter.view = view
        presenter.viewDidLoad()
        presenter.check()
        XCTAssertEqual(recognizer.calls, 0, "Nothing drawn, nothing to check")
        presenter.inkChanged(stroke)
        presenter.check()
        XCTAssertEqual(view.states.last?.phase, .answered(correct: true))
        presenter.check()
        XCTAssertEqual(recognizer.calls, 1)
        presenter.next()
        XCTAssertEqual(view.states.last?.question?.target, "議")
        XCTAssertEqual(view.states.last?.hasInk, false)
        XCTAssertEqual(view.clears, 1)
        recognizer.result = .just(["義"])
        presenter.inkChanged(stroke)
        presenter.check()
        XCTAssertEqual(view.states.last?.phase, .answered(correct: false))
        presenter.next()
        XCTAssertEqual(view.states.last?.phase, .finished)
        XCTAssertEqual(view.states.last?.correct, 1)
    }

    func test_aRecognizerFailureLetsTheLearnerTryAgainAndADeckWithoutKanjiSaysSo() {
        let recognizer = FakeRecognizer()
        recognizer.result = .error(HandwritingRecognitionError.tooMuchInk)
        let view = SpyWritingView()
        let presenter = KanjiWritingPresenter(questions: questions, recognizer: recognizer)
        presenter.view = view
        presenter.viewDidLoad()
        presenter.inkChanged(stroke)
        presenter.check()
        XCTAssertEqual(view.states.last?.phase, .writing)
        XCTAssertNotNil(view.states.last?.notice)

        let empty = KanjiWritingPresenter(questions: [], recognizer: recognizer)
        empty.view = view
        empty.viewDidLoad()
        XCTAssertEqual(view.states.last?.phase, .empty)
    }
}
