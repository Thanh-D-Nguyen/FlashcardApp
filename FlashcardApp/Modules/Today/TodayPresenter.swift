import Foundation

/// What the primary button of Today does.
enum TodayAction: Equatable {
    case createDeck
    case chooseDeck
    /// Study these cards of the deck in this order; `nil` studies the whole deck.
    case study(deckID: String, cardIDs: [String]?)
}

/// The one raised block of Today: where the learner is and the one thing to do next.
struct TodayHero: Equatable {
    let eyebrow: String
    let title: String
    /// A real count (never a placeholder) with its caption; both nil when there is no number to show.
    let figure: String?
    let caption: String?
    let lines: [String]
    let ctaTitle: String
    let action: TodayAction
}

struct TodayRows: Equatable {
    let deckName: String
    let sessionLength: String
}

enum TodayLessonAction: Equatable {
    case chooseLevel
    case openLesson(slug: String, title: String)
}

/// The lesson slot under the review block. It never replaces the review CTA and says nothing about due cards.
struct TodayLessonCard: Equatable {
    let eyebrow: String
    let title: String
    let detail: String?
    let ctaTitle: String
    let action: TodayLessonAction
}

struct TodayProgressText: Equatable {
    let title: String
    let detail: String?
}

/// The Daily Radar card of Today: the server's texts only.
struct TodayRadarCard: Equatable {
    let eyebrow: String
    let title: String
    /// The first Japanese expression of the card, the thing to learn.
    let expression: String
    let detail: String?
}

/// The account streak strip, from the server's own count and optional real per-day local history.
struct TodayStreakText: Equatable {
    let title: String
    let detail: String
    let days: Int
    let countsToday: Bool
    let todayStatusText: String
    /// Real 7-day dots for the current week when per-day history exists on this device; `nil` otherwise (no fake dots).
    let weekDots: [TodayWeekDayDot]?

    init(title: String, detail: String, days: Int = 0, countsToday: Bool = false,
         todayStatusText: String = "", weekDots: [TodayWeekDayDot]? = nil) {
        self.title = title
        self.detail = detail
        self.days = days
        self.countsToday = countsToday
        self.todayStatusText = todayStatusText
        self.weekDots = weekDots
    }
}

struct TodayViewState: Equatable {
    enum Phase: Equatable {
        case loaded
        /// The saved progress could not be read. Never shown as zeros.
        case failed
    }

    var phase: Phase
    var subtitle: String
    var hero: TodayHero?
    var rows: TodayRows?
    var progress: TodayProgressText?
    var failureTitle: String?
    var failureMessage: String?
    /// "Learn from Life": independent of the review block above. `nil` hides it.
    var life: TodayHubSection?
    /// Where the learner is in the structured lessons, from their own progress. `nil` hides it.
    var lessonCard: TodayLessonCard?
    /// The signed-in account's current streak. `nil` hides it (guests, no current streak, not loaded, failed).
    var streak: TodayStreakText?
    /// One Daily Radar card. `nil` hides it (loading, failed with no recent copy, nothing usable).
    var radar: TodayRadarCard?
    /// "Today's quest": max 3 real checklist items assembled from review due state, lesson slot, and Daily Radar.
    var quest: TodayQuestState?
}

protocol TodayViewInterface: AnyObject {
    func render(_ state: TodayViewState)
}

protocol TodayPresenterInterface: AnyObject {
    func viewWillAppear()
    /// The screen is still open but the world moved on (the app came back to the foreground, the day changed).
    func refresh()
    func primaryAction()
    func changeDeck()
    func changeBudget()
    func openLevels()
    /// The everyday-situation lessons, whatever Today is showing: they do not depend on the plan or on the life hub.
    func openScenarios()
    /// The lesson slot's button: continues or starts a lesson, or opens the levels.
    func openLessonSlot()
    /// The Daily Radar card was tapped.
    func openRadar()
    /// A checklist item in Today's Quest was tapped.
    func openQuestItem(_ action: TodayQuestAction)
    func retry()
    /// A card of the life hub was tapped (or its button): opens its lesson, asks for the location, or retries, by what the card is.
    func openLifeCard(id: String)
    func changeLifeCity()
    func retryLife()
}

final class TodayPresenter {
    private let interactor: TodayInteractorInterface
    private let wireframe: TodayWireframeInterface
    private let ownerKey: () -> String
    private let now: () -> Date
    weak var view: TodayViewInterface?

    private let life: TodayLifeHubLoading?
    private let lessons: TodayLessonSlotProviding?
    private let streak: TodayStreakLoading?
    private let radar: TodayRadarLoading?
    private let questStore: TodayQuestCompletionStoreInterface
    private let calendar: () -> Calendar

    private var plan: TodayPlan?
    private var state: TodayViewState?

    /// `life` is optional so that the review block can be exercised alone: without it Today shows no lesson offer.
    init(interactor: TodayInteractorInterface, wireframe: TodayWireframeInterface,
         ownerKey: @escaping () -> String = { AuthSession.shared.currentUser?.id ?? "" },
         now: @escaping () -> Date = Date.init,
         life: TodayLifeHubLoading? = nil,
         lessons: TodayLessonSlotProviding? = nil,
         streak: TodayStreakLoading? = nil,
         radar: TodayRadarLoading? = nil,
         questStore: TodayQuestCompletionStoreInterface = UserDefaultsTodayQuestCompletionStore.shared,
         calendar: @escaping () -> Calendar = { .autoupdatingCurrent }) {
        self.lessons = lessons
        self.streak = streak
        self.radar = radar
        self.questStore = questStore
        self.calendar = calendar
        self.interactor = interactor
        self.wireframe = wireframe
        self.ownerKey = ownerKey
        self.now = now
        self.life = life
        life?.onChange = { [weak self] in self?.lifeChanged() }
        streak?.onChange = { [weak self] in self?.lifeChanged() }
        radar?.onChange = { [weak self] in self?.lifeChanged() }
    }

    /// The life hub or the streak changed on their own: everything else on screen stays as it is.
    private func lifeChanged() {
        guard let current = state else { return }
        publish(current)
    }

    // MARK: State

    private func reload() {
        let owner = ownerKey()
        do {
            let plan = try interactor.plan(ownerKey: owner, now: now())
            self.plan = plan
            publish(Self.makeState(plan))
            life?.refresh()
            streak?.refresh()
            radar?.refresh()
        } catch {
            logger.error("Reading today's plan failed: \(error.localizedDescription)")
            plan = nil
            publish(TodayViewState(phase: .failed, subtitle: "", hero: nil, rows: nil, progress: nil,
                                   failureTitle: NSLocalizedString("Couldn't read your progress", comment: ""),
                                   failureMessage: NSLocalizedString("The study data on this device couldn't be opened. Your data is not deleted.", comment: "")))
            life?.refresh()
            streak?.refresh()
            radar?.refresh()
        }
    }

    private func publish(_ state: TodayViewState) {
        var state = state
        let owner = ownerKey()
        let date = now()
        let cal = calendar()
        let lessonSlot = lessons?.slot(ownerKey: owner)
        let lessonCompletedToday = lessons?.completedToday(ownerKey: owner, now: date, calendar: cal) ?? false
        let radarItem = radar?.item
        let radarCompletedToday = radarItem.map {
            questStore.isRadarCompleted(slug: $0.slug, ownerKey: owner, on: date, calendar: cal)
        } ?? false
        let studiedDays = interactor.studiedDaysInCurrentWeek(ownerKey: owner, now: date)
        state.life = life?.section
        state.lessonCard = lessonSlot.map(Self.lessonCard)
        state.streak = streak?.streak.map { Self.streakText($0, studiedDaysInWeek: studiedDays, now: date, calendar: cal) }
        state.radar = radarItem.flatMap(Self.radarCard)
        state.quest = TodayQuestAssembler.make(
            plan: plan,
            lessonSlot: lessonSlot,
            lessonCompletedToday: lessonCompletedToday,
            radar: radarItem,
            radarCompletedToday: radarCompletedToday
        )
        self.state = state
        view?.render(state)
    }

    private static func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    private static func minutesText(_ count: Int) -> String { String.localizedStringWithFormat(text("%lld minutes"), count) }

    private static func estimateText(_ plan: TodayPlan) -> String? {
        plan.estimatedMinutes.map { String.localizedStringWithFormat(text("About %lld minutes"), $0) }
    }

    /// Everything on screen is stated from the plan: real counts, or no number at all.
    static func makeState(_ plan: TodayPlan) -> TodayViewState {
        let deckID = plan.deckID ?? ""
        let deckName = plan.deckName ?? ""
        var state = TodayViewState(phase: .loaded, subtitle: "", hero: nil, rows: nil, progress: nil)

        switch plan.kind {
        case .noDeck:
            state.subtitle = text("No deck yet.")
            state.hero = TodayHero(eyebrow: text("GET STARTED"), title: text("Start with your own deck"), figure: nil, caption: nil,
                                   lines: [text("Make a deck from the words you are learning, or study by level.")],
                                   ctaTitle: text("Create a deck"), action: .createDeck)
            return state
        case .chooseDeck:
            state.subtitle = text("Choose the deck to study.")
            state.hero = TodayHero(eyebrow: text("DECKS"), title: text("Which deck today?"), figure: nil, caption: nil,
                                   lines: [text("You have several decks. Choose one to see what is due.")],
                                   ctaTitle: text("Choose a deck"), action: .chooseDeck)
            return state
        case .practice:
            // A deck answered before, but not in the way studied now, is not "never studied".
            state.subtitle = plan.studiedAnotherWay ? text("You haven't studied this deck this way yet.") : text("You haven't studied this deck yet.")
            state.hero = TodayHero(eyebrow: text("CURRENT DECK"), title: deckName, figure: "\(plan.sessionCardIDs.count)", caption: text("cards to practise"),
                                   lines: [plan.studiedAnotherWay ? text("No answers of this kind saved yet.") : text("No answers saved yet.")]
                                       + (estimateText(plan).map { [$0] } ?? []),
                                   ctaTitle: text("Practise this deck"), action: .study(deckID: deckID, cardIDs: plan.sessionCardIDs))
        case .due, .returning:
            state.subtitle = plan.kind == .due ? text("Short reviews, on what you need to remember.") : text("Welcome back. Let's start gently.")
            let caption = plan.backlog == 0 ? text("to review") : String.localizedStringWithFormat(text("of %lld to review"), plan.dueCount)
            var lines = estimateText(plan).map { [$0] } ?? []
            if plan.backlog > 0 { lines.append(String.localizedStringWithFormat(text("%lld more are waiting"), plan.backlog)) }
            state.hero = TodayHero(eyebrow: text("CURRENT DECK"), title: deckName, figure: "\(plan.sessionCardIDs.count)", caption: caption, lines: lines,
                                   ctaTitle: plan.kind == .due ? text("Start review") : text("Start a short session"),
                                   action: .study(deckID: deckID, cardIDs: plan.sessionCardIDs))
        case .nothingDue:
            state.subtitle = text("Nothing to review today.")
            state.hero = TodayHero(eyebrow: text("CURRENT DECK"), title: deckName, figure: nil, caption: nil,
                                   lines: [text("Nothing due"), text("You can practise more whenever you like.")],
                                   ctaTitle: text("Practise more"), action: .study(deckID: deckID, cardIDs: plan.practiceCardIDs.isEmpty ? nil : plan.practiceCardIDs))
        case .doneToday:
            state.subtitle = text("Today's review is done.")
            state.hero = TodayHero(eyebrow: text("CURRENT DECK"), title: deckName, figure: nil, caption: nil,
                                   lines: [String.localizedStringWithFormat(text("Saved %lld today"), plan.progress.saved)],
                                   ctaTitle: text("Practise more"), action: .study(deckID: deckID, cardIDs: plan.practiceCardIDs.isEmpty ? nil : plan.practiceCardIDs))
        }

        state.rows = TodayRows(deckName: deckName, sessionLength: minutesText(plan.budgetMinutes))
        state.progress = progressText(plan.progress)
        return state
    }

    static func radarCard(_ item: DailyRadarItem) -> TodayRadarCard? {
        guard let expression = item.expressions.first?.japanese else { return nil }
        let detail = [item.level, item.minutes.map(minutesText)].compactMap { $0 }.joined(separator: " · ")
        return TodayRadarCard(eyebrow: item.moduleTitle, title: item.title, expression: expression, detail: detail.isEmpty ? nil : detail)
    }

    static func streakText(_ streak: AccountStreak, studiedDaysInWeek: Set<Date> = [],
                           now: Date = Date(), calendar: Calendar = .autoupdatingCurrent,
                           locale: Locale = AppLanguage.current.locale) -> TodayStreakText {
        let dots = TodayStreakStripBuilder.weekDots(
            streak: streak,
            studiedDaysInWeek: studiedDaysInWeek,
            now: now,
            calendar: calendar,
            locale: locale
        )
        return TodayStreakText(
            title: String.localizedStringWithFormat(text("%lld-day study streak"), streak.days),
            detail: streak.countsToday ? text("Today is counted on your account.") : text("Review an account card today to keep it going."),
            days: streak.days,
            countsToday: streak.countsToday,
            todayStatusText: streak.countsToday ? text("Studied today") : text("Not studied today"),
            weekDots: dots
        )
    }

    static func lessonCard(_ slot: TodayLessonSlot) -> TodayLessonCard {
        switch slot {
        case .start:
            return TodayLessonCard(eyebrow: text("LESSONS"), title: text("Learn Japanese for work"), detail: text("Short structured lessons with practice."),
                                   ctaTitle: text("Choose a level"), action: .chooseLevel)
        case .continueLesson(let slug, let title, let levelCode, let answered, let total):
            return TodayLessonCard(eyebrow: text("CONTINUE LESSON"), title: title ?? String(format: text("%@ lesson"), levelCode),
                                   detail: String(format: text("%lld of %lld answered"), answered, total),
                                   ctaTitle: text("Continue"), action: .openLesson(slug: slug, title: title ?? slug))
        case .next(let slug, let title, let levelCode):
            return TodayLessonCard(eyebrow: text("NEXT LESSON"), title: title, detail: levelCode, ctaTitle: text("Start lesson"),
                                   action: .openLesson(slug: slug, title: title))
        case .finishedOpened(let completed):
            return TodayLessonCard(eyebrow: text("LESSONS"), title: text("Pick your next lesson"),
                                   detail: String(format: text("Lessons finished: %lld"), completed), ctaTitle: text("Choose a lesson"), action: .chooseLevel)
        }
    }

    private static func progressText(_ progress: TodayProgress) -> TodayProgressText {
        guard progress.saved > 0 else { return TodayProgressText(title: text("Nothing saved yet today."), detail: nil) }
        var parts: [String] = []
        if progress.quizCorrect + progress.quizIncorrect > 0 {
            parts.append(text("Quiz") + " " + String(format: text("%1$lld correct · %2$lld incorrect"), progress.quizCorrect, progress.quizIncorrect))
        }
        if progress.selfRated > 0 {
            parts.append(text("Self-rating") + " " + String.localizedStringWithFormat(text("%lld attempts"), progress.selfRated))
        }
        return TodayProgressText(title: String.localizedStringWithFormat(text("Saved %lld attempts"), progress.saved),
                                 detail: parts.isEmpty ? nil : parts.joined(separator: " · "))
    }
}

extension TodayPresenter: TodayPresenterInterface {
    func viewWillAppear() { reload() }

    func refresh() { reload() }

    func primaryAction() {
        guard let action = state?.hero?.action else { return }
        switch action {
        case .createDeck:
            wireframe.showCreateDeck { [weak self] in self?.reload() }
        case .chooseDeck:
            changeDeck()
        case .study(let deckID, let cardIDs):
            wireframe.showStudy(deckId: deckID, cardIDs: cardIDs)
        }
    }

    func changeDeck() {
        wireframe.showDeckChooser(interactor.deckChoices(), selectedID: plan?.deckID) { [weak self] id in
            guard let self else { return }
            self.interactor.selectDeck(id: id, ownerKey: self.ownerKey())
            self.reload()
        }
    }

    func changeBudget() {
        wireframe.showBudgetChooser(current: interactor.budgetMinutes(ownerKey: ownerKey())) { [weak self] minutes in
            guard let self else { return }
            self.interactor.setBudgetMinutes(minutes, ownerKey: self.ownerKey())
            self.reload()
        }
    }

    func openLevels() { wireframe.showLevels() }

    func openScenarios() { wireframe.showScenarios() }

    func openLessonSlot() {
        guard let action = state?.lessonCard?.action else { return }
        switch action {
        case .chooseLevel: wireframe.showLevels()
        case .openLesson(let slug, let title): wireframe.showLesson(slug: slug, title: title)
        }
    }

    func openRadar() {
        guard state?.radar != nil, let item = radar?.item else { return }
        questStore.markRadarCompleted(slug: item.slug, ownerKey: ownerKey(), on: now(), calendar: calendar())
        if let current = state { publish(current) }
        wireframe.showRadarCard(item)
    }

    func openQuestItem(_ action: TodayQuestAction) {
        switch action {
        case .review: primaryAction()
        case .lesson: openLessonSlot()
        case .radar: openRadar()
        }
    }

    func retry() { reload() }

    func openLifeCard(id: String) {
        guard let life, let card = state?.life?.cards.first(where: { $0.id == id }) else { return }
        switch card.status {
        case .ready:
            guard let lesson = life.lesson(forCard: id) else { return }
            wireframe.showLifeLesson(cityID: life.cityID, lesson: lesson)
        case .needsLocation: life.requestLocation()
        case .locationDenied: wireframe.openAppSettings()
        case .failed: life.retry()
        case .loading, .locating: break
        }
    }

    func changeLifeCity() {
        guard let life else { return }
        wireframe.showCityChooser(selectedID: life.cityID) { id in life.selectCity(id) }
    }

    func retryLife() { life?.retry() }
}
