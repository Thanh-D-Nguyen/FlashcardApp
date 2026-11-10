import SafariServices
import UIKit

protocol LotoWireframeInterface: AnyObject {
    func showOfficialSite(_ url: URL)
}

/// The Loto screen. It is pushed from Discover, so it has no tab bar item of its own.
final class LotoWireframe: BaseWireframe<LotoViewController> {
    init(interactor: LotoInteractorInterface = LotoWireframe.defaultInteractor(),
         environment: LotoEnvironmentInteractorInterface = LotoWireframe.defaultEnvironment()) {
        let controller = LotoViewController()
        super.init(viewController: controller)
        controller.title = NSLocalizedString("Loto", comment: "Name of the Loto number-sets feature")
        let presenter = LotoPresenter(interactor: interactor, wireframe: self, environment: environment)
        presenter.view = controller
        controller.presenter = presenter
    }
}

extension LotoWireframe {
    private static func defaultEnvironment() -> LotoEnvironmentInteractorInterface {
        #if DEBUG
        // The fixture runs without a network, so the chaos system has no weather factors.
        if ProcessInfo.processInfo.arguments.contains("-LotoFixture") { return LotoNoEnvironment() }
        #endif
        return LotoEnvironmentInteractor()
    }

    private static func defaultInteractor() -> LotoInteractorInterface {
        #if DEBUG
        // `-LotoFixture` shows recorded production payloads, for screenshots and UI tests without Loto data on the local backend.
        if ProcessInfo.processInfo.arguments.contains("-LotoFixture") { return LotoInteractor(api: LotoFixtureAPI()) }
        #endif
        return LotoInteractor()
    }
}

extension LotoWireframe: LotoWireframeInterface {
    func showOfficialSite(_ url: URL) {
        guard url.scheme == "https" else { return }
        viewController.present(SFSafariViewController(url: url), animated: true)
    }
}
