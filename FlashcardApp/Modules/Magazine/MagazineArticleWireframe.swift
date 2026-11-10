import UIKit

protocol MagazineArticleWireframeInterface: AnyObject {
    /// Existing decks, plus the "Magazine" deck as a new one when it does not exist yet.
    func showDeckChooser(_ choices: [TodayDeckChoice], magazineDeckExists: Bool, selected: MagazineSaveTarget, onSelect: @escaping (MagazineSaveTarget) -> Void)
    func showStudy(deckId: String, cardIDs: [String])
}

final class MagazineArticleWireframe: BaseWireframe<MagazineArticleViewController> {
    init(slug: String, day: MagazineDay?, interactor: MagazineInteractorInterface = MagazineInteractor()) {
        let controller = MagazineArticleViewController()
        super.init(viewController: controller)
        let presenter = MagazineArticlePresenter(slug: slug, day: day, interactor: interactor, wireframe: self)
        presenter.view = controller
        controller.presenter = presenter
    }
}

extension MagazineArticleWireframe: MagazineArticleWireframeInterface {
    func showDeckChooser(_ choices: [TodayDeckChoice], magazineDeckExists: Bool, selected: MagazineSaveTarget, onSelect: @escaping (MagazineSaveTarget) -> Void) {
        let sheet = UIAlertController(title: NSLocalizedString("Save words to", comment: "Deck chooser title"), message: nil, preferredStyle: .actionSheet)
        let selectedID: String? = {
            switch selected {
            case .existing(let id): return id
            case .newMagazineDeck: return magazineDeckExists ? MagazineInteractor.magazineDeckID : nil
            }
        }()
        if !magazineDeckExists {
            let mark = selected == .newMagazineDeck ? "✓ " : ""
            sheet.addAction(UIAlertAction(title: mark + NSLocalizedString("Magazine (new deck)", comment: ""), style: .default) { _ in onSelect(.newMagazineDeck) })
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
}
