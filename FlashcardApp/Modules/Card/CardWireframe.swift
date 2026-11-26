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
    /// The cards the learner keeps getting wrong, from this device's history.
    func showOftenMissed()
    /// Asks for a pasted share link (or token) of a deck; `onSubmit` receives the text.
    func askForSharedDeckLink(onSubmit: @escaping (String) -> Void)
    /// The public preview of a shared deck, where it can be copied into the account.
    func showSharedDeck(_ link: DeckShareLink)
    /// Starts a review of these due cards.
    func showReview(cards: [DueCard])
    /// Opens a deck of the account (cards, save to device, study).
    func showRemoteDeck(deckId: String)
    func showSignIn(onFinish: @escaping () -> Void)
    func confirmDelete(deckName: String, onConfirm: @escaping () -> Void)
    func confirmUpload(deckName: String, cardCount: Int, pictureCount: Int, onConfirm: @escaping () -> Void)
    /// A blocking progress alert; `onCancel == nil` shows it without a working Cancel button.
    func showUploadProgress(message: String, onCancel: (() -> Void)?)
    func hideUploadProgress(then: @escaping () -> Void)
    func showAlert(with title: String?, message: String?)
}

final class CardWireframe: BaseWireframe<CardViewController> {
    private var uploadAlert: UIAlertController?
    private var uploadCancel: UIAlertAction?
    private var uploadOnCancel: (() -> Void)?

    init() {
        let moduleViewController = CardViewController()
        super.init(viewController: moduleViewController)
        moduleViewController.title = MainTabbarName.card.title
        moduleViewController.tabBarItem = MainTabbarName.card.tabBarItem
        let deskInteractor = DeskInteractor()
        let presenter = CardPresenter(deskInteractor: deskInteractor, wireframe: self)
        presenter.view = moduleViewController
        moduleViewController.presenter = presenter
    } 
}

extension CardWireframe: CardWireframeInterface {

    func showEditor(deckId: String?, onFinish: @escaping () -> Void) {
        NewDeckFlow.presentEditor(from: viewController, deckId: deckId, onFinish: onFinish)
    }

    func showNewDeckOptions(onChoose: @escaping (NewDeckMethod) -> Void) {
        NewDeckFlow.presentOptions(from: viewController, onChoose: onChoose)
    }

    func showDeckGenerator(onImported: @escaping (String) -> Void) {
        NewDeckFlow.presentGenerator(from: viewController, onImported: onImported)
    }

    func showStudy(deckId: String) {
        navigationController?.pushWireframe(CardStudyWireframe(deckId: deckId))
    }

    func showOftenMissed() {
        navigationController?.pushWireframe(OftenMissedWireframe())
    }

    func showReview(cards: [DueCard]) {
        navigationController?.pushWireframe(CardReviewWireframe(initialCards: cards))
    }

    func showRemoteDeck(deckId: String) {
        navigationController?.pushWireframe(RemoteDeckWireframe(deckId: deckId))
    }

    func askForSharedDeckLink(onSubmit: @escaping (String) -> Void) {
        let alert = UIAlertController(title: NSLocalizedString("Add a shared deck", comment: "Cards: open a deck shared by link"),
                                      message: NSLocalizedString("Paste the link someone shared with you.", comment: ""), preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "https://kiokoto.com/…/decks/shared/…"
            field.keyboardType = .URL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.accessibilityIdentifier = "shared_deck_link_field"
            if let pasted = UIPasteboard.general.hasURLs ? UIPasteboard.general.url?.absoluteString : nil { field.text = pasted }
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Open", comment: ""), style: .default) { [weak alert] _ in
            onSubmit(alert?.textFields?.first?.text ?? "")
        })
        viewController.present(alert, animated: true)
    }

    func showSharedDeck(_ link: DeckShareLink) {
        navigationController?.pushWireframe(SharedDeckWireframe(link: link))
    }

    func showSignIn(onFinish: @escaping () -> Void) {
        let login = MailLoginWireframe(onFinish: onFinish)
        // Read once: the wireframe hands out its only strong reference to the controller on first access.
        let loginController = login.viewController
        loginController.modalPresentationStyle = .fullScreen
        viewController.present(loginController, animated: true)
    }

    func confirmDelete(deckName: String, onConfirm: @escaping () -> Void) {
        let message = String.localizedStringWithFormat(
            NSLocalizedString("“%@”, all of its cards and your study history for them will be deleted from this device. This can't be undone.", comment: "Delete deck confirmation"),
            deckName)
        let delete = UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { _ in onConfirm() }
        let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
        showAlert(with: NSLocalizedString("Delete this deck?", comment: ""), message: message, actions: [delete, cancel])
    }

    func confirmUpload(deckName: String, cardCount: Int, pictureCount: Int, onConfirm: @escaping () -> Void) {
        var message = String.localizedStringWithFormat(
            NSLocalizedString("“%@” will be copied to your account as a private deck of %lld cards.", comment: ""), deckName, cardCount)
        if pictureCount > 0 {
            message += "\n" + String.localizedStringWithFormat(
                NSLocalizedString("%lld pictures are shrunk and compressed to a few hundred KB each before uploading.", comment: ""), pictureCount)
        }
        message += "\n" + NSLocalizedString("Changes you make here afterwards are not synchronised.", comment: "")
        let save = UIAlertAction(title: NSLocalizedString("Save", comment: ""), style: .default) { _ in onConfirm() }
        let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel)
        showAlert(with: NSLocalizedString("Save this deck to your account?", comment: ""), message: message, actions: [save, cancel])
    }

    func showUploadProgress(message: String, onCancel: (() -> Void)?) {
        if let alert = uploadAlert {
            alert.message = message
            uploadOnCancel = onCancel
            uploadCancel?.isEnabled = onCancel != nil
            return
        }
        let alert = UIAlertController(title: NSLocalizedString("Saving to your account", comment: ""), message: message, preferredStyle: .alert)
        let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { [weak self] _ in
            self?.uploadOnCancel?()
            self?.uploadAlert = nil
        }
        cancel.isEnabled = onCancel != nil
        alert.addAction(cancel)
        uploadAlert = alert
        uploadCancel = cancel
        uploadOnCancel = onCancel
        (navigationController ?? viewController).present(alert, animated: true)
    }

    func hideUploadProgress(then: @escaping () -> Void) {
        guard let alert = uploadAlert else { return then() }
        uploadAlert = nil
        alert.dismiss(animated: true, completion: then)
    }
}
