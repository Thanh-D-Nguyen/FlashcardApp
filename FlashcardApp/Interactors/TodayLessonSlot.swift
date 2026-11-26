import Foundation

/// What Today's lesson slot offers, decided only from the learner's own progress on this device.
enum TodayLessonSlot: Equatable {
    /// Nothing started: choose a level.
    case start
    /// A lesson with answers but not finished. `title` is nil when the lesson is not saved on this device.
    case continueLesson(slug: String, title: String?, levelCode: String, answered: Int, total: Int)
    /// The lesson after the one finished last, as that lesson's saved copy names it.
    case next(slug: String, title: String, levelCode: String)
    /// Lessons were finished but the one after them is unknown or already done: choose again.
    case finishedOpened(completed: Int)
}

protocol TodayLessonSlotProviding: AnyObject {
    func slot(ownerKey: String) -> TodayLessonSlot
    func completedToday(ownerKey: String, now: Date, calendar: Calendar) -> Bool
}

extension TodayLessonSlotProviding {
    func completedToday(ownerKey: String, now: Date, calendar: Calendar) -> Bool { false }
}

final class TodayLessonSlotProvider: TodayLessonSlotProviding {
    private let store: LessonProgressStoreInterface
    private let cache: LessonCacheInterface
    private let language: () -> AppLanguage

    init(store: LessonProgressStoreInterface = RealmLessonProgressStore.shared, cache: LessonCacheInterface = LessonCache.shared,
         language: @escaping () -> AppLanguage = { .current }) {
        self.store = store
        self.cache = cache
        self.language = language
    }

    /// A lesson being practised comes first; otherwise the lesson after the one finished last. Every number is a real count of
    /// this learner's saved answers: nothing is guessed about lessons that were never opened here.
    func slot(ownerKey: String) -> TodayLessonSlot {
        let progress = store.allProgress(ownerKey: ownerKey)
        if let current = progress.filter({ !$0.isCompletedLocally && !$0.answers.isEmpty }).max(by: { $0.startedAt < $1.startedAt }) {
            return .continueLesson(slug: current.slug, title: title(of: cache.lesson(slug: current.slug)), levelCode: current.levelCode,
                                   answered: current.answers.count, total: current.activityTotal)
        }
        let finished = progress.filter(\.isCompletedLocally).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        guard !finished.isEmpty else { return .start }
        let finishedSlugs = Set(finished.map(\.slug))
        for lesson in finished {
            // The saved copy of a finished lesson names the one after it; a lesson never saved on this device names none.
            if let next = cache.lesson(slug: lesson.slug)?.nextLesson, !finishedSlugs.contains(next.slug) {
                return .next(slug: next.slug, title: next.titleVi, levelCode: lesson.levelCode)
            }
        }
        return .finishedOpened(completed: finished.count)
    }

    func completedToday(ownerKey: String, now: Date, calendar: Calendar) -> Bool {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return store.allProgress(ownerKey: ownerKey).contains { lesson in
            guard let done = lesson.completedAt else { return false }
            return done >= start && done < end
        }
    }

    private func title(of lesson: BJTLessonDetailDTO?) -> String? {
        guard let lesson else { return nil }
        let preferred = language() == .japanese ? lesson.titleJa : lesson.titleVi
        return [preferred, lesson.titleVi, lesson.titleJa].first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
