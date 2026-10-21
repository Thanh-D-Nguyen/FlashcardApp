import UIKit

protocol HomeWireframeInterface: AnyObject {
    func showLevel(_ level: BJTLevelDTO)
    func showMeaning(title: String, message: String)
}

final class HomeWireframe: BaseWireframe<HomeViewController>, HomeWireframeInterface {
    init(level: BJTLevelDTO? = nil) {
        let controller = HomeViewController()
        super.init(viewController: controller)
        controller.title = level?.nameVi ?? "Cấp độ"
        controller.tabBarItem = MainTabbarName.home.tabBarItem
        controller.presenter = HomePresenter(interactor: HomeInteractor(), wireframe: self, level: level)
    }

    func showLevel(_ level: BJTLevelDTO) {
        let controller = HomeWireframe(level: level).viewController
        if let navigationController {
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
