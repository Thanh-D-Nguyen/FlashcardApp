import UIKit

protocol CardStudyWireframeInterface: AnyObject {
    func showEditor(deckId: String, onFinish: @escaping () -> Void)
    func leave()
}

final class CardStudyWireframe: BaseWireframe<CardStudyViewController> {

    init(deckId: String) {
        let controller = CardStudyViewController()
        super.init(viewController: controller)
        controller.hidesBottomBarWhenPushed = true
        let presenter = CardStudyPresenter(deckId: deckId, interactor: CardStudyInteractor(), wireframe: self)
        presenter.view = controller
        controller.presenter = presenter
    }
}

extension CardStudyWireframe: CardStudyWireframeInterface {
    func showEditor(deckId: String, onFinish: @escaping () -> Void) {
        let editor = CreateDeskWireframe(deckId: deckId, onFinish: onFinish)
        viewController.present(UINavigationController(rootViewController: editor.viewController), animated: true)
    }

    func leave() {
        if navigationController?.topViewController === viewController {
            navigationController?.popViewController(animated: true)
        }
    }
}
