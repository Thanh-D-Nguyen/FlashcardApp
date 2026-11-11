import XCTest
@testable import FlashcardApp

private final class FakeSpeech: SpeechServiceInterface {
    private(set) var spoken: [(String, String)] = []
    private(set) var stops = 0
    func speak(_ text: String, languageCode: String) { spoken.append((text, languageCode)) }
    func stop() { stops += 1 }
}

private final class FakeRecorder: ShadowingRecording {
    var allowed = true
    var failStart = false
    private(set) var started: [URL] = []
    private(set) var stopped = 0
    private(set) var played: [URL] = []
    func requestPermission(_ completion: @escaping (Bool) -> Void) { completion(allowed) }
    func startRecording(to url: URL) throws {
        if failStart { throw CocoaError(.fileWriteUnknown) }
        started.append(url)
        FileManager.default.createFile(atPath: url.path, contents: Data([0]))
    }
    func stopRecording() { stopped += 1 }
    func play(_ url: URL) throws { played.append(url) }
    func stopPlaying() {}
}

private final class SpyShadowingView: ShadowingViewInterface {
    var states: [ShadowingState] = []
    func render(_ state: ShadowingState) { states.append(state) }
}

final class ShadowingPresenterTests: XCTestCase {
    private let sentences = [ShadowingSentence(japanese: "おはようございます。", translation: "Chào buổi sáng."),
                             ShadowingSentence(japanese: "よろしくお願いします。", translation: nil)]
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("shadow-test-\(UUID().uuidString)")
    }

    func test_listenRecordAndHearYourselfThenTheRecordingsAreRemoved() {
        let speech = FakeSpeech(), recorder = FakeRecorder(), view = SpyShadowingView()
        let presenter = ShadowingPresenter(sentences: sentences, speech: speech, recorder: recorder, directory: directory)
        presenter.view = view
        presenter.viewDidLoad()
        presenter.listen()
        XCTAssertEqual(speech.spoken.first?.0, "おはようございます。")
        XCTAssertEqual(speech.spoken.first?.1, "ja-JP")
        presenter.playMine()
        XCTAssertTrue(recorder.played.isEmpty, "Nothing recorded yet")
        presenter.toggleRecording()
        XCTAssertEqual(view.states.last?.phase, .recording)
        presenter.next()
        XCTAssertEqual(view.states.last?.position, 0, "Not while recording")
        presenter.toggleRecording()
        XCTAssertEqual(view.states.last?.phase, .recorded)
        presenter.playMine()
        XCTAssertEqual(recorder.played, recorder.started)
        presenter.next()
        XCTAssertEqual(view.states.last?.phase, .ready)
        presenter.previous()
        XCTAssertEqual(view.states.last?.phase, .recorded, "Going back finds the recording of that sentence")
        presenter.leave()
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path), "Recordings are only for this screen")
    }

    func test_aRefusedMicrophoneSaysWhatToDoAndAnEmptyLessonSaysSo() {
        let recorder = FakeRecorder()
        recorder.allowed = false
        let view = SpyShadowingView()
        let presenter = ShadowingPresenter(sentences: sentences, speech: FakeSpeech(), recorder: recorder, directory: directory)
        presenter.view = view
        presenter.viewDidLoad()
        presenter.toggleRecording()
        XCTAssertEqual(view.states.last?.phase, .ready)
        XCTAssertNotNil(view.states.last?.notice)
        XCTAssertTrue(recorder.started.isEmpty)

        let empty = ShadowingPresenter(sentences: [], speech: FakeSpeech(), recorder: recorder, directory: directory)
        empty.view = view
        empty.viewDidLoad()
        XCTAssertEqual(view.states.last?.phase, .empty)
    }
}
