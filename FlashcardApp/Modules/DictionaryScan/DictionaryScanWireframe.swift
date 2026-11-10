import PhotosUI
import UIKit

protocol DictionaryScanWireframeInterface: AnyObject {
    func showCamera()
    func showPhotoPicker()
    /// Closes the scanner and runs the search for `text`.
    func finish(lookingUp text: String)
    func close()
    func openSystemSettings()
}

final class DictionaryScanWireframe: BaseWireframe<DictionaryScanViewController> {
    private let onLookUp: (String) -> Void

    init(onLookUp: @escaping (String) -> Void, interactor: DictionaryScanInteractorInterface = DictionaryScanInteractor()) {
        self.onLookUp = onLookUp
        let controller = DictionaryScanViewController()
        super.init(viewController: controller)
        controller.presenter = DictionaryScanPresenter(interactor: interactor, wireframe: self)
    }
}

extension DictionaryScanWireframe: DictionaryScanWireframeInterface {
    func showCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = viewController
        picker.accessibilityViewIsModal = true
        viewController.present(picker, animated: true)
    }

    func showPhotoPicker() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        // The picker runs out of process: the app sees only the one photo the learner chooses, and needs no library permission.
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = viewController
        viewController.present(picker, animated: true)
    }

    func finish(lookingUp text: String) {
        let completion = onLookUp
        viewController.presentingViewController?.dismiss(animated: true) { completion(text) }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
