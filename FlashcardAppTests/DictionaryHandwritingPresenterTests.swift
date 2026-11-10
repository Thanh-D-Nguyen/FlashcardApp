import RxSwift
import XCTest
@testable import FlashcardApp

final class DictionaryHandwritingPresenterTests: XCTestCase {
    private var interactor: FakeHandwritingInteractor!
    private var wireframe: FakeHandwritingWireframe!
    private var presenter: DictionaryHandwritingPresenter!
    private let bag = DisposeBag()

    override func setUp() {
        super.setUp()
        interactor = FakeHandwritingInteractor()
        wireframe = FakeHandwritingWireframe()
        presenter = DictionaryHandwritingPresenter(interactor: interactor, wireframe: wireframe, debounce: .milliseconds(10))
    }

    private func pump(_ seconds: TimeInterval = 0.1) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }

    private func stroke(_ offset: Double = 0) -> HandwritingInk {
        HandwritingInk(strokes: [[InkPoint(location: CGPoint(x: offset, y: 0)), InkPoint(location: CGPoint(x: offset + 10, y: 10))]])
    }

    func testDrawingShowsCandidatesAfterTheShortDelay() {
        interactor.result = .success(["日", "目"])
        presenter.inkChanged(stroke())
        XCTAssertEqual(presenter.state.value.recognition, .recognizing)
        pump()
        XCTAssertEqual(presenter.state.value.candidates, ["日", "目"])
        XCTAssertEqual(presenter.state.value.recognition, .idle)
        XCTAssertEqual(interactor.requests, 1)
    }

    func testAnotherStrokeBeforeTheDelayReplacesTheRequest() {
        presenter.inkChanged(stroke())
        presenter.inkChanged(stroke(5))
        pump()
        XCTAssertEqual(interactor.requests, 1, "Only the latest strokes are read")
    }

    func testNoMatchAndFailureAreReportedAndClearOldCandidates() {
        interactor.result = .success(["日"])
        presenter.inkChanged(stroke())
        pump()
        interactor.result = .success([])
        presenter.inkChanged(stroke(1))
        pump()
        XCTAssertEqual(presenter.state.value.recognition, .noMatch)
        XCTAssertEqual(presenter.state.value.candidates, [])
        interactor.result = .failure(HandwritingRecognitionError.templatesUnavailable)
        presenter.inkChanged(stroke(2))
        pump()
        XCTAssertEqual(presenter.state.value.recognition, .failed(HandwritingRecognitionError.templatesUnavailable.localizedDescription))
    }

    func testClearingTheCanvasClearsCandidatesWithoutReading() {
        interactor.result = .success(["日"])
        presenter.inkChanged(stroke())
        pump()
        presenter.inkChanged(HandwritingInk())
        XCTAssertEqual(presenter.state.value.candidates, [])
        XCTAssertEqual(presenter.state.value.recognition, .idle)
        XCTAssertEqual(interactor.requests, 1)
    }

    func testChoosingACandidateAppendsItAndClearsTheCanvas() {
        var cleared = 0
        presenter.canvasShouldClear.subscribe(onNext: { cleared += 1 }).disposed(by: bag)
        interactor.result = .success(["日", "目"])
        presenter.inkChanged(stroke())
        pump()
        presenter.choose("日")
        XCTAssertEqual(presenter.state.value.text, "日")
        XCTAssertEqual(presenter.state.value.candidates, [])
        XCTAssertEqual(cleared, 1)
        interactor.result = .success(["本"])
        presenter.inkChanged(stroke(3))
        pump()
        presenter.choose("本")
        XCTAssertEqual(presenter.state.value.text, "日本")
    }

    func testOnlyAnOfferedCandidateCanBeChosen() {
        presenter.choose("日")
        XCTAssertEqual(presenter.state.value.text, "")
    }

    func testAReadingStillRunningWhenACandidateIsChosenIsDropped() {
        interactor.result = .success(["日"])
        presenter.inkChanged(stroke())
        pump()
        interactor.result = .success(["本"])
        presenter.inkChanged(stroke(2))
        presenter.choose("日")
        pump()
        XCTAssertEqual(presenter.state.value.candidates, [], "The late reading belongs to strokes that were already used")
    }

    func testTheKeywordIsCapped() {
        for _ in 0..<DictionaryHandwritingPresenter.maximumCharacters {
            interactor.result = .success(["日"])
            presenter.inkChanged(stroke())
            pump(0.05)
            presenter.choose("日")
        }
        interactor.result = .success(["本"])
        presenter.inkChanged(stroke(1))
        pump(0.05)
        presenter.choose("本")
        XCTAssertEqual(presenter.state.value.text.count, DictionaryHandwritingPresenter.maximumCharacters)
    }

    func testDeleteLookUpAndClose() {
        interactor.result = .success(["日"])
        presenter.inkChanged(stroke())
        pump()
        presenter.choose("日")
        presenter.deleteLastCharacter()
        XCTAssertEqual(presenter.state.value.text, "")
        presenter.lookUp()
        XCTAssertNil(wireframe.lookedUp, "Nothing to look up")
        interactor.result = .success(["本"])
        presenter.inkChanged(stroke(1))
        pump()
        presenter.choose("本")
        presenter.lookUp()
        XCTAssertEqual(wireframe.lookedUp, "本")
        presenter.close()
        XCTAssertEqual(wireframe.closed, 1)
    }
}

private final class FakeHandwritingInteractor: DictionaryHandwritingInteractorInterface {
    var result: Result<[String], Error> = .success([])
    private(set) var requests = 0

    func candidates(for ink: HandwritingInk) -> Single<[String]> {
        requests += 1
        return .create { [result] observer in observer(result.map { $0 }); return Disposables.create() }
    }
}

private final class FakeHandwritingWireframe: DictionaryHandwritingWireframeInterface {
    var lookedUp: String?
    var closed = 0
    func finish(lookingUp text: String) { lookedUp = text }
    func close() { closed += 1 }
}
