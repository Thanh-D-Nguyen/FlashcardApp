import UIKit

/// One lesson, pushed from the lesson list.
final class LessonReaderWireframe: BaseWireframe<LessonReaderViewController> {
    init(slug: String, title: String, interactor: LessonReaderInteractorInterface = LessonReaderInteractor()) {
        let controller = LessonReaderViewController()
        super.init(viewController: controller)
        controller.title = NSLocalizedString("Lesson", comment: "Title of the lesson reader")
        controller.presenter = LessonReaderPresenter(slug: slug, title: title, interactor: interactor)
    }
}
