import UIKit

protocol RemoteDeckWireframeInterface: AnyObject {
    func showStudy(deckId: String)
    func showSignIn(onFinish: @escaping () -> Void)
    /// Asks before hiding the learner's own deck on the server.
    func confirmArchive(deckName: String, onConfirm: @escaping () -> Void)
    func leave()
}

final class RemoteDeckWireframe: BaseWireframe<RemoteDeckViewController> {

    init(deckId: String) {
        let controller = RemoteDeckViewController()
        super.init(viewController: controller)
        controller.hidesBottomBarWhenPushed = true
        let presenter = RemoteDeckPresenter(deckId: deckId, interactor: CardLibraryServerInteractor(), wireframe: self)
        presenter.view = controller
        controller.presenter = presenter
    }
}

extension RemoteDeckWireframe: RemoteDeckWireframeInterface {
    func showStudy(deckId: String) {
        navigationController?.pushWireframe(CardStudyWireframe(deckId: deckId))
    }

    func showSignIn(onFinish: @escaping () -> Void) {
        let login = MailLoginWireframe(onFinish: onFinish)
        // Read once: the wireframe hands out its only strong reference to the controller on first access.
        let loginController = login.viewController
        loginController.modalPresentationStyle = .fullScreen
        viewController.present(loginController, animated: true)
    }

    func confirmArchive(deckName: String, onConfirm: @escaping () -> Void) {
        let message = String.localizedStringWithFormat(
            NSLocalizedString("“%@” will be removed from your account's library and from the website. A copy saved on this device stays.", comment: "Archive deck confirmation"),
            deckName)
        let archive = UIAlertAction(title: NSLocalizedString("Archive", comment: ""), style: .destructive) { _ in onConfirm() }
        let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
        showAlert(with: NSLocalizedString("Archive this deck?", comment: ""), message: message, actions: [archive, cancel])
    }

    func leave() {
        navigationController?.popViewController(animated: true)
    }
}
