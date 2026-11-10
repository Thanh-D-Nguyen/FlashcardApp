import UIKit

protocol DictionarySavedWireframeInterface: AnyObject {
    func showEntry(_ item: DictionaryItem)
    func showSignIn(onFinish: @escaping () -> Void)
}

final class DictionarySavedWireframe: BaseWireframe<DictionarySavedViewController> {
    private let lookUp: (String) -> Void

    init(lookUp: @escaping (String) -> Void, interactor: DictionarySavedInteractorInterface = DictionarySavedInteractor()) {
        self.lookUp = lookUp
        let controller = DictionarySavedViewController()
        super.init(viewController: controller)
        controller.presenter = DictionarySavedPresenter(interactor: interactor, wireframe: self)
    }
}

extension DictionarySavedWireframe: DictionarySavedWireframeInterface {
    func showEntry(_ item: DictionaryItem) {
        navigationController?.pushWireframe(DictionaryEntryWireframe(item: item, lookUp: lookUp))
    }

    func showSignIn(onFinish: @escaping () -> Void) {
        let login = MailLoginWireframe(onFinish: onFinish)
        // Read once: the wireframe hands out its only strong reference to the controller on first access.
        let loginController = login.viewController
        loginController.modalPresentationStyle = .fullScreen
        viewController.present(loginController, animated: true)
    }
}
