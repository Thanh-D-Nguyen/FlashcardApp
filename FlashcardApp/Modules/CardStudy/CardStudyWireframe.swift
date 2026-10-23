import UIKit

protocol CardStudyWireframeInterface: AnyObject {
    func showEditor(deckId: String, onFinish: @escaping () -> Void)
    /// Presents the card style picker; `onChange` runs each time the learner picks a style.
    func showStylePicker(selectedSlug: String?, onChange: @escaping () -> Void)
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

    func showStylePicker(selectedSlug: String?, onChange: @escaping () -> Void) {
        let picker = CardStylePickerWireframe(selectedSlug: selectedSlug, onChange: onChange)
        // Read once: the wireframe hands out its only strong reference to the controller on first access.
        let pickerController = picker.viewController
        let navigation = UINavigationController(rootViewController: pickerController)
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        viewController.present(navigation, animated: true)
    }

    func leave() {
        if navigationController?.topViewController === viewController {
            navigationController?.popViewController(animated: true)
        }
    }
}
