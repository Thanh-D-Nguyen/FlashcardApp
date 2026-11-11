import UIKit

protocol RemoteDeckWireframeInterface: AnyObject {
    func showStudy(deckId: String)
    func showSignIn(onFinish: @escaping () -> Void)
    /// Asks before hiding the learner's own deck on the server.
    func confirmArchive(deckName: String, onConfirm: @escaping () -> Void)
    func chooseReportReason(onSelect: @escaping (String) -> Void)
    func confirmBlockAuthor(onConfirm: @escaping () -> Void)
    func leave()
    /// The system share sheet with the deck's link.
    func shareLink(_ url: URL)
    func confirmStopSharing(onConfirm: @escaping () -> Void)
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

    func chooseReportReason(onSelect: @escaping (String) -> Void) {
        let alert = UIAlertController(title: NSLocalizedString("Report this deck", comment: ""),
                                      message: NSLocalizedString("Why are you reporting this deck?", comment: ""), preferredStyle: .alert)
        for (reason, title) in [
            ("spam", NSLocalizedString("Spam or advertising", comment: "")),
            ("abuse", NSLocalizedString("Harassment or hateful content", comment: "")),
            ("sexual", NSLocalizedString("Sexual or inappropriate content", comment: "")),
            ("other", NSLocalizedString("Other concern", comment: ""))
        ] {
            alert.addAction(UIAlertAction(title: title, style: .default) { _ in onSelect(reason) })
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        viewController.present(alert, animated: true)
    }

    func confirmBlockAuthor(onConfirm: @escaping () -> Void) {
        showAlert(with: NSLocalizedString("Block this author?", comment: ""),
                  message: NSLocalizedString("Public decks from this author will disappear from your account. You can still keep copies already saved on this device.", comment: ""),
                  actions: [UIAlertAction(title: NSLocalizedString("Block author", comment: ""), style: .destructive) { _ in onConfirm() },
                            UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)])
    }

    func leave() {
        navigationController?.popViewController(animated: true)
    }

    func shareLink(_ url: URL) {
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = viewController.view
        viewController.present(sheet, animated: true)
    }

    func confirmStopSharing(onConfirm: @escaping () -> Void) {
        showAlert(with: NSLocalizedString("Stop sharing this deck?", comment: ""),
                  message: NSLocalizedString("The link stops working for everyone. Copies already saved by others stay theirs.", comment: "Stop sharing confirmation"),
                  actions: [UIAlertAction(title: NSLocalizedString("Stop sharing", comment: ""), style: .destructive) { _ in onConfirm() },
                            UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)])
    }
}

/// A deck someone shared by link: its public preview, and a copy into the account.
final class SharedDeckWireframe: BaseWireframe<SharedDeckViewController> {
    init(link: DeckShareLink) {
        let controller = SharedDeckViewController()
        super.init(viewController: controller)
        controller.hidesBottomBarWhenPushed = true
        let presenter = SharedDeckPresenter(link: link, interactor: DeckSharingInteractor(), wireframe: self)
        presenter.view = controller
        controller.presenter = presenter
    }
}

extension SharedDeckWireframe: SharedDeckWireframeInterface {
    func showSignIn(onFinish: @escaping () -> Void) {
        let login = MailLoginWireframe(onFinish: onFinish)
        let loginController = login.viewController
        loginController.modalPresentationStyle = .fullScreen
        viewController.present(loginController, animated: true)
    }

    func showAccountDeck(id: String) {
        guard let navigationController else { return }
        let deck = RemoteDeckWireframe(deckId: id)
        var stack = navigationController.viewControllers
        if stack.last === viewController { stack.removeLast() }
        stack.append(deck.viewController)
        navigationController.setViewControllers(stack, animated: true)
    }
}
