import SafariServices
import UIKit

protocol DictionaryEntryWireframeInterface: AnyObject {
    /// Opens another entry on top of this one; going back returns here, and then to the search.
    func showEntry(_ item: DictionaryItem)
    func showDeckChooser(_ choices: [TodayDeckChoice], dictionaryDeckExists: Bool, onSelect: @escaping (DictionaryDeckTarget) -> Void)
    func showSignIn(onFinish: @escaping () -> Void)
    func share(_ text: String)
    /// Back to the dictionary with `text` in its search field.
    func showSearch(for text: String)
    func openSystemSettings()
}

final class DictionaryEntryWireframe: BaseWireframe<DictionaryEntryViewController> {
    private let lookUp: (String) -> Void

    /// `lookUp` runs the dictionary search for a text the learner selected inside an entry.
    init(item: DictionaryItem, lookUp: @escaping (String) -> Void,
         interactor: DictionaryEntryInteractorInterface = DictionaryEntryInteractor()) {
        self.lookUp = lookUp
        let controller = DictionaryEntryViewController()
        super.init(viewController: controller)
        let presenter = DictionaryEntryPresenter(item: item, interactor: interactor, wireframe: self)
        controller.presenter = presenter
    }
}

extension DictionaryEntryWireframe: DictionaryEntryWireframeInterface {
    func showEntry(_ item: DictionaryItem) {
        navigationController?.pushWireframe(DictionaryEntryWireframe(item: item, lookUp: lookUp))
    }

    func showDeckChooser(_ choices: [TodayDeckChoice], dictionaryDeckExists: Bool, onSelect: @escaping (DictionaryDeckTarget) -> Void) {
        let sheet = UIAlertController(title: NSLocalizedString("Add to flashcards", comment: "Deck chooser title"),
                                      message: NSLocalizedString("Choose the deck for this card.", comment: ""), preferredStyle: .actionSheet)
        for choice in choices {
            let cards = String.localizedStringWithFormat(NSLocalizedString("%lld cards", comment: ""), choice.cardCount)
            sheet.addAction(UIAlertAction(title: "\(choice.name) · \(cards)", style: .default) { _ in onSelect(.existing(deckID: choice.id)) })
        }
        if !dictionaryDeckExists {
            sheet.addAction(UIAlertAction(title: NSLocalizedString("New deck: Saved from dictionary", comment: ""), style: .default) { _ in onSelect(.newDictionaryDeck) })
        }
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        let host = viewController
        if host.traitCollection.userInterfaceIdiom == .pad {
            sheet.popoverPresentationController?.sourceView = host.view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: host.view.bounds.midX, y: host.view.bounds.midY, width: 0, height: 0)
        }
        host.present(sheet, animated: true)
    }

    func showSignIn(onFinish: @escaping () -> Void) {
        let login = MailLoginWireframe(onFinish: onFinish)
        // Read once: the wireframe hands out its only strong reference to the controller on first access.
        let loginController = login.viewController
        loginController.modalPresentationStyle = .fullScreen
        viewController.present(loginController, animated: true)
    }

    func share(_ text: String) {
        let sheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        let host = viewController
        sheet.popoverPresentationController?.barButtonItem = host.navigationItem.rightBarButtonItems?.last
        host.present(sheet, animated: true)
    }

    func showSearch(for text: String) {
        navigationController?.popToRootViewController(animated: true)
        lookUp(text)
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
