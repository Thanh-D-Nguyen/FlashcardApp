import Foundation
import RxSwift

protocol LessonListInteractorInterface: AnyObject {
    func lessons(levelCode: String) -> Single<[BJTLessonSummaryDTO]>
}

final class LessonListInteractor: LessonListInteractorInterface {
    private let api: BJTLessonAPIInterface

    init(api: BJTLessonAPIInterface = BJTLessonAPI.shared) { self.api = api }

    func lessons(levelCode: String) -> Single<[BJTLessonSummaryDTO]> { api.lessons(levelCode: levelCode) }
}
