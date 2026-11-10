import Foundation
import RxSwift

protocol DictionaryVoiceInteractorInterface: AnyObject {
    var access: SpeechAccess { get }
    func requestAccess() -> Single<SpeechAccess>
    func listen(stop: Observable<Void>) -> Observable<SpeechUpdate>
}

final class DictionaryVoiceInteractor: DictionaryVoiceInteractorInterface {
    private let recognizer: SpeechRecognizing

    init(recognizer: SpeechRecognizing = SystemSpeechRecognizer()) {
        self.recognizer = recognizer
    }

    var access: SpeechAccess { recognizer.access }
    func requestAccess() -> Single<SpeechAccess> { recognizer.requestAccess() }
    func listen(stop: Observable<Void>) -> Observable<SpeechUpdate> { recognizer.listen(stop: stop) }
}
