import UIKit

protocol LevelEntryDetailWireframeInterface: AnyObject {
    func showDictionaryEntry(_ item: DictionaryItem)
    func showLessons()
    func share(_ text: String)
    func openSystemSettings()
}

final class LevelEntryDetailWireframe: BaseWireframe<LevelEntryDetailViewController>, LevelEntryDetailWireframeInterface {
    private let level: BJTLevelDTO?

    init(entry: LevelEntry, level: BJTLevelDTO? = nil) {
        self.level = level
        let controller = LevelEntryDetailViewController()
        super.init(viewController: controller)
        controller.title = entry.kind.title
        let presenter = LevelEntryDetailPresenter(entry: entry, wireframe: self)
        presenter.view = controller
        controller.presenter = presenter
    }

    func showDictionaryEntry(_ item: DictionaryItem) {
        let wireframe = DictionaryEntryWireframe(item: item, lookUp: { [weak self] text in
            self?.routeToDictionarySearch(text)
        }, popsToRootOnLookUp: false)
        navigationController?.pushWireframe(wireframe)
    }

    func showLessons() {
        guard let level else { return }
        navigationController?.pushWireframe(LessonListWireframe(level: level))
    }

    func share(_ text: String) {
        let sheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        let host = viewController
        sheet.popoverPresentationController?.barButtonItem = host.navigationItem.rightBarButtonItem
        host.present(sheet, animated: true)
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// Switches to the Dictionary tab and runs a search without destroying the Level stack on another tab.
    private func routeToDictionarySearch(_ text: String) {
        guard let tabs = viewController.tabBarController,
              let controllers = tabs.viewControllers,
              controllers.indices.contains(MainTab.dictionary.rawValue) else { return }
        tabs.selectedIndex = MainTab.dictionary.rawValue
        let target = controllers[MainTab.dictionary.rawValue]
        let nav = target as? UINavigationController
        nav?.popToRootViewController(animated: false)
        let root = nav?.viewControllers.first ?? target
        if let dictionary = root as? DictionaryViewController {
            dictionary.presenter.beginSearch(text)
        }
    }
}
