import UIKit

protocol CardReviewWireframeInterface: AnyObject {
    func leave()
}

final class CardReviewWireframe: BaseWireframe<CardReviewViewController> {

    init(initialCards: [DueCard]?) {
        let controller = CardReviewViewController()
        super.init(viewController: controller)
        controller.hidesBottomBarWhenPushed = true
        let presenter = CardReviewPresenter(initialCards: initialCards, interactor: CardLibraryServerInteractor(), wireframe: self)
        presenter.view = controller
        controller.presenter = presenter
    }
}

extension CardReviewWireframe: CardReviewWireframeInterface {
    func leave() {
        navigationController?.popViewController(animated: true)
    }
}
