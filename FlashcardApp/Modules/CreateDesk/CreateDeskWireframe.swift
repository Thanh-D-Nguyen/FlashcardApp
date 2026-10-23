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
    /// Asks before replacing text the learner wrote with a dictionary entry's.
    func confirmReplace(_ proposals: [ReplacementProposal], onReplace: @escaping () -> Void)
    /// Presents the picture search; `onPick` runs once with the picture the learner chose.
    func showPictureSearch(term: String, onPick: @escaping (PictureSuggestion) -> Void)
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
                  message: NSLocalizedString("Its text, picture and study history will be removed from this deck when you save.", comment: ""), actions: [delete, cancel])
    }

    func confirmDeleteDeck(named name: String, onDelete: @escaping () -> Void) {
        let delete = UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { _ in onDelete() }
        let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
        let message = String.localizedStringWithFormat(
            NSLocalizedString("“%@”, all of its cards and your study history for them will be deleted from this device. This can't be undone.", comment: "Delete deck confirmation"), name)
        showAlert(with: NSLocalizedString("Delete this deck?", comment: ""), message: message, actions: [delete, cancel])
    }

    func offerDraftRestore(restore: @escaping () -> Void, discard: @escaping () -> Void) {
        let restoreAction = UIAlertAction(title: NSLocalizedString("Restore draft", comment: ""), style: .default) { _ in restore() }
        let discardAction = UIAlertAction(title: NSLocalizedString("Discard draft", comment: ""), style: .destructive) { _ in discard() }
        showAlert(with: NSLocalizedString("Unsaved draft found", comment: ""),
                  message: NSLocalizedString("You have unsaved changes from an earlier session. Restore them?", comment: ""),
                  actions: [restoreAction, discardAction])
    }

    func confirmReplace(_ proposals: [ReplacementProposal], onReplace: @escaping () -> Void) {
        guard let first = proposals.first else { return }
        let message: String
        if proposals.count == 1 {
            message = String.localizedStringWithFormat(NSLocalizedString("This card already says “%1$@”. Replace it with “%2$@” from the dictionary?", comment: ""), first.current, first.proposed)
        } else {
            message = String.localizedStringWithFormat(NSLocalizedString("%1$lld fields on this card already have text, for example “%2$@”. Replace them with the dictionary entry?", comment: ""), proposals.count, first.current)
        }
        let replace = UIAlertAction(title: NSLocalizedString("Replace", comment: ""), style: .default) { _ in onReplace() }
        let keep = UIAlertAction(title: NSLocalizedString("Keep mine", comment: ""), style: .cancel)
        showAlert(with: NSLocalizedString("Replace what you wrote?", comment: ""), message: message, actions: [replace, keep])
    }

    func showPictureSearch(term: String, onPick: @escaping (PictureSuggestion) -> Void) {
        let search = PictureSearchWireframe(term: term, onPick: onPick)
        let navigation = UINavigationController(rootViewController: search.viewController)
        navigation.modalPresentationStyle = .pageSheet
        navigation.sheetPresentationController?.detents = [.medium(), .large()]
        navigation.sheetPresentationController?.prefersGrabberVisible = true
        viewController.present(navigation, animated: true)
    }
}
