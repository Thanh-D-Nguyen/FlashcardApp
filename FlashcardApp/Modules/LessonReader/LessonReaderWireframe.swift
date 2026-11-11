import UIKit

/// One lesson, pushed from the lesson list.
final class LessonReaderWireframe: BaseWireframe<LessonReaderViewController> {
    init(slug: String, title: String, interactor: LessonReaderInteractorInterface = LessonReaderInteractor()) {
        let controller = LessonReaderViewController()
        super.init(viewController: controller)
        controller.title = NSLocalizedString("Lesson", comment: "Title of the lesson reader")
        let presenter = LessonReaderPresenter(slug: slug, title: title, interactor: interactor)
        presenter.wireframe = self
        controller.presenter = presenter
    }
}

extension LessonReaderWireframe: LessonReaderWireframeInterface {
    func showPractice(lesson: BJTLessonDetailDTO) {
        navigationController?.pushWireframe(LessonPracticeWireframe(lesson: lesson))
    }

    func chooseDeck(from choices: [TodayDeckChoice], completion: @escaping (DictionaryDeckTarget?) -> Void) {
        let sheet = UIAlertController(title: NSLocalizedString("Save to which deck?", comment: "Lesson reader"), message: nil, preferredStyle: .actionSheet)
        for choice in choices {
            sheet.addAction(UIAlertAction(title: "\(choice.name) (\(choice.cardCount))", style: .default) { _ in completion(.existing(deckID: choice.id)) })
        }
        let hasLessonDeck = choices.contains { $0.id == LessonWordSaver.lessonDeckID }
        if !hasLessonDeck {
            sheet.addAction(UIAlertAction(title: NSLocalizedString("New deck: Saved from lessons", comment: "Lesson reader"), style: .default) { _ in completion(.newDictionaryDeck) })
        }
        sheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in completion(nil) })
        sheet.popoverPresentationController?.sourceView = viewController.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 1, height: 1)
        viewController.present(sheet, animated: true)
    }

    func showMessage(title: String, message: String) {
        showAlert(with: title, message: message)
    }
}
