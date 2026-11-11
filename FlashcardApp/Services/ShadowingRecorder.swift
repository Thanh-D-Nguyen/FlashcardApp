import AVFoundation
import Foundation

/// The microphone and speaker for shadowing. Recording uses the play-and-record session so the learner can hear the model sentence
/// and themselves without leaving the screen; the session is released when nothing is recording or playing.
final class ShadowingRecorder: NSObject, ShadowingRecording {
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?

    func requestPermission(_ completion: @escaping (Bool) -> Void) {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: completion(true)
        case .denied: completion(false)
        default:
            AVAudioApplication.requestRecordPermission { allowed in DispatchQueue.main.async { completion(allowed) } }
        }
    }

    func startRecording(to url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1,
                                       AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        // Long enough for a sentence; a forgotten recording does not fill the disk.
        guard recorder.record(forDuration: 30) else { throw CocoaError(.fileWriteUnknown) }
        self.recorder = recorder
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
    }

    func play(_ url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try session.setActive(true)
        let player = try AVAudioPlayer(contentsOf: url)
        guard player.play() else { throw CocoaError(.fileReadUnknown) }
        self.player = player
    }

    func stopPlaying() {
        player?.stop()
        player = nil
    }
}
