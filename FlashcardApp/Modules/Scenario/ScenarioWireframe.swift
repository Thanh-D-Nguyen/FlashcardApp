import UIKit

protocol ScenarioListWireframeInterface: AnyObject {
    /// `ordered` is the list as the learner sees it, so "next situation" follows it.
    func showScenario(_ summary: ScenarioSummary, ordered: [ScenarioSummary])
    func showSignIn(onFinish: @escaping () -> Void)
}

/// The catalogue of everyday situations. It is pushed from Today, so it has no tab bar item of its own.
final class ScenarioListWireframe: BaseWireframe<ScenarioListViewController> {
    private let interactor: ScenarioInteractorInterface

    init(interactor: ScenarioInteractorInterface = ScenarioInteractor()) {
        self.interactor = interactor
        let controller = ScenarioListViewController()
        super.init(viewController: controller)
        controller.title = NSLocalizedString("Daily-life situations", comment: "Name of the situation lessons")
        let presenter = ScenarioListPresenter(interactor: interactor, wireframe: self)
        presenter.view = controller
        controller.presenter = presenter
    }
}

extension ScenarioListWireframe: ScenarioListWireframeInterface {
    func showScenario(_ summary: ScenarioSummary, ordered: [ScenarioSummary]) {
        navigationController?.pushWireframe(ScenarioPlayWireframe(summary: summary, ordered: ordered, interactor: interactor))
    }

    func showSignIn(onFinish: @escaping () -> Void) {
        let login = MailLoginWireframe(onFinish: onFinish)
        // Read once: the wireframe hands out its only strong reference to the controller on first access.
        let loginController = login.viewController
        loginController.modalPresentationStyle = .fullScreen
        viewController.present(loginController, animated: true)
    }
}

protocol ScenarioPlayWireframeInterface: AnyObject {
    /// Replaces this situation with the next one, so Back returns to the catalogue.
    func showNext(_ summary: ScenarioSummary)
    func leave()
}

final class ScenarioPlayWireframe: BaseWireframe<ScenarioPlayViewController> {
    private let ordered: [ScenarioSummary]
    private let interactor: ScenarioInteractorInterface

    init(summary: ScenarioSummary, ordered: [ScenarioSummary], interactor: ScenarioInteractorInterface) {
        self.ordered = ordered
        self.interactor = interactor
        let controller = ScenarioPlayViewController()
        super.init(viewController: controller)
        let next = ordered.firstIndex(where: { $0.id == summary.id }).flatMap { index in
            ordered.indices.contains(index + 1) ? ordered[index + 1] : nil
        }
        let presenter = ScenarioPlayPresenter(summary: summary, next: next, interactor: interactor, wireframe: self)
        presenter.view = controller
        controller.presenter = presenter
    }
}

extension ScenarioPlayWireframe: ScenarioPlayWireframeInterface {
    func showNext(_ summary: ScenarioSummary) {
        guard let navigation = navigationController else { return }
        let next = ScenarioPlayWireframe(summary: summary, ordered: ordered, interactor: interactor)
        var stack = navigation.viewControllers
        if !stack.isEmpty { stack.removeLast() }
        stack.append(next.viewController)
        navigation.setViewControllers(stack, animated: true)
    }

    func leave() {
        navigationController?.popViewController(animated: true)
    }
}
