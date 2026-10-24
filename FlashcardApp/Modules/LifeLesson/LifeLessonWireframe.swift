import UIKit

protocol LifeLessonWireframeInterface: AnyObject {
    /// Existing decks, plus the "Learn from Life" deck as a new one when it does not exist yet.
    func showDeckChooser(_ choices: [TodayDeckChoice], lifeDeckExists: Bool, selected: LifeSaveTarget, onSelect: @escaping (LifeSaveTarget) -> Void)
    func showStudy(deckId: String, cardIDs: [String])
    /// The data source's own page: the attribution link its licence asks for.
    func openSource(_ url: URL)
    /// Back to Today.
    func finish()
}

final class LifeLessonWireframe: BaseWireframe<LifeLessonViewController> {
    init(cityID: String, lesson: LifeLesson?, interactor: LifeLessonInteractorInterface = LifeLessonInteractor()) {
        let controller = LifeLessonViewController()
        super.init(viewController: controller)
        let presenter = LifeLessonPresenter(cityID: cityID, lesson: lesson, interactor: interactor, wireframe: self)
        presenter.view = controller
        controller.presenter = presenter
    }
}

extension LifeLessonWireframe: LifeLessonWireframeInterface {
    func showDeckChooser(_ choices: [TodayDeckChoice], lifeDeckExists: Bool, selected: LifeSaveTarget, onSelect: @escaping (LifeSaveTarget) -> Void) {
        let sheet = UIAlertController(title: NSLocalizedString("Save words to", comment: "Deck chooser title"), message: nil, preferredStyle: .actionSheet)
        let selectedID: String? = {
            switch selected {
            case .existing(let id): return id
            case .newLifeDeck: return lifeDeckExists ? LifeLessonInteractor.lifeDeckID : nil
            }
        }()
        if !lifeDeckExists {
            let mark = selected == .newLifeDeck ? "✓ " : ""
            sheet.addAction(UIAlertAction(title: mark + NSLocalizedString("Learn from Life (new deck)", comment: ""), style: .default) { _ in onSelect(.newLifeDeck) })
        }
        for choice in choices {
            let cards = String.localizedStringWithFormat(NSLocalizedString("%lld cards", comment: ""), choice.cardCount)
            let mark = choice.id == selectedID ? "✓ " : ""
            sheet.addAction(UIAlertAction(title: "\(mark)\(choice.name) · \(cards)", style: .default) { _ in onSelect(.existing(deckID: choice.id)) })
        }
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        if viewController.traitCollection.userInterfaceIdiom == .pad {
            sheet.popoverPresentationController?.sourceView = viewController.view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
        }
        viewController.present(sheet, animated: true)
    }

    func showStudy(deckId: String, cardIDs: [String]) {
        navigationController?.pushWireframe(CardStudyWireframe(deckId: deckId, cardIDs: cardIDs))
    }

    func openSource(_ url: URL) {
        guard url.scheme == "https" else { return }
        UIApplication.shared.open(url)
    }

    func finish() {
        navigationController?.popToRootViewController(animated: true)
    }
}
