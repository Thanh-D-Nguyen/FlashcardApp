import UIKit

/// The lessons of one level. Pushed from the level screen, so it has no tab bar item of its own.
final class LessonListWireframe: BaseWireframe<LessonListViewController> {
    init(level: BJTLevelDTO, interactor: LessonListInteractorInterface = LessonListInteractor()) {
        let controller = LessonListViewController()
        super.init(viewController: controller)
        controller.title = String(format: NSLocalizedString("%@ lessons", comment: "Title of the lesson list; the level code, e.g. J5"), level.code)
        let presenter = LessonListPresenter(levelCode: level.code, interactor: interactor)
        presenter.wireframe = self
        controller.presenter = presenter
    }
}

extension LessonListWireframe: LessonListWireframeInterface {
    func showLesson(slug: String, title: String) {
        navigationController?.pushWireframe(LessonReaderWireframe(slug: slug, title: title))
    }
}
