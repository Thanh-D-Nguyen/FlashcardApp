import AVFoundation
import Foundation

protocol SpeechServiceInterface: AnyObject {
    func speak(_ text: String, languageCode: String)
    func stop()
}

/// Reads card text aloud with the system voices (Japanese `ja-JP`, Vietnamese `vi-VN`). The audio session is
/// only active while speaking and ducks other audio instead of stopping it.
final class SystemSpeechService: NSObject, SpeechServiceInterface, AVSpeechSynthesizerDelegate {
    static let shared = SystemSpeechService()

    /// Only ever touched from the main thread (presenters call in from there).
    nonisolated(unsafe) private let synthesizer = AVSpeechSynthesizer()

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, languageCode: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        stop()
        // A missing session or voice must not break studying: speech is an aid, so failures only skip the audio.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
    }

    private func endSession() {
        guard !synthesizer.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { endSession() }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { endSession() }
}
