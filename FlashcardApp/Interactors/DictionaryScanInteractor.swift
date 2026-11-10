import AVFoundation
import Foundation
import RxSwift
import UIKit

enum CameraAccess: Equatable {
    /// Authorised and a camera exists.
    case available
    /// The system will ask when the camera is first used.
    case notDetermined
    case denied
    /// No camera (a Simulator, some iPads).
    case unavailable
}

protocol DictionaryScanInteractorInterface: AnyObject {
    var cameraAccess: CameraAccess { get }
    /// Asks the system for camera permission; `true` when granted.
    func requestCamera() -> Single<Bool>
    func recognize(_ image: UIImage) -> Single<RecognizedText>
}

final class DictionaryScanInteractor: DictionaryScanInteractorInterface {
    private let recognizer: TextRecognizing

    init(recognizer: TextRecognizing = VisionTextRecognizer()) {
        self.recognizer = recognizer
    }

    var cameraAccess: CameraAccess {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return .unavailable }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .available
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    func requestCamera() -> Single<Bool> {
        Single.create { observer in
            AVCaptureDevice.requestAccess(for: .video) { granted in observer(.success(granted)) }
            return Disposables.create()
        }
    }

    func recognize(_ image: UIImage) -> Single<RecognizedText> { recognizer.recognize(image) }
}
