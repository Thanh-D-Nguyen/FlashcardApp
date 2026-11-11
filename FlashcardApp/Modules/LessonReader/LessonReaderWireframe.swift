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
}
