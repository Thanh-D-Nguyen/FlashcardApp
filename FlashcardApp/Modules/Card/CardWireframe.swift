//
//  CardWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import UIKit

protocol CardWireframeInterface: AnyObject {
    func showEditor(deckId: String?, onFinish: @escaping () -> Void)
    /// The choice between typing a deck and generating one; the sheet closes before `onChoose` runs.
    func showNewDeckOptions(onChoose: @escaping (NewDeckMethod) -> Void)
    /// `onImported` runs with the local deck id after the generator has closed.
    func showDeckGenerator(onImported: @escaping (String) -> Void)
    func showStudy(deckId: String)
    func confirmDelete(deckName: String, onConfirm: @escaping () -> Void)
    func showAlert(with title: String?, message: String?)
}

final class CardWireframe: BaseWireframe<CardViewController> {

    init() {
        let moduleViewController = CardViewController()
        super.init(viewController: moduleViewController)
        moduleViewController.title = MainTabbarName.card.title
        moduleViewController.tabBarItem = MainTabbarName.card.tabBarItem
        let interactor = CardInteractor()
        let deskInteractor = DeskInteractor()
        let presenter = CardPresenter(interactor: interactor, deskInteractor: deskInteractor, wireframe: self)
        presenter.view = moduleViewController
        moduleViewController.presenter = presenter
    } 
}

extension CardWireframe: CardWireframeInterface {

    func showEditor(deckId: String?, onFinish: @escaping () -> Void) {
        let editor = CreateDeskWireframe(deckId: deckId, onFinish: onFinish)
        let navigation = UINavigationController(rootViewController: editor.viewController)
        viewController.present(navigation, animated: true)
    }

    func showNewDeckOptions(onChoose: @escaping (NewDeckMethod) -> Void) {
        let options = NewDeckOptionsViewController(onChoose: onChoose)
        options.modalPresentationStyle = .pageSheet
        if let sheet = options.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        viewController.present(options, animated: true)
    }

    func showDeckGenerator(onImported: @escaping (String) -> Void) {
        let generator = DeckGeneratorWireframe(onImported: onImported)
        let navigation = UINavigationController(rootViewController: generator.viewController)
        navigation.modalPresentationStyle = .pageSheet
        navigation.sheetPresentationController?.detents = [.large()]
        viewController.present(navigation, animated: true)
    }

    func showStudy(deckId: String) {
        navigationController?.pushWireframe(CardStudyWireframe(deckId: deckId))
    }

    func confirmDelete(deckName: String, onConfirm: @escaping () -> Void) {
        let message = String.localizedStringWithFormat(
            NSLocalizedString("“%@” and all of its cards will be deleted from this device. This can't be undone.", comment: "Delete deck confirmation"),
            deckName)
        let delete = UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { _ in onConfirm() }
        let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
        showAlert(with: NSLocalizedString("Delete this deck?", comment: ""), message: message, actions: [delete, cancel])
    }
}
