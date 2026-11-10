import RxSwift
import XCTest
@testable import FlashcardApp

final class DictionaryVoicePresenterTests: XCTestCase {
    private var interactor: FakeVoiceInteractor!
    private var wireframe: FakeVoiceWireframe!
    private var presenter: DictionaryVoicePresenter!

    override func setUp() {
        super.setUp()
        interactor = FakeVoiceInteractor()
        wireframe = FakeVoiceWireframe()
        presenter = DictionaryVoicePresenter(interactor: interactor, wireframe: wireframe)
    }

    private func pump() { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }

    func testItStartsReadyWithTheCurrentAccess() {
        XCTAssertEqual(presenter.state.value, .ready(.authorized))
    }

    func testListeningShowsPartialTextThenTheFinalResultForCorrection() {
        presenter.toggleListening()
        XCTAssertEqual(presenter.state.value, .listening(partial: ""))
        interactor.updates.onNext(.partial("た"))
        interactor.updates.onNext(.partial("たべる"))
        XCTAssertEqual(presenter.state.value, .listening(partial: "たべる"))
        interactor.updates.onNext(.final("食べる"))
        pump()
        XCTAssertEqual(presenter.state.value, .result("食べる"))
        XCTAssertFalse(interactor.isListening, "The microphone is released when the result is in")
    }

    func testStoppingEndsTheAudioButLetsTheRecognizerDeliverTheLastWords() {
        presenter.toggleListening()
        interactor.updates.onNext(.partial("ありがとう"))
        presenter.toggleListening()
        XCTAssertEqual(interactor.stopSignals, 1, "The audio is asked to end")
        XCTAssertEqual(presenter.state.value, .listening(partial: "ありがとう"), "Still waiting for the final words")
        interactor.updates.onNext(.final("ありがとうございます"))
        pump()
        XCTAssertEqual(presenter.state.value, .result("ありがとうございます"), "The last words are not lost")
        XCTAssertFalse(interactor.isListening)
    }

    func testIfTheRecognizerNeverAnswersAfterStopWhatWasHeardIsKept() {
        presenter.toggleListening()
        interactor.updates.onNext(.partial("ありがとう"))
        presenter.toggleListening()
        interactor.updates.onCompleted()   // the service's grace period ran out
        pump()
        XCTAssertEqual(presenter.state.value, .result("ありがとう"))
    }

    func testStoppingBeforeAnythingWasHeardIsNothingHeardNotASearch() {
        presenter.toggleListening()
        presenter.toggleListening()
        interactor.updates.onCompleted()
        pump()
        guard case .failed = presenter.state.value else { return XCTFail("expected a retryable failure") }
    }

    func testLeavingTheScreenStopsListening() {
        presenter.toggleListening()
        presenter.viewWillDisappear()
        XCTAssertFalse(interactor.isListening)
    }

    func testAFailureAfterSomeSpeechKeepsTheSpeechAndAFailureBeforeItIsExplained() {
        presenter.toggleListening()
        interactor.updates.onNext(.partial("日本"))
        interactor.updates.onError(SpeechRecognitionError.failed("network"))
        pump()
        XCTAssertEqual(presenter.state.value, .result("日本"))

        presenter.toggleListening()
        interactor.updates.onError(SpeechRecognitionError.unavailable)
        pump()
        XCTAssertEqual(presenter.state.value, .failed(SpeechRecognitionError.unavailable.errorDescription!))
    }

    func testDeniedAndUnavailableNeverStartTheMicrophone() {
        interactor.currentAccess = .denied
        presenter.toggleListening()
        XCTAssertEqual(presenter.state.value, .ready(.denied))
        interactor.currentAccess = .unavailable
        presenter.toggleListening()
        XCTAssertEqual(presenter.state.value, .ready(.unavailable))
        XCTAssertEqual(interactor.listenCalls, 0)
        presenter.openSettings()
        XCTAssertEqual(wireframe.settingsOpened, 1)
    }

    func testTheFirstUseAsksPermissionAndListensOnlyIfGranted() {
        interactor.currentAccess = .notDetermined
        interactor.requestResult = .denied
        presenter.toggleListening()
        pump()
        XCTAssertEqual(presenter.state.value, .ready(.denied))
        XCTAssertEqual(interactor.listenCalls, 0)

        interactor.currentAccess = .notDetermined
        interactor.requestResult = .authorized
        presenter.toggleListening()
        pump()
        XCTAssertEqual(interactor.listenCalls, 1)
        XCTAssertEqual(presenter.state.value, .listening(partial: ""))
    }

    func testOnlyTextASearchAcceptsIsLookedUp() {
        presenter.lookUp(" 食べる ")
        presenter.lookUp("")
        XCTAssertEqual(wireframe.lookedUp, ["食べる"])
        presenter.close()
        XCTAssertEqual(wireframe.closed, 1)
    }
}

private final class FakeVoiceInteractor: DictionaryVoiceInteractorInterface {
    var currentAccess: SpeechAccess = .authorized
    var requestResult: SpeechAccess = .authorized
    var updates = PublishSubject<SpeechUpdate>()
    var listenCalls = 0
    var stopSignals = 0
    var isListening = false
    private let bag = DisposeBag()
    var access: SpeechAccess { currentAccess }
    func requestAccess() -> Single<SpeechAccess> { .just(requestResult) }
    func listen(stop: Observable<Void>) -> Observable<SpeechUpdate> {
        listenCalls += 1
        stop.subscribe(onNext: { [unowned self] in stopSignals += 1 }).disposed(by: bag)
        updates = PublishSubject<SpeechUpdate>()
        return updates.do(onSubscribe: { [unowned self] in isListening = true }, onDispose: { [unowned self] in isListening = false })
    }
}

private final class FakeVoiceWireframe: DictionaryVoiceWireframeInterface {
    var lookedUp: [String] = []
    var closed = 0
    var settingsOpened = 0
    func finish(lookingUp text: String) { lookedUp.append(text) }
    func close() { closed += 1 }
    func openSystemSettings() { settingsOpened += 1 }
}
