import UIKit

protocol DictionaryHandwritingWireframeInterface: AnyObject {
    /// Closes the sheet and runs the search for `text`.
    func finish(lookingUp text: String)
    func close()
}

final class DictionaryHandwritingWireframe: BaseWireframe<DictionaryHandwritingViewController> {
    private let onLookUp: (String) -> Void

    init(onLookUp: @escaping (String) -> Void,
         interactor: DictionaryHandwritingInteractorInterface = DictionaryHandwritingInteractor()) {
        self.onLookUp = onLookUp
        let controller = DictionaryHandwritingViewController()
        super.init(viewController: controller)
        controller.presenter = DictionaryHandwritingPresenter(interactor: interactor, wireframe: self)
    }
}

extension DictionaryHandwritingWireframe: DictionaryHandwritingWireframeInterface {
    func finish(lookingUp text: String) {
        let completion = onLookUp
        viewController.presentingViewController?.dismiss(animated: true) { completion(text) }
    }
}
