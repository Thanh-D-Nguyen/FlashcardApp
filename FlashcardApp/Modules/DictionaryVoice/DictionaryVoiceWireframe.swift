import UIKit

protocol DictionaryVoiceWireframeInterface: AnyObject {
    func finish(lookingUp text: String)
    func close()
    func openSystemSettings()
}

final class DictionaryVoiceWireframe: BaseWireframe<DictionaryVoiceViewController> {
    private let onLookUp: (String) -> Void

    init(onLookUp: @escaping (String) -> Void, interactor: DictionaryVoiceInteractorInterface = DictionaryVoiceInteractor()) {
        self.onLookUp = onLookUp
        let controller = DictionaryVoiceViewController()
        super.init(viewController: controller)
        controller.presenter = DictionaryVoicePresenter(interactor: interactor, wireframe: self)
    }
}

extension DictionaryVoiceWireframe: DictionaryVoiceWireframeInterface {
    func finish(lookingUp text: String) {
        let completion = onLookUp
        viewController.presentingViewController?.dismiss(animated: true) { completion(text) }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
