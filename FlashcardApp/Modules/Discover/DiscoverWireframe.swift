import UIKit

protocol DiscoverWireframeInterface: AnyObject {
    func show(_ feature: DiscoverFeature)
    func showMagazineArticle(slug: String, day: MagazineDay?)
}

final class DiscoverWireframe: BaseWireframe<DiscoverViewController> {
    init() {
        let controller = DiscoverViewController()
        super.init(viewController: controller)
        controller.title = MainTabbarName.discover.title
        controller.tabBarItem = MainTabbarName.discover.tabBarItem
        let presenter = DiscoverPresenter(wireframe: self)
        presenter.view = controller
        controller.presenter = presenter
    }
}

extension DiscoverWireframe: DiscoverWireframeInterface {
    func show(_ feature: DiscoverFeature) {
        switch feature {
        case .loto: navigationController?.pushWireframe(LotoWireframe())
        case .magazine: navigationController?.pushWireframe(MagazineWireframe())
        case .levels: navigationController?.pushWireframe(HomeWireframe())
        }
    }

    func showMagazineArticle(slug: String, day: MagazineDay?) {
        navigationController?.pushWireframe(MagazineArticleWireframe(slug: slug, day: day))
    }
}
