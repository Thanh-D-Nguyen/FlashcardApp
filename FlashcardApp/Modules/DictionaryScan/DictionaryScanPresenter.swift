import Foundation
import RxRelay
import RxSwift
import UIKit

enum ScanState: Equatable {
    /// Waiting for a photo.
    case choosing(camera: CameraAccess)
    case recognizing
    case recognized(String)
    /// Recognition ran and found no text.
    case noText
    case failed(String)
}

protocol DictionaryScanPresenterInterface: AnyObject {
    var state: BehaviorRelay<ScanState> { get }
    func viewWillAppear()
    func takePhoto()
    func choosePhoto()
    func imagePicked(_ image: UIImage)
    func pickerCancelled()
    /// Looks up `text` in the dictionary and closes the scanner. Only text a search accepts is looked up.
    func lookUp(_ text: String)
    func scanAnother()
    func close()
    func openSettings()
}

final class DictionaryScanPresenter: DictionaryScanPresenterInterface {
    let state: BehaviorRelay<ScanState>

    private let interactor: DictionaryScanInteractorInterface
    private let wireframe: DictionaryScanWireframeInterface
    private var recognitionBag = DisposeBag()
    private let permissionBag = DisposeBag()

    init(interactor: DictionaryScanInteractorInterface, wireframe: DictionaryScanWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
        state = BehaviorRelay(value: .choosing(camera: interactor.cameraAccess))
    }

    func viewWillAppear() {
        // The learner may have changed the permission in Settings and come back.
        if case .choosing = state.value { state.accept(.choosing(camera: interactor.cameraAccess)) }
    }

    func takePhoto() {
        switch interactor.cameraAccess {
        case .available:
            wireframe.showCamera()
        case .notDetermined:
            interactor.requestCamera()
                .observe(on: MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] granted in
                    guard let self else { return }
                    self.state.accept(.choosing(camera: self.interactor.cameraAccess))
                    if granted { self.wireframe.showCamera() }
                })
                .disposed(by: permissionBag)
        case .denied:
            state.accept(.choosing(camera: .denied))
        case .unavailable:
            state.accept(.choosing(camera: .unavailable))
        }
    }

    func choosePhoto() { wireframe.showPhotoPicker() }

    func imagePicked(_ image: UIImage) {
        recognitionBag = DisposeBag()
        state.accept(.recognizing)
        interactor.recognize(image)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] recognized in
                self?.state.accept(recognized.isEmpty ? .noText : .recognized(recognized.text))
            }, onFailure: { [weak self] error in
                self?.state.accept(.failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription))
            })
            .disposed(by: recognitionBag)
    }

    func pickerCancelled() {
        // Cancelling the picker keeps whatever was on screen; only an unfinished recognition is abandoned.
        if state.value == .recognizing { recognitionBag = DisposeBag(); state.accept(.choosing(camera: interactor.cameraAccess)) }
    }

    func lookUp(_ text: String) {
        guard case .valid(let query) = DictionaryQuery.validate(text) else { return }
        wireframe.finish(lookingUp: query.text)
    }

    func scanAnother() {
        recognitionBag = DisposeBag()
        state.accept(.choosing(camera: interactor.cameraAccess))
    }

    func close() { wireframe.close() }
    func openSettings() { wireframe.openSystemSettings() }
}
