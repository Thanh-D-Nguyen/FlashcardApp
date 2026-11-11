import UIKit

/// The activities of one lesson, pushed from the lesson reader.
final class LessonPracticeWireframe: BaseWireframe<LessonPracticeViewController> {
    init(lesson: BJTLessonDetailDTO,
         store: LessonProgressStoreInterface = RealmLessonProgressStore.shared,
         api: BJTLessonProgressAPIInterface = BJTLearnerAPI.shared) {
        let controller = LessonPracticeViewController()
        super.init(viewController: controller)
        controller.title = NSLocalizedString("Practice", comment: "")
        controller.presenter = LessonPracticePresenter(lesson: lesson, store: store, api: api,
                                                       ownerKey: { AuthSession.shared.currentUser?.id ?? "" })
    }
}
