import UIKit

protocol CardStudyWireframeInterface: AnyObject {
    func showEditor(deckId: String, onFinish: @escaping () -> Void)
    /// Presents the card style picker; `onChange` runs each time the learner picks a style.
    func showStylePicker(selectedSlug: String?, onChange: @escaping () -> Void)
    /// Presents the form for a sentence. `save` validates and stores it; when it throws, the form stays open and shows the message.
    func showExampleEditor(isNew: Bool, draft: CardExampleDraft, save: @escaping (CardExampleDraft) throws -> Void)
    /// Asks before a sentence goes: what happens depends on whether it is the learner's or the server's.
    func confirmRemoveExample(origin: ExampleOrigin, onConfirm: @escaping () -> Void)
    func showError(_ message: String)
    /// Asks before leaving while an attempt is not saved: it will not count toward the learner's progress.
    func confirmLeaveUnsaved(onLeave: @escaping () -> Void)
    /// Tells the learner the session cannot go on (the account changed), then leaves.
    func endSession(message: String)
    func leave()
}

final class CardStudyWireframe: BaseWireframe<CardStudyViewController> {

    init(deckId: String, cardIDs: [String]? = nil) {
        let controller = CardStudyViewController()
        super.init(viewController: controller)
        controller.hidesBottomBarWhenPushed = true
#if DEBUG
        let history = DebugFixtures.reviewHistory()
#else
        let history: ReviewHistoryStoreInterface = RealmReviewHistoryStore()
#endif
        let presenter = CardStudyPresenter(deckId: deckId, cardIDs: cardIDs, interactor: CardStudyInteractor(), wireframe: self, reviewHistory: history)
        presenter.view = controller
        controller.presenter = presenter
    }
}

extension CardStudyWireframe: CardStudyWireframeInterface {
    func showEditor(deckId: String, onFinish: @escaping () -> Void) {
        let editor = CreateDeskWireframe(deckId: deckId, onFinish: onFinish)
        viewController.present(UINavigationController(rootViewController: editor.viewController), animated: true)
    }

    func showStylePicker(selectedSlug: String?, onChange: @escaping () -> Void) {
        let picker = CardStylePickerWireframe(selectedSlug: selectedSlug, onChange: onChange)
        // Read once: the wireframe hands out its only strong reference to the controller on first access.
        let pickerController = picker.viewController
        let navigation = UINavigationController(rootViewController: pickerController)
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        viewController.present(navigation, animated: true)
    }

    func showExampleEditor(isNew: Bool, draft: CardExampleDraft, save: @escaping (CardExampleDraft) throws -> Void) {
        let editor = ExampleEditorWireframe(isNew: isNew, draft: draft, save: save)
        // Read once: the wireframe hands out its only strong reference to the controller on first access.
        let editorController = editor.viewController
        let navigation = UINavigationController(rootViewController: editorController)
        navigation.modalPresentationStyle = .pageSheet
        viewController.present(navigation, animated: true)
    }

    func confirmRemoveExample(origin: ExampleOrigin, onConfirm: @escaping () -> Void) {
        let isServer = origin != .custom
        let alert = UIAlertController(
            title: isServer ? NSLocalizedString("Remove this example sentence?", comment: "") : NSLocalizedString("Delete this example sentence?", comment: ""),
            message: isServer
                ? NSLocalizedString("It is removed from your examples only. Other learners still see it, and you can bring it back.", comment: "")
                : NSLocalizedString("The sentence you wrote will be deleted. This can't be undone.", comment: ""),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        let confirm = UIAlertAction(title: isServer ? NSLocalizedString("Remove", comment: "") : NSLocalizedString("Delete", comment: ""),
                                    style: .destructive) { _ in onConfirm() }
        alert.addAction(confirm)
        viewController.present(alert, animated: true)
    }

    func showError(_ message: String) {
        showAlert(with: nil, message: message)
    }

    func confirmLeaveUnsaved(onLeave: @escaping () -> Void) {
        let alert = UIAlertController(
            title: NSLocalizedString("Leave without saving?", comment: ""),
            message: NSLocalizedString("The last answer isn't saved, so it won't count toward your progress.", comment: ""),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Stay", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Leave session", comment: ""), style: .destructive) { _ in onLeave() })
        viewController.present(alert, animated: true)
    }

    func endSession(message: String) {
        // On whatever is on top (the editor may be open), and never a second alert over the first.
        var top: UIViewController = viewController
        while let presented = top.presentedViewController { top = presented }
        guard !(top is UIAlertController) else { return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { [weak self] _ in self?.leave() })
        top.present(alert, animated: true)
    }

    func leave() {
        if navigationController?.topViewController === viewController {
            navigationController?.popViewController(animated: true)
        }
    }
}
