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

    func showReview(cards: [DueCard]) {
        navigationController?.pushWireframe(CardReviewWireframe(initialCards: cards))
    }

    func showRemoteDeck(deckId: String) {
        navigationController?.pushWireframe(RemoteDeckWireframe(deckId: deckId))
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
                NSLocalizedString("%lld pictures are uploaded at a reduced size (up to 1 MB each).", comment: ""), pictureCount)
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
