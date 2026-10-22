import UIKit

protocol HomeWireframeInterface: AnyObject {
    func showLevel(_ level: BJTLevelDTO, kind: HomeContentKind)
    func showMeaning(title: String, message: String)
}

final class HomeWireframe: BaseWireframe<HomeViewController>, HomeWireframeInterface {
    init(level: BJTLevelDTO? = nil, kind: HomeContentKind = .vocabulary) {
        let controller = HomeViewController()
        super.init(viewController: controller)
        controller.title = level?.localizedName(for: .current) ?? NSLocalizedString("Levels", comment: "")
        controller.tabBarItem = MainTabbarName.home.tabBarItem
        controller.presenter = HomePresenter(interactor: HomeInteractor(), wireframe: self, level: level, kind: kind)
    }

    func showLevel(_ level: BJTLevelDTO, kind: HomeContentKind) {
        let controller = HomeWireframe(level: level, kind: kind).viewController
        if let navigationController {
            // The level's numeral grows into the level screen; the system drops this to a
            // cross-fade under Reduce Motion and falls back to a push if the source scrolled away.
            controller.preferredTransition = .zoom { [weak self] _ in
                self?.viewController.transitionSourceView(forLevelCode: level.code)
            }
            navigationController.pushViewController(controller, animated: true)
        } else {
            let navigation = UINavigationController(rootViewController: controller)
            controller.navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close,
                primaryAction: UIAction { [weak navigation] _ in navigation?.dismiss(animated: true) })
            viewController.present(navigation, animated: true)
        }
    }

    func showMeaning(title: String, message: String) {
        showAlert(with: title, message: message)
    }
}
