import Foundation

/// One example sentence of a lesson, as the server wrote it.
struct ShadowingSentence: Equatable {
    let japanese: String
    let translation: String?
}

/// The microphone side of shadowing: record the learner, play the recording back. Recordings are temporary files of this screen.
protocol ShadowingRecording: AnyObject {
    /// `true` when the learner allows the microphone (asks the first time).
    func requestPermission(_ completion: @escaping (Bool) -> Void)
    func startRecording(to url: URL) throws
    func stopRecording()
    func play(_ url: URL) throws
    func stopPlaying()
}

struct ShadowingState: Equatable {
    enum Phase: Equatable {
        case empty
        case ready
        case recording
        case recorded
    }

    var phase: Phase = .ready
    var sentence: ShadowingSentence?
    var position = 0
    var total = 0
    var notice: String?
    var canGoBack: Bool { position > 0 }
    var canGoForward: Bool { position + 1 < total }
}

protocol ShadowingViewInterface: AnyObject {
    func render(_ state: ShadowingState)
}

protocol ShadowingPresenterInterface: AnyObject {
    func viewDidLoad()
    func listen()
    func toggleRecording()
    func playMine()
    func next()
    func previous()
    func leave()
}

/// Shadowing: hear a sentence (the system's Japanese voice), say it, hear yourself, compare. The app does not grade the
/// pronunciation: there is no honest automatic score here, so it only gives the two recordings side by side.
final class ShadowingPresenter: ShadowingPresenterInterface {
    private let sentences: [ShadowingSentence]
    private let speech: SpeechServiceInterface
    private let recorder: ShadowingRecording
    private let directory: URL
    weak var view: ShadowingViewInterface?

    private(set) var state = ShadowingState()

    init(sentences: [ShadowingSentence], speech: SpeechServiceInterface, recorder: ShadowingRecording,
         directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("Shadowing-\(UUID().uuidString)", isDirectory: true)) {
        self.sentences = sentences
        self.speech = speech
        self.recorder = recorder
        self.directory = directory
    }

    private func recording(at position: Int) -> URL { directory.appendingPathComponent("sentence-\(position).m4a") }

    private func publish() { view?.render(state) }

    func viewDidLoad() {
        state.total = sentences.count
        state.sentence = sentences.first
        state.phase = sentences.isEmpty ? .empty : .ready
        publish()
    }

    func listen() {
        guard let sentence = state.sentence, state.phase != .recording else { return }
        recorder.stopPlaying()
        speech.speak(sentence.japanese, languageCode: "ja-JP")
    }

    func toggleRecording() {
        guard state.sentence != nil else { return }
        if state.phase == .recording {
            recorder.stopRecording()
            state.phase = .recorded
            return publish()
        }
        speech.stop()
        recorder.stopPlaying()
        let position = state.position
        recorder.requestPermission { [weak self] allowed in
            guard let self, self.state.position == position, self.state.phase != .recording else { return }
            guard allowed else {
                self.state.notice = NSLocalizedString("Allow the microphone in Settings to record yourself.", comment: "Shadowing")
                self.publish()
                return
            }
            do {
                try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
                try self.recorder.startRecording(to: self.recording(at: position))
                self.state.phase = .recording
                self.state.notice = nil
            } catch {
                self.state.notice = NSLocalizedString("Recording could not start.", comment: "Shadowing")
            }
            self.publish()
        }
    }

    func playMine() {
        guard state.phase == .recorded else { return }
        speech.stop()
        do { try recorder.play(recording(at: state.position)) } catch {
            state.notice = NSLocalizedString("Your recording could not be played.", comment: "Shadowing")
            publish()
        }
    }

    private func move(to position: Int) {
        guard sentences.indices.contains(position), state.phase != .recording else { return }
        speech.stop()
        recorder.stopPlaying()
        state.position = position
        state.sentence = sentences[position]
        state.phase = FileManager.default.fileExists(atPath: recording(at: position).path) ? .recorded : .ready
        state.notice = nil
        publish()
    }

    func next() { move(to: state.position + 1) }

    func previous() { move(to: state.position - 1) }

    /// Stops sound and removes the recordings: they are only for comparing on this screen.
    func leave() {
        if state.phase == .recording { recorder.stopRecording() }
        recorder.stopPlaying()
        speech.stop()
        try? FileManager.default.removeItem(at: directory)
    }
}
