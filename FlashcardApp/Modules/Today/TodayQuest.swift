import Foundation

enum TodayQuestAction: Equatable {
    case review
    case lesson
    case radar
}

struct TodayQuestItem: Equatable {
    let id: String
    let action: TodayQuestAction
    let title: String
    let detail: String?
    let estimatedMinutes: Int?
    let isDone: Bool
}

struct TodayQuestState: Equatable {
    let title: String
    let summary: String
    let completionTitle: String
    let items: [TodayQuestItem]
    let completedCount: Int
    let totalCount: Int

    var isAllDone: Bool { totalCount > 0 && completedCount == totalCount }
    var progressFraction: Double { totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0 }
}

/// Date-stamped UserDefaults persistence for Today's Daily Radar completion. No Realm schema change.
protocol TodayQuestCompletionStoreInterface: AnyObject {
    func isRadarCompleted(slug: String, ownerKey: String, on date: Date, calendar: Calendar) -> Bool
    func markRadarCompleted(slug: String, ownerKey: String, on date: Date, calendar: Calendar)
}

final class UserDefaultsTodayQuestCompletionStore: TodayQuestCompletionStoreInterface {
    static let shared = UserDefaultsTodayQuestCompletionStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func storageKey(ownerKey: String, on date: Date, calendar: Calendar) -> String {
        let day = AccountStreak.dayKey(date, calendar: calendar)
        return "com.flashcardapp.today.quest.radar.\(ownerKey).\(day)"
    }

    func isRadarCompleted(slug: String, ownerKey: String, on date: Date, calendar: Calendar) -> Bool {
        guard !slug.isEmpty else { return false }
        let completed = defaults.stringArray(forKey: storageKey(ownerKey: ownerKey, on: date, calendar: calendar)) ?? []
        return completed.contains(slug)
    }

    func markRadarCompleted(slug: String, ownerKey: String, on date: Date, calendar: Calendar) {
        guard !slug.isEmpty else { return }
        let key = storageKey(ownerKey: ownerKey, on: date, calendar: calendar)
        var completed = defaults.stringArray(forKey: key) ?? []
        if !completed.contains(slug) {
            completed.append(slug)
            defaults.set(completed, forKey: key)
        }
    }
}

/// Assembles up to 3 Today's Quest checklist items strictly from real app state. Never invents counts or items.
enum TodayQuestAssembler {
    static let maxItems = 3

    private static func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }
    private static func minutesText(_ count: Int) -> String { String.localizedStringWithFormat(text("%lld minutes"), count) }
    private static func estimateText(_ count: Int) -> String { String.localizedStringWithFormat(text("About %lld minutes"), count) }
    private static func cardsText(_ count: Int) -> String { String.localizedStringWithFormat(text("%lld cards"), count) }

    static func make(plan: TodayPlan?, lessonSlot: TodayLessonSlot?, lessonCompletedToday: Bool,
                     radar: DailyRadarItem?, radarCompletedToday: Bool) -> TodayQuestState? {
        var items: [TodayQuestItem] = []

        if let reviewItem = reviewQuestItem(from: plan) {
            items.append(reviewItem)
        }
        if let lessonItem = lessonQuestItem(from: lessonSlot, completedToday: lessonCompletedToday) {
            items.append(lessonItem)
        }
        if let radarItem = radarQuestItem(from: radar, completedToday: radarCompletedToday) {
            items.append(radarItem)
        }

        let trimmed = Array(items.prefix(maxItems))
        guard !trimmed.isEmpty else { return nil }

        let completed = trimmed.filter(\.isDone).count
        let total = trimmed.count
        let isAllDone = completed == total
        let summary = isAllDone
            ? text("Done for today")
            : String.localizedStringWithFormat(text("%1$lld of %2$lld done"), completed, total)

        return TodayQuestState(
            title: text("Today's quest"),
            summary: summary,
            completionTitle: text("Done for today"),
            items: trimmed,
            completedCount: completed,
            totalCount: total
        )
    }

    private static func reviewQuestItem(from plan: TodayPlan?) -> TodayQuestItem? {
        guard let plan else { return nil }
        switch plan.kind {
        case .due, .returning:
            guard plan.dueCount > 0 else { return nil }
            let sessionCount = plan.sessionCardIDs.isEmpty ? plan.dueCount : plan.sessionCardIDs.count
            let waiting = plan.backlog > 0
                ? String.localizedStringWithFormat(text("%lld more are waiting"), plan.backlog)
                : nil
            let detail = [cardsText(sessionCount), plan.estimatedMinutes.map(estimateText), waiting]
                .compactMap { $0 }
                .joined(separator: " · ")
            return TodayQuestItem(id: "review", action: .review, title: text("Review due cards"),
                                  detail: detail, estimatedMinutes: plan.estimatedMinutes, isDone: false)
        case .doneToday:
            return TodayQuestItem(id: "review", action: .review, title: text("Review due cards"),
                                  detail: String.localizedStringWithFormat(text("Saved %lld today"), plan.progress.saved),
                                  estimatedMinutes: nil, isDone: true)
        case .practice:
            guard !plan.sessionCardIDs.isEmpty else { return nil }
            let detail = [cardsText(plan.sessionCardIDs.count), plan.estimatedMinutes.map(estimateText)]
                .compactMap { $0 }
                .joined(separator: " · ")
            return TodayQuestItem(id: "review", action: .review, title: text("Practise this deck"),
                                  detail: detail, estimatedMinutes: plan.estimatedMinutes, isDone: false)
        case .noDeck, .chooseDeck, .nothingDue:
            return nil
        }
    }

    private static func lessonQuestItem(from slot: TodayLessonSlot?, completedToday: Bool) -> TodayQuestItem? {
        guard let slot else { return nil }
        if completedToday {
            return TodayQuestItem(id: "lesson", action: .lesson, title: text("Today's lesson"),
                                  detail: text("Completed today"), estimatedMinutes: nil, isDone: true)
        }
        switch slot {
        case .continueLesson(_, let title, let levelCode, let answered, let total):
            let resolvedTitle = title ?? String(format: text("%@ lesson"), levelCode)
            let clampedAnswered = total > 0 ? min(answered, total) : answered
            let detail = String.localizedStringWithFormat(text("%lld of %lld answered"), clampedAnswered, total)
            return TodayQuestItem(id: "lesson", action: .lesson, title: resolvedTitle,
                                  detail: detail, estimatedMinutes: nil, isDone: false)
        case .next(_, let title, let levelCode):
            return TodayQuestItem(id: "lesson", action: .lesson, title: title,
                                  detail: levelCode, estimatedMinutes: nil, isDone: false)
        case .start:
            return TodayQuestItem(id: "lesson", action: .lesson, title: text("Learn Japanese for work"),
                                  detail: nil, estimatedMinutes: nil, isDone: false)
        case .finishedOpened(let completed):
            return TodayQuestItem(id: "lesson", action: .lesson, title: text("Pick your next lesson"),
                                  detail: String.localizedStringWithFormat(text("Lessons finished: %lld"), completed),
                                  estimatedMinutes: nil, isDone: false)
        }
    }

    private static func radarQuestItem(from radar: DailyRadarItem?, completedToday: Bool) -> TodayQuestItem? {
        guard let radar else { return nil }
        let detail: String?
        if completedToday {
            detail = text("Completed today")
        } else {
            let joined = [radar.level, radar.minutes.map(minutesText)].compactMap { $0 }.joined(separator: " · ")
            detail = joined.isEmpty ? nil : joined
        }
        return TodayQuestItem(id: "radar:\(radar.slug)", action: .radar, title: radar.title,
                              detail: detail, estimatedMinutes: radar.minutes, isDone: completedToday)
    }
}
