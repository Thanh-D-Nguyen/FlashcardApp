import UIKit

final class CardStylePickerWireframe: BaseWireframe<CardStylePickerViewController> {
    init(selectedSlug: String?, onChange: @escaping () -> Void) {
        let controller = CardStylePickerViewController()
        super.init(viewController: controller)
        let presenter = CardStylePickerPresenter(selectedSlug: selectedSlug, wireframe: self, onChange: onChange)
        presenter.view = controller
        controller.presenter = presenter
    }
}

extension CardStylePickerWireframe: CardStylePickerWireframeInterface {
    // The sheet is presented inside a navigation controller, which is what has to be dismissed.
    func finish() {
        (navigationController ?? viewController).presentingViewController?.dismiss(animated: true)
    }
}
