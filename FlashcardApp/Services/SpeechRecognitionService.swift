//
//  SpeechRecognitionService.swift
//  FlashcardApp
//
//  Voice input for the dictionary search with Apple's Speech framework (no third-party SDK). It listens in Japanese, prefers
//  on-device recognition when the system offers it, and always ends: when the learner stops it, when the recognizer reports
//  a final result, after a time limit, or when its subscription is disposed. The audio is never recorded to a file.
//

import AVFoundation
import Foundation
import RxSwift
import Speech

enum SpeechAccess: Equatable {
    case authorized
    /// The system will ask on first use.
    case notDetermined
    case denied
    /// Japanese recognition is not available now (no support for the language, or no connection when it needs one).
    case unavailable
}

enum SpeechUpdate: Equatable {
    case partial(String)
    case final(String)
}

enum SpeechRecognitionError: Error, Equatable, LocalizedError {
    case unavailable
    case audioFailed(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: return NSLocalizedString("Japanese speech recognition isn’t available right now.", comment: "")
        case .audioFailed(let reason): return String(format: NSLocalizedString("The microphone could not be used: %@", comment: ""), reason)
        case .failed(let reason): return String(format: NSLocalizedString("Speech recognition failed: %@", comment: ""), reason)
        }
    }
}

protocol SpeechRecognizing: AnyObject {
    var access: SpeechAccess { get }
    /// Asks for speech-recognition and microphone permission together; the result is the resulting access.
    func requestAccess() -> Single<SpeechAccess>
    /// Starts listening. Emits growing partial text, then one `.final`, then completes. Disposing stops the microphone at once.
    /// `stop` ends the audio and lets the recognizer deliver the words it was still working on (it completes after at most
    /// `stopGraceSeconds` even if no final result comes).
    func listen(stop: Observable<Void>) -> Observable<SpeechUpdate>
}

final class SystemSpeechRecognizer: SpeechRecognizing {
    static let maximumListeningSeconds: TimeInterval = 30
    static let stopGraceSeconds: TimeInterval = 2

    private let locale = Locale(identifier: "ja-JP")

    var access: SpeechAccess {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else { return .unavailable }
        let speech = SFSpeechRecognizer.authorizationStatus()
        let microphone = AVAudioApplication.shared.recordPermission
        if speech == .denied || speech == .restricted || microphone == .denied { return .denied }
        if speech == .notDetermined || microphone == .undetermined { return .notDetermined }
        return .authorized
    }

    func requestAccess() -> Single<SpeechAccess> {
        Single.create { [weak self] observer in
            SFSpeechRecognizer.requestAuthorization { _ in
                AVAudioApplication.requestRecordPermission { _ in
                    observer(.success(self?.access ?? .unavailable))
                }
            }
            return Disposables.create()
        }
    }

    func listen(stop: Observable<Void>) -> Observable<SpeechUpdate> {
        Observable.create { [locale] observer in
            guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
                observer.onError(SpeechRecognitionError.unavailable)
                return Disposables.create()
            }
            let engine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            // On-device when the system can; otherwise Apple's servers process the audio (the screen says so).
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.record, mode: .measurement, options: [])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                let format = engine.inputNode.outputFormat(forBus: 0)
                guard format.sampleRate > 0 else { throw SpeechRecognitionError.audioFailed(NSLocalizedString("no audio input", comment: "")) }
                engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
                engine.prepare()
                try engine.start()
            } catch {
                engine.inputNode.removeTap(onBus: 0)
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
                observer.onError(error as? SpeechRecognitionError ?? SpeechRecognitionError.audioFailed(error.localizedDescription))
                return Disposables.create()
            }

            let task = recognizer.recognitionTask(with: request) { result, error in
                if let result {
                    let text = result.bestTranscription.formattedString
                    if result.isFinal {
                        observer.onNext(.final(text))
                        observer.onCompleted()
                    } else {
                        observer.onNext(.partial(text))
                    }
                } else if let error {
                    observer.onError(SpeechRecognitionError.failed(error.localizedDescription))
                }
            }
            let timeout = DispatchWorkItem { request.endAudio() }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.maximumListeningSeconds, execute: timeout)
            // A requested stop closes the audio but keeps the task, so the last words are still recognized.
            let grace = DispatchWorkItem { observer.onCompleted() }
            let stopping = stop.take(1).subscribe(onNext: {
                if engine.isRunning { engine.stop() }
                engine.inputNode.removeTap(onBus: 0)
                request.endAudio()
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.stopGraceSeconds, execute: grace)
            })

            return Disposables.create {
                // The task must not outlive its recognizer, or the system cancels it early.
                withExtendedLifetime(recognizer) {}
                stopping.dispose()
                grace.cancel()
                timeout.cancel()
                if engine.isRunning { engine.stop() }
                engine.inputNode.removeTap(onBus: 0)
                request.endAudio()
                task.cancel()
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }
}
