import UIKit

protocol MagazineWireframeInterface: AnyObject {
    func showArticle(slug: String, day: MagazineDay?)
}

/// The article list. It is pushed from Discover, so it has no tab bar item of its own.
final class MagazineWireframe: BaseWireframe<MagazineViewController> {
    init(interactor: MagazineInteractorInterface = MagazineInteractor()) {
        let controller = MagazineViewController()
        super.init(viewController: controller)
        controller.title = NSLocalizedString("Magazine", comment: "Name of the daily reading feed")
        let presenter = MagazinePresenter(interactor: interactor, wireframe: self)
        presenter.view = controller
        controller.presenter = presenter
    }
}

extension MagazineWireframe: MagazineWireframeInterface {
    func showArticle(slug: String, day: MagazineDay?) {
        navigationController?.pushWireframe(MagazineArticleWireframe(slug: slug, day: day))
    }
}
