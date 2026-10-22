import UIKit

final class DeckGeneratorWireframe: BaseWireframe<DeckGeneratorViewController> {
    private let onImported: (String) -> Void

    /// `onImported` runs with the local deck id after the generator has closed.
    init(interactor: DeckGeneratorInteractorInterface = DeckGeneratorInteractor(), onImported: @escaping (String) -> Void) {
        self.onImported = onImported
        let moduleViewController = DeckGeneratorViewController()
        super.init(viewController: moduleViewController)
        let presenter = DeckGeneratorPresenter(interactor: interactor, wireframe: self)
        presenter.view = moduleViewController
        moduleViewController.presenter = presenter
    }
}

extension DeckGeneratorWireframe: DeckGeneratorWireframeInterface {
    func showDeck(withId id: String) {
        let completion = onImported
        (navigationController ?? viewController).presentingViewController?.dismiss(animated: true) { completion(id) }
    }

    func showSignIn(onFinish: @escaping () -> Void) {
        let login = MailLoginWireframe(onFinish: onFinish)
        // Read once: the wireframe hands out its only strong reference to the controller on first access.
        let loginController = login.viewController
        loginController.modalPresentationStyle = .fullScreen
        viewController.present(loginController, animated: true)
    }
}
