import Foundation
import RxSwift

struct LessonReadResult: Equatable {
    let lesson: BJTLessonDetailDTO
    /// True when the server could not be reached and the copy saved from an earlier visit is shown.
    let isFromCache: Bool
}

protocol LessonReaderInteractorInterface: AnyObject {
    func lesson(slug: String) -> Single<LessonReadResult>
}

/// Server first, so a lesson is always the current one when the server answers. The copy saved from an earlier visit is
/// used only when the server could not be reached (or is overloaded); it never hides a lesson the server says is gone or broken.
final class LessonReaderInteractor: LessonReaderInteractorInterface {
    private let api: BJTLessonAPIInterface
    private let cache: LessonCacheInterface

    init(api: BJTLessonAPIInterface = BJTLessonAPI.shared, cache: LessonCacheInterface = LessonCache.shared) {
        self.api = api
        self.cache = cache
    }

    func lesson(slug: String) -> Single<LessonReadResult> {
        api.lessonPayload(slug: slug)
            .map { [cache] payload in
                // Reading does not depend on saving: a full disk must not turn a good lesson into an error.
                try? cache.store(payload: payload.data, slug: slug)
                return LessonReadResult(lesson: payload.lesson, isFromCache: false)
            }
            .catch { [cache] error in
                guard Self.isUnreachable(error), let saved = cache.lesson(slug: slug) else { return .error(error) }
                return .just(LessonReadResult(lesson: saved, isFromCache: true))
            }
    }

    private static func isUnreachable(_ error: Error) -> Bool {
        switch error as? LearnerAPIError {
        case .offline?, .interrupted?, .rateLimited?, .serviceUnavailable?: return true
        case .server(let status)?: return status >= 500
        default: return false
        }
    }
}
