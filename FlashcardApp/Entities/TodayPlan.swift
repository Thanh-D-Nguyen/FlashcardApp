//
//  TodayPlan.swift
//  FlashcardApp
//
//  What the Today screen offers: for the deck the learner studies, what is due, what a session would contain and which
//  state they are in. Pure Foundation: the numbers come from saved attempts and schedules only, never from fixtures.
//

import Foundation

/// A card as Today sees it: its identity and the wording (`StudyCard.contentVersion`) its schedule must match.
struct TodayCard: Equatable {
    let id: String
    let version: String
}

struct TodayDeck: Equatable {
    let id: String
    let name: String
    let cards: [TodayCard]
    /// Whether a quiz can be made from this deck (at least two different answers), which decides the kind of answer studied.
    let canQuiz: Bool
    /// Whether every card has a kana reading to type (the typed kind of answer).
    var canType = false
}

/// How long a session may take. The time per item is an assumption, not a measurement (the app records no response times
/// yet), so the minutes only size a session and are shown as an estimate beside the real number of items.
struct TodayBudget: Equatable {
    static let allowedMinutes = [3, 5, 10]
    static let defaultMinutes = 5
    static let assumedSecondsPerItem = 20

    let minutes: Int

    init(minutes: Int) {
        self.minutes = Self.allowedMinutes.contains(minutes) ? minutes : Self.defaultMinutes
    }

    var itemLimit: Int { max(1, minutes * 60 / Self.assumedSecondsPerItem) }

    static func estimatedMinutes(forItems count: Int) -> Int {
        max(1, Int((Double(count * assumedSecondsPerItem) / 60).rounded(.up)))
    }
}

/// What was saved today for the deck: kept apart because a quiz result and a self-rating are different evidence.
struct TodayProgress: Equatable {
    var saved = 0
    var quizCorrect = 0
    var quizIncorrect = 0
    var selfRated = 0
}

enum TodayKind: Equatable {
    /// No deck exists: make one, or study a level.
    case noDeck
    /// Several decks and none chosen yet.
    case chooseDeck
    /// The deck has cards but nothing was ever answered for this kind of answer: practise it. Nothing is "due" or "forgotten".
    case practice
    /// Items are due.
    case due
    /// Items are due after a long break: a small session, with the whole backlog shown.
    case returning
    /// Nothing is due and nothing was saved today.
    case nothingDue
    /// Nothing is due and something was saved today.
    case doneToday
}

struct TodayPlan: Equatable {
    var kind: TodayKind
    var deckID: String?
    var deckName: String?
    var cardCount = 0
    /// The kind of answer the plan is about: the study mode the learner uses decides it.
    var skill: ReviewSkill?
    /// Cards due now for that kind of answer, all of them.
    var dueCount = 0
    /// Cards never answered for that kind of answer (or whose wording changed since).
    var unseenCount = 0
    /// What one session holds, in the order it is studied; empty when there is nothing to start.
    var sessionCardIDs: [String] = []
    /// What "practise more" studies: the cards never studied, in deck order, up to the budget. Empty when every card has been
    /// studied; the caller then studies the whole deck.
    var practiceCardIDs: [String] = []
    var estimatedMinutes: Int?
    var budgetMinutes = TodayBudget.defaultMinutes
    var progress = TodayProgress()
    /// The deck was studied before, but not in the way the learner studies now (a quiz and a self-rating are different answers).
    var studiedAnotherWay = false
    /// Due cards a session does not hold (the budget is smaller than the backlog).
    var backlog: Int { max(0, dueCount - sessionCardIDs.count) }
}

enum TodayPlanner {
    /// A break of this many days or more counts as coming back.
    static let longBreak: TimeInterval = 7 * ReviewScheduler.secondsPerDay

    static func plan(decks: [TodayDeck], selectedDeckID: String?, mode: StudyMode, schedules: [ReviewSchedule],
                     attemptsToday: [ReviewAttempt], budget: TodayBudget, now: Date, dueBefore: Date? = nil,
                     scheduler: ReviewScheduler = ReviewScheduler()) -> TodayPlan {
        // A deck without cards cannot be studied, so it is not offered.
        let decks = decks.filter { !$0.cards.isEmpty }
        guard !decks.isEmpty else { return TodayPlan(kind: .noDeck, budgetMinutes: budget.minutes) }
        // The deck the learner chose; with a single deck there is nothing to choose; a choice that no longer exists is no choice.
        let deck = decks.first { $0.id == selectedDeckID } ?? (decks.count == 1 ? decks[0] : nil)
        guard let deck else { return TodayPlan(kind: .chooseDeck, budgetMinutes: budget.minutes) }

        let skill: ReviewSkill
        switch mode {
        case .quiz where deck.canQuiz: skill = .recognition
        case .type where deck.canType: skill = .typedRecall
        default: skill = .selfRecall
        }
        var versions: [String: String] = [:]
        for card in deck.cards where versions[card.id] == nil { versions[card.id] = card.version }

        // Only schedules of the wording each card has now, made by this algorithm, count at all.
        let current = schedules.filter { versions[$0.cardID] == $0.state.contentVersion && $0.state.algorithm == FSRSParameters.algorithm }
        let forSkill = current.filter { $0.skill == skill }
        // Due by the learner's calendar day when a horizon is given (the end of today); otherwise at this very instant.
        let isDue: (ReviewSchedule) -> Bool = { schedule in dueBefore.map { schedule.state.due < $0 } ?? scheduler.isDue(schedule.state, at: now) }
        let due = forSkill.filter(isDue)
            .sorted { ($0.state.due, $0.cardID) < ($1.state.due, $1.cardID) }
        let scheduled = Set(forSkill.map(\.cardID))

        var progress = TodayProgress()
        for attempt in attemptsToday where versions[attempt.cardID] != nil {
            progress.saved += 1
            switch attempt.result {
            case .correct, .typedCorrect: progress.quizCorrect += 1
            case .incorrect, .typedIncorrect: progress.quizIncorrect += 1
            case .remembered, .needsReview: progress.selfRated += 1
            }
        }

        let limit = budget.itemLimit
        var plan = TodayPlan(kind: .nothingDue, deckID: deck.id, deckName: deck.name, cardCount: deck.cards.count, skill: skill)
        plan.dueCount = due.count
        let unseen = deck.cards.filter { !scheduled.contains($0.id) }
        plan.unseenCount = unseen.count
        plan.practiceCardIDs = unseen.prefix(budget.itemLimit).map(\.id)
        plan.budgetMinutes = budget.minutes
        plan.progress = progress
        if !due.isEmpty {
            let lastStudied = current.map(\.state.lastReview).max()
            plan.kind = lastStudied.map { now.timeIntervalSince($0) >= longBreak } == true ? .returning : .due
            plan.sessionCardIDs = due.prefix(limit).map(\.cardID)
        } else if forSkill.isEmpty {
            plan.kind = .practice
            plan.studiedAnotherWay = !current.isEmpty
            plan.sessionCardIDs = deck.cards.prefix(limit).map(\.id)
        } else {
            plan.kind = progress.saved > 0 ? .doneToday : .nothingDue
        }
        if !plan.sessionCardIDs.isEmpty { plan.estimatedMinutes = TodayBudget.estimatedMinutes(forItems: plan.sessionCardIDs.count) }
        return plan
    }
}
