import UIKit

protocol PictureSearchWireframeInterface: AnyObject {
    /// Dismisses the search, then runs `then` (the chosen picture's download starts after the sheet is gone).
    func close(then: (() -> Void)?)
    func showSignIn(onFinish: @escaping () -> Void)
}

final class PictureSearchWireframe: BaseWireframe<PictureSearchViewController> {
    init(term: String, interactor: PictureSearchInteractorInterface = PictureSearchInteractor(),
         onPick: @escaping (PictureSuggestion) -> Void) {
        let moduleViewController = PictureSearchViewController()
        super.init(viewController: moduleViewController)
        let presenter = PictureSearchPresenter(term: term, interactor: interactor, wireframe: self, onPick: onPick)
        presenter.view = moduleViewController
        moduleViewController.presenter = presenter
    }
}

extension PictureSearchWireframe: PictureSearchWireframeInterface {
    func close(then: (() -> Void)?) {
        (navigationController ?? viewController).presentingViewController?.dismiss(animated: true, completion: then)
    }

    func showSignIn(onFinish: @escaping () -> Void) {
        let login = MailLoginWireframe(onFinish: onFinish)
        // Read once: the wireframe hands out its only strong reference to the controller on first access.
        let loginController = login.viewController
        loginController.modalPresentationStyle = .fullScreen
        viewController.present(loginController, animated: true)
    }
}
