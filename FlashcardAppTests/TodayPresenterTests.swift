import RxSwift
import UIKit
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
    var lessonsOpened: [(slug: String, title: String)] = []
    func showLesson(slug: String, title: String) { lessonsOpened.append((slug, title)) }
    var radarOpened: [DailyRadarItem] = []
    func showRadarCard(_ item: DailyRadarItem) { radarOpened.append(item) }
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


/// The lesson slot: separate from the review block, from real progress only.
private final class FakeLessonSlots: TodayLessonSlotProviding {
    var slot: TodayLessonSlot = .start
    var owners: [String] = []
    func slot(ownerKey: String) -> TodayLessonSlot { owners.append(ownerKey); return slot }
}

extension TodayPresenterTests {
    private func startWithLessons(_ slots: FakeLessonSlots, plan: TodayPlan) -> (TodayPresenter, FakeTodayWireframe, SpyTodayView) {
        let interactor = FakeTodayInteractor()
        interactor.result = .success(plan)
        let wireframe = FakeTodayWireframe()
        let view = SpyTodayView()
        let presenter = TodayPresenter(interactor: interactor, wireframe: wireframe, ownerKey: { "owner" },
                                       now: { Date(timeIntervalSince1970: 1_800_000_000) }, lessons: slots)
        presenter.view = view
        presenter.viewWillAppear()
        return (presenter, wireframe, view)
    }

    func test_theLessonSlotNeverChangesTheReviewBlock() {
        let slots = FakeLessonSlots()
        let (_, _, withSlot) = startWithLessons(slots, plan: duePlan())
        interactor.result = .success(duePlan())
        start(duePlan())
        XCTAssertEqual(withSlot.renders.last?.hero, state.hero)
        XCTAssertEqual(withSlot.renders.last?.rows, state.rows)
        XCTAssertEqual(withSlot.renders.last?.progress, state.progress)
        XCTAssertNil(state.lessonCard, "Without a provider Today shows no lesson slot")
    }

    func test_aFreshLearnerIsOfferedTheLevelsAndNoNumbers() {
        let slots = FakeLessonSlots()
        slots.slot = .start
        let (presenter, wireframe, view) = startWithLessons(slots, plan: TodayPlan(kind: .noDeck))
        let card = view.renders.last?.lessonCard
        XCTAssertEqual(card?.eyebrow, text("LESSONS"))
        XCTAssertEqual(card?.action, .chooseLevel)
        XCTAssertEqual(card?.ctaTitle, text("Choose a level"))
        presenter.openLessonSlot()
        XCTAssertEqual(wireframe.levelsOpened, 1)
        XCTAssertTrue(wireframe.lessonsOpened.isEmpty)
    }

    func test_aLessonInProgressIsContinuedWithItsAnsweredCount() {
        let slots = FakeLessonSlots()
        slots.slot = .continueLesson(slug: "j5-01", title: "Chào hỏi", levelCode: "J5", answered: 3, total: 5)
        let (presenter, wireframe, view) = startWithLessons(slots, plan: duePlan())
        let card = view.renders.last?.lessonCard
        XCTAssertEqual(card?.eyebrow, text("CONTINUE LESSON"))
        XCTAssertEqual(card?.title, "Chào hỏi")
        XCTAssertEqual(card?.detail, String(format: text("%lld of %lld answered"), 3, 5))
        XCTAssertEqual(view.renders.last?.hero?.action, .study(deckID: "deck", cardIDs: (1...12).map { "c\($0)" }), "The review CTA is untouched")
        presenter.openLessonSlot()
        XCTAssertEqual(wireframe.lessonsOpened.map(\.slug), ["j5-01"])
        XCTAssertEqual(wireframe.lessonsOpened.map(\.title), ["Chào hỏi"])

        let resume = view.renders.last?.resumeCard
        XCTAssertEqual(resume?.title, "Chào hỏi")
        XCTAssertEqual(resume?.levelCode, "J5")
        XCTAssertEqual(resume?.percent, 60)
        XCTAssertEqual(resume?.progressFraction ?? 0, 0.6, accuracy: 0.001)
        presenter.openResume()
        XCTAssertEqual(wireframe.lessonsOpened.map(\.slug), ["j5-01", "j5-01"], "Tapping the pinned resume card resumes the exact in-progress lesson")
    }

    func test_resumeCardIsHiddenWhenNothingIsInProgress() {
        let slots = FakeLessonSlots()
        slots.slot = .start
        let (_, _, startView) = startWithLessons(slots, plan: duePlan())
        XCTAssertNil(startView.renders.last?.resumeCard, "No placeholder when nothing is in progress")

        slots.slot = .next(slug: "j5-02", title: "Hai", levelCode: "J5")
        let (_, _, nextView) = startWithLessons(slots, plan: duePlan())
        XCTAssertNil(nextView.renders.last?.resumeCard)

        slots.slot = .finishedOpened(completed: 2)
        let (_, _, finishedView) = startWithLessons(slots, plan: duePlan())
        XCTAssertNil(finishedView.renders.last?.resumeCard)
    }

    func test_theNextLessonIsOfferedWithItsTitleAndLevel() {
        let slots = FakeLessonSlots()
        slots.slot = .next(slug: "j5-02", title: "Hai", levelCode: "J5")
        let (presenter, wireframe, view) = startWithLessons(slots, plan: duePlan())
        XCTAssertEqual(view.renders.last?.lessonCard?.eyebrow, text("NEXT LESSON"))
        XCTAssertEqual(view.renders.last?.lessonCard?.title, "Hai")
        XCTAssertEqual(view.renders.last?.lessonCard?.detail, "J5")
        presenter.openLessonSlot()
        XCTAssertEqual(wireframe.lessonsOpened.map(\.slug), ["j5-02"])
    }

    func test_aLessonNotSavedOnTheDeviceIsContinuedWithItsLevelInTheTitle() {
        let slots = FakeLessonSlots()
        slots.slot = .continueLesson(slug: "j5-01", title: nil, levelCode: "J5", answered: 1, total: 5)
        let (_, _, view) = startWithLessons(slots, plan: duePlan())
        XCTAssertEqual(view.renders.last?.lessonCard?.title, String(format: text("%@ lesson"), "J5"))
    }

    func test_afterFinishingLessonsWithNoKnownNextOneTheLearnerChoosesAgain() {
        let slots = FakeLessonSlots()
        slots.slot = .finishedOpened(completed: 4)
        let (presenter, wireframe, view) = startWithLessons(slots, plan: duePlan())
        XCTAssertEqual(view.renders.last?.lessonCard?.detail, String(format: text("Lessons finished: %lld"), 4))
        presenter.openLessonSlot()
        XCTAssertEqual(wireframe.levelsOpened, 1)
    }

    func test_theSlotIsReadForTheCurrentAccountEachTimeTodayAppearsAndSurvivesAFailedPlan() {
        let slots = FakeLessonSlots()
        let interactor = FakeTodayInteractor()
        interactor.result = .failure(NSError(domain: "t", code: 1))
        let view = SpyTodayView()
        var owner = "a"
        let presenter = TodayPresenter(interactor: interactor, wireframe: FakeTodayWireframe(), ownerKey: { owner }, lessons: slots)
        presenter.view = view
        presenter.viewWillAppear()
        owner = "b"
        presenter.viewWillAppear()
        XCTAssertEqual(slots.owners, ["a", "b"], "Switching account reads that account's progress")
        XCTAssertEqual(view.renders.last?.phase, .failed)
        XCTAssertNotNil(view.renders.last?.lessonCard, "Lessons do not depend on the review data")
    }
}

private final class FakeStreak: TodayStreakLoading {
    var streak: AccountStreak?
    var onChange: (() -> Void)?
    private(set) var refreshes = 0
    func refresh() { refreshes += 1 }
}

/// The account streak line: only the server's number, only for an account, never in place of anything else.
final class TodayPresenterStreakTests: XCTestCase {
    private func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    func test_theServerStreakIsShownWithWhetherTodayAlreadyCounts() {
        let interactor = FakeTodayInteractor()
        interactor.result = .failure(NSError(domain: "t", code: 1))
        let loader = FakeStreak()
        let view = SpyTodayView()
        let presenter = TodayPresenter(interactor: interactor, wireframe: FakeTodayWireframe(), ownerKey: { "owner" }, streak: loader)
        presenter.view = view
        presenter.viewWillAppear()
        XCTAssertEqual(loader.refreshes, 1, "Each time Today appears")
        XCTAssertNil(view.renders.last?.streak, "Nothing until the server answered")

        loader.streak = AccountStreak(days: 3, countsToday: false)
        loader.onChange?()
        XCTAssertEqual(view.renders.last?.streak?.title, String.localizedStringWithFormat(text("%lld-day study streak"), 3))
        XCTAssertEqual(view.renders.last?.streak?.detail, text("Review an account card today to keep it going."))
        XCTAssertEqual(view.renders.last?.phase, .failed, "The streak does not depend on the review data")

        loader.streak = AccountStreak(days: 4, countsToday: true)
        loader.onChange?()
        XCTAssertEqual(view.renders.last?.streak?.detail, text("Today is counted on your account."))

        loader.streak = nil
        loader.onChange?()
        XCTAssertNil(view.renders.last?.streak)
    }
}

private final class FakeRadar: TodayRadarLoading {
    var item: DailyRadarItem?
    var onChange: (() -> Void)?
    private(set) var refreshes = 0
    func refresh() { refreshes += 1 }
}

/// The Daily Radar card: one card when the server has a usable one, opened in the app, never in place of anything else.
final class TodayPresenterRadarTests: XCTestCase {
    private let item = DailyRadarItem(id: "1", slug: "kentou", moduleTitle: "Honne & tatemae", title: "「検討します」",
                                      summary: "Nghĩa thật", expressions: [.init(japanese: "検討します", reading: "けんとうします")],
                                      usageNote: nil, reason: nil, minutes: 3, level: "BJT J3")

    func test_theCardShowsTheServersTextsAndOpensInTheApp() {
        let interactor = FakeTodayInteractor()
        interactor.result = .failure(NSError(domain: "t", code: 1))
        let radar = FakeRadar()
        let wireframe = FakeTodayWireframe()
        let view = SpyTodayView()
        let presenter = TodayPresenter(interactor: interactor, wireframe: wireframe, ownerKey: { "" }, radar: radar)
        presenter.view = view
        presenter.viewWillAppear()
        XCTAssertEqual(radar.refreshes, 1)
        XCTAssertNil(view.renders.last?.radar)
        presenter.openRadar()
        XCTAssertTrue(wireframe.radarOpened.isEmpty, "Nothing to open yet")

        radar.item = item
        radar.onChange?()
        let card = view.renders.last?.radar
        XCTAssertEqual(card?.eyebrow, "Honne & tatemae")
        XCTAssertEqual(card?.title, "「検討します」")
        XCTAssertEqual(card?.expression, "検討します")
        XCTAssertEqual(card?.detail, ["BJT J3", String.localizedStringWithFormat(NSLocalizedString("%lld minutes", comment: ""), 3)].joined(separator: " · "))
        XCTAssertEqual(view.renders.last?.phase, .failed, "The radar does not depend on the review data")
        presenter.openRadar()
        XCTAssertEqual(wireframe.radarOpened, [item])
    }

    func test_radarSpeakSaveAndStudyNowDeepLinkWork() {
        let scenarioItem = DailyRadarItem(
            id: "2", slug: "email-j2", moduleKey: "workplace_mission", moduleTitle: "Tình huống công việc",
            moduleType: "scenario_link", targetRoute: "/vi/story/arcs", title: "催促メール",
            summary: "Trả lời email", expressions: [.init(japanese: "進捗はいかがでしょうか", reading: nil)],
            usageNote: nil, reason: nil, minutes: 5, level: "BJT J2"
        )
        let interactor = FakeTodayInteractor()
        let radar = FakeRadar()
        radar.item = scenarioItem
        let speech = SpySpeechService()
        let saver = SpyWordSaver()
        let wireframe = InteractiveRadarWireframe()
        let view = SpyNoticeView()
        let presenter = TodayPresenter(
            interactor: interactor,
            wireframe: wireframe,
            ownerKey: { "u1" },
            radar: radar,
            speech: speech,
            wordSaver: saver
        )
        presenter.view = view
        presenter.viewWillAppear()

        XCTAssertEqual(view.lastState?.radar?.hasDeepLink, true)
        presenter.speakRadar()
        XCTAssertEqual(speech.spoken.map(\.0), ["進捗はいかがでしょうか"])
        XCTAssertEqual(speech.spoken.map(\.1), ["ja-JP"])

        presenter.saveRadarToDeck()
        XCTAssertEqual(wireframe.saveChoosers.count, 1)
        wireframe.saveChoosers[0].select(.newDictionaryDeck)
        XCTAssertEqual(saver.savedWords.first?.first?.japanese, "進捗はいかがでしょうか")
        XCTAssertEqual(view.notices.count, 1)

        presenter.studyRadarNow()
        XCTAssertEqual(wireframe.scenariosOpened, 1, "scenario_link deep-links to Scenarios")
    }

    func test_savingWordsFromRadarOrLifeCardReloadsTodaySoNewDeckAppearsImmediately() throws {
        let interactor = FakeTodayInteractor()
        interactor.result = .success(TodayPlan(kind: .noDeck))
        let radar = FakeRadar()
        radar.item = item
        let hub = FakeHub()
        let lifeLesson = try LifeLessonFixtures.lesson()
        let lifeCard = LifeFeedMapper.card(for: lifeLesson, language: .vietnamese)
        hub.section = TodayHubSection(
            header: TodayLifeHubLoader.header(now: LifeLessonFixtures.morning, calendar: LifeLessonFixtures.japanCalendar),
            cityName: "Tokyo",
            cards: [lifeCard]
        )
        hub.lessons[lifeCard.id] = lifeLesson
        let saver = SpyWordSaver()
        let lifeSaver = SpyLifeSaver()
        let wireframe = InteractiveRadarWireframe()
        let view = SpyNoticeView()
        let presenter = TodayPresenter(
            interactor: interactor,
            wireframe: wireframe,
            ownerKey: { "u1" },
            life: hub,
            radar: radar,
            wordSaver: saver,
            lifeSaver: lifeSaver
        )
        presenter.view = view
        presenter.viewWillAppear()
        XCTAssertEqual(view.lastState?.hero?.action, .createDeck)

        var practicePlan = TodayPlan(kind: .practice, deckID: "lesson-words", deckName: "Saved from lessons", cardCount: 1, skill: .selfRecall)
        practicePlan.sessionCardIDs = ["c1"]
        practicePlan.estimatedMinutes = 1
        interactor.result = .success(practicePlan)

        presenter.saveRadarToDeck()
        wireframe.saveChoosers[0].select(.newDictionaryDeck)
        XCTAssertEqual(view.lastState?.hero?.title, "Saved from lessons", "Creating a deck via Radar save must refresh Today's hero immediately")
        XCTAssertEqual(view.lastState?.quest?.items.first?.action, .review, "Quest must immediately reflect the newly created deck")

        var lifePlan = TodayPlan(kind: .practice, deckID: "life-learning", deckName: "Learn from Life", cardCount: 2, skill: .selfRecall)
        lifePlan.sessionCardIDs = ["l1", "l2"]
        lifePlan.estimatedMinutes = 1
        interactor.result = .success(lifePlan)

        presenter.saveLifeCardToDeck(id: lifeCard.id)
        wireframe.saveChoosers[1].select(.newDictionaryDeck)
        XCTAssertEqual(view.lastState?.hero?.title, "Learn from Life", "Creating a deck via Life save must refresh Today's hero immediately")
    }

    func test_radarCardAndDetailScreenExposeCleanAccessibilityAndAdaptiveActionLayout() {
        let cardView = TodayRadarCardView(frame: CGRect(x: 0, y: 0, width: 320, height: 320))
        let radarModel = TodayRadarCard(
            eyebrow: "Tình huống công việc",
            title: "催促メールが来た",
            expression: "進捗はいかがでしょうか",
            detail: "BJT J2 · 5 phút",
            scene: .transit,
            topic: .transit,
            canSave: true,
            hasDeepLink: true
        )
        cardView.configure(radarModel)
        cardView.layoutIfNeeded()
        XCTAssertEqual(cardView.accessibilityElements?.count, 4, "Headline + Listen + Save + Study without duplicate child labels")

        let detail = DailyRadarCardViewController(item: item)
        detail.traitOverrides.preferredContentSizeCategory = .extraExtraExtraLarge
        detail.loadViewIfNeeded()
        detail.view.frame = CGRect(x: 0, y: 0, width: 375, height: 812)
        detail.view.setNeedsLayout()
        detail.view.layoutIfNeeded()
        func allStacks(in root: UIView) -> [UIStackView] {
            var stacks: [UIStackView] = []
            for sub in root.subviews {
                if let stack = sub as? UIStackView { stacks.append(stack) }
                stacks.append(contentsOf: allStacks(in: sub))
            }
            return stacks
        }
        let buttonStacks = allStacks(in: detail.view).filter { stack in
            stack.arrangedSubviews.count == 2 && stack.arrangedSubviews.allSatisfy { $0 is UIButton }
        }
        XCTAssertEqual(buttonStacks.first?.axis, .vertical, "Listen + Save row must stack vertically at xxxLarge to avoid wrapping")
    }
}

private final class SpyLifeSaver: LifeLessonInteractorInterface {
    func loadWeather(cityID: String) -> Single<LifeLesson> { .never() }
    func selectedCityID(ownerKey: String) -> String { "tokyo" }
    func setSelectedCityID(_ id: String, ownerKey: String) {}
    func deckChoices() -> [TodayDeckChoice] { [] }
    func lifeDeckExists() -> Bool { false }
    func saveVocabulary(_ words: [LifeLesson.Vocabulary], target: LifeSaveTarget, language: AppLanguage) throws -> LifeSaveOutcome {
        LifeSaveOutcome(deckID: "life-learning", deckName: "Learn from Life", added: words.map(\.id), alreadyPresent: [], cardIDs: words.map(\.id))
    }
}

private final class SpySpeechService: SpeechServiceInterface {
    var spoken: [(String, String)] = []
    func speak(_ text: String, languageCode: String) { spoken.append((text, languageCode)) }
    func stop() {}
}

private final class SpyWordSaver: LessonWordSaverInterface {
    var savedWords: [[LessonWord]] = []
    func choices() -> [TodayDeckChoice] { [] }
    func save(_ words: [LessonWord], fromLesson slug: String, to target: DictionaryDeckTarget) throws -> LessonWordSaveOutcome {
        savedWords.append(words)
        return LessonWordSaveOutcome(deckID: "lesson-words", deckName: "Saved from lessons", added: words.count, alreadyThere: 0, skipped: 0)
    }
}

private final class InteractiveRadarWireframe: TodayWireframeInterface {
    var scenariosOpened = 0
    var saveChoosers: [(choices: [TodayDeckChoice], newDeckTitle: String?, select: (DictionaryDeckTarget) -> Void)] = []
    func showStudy(deckId: String, cardIDs: [String]?) {}
    func showCreateDeck(onFinish: @escaping () -> Void) {}
    func showDeckChooser(_ choices: [TodayDeckChoice], selectedID: String?, onSelect: @escaping (String) -> Void) {}
    func showBudgetChooser(current: Int, onSelect: @escaping (Int) -> Void) {}
    func showLevels() {}
    func showScenarios() { scenariosOpened += 1 }
    func showLesson(slug: String, title: String) {}
    func showRadarCard(_ item: DailyRadarItem) {}
    func showSaveDeckChooser(_ choices: [TodayDeckChoice], newDeckTitle: String?, onSelect: @escaping (DictionaryDeckTarget) -> Void) {
        saveChoosers.append((choices, newDeckTitle, onSelect))
    }
    func showLifeLesson(cityID: String, lesson: LifeLesson) {}
    func showCityChooser(selectedID: String, onSelect: @escaping (String) -> Void) {}
    func openAppSettings() {}
}

private final class SpyNoticeView: TodayViewInterface {
    var lastState: TodayViewState?
    var notices: [String] = []
    func render(_ state: TodayViewState) { lastState = state }
    func showNotice(_ text: String) { notices.append(text) }
}
