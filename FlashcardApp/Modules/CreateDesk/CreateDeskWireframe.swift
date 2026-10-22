//
//  CreateDeskWireframe.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//  
//

import UIKit

protocol CreateDeskWireframeInterface: AnyObject {
    func showAlert(with title: String?, message: String?)
    func close()
    func confirmDiscard(onDiscard: @escaping () -> Void)
    func confirmDeleteCard(number: Int, onDelete: @escaping () -> Void)
    func confirmDeleteDeck(named name: String, onDelete: @escaping () -> Void)
    func offerDraftRestore(restore: @escaping () -> Void, discard: @escaping () -> Void)
}

final class CreateDeskWireframe: BaseWireframe<CreateDeskViewController> {

    /// `deckId == nil` creates a deck; otherwise that deck is edited. `onFinish` runs after a successful save.
    init(deckId: String? = nil, onFinish: (() -> Void)? = nil) {
        let moduleViewController = CreateDeskViewController()
        super.init(viewController: moduleViewController)
        let interactor = CreateDeskInteractor()
        let presenter = CreateDeskPresenter(interactor: interactor, wireframe: self, deckId: deckId, onFinish: onFinish)
        presenter.view = moduleViewController
        moduleViewController.presenter = presenter
    } 
}

extension CreateDeskWireframe: CreateDeskWireframeInterface {

    func confirmDiscard(onDiscard: @escaping () -> Void) {
        let discard = UIAlertAction(title: NSLocalizedString("Discard changes", comment: ""), style: .destructive) { _ in onDiscard() }
        let keep = UIAlertAction(title: NSLocalizedString("Keep editing", comment: ""), style: .cancel)
        showAlert(with: NSLocalizedString("Discard your changes?", comment: ""),
                  message: NSLocalizedString("The changes to this deck have not been saved.", comment: ""), actions: [discard, keep])
    }

    func confirmDeleteCard(number: Int, onDelete: @escaping () -> Void) {
        let delete = UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { _ in onDelete() }
        let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
        showAlert(with: String(format: NSLocalizedString("Delete card %lld?", comment: ""), number),
                  message: NSLocalizedString("Its text and picture will be removed from this deck.", comment: ""), actions: [delete, cancel])
    }

    func confirmDeleteDeck(named name: String, onDelete: @escaping () -> Void) {
        let delete = UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { _ in onDelete() }
        let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
        let message = String.localizedStringWithFormat(
            NSLocalizedString("“%@” and all of its cards will be deleted from this device. This can't be undone.", comment: "Delete deck confirmation"), name)
        showAlert(with: NSLocalizedString("Delete this deck?", comment: ""), message: message, actions: [delete, cancel])
    }

    func offerDraftRestore(restore: @escaping () -> Void, discard: @escaping () -> Void) {
        let restoreAction = UIAlertAction(title: NSLocalizedString("Restore draft", comment: ""), style: .default) { _ in restore() }
        let discardAction = UIAlertAction(title: NSLocalizedString("Discard draft", comment: ""), style: .destructive) { _ in discard() }
        showAlert(with: NSLocalizedString("Unsaved draft found", comment: ""),
                  message: NSLocalizedString("You have unsaved changes from an earlier session. Restore them?", comment: ""),
                  actions: [restoreAction, discardAction])
    }
}
