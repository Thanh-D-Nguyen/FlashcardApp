import Foundation
import RxSwift

protocol DictionaryHandwritingInteractorInterface: AnyObject {
    func candidates(for ink: HandwritingInk) -> Single<[String]>
}

final class DictionaryHandwritingInteractor: DictionaryHandwritingInteractorInterface {
    private let recognizer: HandwritingRecognizing

    init(recognizer: HandwritingRecognizing = StrokeTemplateRecognizer()) {
        self.recognizer = recognizer
    }

    func candidates(for ink: HandwritingInk) -> Single<[String]> { recognizer.candidates(for: ink) }
}
