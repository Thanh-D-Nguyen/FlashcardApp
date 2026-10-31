import XCTest
@testable import FlashcardApp

/// What Today says and does for each plan. The copy is compared with the localized strings the screen itself uses.
final class TodayPresenterTests: XCTestCase {
    private var interactor: FakeTodayInteractor!
    private var wireframe: FakeTodayWireframe!
    private var view: SpyTodayView!
    private var presenter: TodayPresenter!
    private var owner = "11111111-1111-1111-1111-111111111111"

    override func setUp() {
        super.setUp()
        interactor = FakeTodayInteractor()
        wireframe = FakeTodayWireframe()
        view = SpyTodayView()
    }

    private func start(_ plan: TodayPlan) {
        interactor.result = .success(plan)
        presenter = TodayPresenter(interactor: interactor, wireframe: wireframe, ownerKey: { [unowned self] in owner }, now: { Date(timeIntervalSince1970: 1_800_000_000) })
        presenter.view = view
        presenter.viewWillAppear()
    }

    private var state: TodayViewState { view.renders.last! }
    private func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    private func duePlan(kind: TodayKind = .due, due: Int = 12, session: Int = 12) -> TodayPlan {
        var plan = TodayPlan(kind: kind, deckID: "deck", deckName: "JLPT N5", cardCount: 24, skill: .selfRecall)
        plan.dueCount = due
        plan.sessionCardIDs = (1...session).map { "c\($0)" }
        plan.estimatedMinutes = TodayBudget.estimatedMinutes(forItems: session)
        return plan
    }

    // MARK: Each state

    func test_withNoDeckTheOnlyOfferIsToMakeOneAndThereAreNoNumbers() {
        start(TodayPlan(kind: .noDeck))
        XCTAssertEqual(state.phase, .loaded)
        XCTAssertEqual(state.subtitle, text("No deck yet."))
        XCTAssertEqual(state.hero?.eyebrow, text("GET STARTED"))
        XCTAssertEqual(state.hero?.title, text("Start with your own deck"))
        XCTAssertEqual(state.hero?.ctaTitle, text("Create a deck"))
        XCTAssertEqual(state.hero?.action, .createDeck)
        XCTAssertNil(state.hero?.figure)
        XCTAssertNil(state.rows, "No deck, nothing to change")
        XCTAssertNil(state.progress, "No dashboard without a deck")
    }

    func test_severalDecksAndNoChoiceAskToChooseOne() {
        start(TodayPlan(kind: .chooseDeck))
        XCTAssertEqual(state.subtitle, text("Choose the deck to study."))
        XCTAssertEqual(state.hero?.title, text("Which deck today?"))
        XCTAssertEqual(state.hero?.ctaTitle, text("Choose a deck"))
        XCTAssertEqual(state.hero?.action, .chooseDeck)
        XCTAssertNil(state.hero?.figure)
        XCTAssertNil(state.rows)
    }

    func test_aDeckNeverStudiedIsPractisedAndNothingIsCalledDue() {
        var plan = TodayPlan(kind: .practice, deckID: "deck", deckName: "JLPT N5", cardCount: 24, skill: .selfRecall)
        plan.unseenCount = 24
        plan.sessionCardIDs = (1...15).map { "c\($0)" }
        plan.practiceCardIDs = plan.sessionCardIDs
        plan.estimatedMinutes = 5
        start(plan)
        XCTAssertEqual(state.subtitle, text("You haven't studied this deck yet."))
        XCTAssertEqual(state.hero?.title, "JLPT N5")
        XCTAssertEqual(state.hero?.figure, "15", "The cards this session holds, not the size of the deck")
        XCTAssertEqual(state.hero?.caption, text("cards to practise"))
        XCTAssertEqual(state.hero?.lines, [text("No answers saved yet."), String.localizedStringWithFormat(text("About %lld minutes"), 5)])
        XCTAssertEqual(state.hero?.ctaTitle, text("Practise this deck"))
        XCTAssertEqual(state.hero?.action, .study(deckID: "deck", cardIDs: (1...15).map { "c\($0)" }))
    }

    func test_aDeckStudiedTheOtherWayDoesNotClaimItWasNeverStudied() {
        var plan = TodayPlan(kind: .practice, deckID: "deck", deckName: "JLPT N5", cardCount: 24, skill: .recognition)
        plan.studiedAnotherWay = true
        plan.sessionCardIDs = ["c1", "c2"]
        plan.estimatedMinutes = 1
        start(plan)
        XCTAssertEqual(state.subtitle, text("You haven't studied this deck this way yet."))
        XCTAssertEqual(state.hero?.lines.first, text("No answers of this kind saved yet."))
        XCTAssertEqual(state.hero?.ctaTitle, text("Practise this deck"))
    }

    func test_dueCardsShowTheRealCountAnEstimateAndStartTheDueSession() {
        start(duePlan(due: 12, session: 12))
        XCTAssertEqual(state.subtitle, text("Short reviews, on what you need to remember."))
        XCTAssertEqual(state.hero?.eyebrow, text("CURRENT DECK"))
        XCTAssertEqual(state.hero?.title, "JLPT N5")
        XCTAssertEqual(state.hero?.figure, "12")
        XCTAssertEqual(state.hero?.caption, text("to review"))
        XCTAssertEqual(state.hero?.lines, [String.localizedStringWithFormat(text("About %lld minutes"), 4)])
        XCTAssertEqual(state.hero?.ctaTitle, text("Start review"))
        XCTAssertEqual(state.hero?.action, .study(deckID: "deck", cardIDs: (1...12).map { "c\($0)" }))
    }

    func test_aBacklogBiggerThanTheSessionIsShownInFullAndTheSessionIsSmall() {
        start(duePlan(due: 87, session: 15))
        XCTAssertEqual(state.hero?.figure, "15")
        XCTAssertEqual(state.hero?.caption, String.localizedStringWithFormat(text("of %lld to review"), 87))
        XCTAssertEqual(state.hero?.lines.last, String.localizedStringWithFormat(text("%lld more are waiting"), 72))
    }

    func test_comingBackAfterABreakGreetsGentlyAndStartsAShortSession() {
        start(duePlan(kind: .returning, due: 87, session: 15))
        XCTAssertEqual(state.subtitle, text("Welcome back. Let's start gently."))
        XCTAssertEqual(state.hero?.ctaTitle, text("Start a short session"))
        XCTAssertEqual(state.hero?.caption, String.localizedStringWithFormat(text("of %lld to review"), 87))
    }

    func test_nothingDueIsNotDoneAndOffersMorePractice() {
        start(TodayPlan(kind: .nothingDue, deckID: "deck", deckName: "JLPT N5", cardCount: 24, skill: .selfRecall))
        XCTAssertEqual(state.subtitle, text("Nothing to review today."))
        XCTAssertEqual(state.hero?.title, "JLPT N5")
        XCTAssertEqual(state.hero?.lines, [text("Nothing due"), text("You can practise more whenever you like.")])
        XCTAssertNil(state.hero?.figure)
        XCTAssertEqual(state.hero?.ctaTitle, text("Practise more"))
        XCTAssertEqual(state.hero?.action, .study(deckID: "deck", cardIDs: nil), "Nothing unseen: the whole deck, like the Cards tab")
        XCTAssertEqual(state.progress?.title, text("Nothing saved yet today."))
        XCTAssertNil(state.progress?.detail)
    }

    func test_morePracticeContinuesWithTheCardsNeverStudiedWhenThereAreSome() {
        var plan = TodayPlan(kind: .doneToday, deckID: "deck", deckName: "JLPT N5", cardCount: 24, skill: .selfRecall)
        plan.unseenCount = 12
        plan.practiceCardIDs = (13...24).map { "c\($0)" }
        plan.progress = TodayProgress(saved: 3, quizCorrect: 0, quizIncorrect: 0, selfRated: 3)
        start(plan)
        XCTAssertEqual(state.hero?.action, .study(deckID: "deck", cardIDs: (13...24).map { "c\($0)" }))
        plan.kind = .nothingDue
        start(plan)
        XCTAssertEqual(state.hero?.action, .study(deckID: "deck", cardIDs: (13...24).map { "c\($0)" }))
    }

    func test_doneTodayConfirmsWhatWasSavedAndKeepsPractiseAsAChoice() {
        var plan = TodayPlan(kind: .doneToday, deckID: "deck", deckName: "JLPT N5", cardCount: 24, skill: .selfRecall)
        plan.progress = TodayProgress(saved: 12, quizCorrect: 7, quizIncorrect: 2, selfRated: 3)
        start(plan)
        XCTAssertEqual(state.subtitle, text("Today's review is done."))
        XCTAssertEqual(state.hero?.lines.first, String.localizedStringWithFormat(text("Saved %lld today"), 12))
        XCTAssertEqual(state.hero?.ctaTitle, text("Practise more"))
        XCTAssertEqual(state.hero?.action, .study(deckID: "deck", cardIDs: nil))
    }

    // MARK: Rows and progress

    func test_aDeckShowsItsNameAndTheSessionLengthAndTodaysSavedAnswersKeptApart() {
        var plan = duePlan()
        plan.budgetMinutes = 10
        plan.progress = TodayProgress(saved: 6, quizCorrect: 4, quizIncorrect: 1, selfRated: 1)
        start(plan)
        XCTAssertEqual(state.rows, TodayRows(deckName: "JLPT N5", sessionLength: String.localizedStringWithFormat(text("%lld minutes"), 10)))
        XCTAssertEqual(state.progress?.title, String.localizedStringWithFormat(text("Saved %lld attempts"), 6))
        let quiz = text("Quiz") + " " + String(format: text("%1$lld correct · %2$lld incorrect"), 4, 1)
        let rated = text("Self-rating") + " " + String.localizedStringWithFormat(text("%lld attempts"), 1)
        XCTAssertEqual(state.progress?.detail, quiz + " · " + rated)
    }

    func test_theProgressDetailOmitsWhatDidNotHappen() {
        var plan = duePlan()
        plan.progress = TodayProgress(saved: 2, quizCorrect: 2, quizIncorrect: 0, selfRated: 0)
        start(plan)
        XCTAssertEqual(state.progress?.detail, text("Quiz") + " " + String(format: text("%1$lld correct · %2$lld incorrect"), 2, 0))
    }

    // MARK: Failure

    func test_whenProgressCannotBeReadTheScreenSaysSoInsteadOfShowingZeros() {
        struct Unreadable: Error {}
        interactor.result = .failure(Unreadable())
        presenter = TodayPresenter(interactor: interactor, wireframe: wireframe, ownerKey: { [unowned self] in owner })
        presenter.view = view
        presenter.viewWillAppear()
        XCTAssertEqual(state.phase, .failed)
        XCTAssertEqual(state.failureTitle, text("Couldn't read your progress"))
        XCTAssertEqual(state.failureMessage, text("The study data on this device couldn't be opened. Your data is not deleted."))
        XCTAssertNil(state.hero)
        XCTAssertNil(state.progress)

        interactor.result = .success(duePlan())
        presenter.retry()
        XCTAssertEqual(state.phase, .loaded)
        XCTAssertEqual(state.hero?.figure, "12")
    }

    // MARK: Actions

    func test_theLearnerIsTheOneWhoIsSignedInNow() {
        start(TodayPlan(kind: .noDeck))
        owner = "22222222-2222-2222-2222-222222222222"
        presenter.viewWillAppear()
        XCTAssertEqual(interactor.requestedOwners, ["11111111-1111-1111-1111-111111111111", "22222222-2222-2222-2222-222222222222"])
    }

    func test_thePrimaryButtonStartsTheStudySessionTheStateOffers() {
        start(duePlan(due: 3, session: 3))
        presenter.primaryAction()
        XCTAssertEqual(wireframe.studies.count, 1)
        XCTAssertEqual(wireframe.studies[0].deckId, "deck")
        XCTAssertEqual(wireframe.studies[0].cardIDs, ["c1", "c2", "c3"])
    }

    func test_thePrimaryButtonWithoutADeckOpensTheDeckFlowAndRefreshesWhenItEnds() {
        start(TodayPlan(kind: .noDeck))
        presenter.primaryAction()
        XCTAssertEqual(wireframe.createFlows.count, 1)
        interactor.result = .success(duePlan())
        wireframe.createFlows[0]()
        XCTAssertEqual(state.hero?.figure, "12", "Back on Today with the new deck")
    }

    func test_choosingADeckStoresTheChoiceAndRefreshes() {
        start(TodayPlan(kind: .chooseDeck))
        interactor.choices = [TodayDeckChoice(id: "a", name: "Alpha", cardCount: 2), TodayDeckChoice(id: "b", name: "Beta", cardCount: 5)]
        presenter.primaryAction()
        XCTAssertEqual(wireframe.deckChoosers.count, 1)
        XCTAssertEqual(wireframe.deckChoosers[0].choices.map(\.id), ["a", "b"])
        interactor.result = .success(duePlan())
        wireframe.deckChoosers[0].select("b")
        XCTAssertEqual(interactor.selected.map(\.id), ["b"])
        XCTAssertEqual(interactor.selected.map(\.owner), [owner])
        XCTAssertEqual(state.hero?.title, "JLPT N5")
    }

    func test_theDeckRowOffersTheSameChoiceAndMarksTheCurrentDeck() {
        start(duePlan())
        interactor.choices = [TodayDeckChoice(id: "deck", name: "JLPT N5", cardCount: 24)]
        presenter.changeDeck()
        XCTAssertEqual(wireframe.deckChoosers.first?.selectedID, "deck")
    }

    func test_theTimeRowOffersTheTimesAndTheChoiceIsKeptAndShown() {
        start(duePlan())
        interactor.budget = 5
        presenter.changeBudget()
        XCTAssertEqual(wireframe.budgetChoosers.first?.current, 5)
        var plan = duePlan()
        plan.budgetMinutes = 3
        interactor.result = .success(plan)
        wireframe.budgetChoosers[0].select(3)
        XCTAssertEqual(interactor.budgetsSet.map(\.minutes), [3])
        XCTAssertEqual(state.rows?.sessionLength, String.localizedStringWithFormat(text("%lld minutes"), 3))
    }

    func test_refreshingReadsTheRealPlanAgainSoAnOpenScreenDoesNotGoStale() {
        start(TodayPlan(kind: .noDeck))
        interactor.result = .success(duePlan(due: 5, session: 5))
        presenter.refresh()
        XCTAssertEqual(state.hero?.figure, "5")
        XCTAssertEqual(interactor.requestedOwners.count, 2)
    }

    func test_theLevelsRowOpensTheLevels() {
        start(TodayPlan(kind: .noDeck))
        presenter.openLevels()
        XCTAssertEqual(wireframe.levelsOpened, 1)
    }

    func test_theSituationsOpenWhateverThePlanIs() {
        start(TodayPlan(kind: .noDeck))
        presenter.openScenarios()
        XCTAssertEqual(wireframe.scenariosOpened, 1)

        interactor.result = .failure(NSError(domain: "test", code: 1))
        presenter.refresh()
        XCTAssertEqual(state.phase, .failed)
        presenter.openScenarios()
        XCTAssertEqual(wireframe.scenariosOpened, 2, "the situations do not depend on reading the study plan")
    }
}

private final class FakeTodayInteractor: TodayInteractorInterface {
    var result: Result<TodayPlan, Error> = .success(TodayPlan(kind: .noDeck))
    var choices: [TodayDeckChoice] = []
    var budget = 5
    var requestedOwners: [String] = []
    var selected: [(id: String, owner: String)] = []
    var budgetsSet: [(minutes: Int, owner: String)] = []

    func plan(ownerKey: String, now: Date) throws -> TodayPlan {
        requestedOwners.append(ownerKey)
        return try result.get()
    }
    func deckChoices() -> [TodayDeckChoice] { choices }
    func selectDeck(id: String, ownerKey: String) { selected.append((id, ownerKey)) }
    func budgetMinutes(ownerKey: String) -> Int { budget }
    func setBudgetMinutes(_ minutes: Int, ownerKey: String) { budgetsSet.append((minutes, ownerKey)) }
}

private final class FakeTodayWireframe: TodayWireframeInterface {
    var studies: [(deckId: String, cardIDs: [String]?)] = []
    var createFlows: [() -> Void] = []
    var deckChoosers: [(choices: [TodayDeckChoice], selectedID: String?, select: (String) -> Void)] = []
    var budgetChoosers: [(current: Int, select: (Int) -> Void)] = []
    var levelsOpened = 0
    var scenariosOpened = 0
    var lifeLessons: [(cityID: String, lesson: LifeLesson)] = []
    var cityChoosers: [(selectedID: String, select: (String) -> Void)] = []
    var settingsOpened = 0

    func showLifeLesson(cityID: String, lesson: LifeLesson) { lifeLessons.append((cityID, lesson)) }
    func showCityChooser(selectedID: String, onSelect: @escaping (String) -> Void) { cityChoosers.append((selectedID, onSelect)) }
    func openAppSettings() { settingsOpened += 1 }
    func showScenarios() { scenariosOpened += 1 }
    func showStudy(deckId: String, cardIDs: [String]?) { studies.append((deckId, cardIDs)) }
    func showCreateDeck(onFinish: @escaping () -> Void) { createFlows.append(onFinish) }
    func showDeckChooser(_ choices: [TodayDeckChoice], selectedID: String?, onSelect: @escaping (String) -> Void) {
        deckChoosers.append((choices, selectedID, onSelect))
    }
    func showBudgetChooser(current: Int, onSelect: @escaping (Int) -> Void) { budgetChoosers.append((current, onSelect)) }
    func showLevels() { levelsOpened += 1 }
}

private final class SpyTodayView: TodayViewInterface {
    var renders: [TodayViewState] = []
    func render(_ state: TodayViewState) { renders.append(state) }
}


/// The life hub next to the review block: independent of it in both directions.
private final class FakeHub: TodayLifeHubLoading {
    var section: TodayHubSection?
    var lessons: [String: LifeLesson] = [:]
    var cityID = "tokyo"
    var onChange: (() -> Void)?
    var refreshes = 0, retries = 0, locationRequests = 0
    var selected: [String] = []

    func lesson(forCard id: String) -> LifeLesson? { lessons[id] }
    func refresh() { refreshes += 1 }
    func retry() { retries += 1 }
    func selectCity(_ id: String) { selected.append(id) }
    func requestLocation() { locationRequests += 1 }
    func update(_ section: TodayHubSection?) { self.section = section; onChange?() }
}

extension TodayPresenterTests {
    private func startWithHub(_ plan: TodayPlan, hub: FakeHub) -> (TodayPresenter, FakeTodayWireframe, SpyTodayView) {
        let interactor = FakeTodayInteractor()
        interactor.result = .success(plan)
        let wireframe = FakeTodayWireframe()
        let view = SpyTodayView()
        let presenter = TodayPresenter(interactor: interactor, wireframe: wireframe, ownerKey: { "owner" }, now: { Date(timeIntervalSince1970: 1_800_000_000) }, life: hub)
        presenter.view = view
        presenter.viewWillAppear()
        return (presenter, wireframe, view)
    }

    private func hubSection(cards: [LifeFeedCard]) -> TodayHubSection {
        TodayHubSection(header: TodayLifeHubLoader.header(now: LifeLessonFixtures.morning, calendar: LifeLessonFixtures.japanCalendar), cityName: "Tokyo", cards: cards)
    }

    private func readyCard() throws -> LifeFeedCard { LifeFeedMapper.card(for: try LifeLessonFixtures.lesson(), language: .vietnamese) }

    private func placeholder(_ status: LifeFeedCard.Status, id: String) -> LifeFeedCard {
        LifeFeedCard(id: id, topic: .nearby, status: status, provenance: .onDevice, eyebrow: "NEAR YOU", headlineJapanese: "近くの場所", reading: "ちかくのばしょ",
                     summary: "x", chips: [], meta: "", scene: .place, ctaTitle: "go", lesson: nil)
    }

    func test_theHubIsAskedForWhenTodayAppearsAndShownBesideTheReviewBlock() throws {
        let hub = FakeHub()
        hub.section = hubSection(cards: [try readyCard()])
        let (_, _, view) = startWithHub(duePlan(), hub: hub)
        XCTAssertEqual(hub.refreshes, 1)
        XCTAssertEqual(view.renders.last?.life, hub.section)
        XCTAssertEqual(view.renders.last?.hero?.ctaTitle, text("Start review"), "The review block is the same with or without the hub")
    }

    func test_whenAHubCardFailsTheReviewBlockIsUntouched() throws {
        let hub = FakeHub()
        let (presenter, _, view) = startWithHub(duePlan(due: 12), hub: hub)
        let reviewOnly = view.renders.last
        hub.update(hubSection(cards: [placeholder(.failed(message: "offline"), id: "weather:failed")]))
        let after = try XCTUnwrap(view.renders.last)
        XCTAssertEqual(after.hero, reviewOnly?.hero)
        XCTAssertEqual(after.rows, reviewOnly?.rows)
        XCTAssertEqual(after.progress, reviewOnly?.progress)
        XCTAssertEqual(after.hero?.figure, "12", "The number of cards to review is not replaced by anything")
        XCTAssertNotNil(after.life)
        withExtendedLifetime(presenter) {}
    }

    func test_whenTheSavedProgressCannotBeReadTheHubIsStillThere() throws {
        let hub = FakeHub()
        hub.section = hubSection(cards: [try readyCard()])
        let interactor = FakeTodayInteractor()
        interactor.result = .failure(NSError(domain: "t", code: 1))
        let view = SpyTodayView()
        let presenter = TodayPresenter(interactor: interactor, wireframe: FakeTodayWireframe(), ownerKey: { "owner" }, life: hub)
        presenter.view = view
        presenter.viewWillAppear()
        XCTAssertEqual(view.renders.last?.phase, .failed)
        XCTAssertNotNil(view.renders.last?.life)
    }

    func test_withoutAHubTodayShowsNoCards() {
        start(duePlan())
        XCTAssertNil(state.life)
    }

    func test_aReadyCardOpensItsLesson() throws {
        let hub = FakeHub()
        let card = try readyCard()
        hub.section = hubSection(cards: [card])
        hub.lessons[card.id] = card.lesson
        let (presenter, wireframe, _) = startWithHub(duePlan(), hub: hub)
        presenter.openLifeCard(id: card.id)
        XCTAssertEqual(wireframe.lifeLessons.count, 1)
        XCTAssertEqual(wireframe.lifeLessons.first?.cityID, "tokyo")
        XCTAssertEqual(wireframe.lifeLessons.first?.lesson.id, "weather:tokyo:2026-10-24")
    }

    func test_whatATapDoesFollowsTheStateOfTheCard() {
        let hub = FakeHub()
        hub.section = hubSection(cards: [placeholder(.needsLocation, id: "ask"), placeholder(.locationDenied, id: "denied"),
                                         placeholder(.failed(message: "x"), id: "failed"), placeholder(.loading, id: "loading"), placeholder(.locating, id: "locating")])
        let (presenter, wireframe, _) = startWithHub(duePlan(), hub: hub)
        presenter.openLifeCard(id: "loading")
        presenter.openLifeCard(id: "locating")
        XCTAssertEqual(hub.locationRequests + hub.retries + wireframe.settingsOpened + wireframe.lifeLessons.count, 0, "Busy cards do nothing")
        presenter.openLifeCard(id: "ask")
        XCTAssertEqual(hub.locationRequests, 1, "The position is read only from the learner's tap on the card")
        presenter.openLifeCard(id: "denied")
        XCTAssertEqual(wireframe.settingsOpened, 1)
        presenter.openLifeCard(id: "failed")
        XCTAssertEqual(hub.retries, 1)
        presenter.openLifeCard(id: "unknown")
        XCTAssertTrue(wireframe.lifeLessons.isEmpty)
    }

    func test_aReadyCardWithoutItsLessonOpensNothing() throws {
        let hub = FakeHub()
        let card = try readyCard()
        hub.section = hubSection(cards: [card])
        let (presenter, wireframe, _) = startWithHub(duePlan(), hub: hub)
        presenter.openLifeCard(id: card.id)
        XCTAssertTrue(wireframe.lifeLessons.isEmpty)
    }

    func test_theCityChoiceStartsFromTheCurrentCityAndAppliesTheChosenOne() {
        let hub = FakeHub()
        hub.cityID = "osaka"
        let (presenter, wireframe, _) = startWithHub(duePlan(), hub: hub)
        presenter.changeLifeCity()
        XCTAssertEqual(wireframe.cityChoosers.first?.selectedID, "osaka")
        wireframe.cityChoosers.first?.select("naha")
        XCTAssertEqual(hub.selected, ["naha"])
    }

    func test_retryAsksTheHubAgainWithoutReloadingTheReviewPlan() {
        let hub = FakeHub()
        let (presenter, _, _) = startWithHub(duePlan(), hub: hub)
        presenter.retryLife()
        XCTAssertEqual(hub.retries, 1)
    }
}
