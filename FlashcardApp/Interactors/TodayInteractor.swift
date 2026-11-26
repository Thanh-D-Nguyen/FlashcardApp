import Foundation

/// A deck the learner can choose to study from Today.
struct TodayDeckChoice: Equatable {
    let id: String
    let name: String
    let cardCount: Int
}

protocol TodayInteractorInterface: AnyObject {
    /// What Today offers this learner now. Throws when the saved progress cannot be read: the learner is told, never shown zeros.
    func plan(ownerKey: String, now: Date) throws -> TodayPlan
    func deckChoices() -> [TodayDeckChoice]
    func selectDeck(id: String, ownerKey: String)
    func budgetMinutes(ownerKey: String) -> Int
    func setBudgetMinutes(_ minutes: Int, ownerKey: String)
    /// Calendar day starts in the learner's current week (Monday–Sunday) that have real recorded study activity on this device.
    func studiedDaysInCurrentWeek(ownerKey: String, now: Date) -> Set<Date>
}

extension TodayInteractorInterface {
    func studiedDaysInCurrentWeek(ownerKey: String, now: Date) -> Set<Date> { [] }
}

final class TodayInteractor: TodayInteractorInterface {
    private let decks: DeskRepositoryInterface
    private let schedules: ReviewScheduleStoreInterface
    private let lessonProgress: LessonProgressStoreInterface
    private let studyPreferences: StudyPreferencesInterface
    private let preferences: TodayPreferencesInterface
    private let calendar: Calendar

    init(decks: DeskRepositoryInterface = DeskManagement.shared,
         schedules: ReviewScheduleStoreInterface = RealmReviewHistoryStore(),
         lessonProgress: LessonProgressStoreInterface = RealmLessonProgressStore.shared,
         studyPreferences: StudyPreferencesInterface = UserDefaultsStudyPreferences.shared,
         preferences: TodayPreferencesInterface = UserDefaultsTodayPreferences.shared,
         calendar: Calendar = .autoupdatingCurrent) {
        self.decks = decks
        self.schedules = schedules
        self.lessonProgress = lessonProgress
        self.studyPreferences = studyPreferences
        self.preferences = preferences
        self.calendar = calendar
    }

    func plan(ownerKey: String, now: Date) throws -> TodayPlan {
        let todayDecks = decks.getAll().map(Self.todayDeck(from:))
        // Schedules are derived from the saved attempts; make sure they exist before reading them (a store that came from a
        // version before schedules, or from another algorithm).
        try schedules.ensureSchedules(ownerKey: ownerKey)
        // "Today" is the learner's local calendar day, not the last 24 hours.
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86_400)
        return TodayPlanner.plan(decks: todayDecks,
                                 selectedDeckID: preferences.selectedDeckID(ownerKey: ownerKey),
                                 mode: studyPreferences.mode,
                                 schedules: schedules.schedules(ownerKey: ownerKey),
                                 // Answers stamped later than today (a clock that was set forward) are not today's.
                                 attemptsToday: schedules.attempts(ownerKey: ownerKey, answeredSince: startOfDay).filter { $0.answeredAt < endOfDay },
                                 budget: TodayBudget(minutes: preferences.budgetMinutes(ownerKey: ownerKey)),
                                 now: now, dueBefore: endOfDay)
    }

    func deckChoices() -> [TodayDeckChoice] {
        decks.getAll().map { TodayDeckChoice(id: $0.id, name: $0.name, cardCount: $0.cards.count) }
    }

    func selectDeck(id: String, ownerKey: String) {
        preferences.setSelectedDeckID(id, ownerKey: ownerKey)
    }

    func budgetMinutes(ownerKey: String) -> Int {
        preferences.budgetMinutes(ownerKey: ownerKey)
    }

    func setBudgetMinutes(_ minutes: Int, ownerKey: String) {
        preferences.setBudgetMinutes(minutes, ownerKey: ownerKey)
    }

    func studiedDaysInCurrentWeek(ownerKey: String, now: Date) -> Set<Date> {
        let weekStart = TodayStreakStripBuilder.currentWeekStart(for: now, calendar: calendar)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart.addingTimeInterval(7 * 86_400)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? weekEnd
        let upperBound = min(weekEnd, todayEnd)

        var days: Set<Date> = []
        for attempt in schedules.attempts(ownerKey: ownerKey, answeredSince: weekStart) where attempt.answeredAt < upperBound {
            days.insert(calendar.startOfDay(for: attempt.answeredAt))
        }
        for lesson in lessonProgress.allProgress(ownerKey: ownerKey) {
            if let done = lesson.completedAt, done >= weekStart, done < upperBound {
                days.insert(calendar.startOfDay(for: done))
            }
        }
        return days
    }

    private static func todayDeck(from entity: DeskEntity) -> TodayDeck {
        let cards = entity.cards.map(StudyCard.init(entity:))
        return TodayDeck(id: entity.id, name: entity.name, cards: cards.map { TodayCard(id: $0.id, version: $0.contentVersion) },
                         canQuiz: StudySession.canQuiz(cards), canType: StudySession.canType(cards))
    }
}
