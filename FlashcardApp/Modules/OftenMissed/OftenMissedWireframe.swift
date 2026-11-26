import UIKit

/// The learner's often-missed cards. Pushed from the Cards tab, so it has no tab bar item of its own.
final class OftenMissedWireframe: BaseWireframe<OftenMissedViewController> {
    init(interactor: OftenMissedInteractorInterface = OftenMissedInteractor()) {
        let controller = OftenMissedViewController()
        super.init(viewController: controller)
        let presenter = OftenMissedPresenter(interactor: interactor)
        presenter.wireframe = self
        controller.presenter = presenter
    }
}

extension OftenMissedWireframe: OftenMissedWireframeInterface {
    func showStudy(deckId: String, cardIDs: [String]) {
        navigationController?.pushWireframe(CardStudyWireframe(deckId: deckId, cardIDs: cardIDs))
    }
}
