import UIKit

final class ExampleEditorWireframe: BaseWireframe<ExampleEditorViewController> {
    init(isNew: Bool, draft: CardExampleDraft, save: @escaping (CardExampleDraft) throws -> Void) {
        let controller = ExampleEditorViewController()
        super.init(viewController: controller)
        let presenter = ExampleEditorPresenter(isNew: isNew, draft: draft, wireframe: self, save: save)
        presenter.view = controller
        controller.presenter = presenter
    }
}

extension ExampleEditorWireframe: ExampleEditorWireframeInterface {
    // The form is presented inside a navigation controller, which is what has to be dismissed.
    func finish() {
        (navigationController ?? viewController).presentingViewController?.dismiss(animated: true)
    }

    func confirmDiscard(onDiscard: @escaping () -> Void) {
        let alert = UIAlertController(title: NSLocalizedString("Discard your changes?", comment: ""), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Keep editing", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Discard", comment: ""), style: .destructive) { _ in onDiscard() })
        viewController.present(alert, animated: true)
    }
}
