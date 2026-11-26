import RealmSwift
import UIKit
import XCTest
@testable import FlashcardApp

final class TodayQuestTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite = ""
    private var store: UserDefaultsTodayQuestCompletionStore!
    private var calendar: Calendar!
    private let day = Date(timeIntervalSince1970: 1_794_373_200) // 2026-11-11 12:00 Hanoi

    override func setUp() {
        super.setUp()
        suite = "today-quest-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        store = UserDefaultsTodayQuestCompletionStore(defaults: defaults)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func sampleRadar(slug: String = "kentou", minutes: Int? = 4) -> DailyRadarItem {
        DailyRadarItem(id: "r1", slug: slug, moduleTitle: "Honne & tatemae", title: "「検討します」",
                       summary: "Nghĩa thật", expressions: [.init(japanese: "検討します", reading: "けんとうします")],
                       usageNote: nil, reason: nil, minutes: minutes, level: "N2+")
    }

    private func duePlan(due: Int = 10, minutes: Int = 4) -> TodayPlan {
        var plan = TodayPlan(kind: .due, deckID: "d1", deckName: "N5", cardCount: 20, skill: .selfRecall)
        plan.dueCount = due
        plan.sessionCardIDs = (1...due).map { "c\($0)" }
        plan.estimatedMinutes = minutes
        return plan
    }

    // MARK: Assembly

    func test_returnsNilWhenNoRealSignalsExist() {
        let state = TodayQuestAssembler.make(
            plan: TodayPlan(kind: .noDeck),
            lessonSlot: nil,
            lessonCompletedToday: false,
            radar: nil,
            radarCompletedToday: false
        )
        XCTAssertNil(state)
    }

    func test_assemblesAllThreeRealSignalsWithRealCountsAndMinutes() {
        let state = TodayQuestAssembler.make(
            plan: duePlan(due: 12, minutes: 4),
            lessonSlot: .continueLesson(slug: "j5-01", title: "Chào hỏi", levelCode: "J5", answered: 2, total: 5),
            lessonCompletedToday: false,
            radar: sampleRadar(minutes: 4),
            radarCompletedToday: false
        )

        XCTAssertEqual(state?.items.count, 3)
        XCTAssertEqual(state?.completedCount, 0)
        XCTAssertEqual(state?.totalCount, 3)
        XCTAssertEqual(state?.isAllDone, false)
        XCTAssertEqual(state?.progressFraction ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(state?.items.map(\.action), [.review, .lesson, .radar])
        XCTAssertEqual(state?.items[0].estimatedMinutes, 4)
        XCTAssertTrue(state?.items[0].detail?.contains("12") == true)
        XCTAssertEqual(state?.items[1].title, "Chào hỏi")
        XCTAssertEqual(state?.items[2].estimatedMinutes, 4)
        XCTAssertEqual(state?.items[2].title, "「検討します」")
    }

    func test_nothingDueAndNoDeckOmitReviewItemInsteadOfInventingDueCount() {
        let nothingDue = TodayQuestAssembler.make(
            plan: TodayPlan(kind: .nothingDue, deckID: "d1", deckName: "N5", cardCount: 10, skill: .selfRecall),
            lessonSlot: .start,
            lessonCompletedToday: false,
            radar: sampleRadar(),
            radarCompletedToday: false
        )
        XCTAssertEqual(nothingDue?.items.map(\.action), [.lesson, .radar])
        XCTAssertEqual(nothingDue?.totalCount, 2)
    }

    func test_progressTracksRealCompletionForReviewLessonAndRadar() {
        var donePlan = TodayPlan(kind: .doneToday, deckID: "d1", deckName: "N5", cardCount: 10, skill: .selfRecall)
        donePlan.progress = TodayProgress(saved: 8, quizCorrect: 6, quizIncorrect: 2, selfRated: 0)

        let partial = TodayQuestAssembler.make(
            plan: donePlan,
            lessonSlot: .next(slug: "j5-02", title: "Bài 2", levelCode: "J5"),
            lessonCompletedToday: true,
            radar: sampleRadar(),
            radarCompletedToday: false
        )
        XCTAssertEqual(partial?.completedCount, 2)
        XCTAssertEqual(partial?.totalCount, 3)
        XCTAssertEqual(partial?.isAllDone, false)
        XCTAssertEqual(partial?.progressFraction ?? 0, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(partial?.items.map(\.isDone), [true, true, false])

        let allDone = TodayQuestAssembler.make(
            plan: donePlan,
            lessonSlot: .next(slug: "j5-02", title: "Bài 2", levelCode: "J5"),
            lessonCompletedToday: true,
            radar: sampleRadar(),
            radarCompletedToday: true
        )
        XCTAssertEqual(allDone?.completedCount, 3)
        XCTAssertEqual(allDone?.totalCount, 3)
        XCTAssertEqual(allDone?.isAllDone, true)
        XCTAssertEqual(allDone?.progressFraction ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(allDone?.summary, NSLocalizedString("Done for today", comment: ""))
    }

    // MARK: Date-stamped UserDefaults radar completion

    func test_radarCompletionPersistsPerOwnerAndResetsOnNewCalendarDay() {
        XCTAssertFalse(store.isRadarCompleted(slug: "kentou", ownerKey: "u1", on: day, calendar: calendar))
        store.markRadarCompleted(slug: "kentou", ownerKey: "u1", on: day, calendar: calendar)

        XCTAssertTrue(store.isRadarCompleted(slug: "kentou", ownerKey: "u1", on: day, calendar: calendar))
        XCTAssertFalse(store.isRadarCompleted(slug: "other", ownerKey: "u1", on: day, calendar: calendar))
        XCTAssertFalse(store.isRadarCompleted(slug: "kentou", ownerKey: "u2", on: day, calendar: calendar))

        let tomorrow = day.addingTimeInterval(24 * 3600)
        XCTAssertFalse(store.isRadarCompleted(slug: "kentou", ownerKey: "u1", on: tomorrow, calendar: calendar))
    }

    // MARK: Lesson completed today from real Realm progress

    func test_lessonCompletedTodayChecksRealLocalCalendarDay() throws {
        let previousRealm = RealmService.shared.realm
        RealmService.shared.realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString, objectTypes: RealmService.storedTypes))
        defer { RealmService.shared.realm = previousRealm }
        let progressStore = RealmLessonProgressStore()
        let provider = TodayLessonSlotProvider(store: progressStore, cache: SlugCacheStub())
        let subject = LessonProgressSubject(slug: "l1", lessonId: "id-1", levelCode: "J5", sortOrder: 1, contentVersion: "v1", activityIds: ["a1"])

        XCTAssertFalse(provider.completedToday(ownerKey: "u1", now: day, calendar: calendar))

        let yesterday = calendar.startOfDay(for: day).addingTimeInterval(-60)
        _ = try progressStore.recordAnswer(LessonAnswer(activityId: "a1", optionKey: "A"), for: subject, ownerKey: "u1", at: yesterday)
        _ = try progressStore.markCompleted(for: subject, ownerKey: "u1", at: yesterday)
        XCTAssertFalse(provider.completedToday(ownerKey: "u1", now: day, calendar: calendar), "Yesterday's lesson does not count as today")

        let todaySubject = LessonProgressSubject(slug: "l2", lessonId: "id-2", levelCode: "J5", sortOrder: 2, contentVersion: "v1", activityIds: ["a2"])
        _ = try progressStore.recordAnswer(LessonAnswer(activityId: "a2", optionKey: "A"), for: todaySubject, ownerKey: "u1", at: day)
        _ = try progressStore.markCompleted(for: todaySubject, ownerKey: "u1", at: day)
        XCTAssertTrue(provider.completedToday(ownerKey: "u1", now: day, calendar: calendar))
        XCTAssertFalse(provider.completedToday(ownerKey: "u2", now: day, calendar: calendar))
    }

    // MARK: Presenter integration

    func test_openingRadarMarksRadarQuestDoneAndRoutesQuestActions() {
        let interactor = QuestFakeInteractor(plan: duePlan(due: 5, minutes: 2))
        let wireframe = QuestFakeWireframe()
        let lessons = QuestFakeLessons(slot: .start, doneToday: false)
        let radar = QuestFakeRadar(item: sampleRadar(slug: "kentou", minutes: 3))
        let view = QuestSpyView()

        let presenter = TodayPresenter(
            interactor: interactor,
            wireframe: wireframe,
            ownerKey: { "u1" },
            now: { [unowned self] in day },
            lessons: lessons,
            radar: radar,
            questStore: store,
            calendar: { [unowned self] in calendar }
        )
        presenter.view = view
        presenter.viewWillAppear()

        XCTAssertEqual(view.last?.quest?.completedCount, 0)
        XCTAssertEqual(view.last?.quest?.totalCount, 3)

        presenter.openQuestItem(.review)
        XCTAssertEqual(wireframe.studies, 1)

        presenter.openQuestItem(.lesson)
        XCTAssertEqual(wireframe.levelsOpened, 1)

        presenter.openQuestItem(.radar)
        XCTAssertEqual(wireframe.radarsOpened, 1)
        XCTAssertTrue(store.isRadarCompleted(slug: "kentou", ownerKey: "u1", on: day, calendar: calendar))
        XCTAssertEqual(view.last?.quest?.completedCount, 1)
        XCTAssertEqual(view.last?.quest?.items.last?.isDone, true)
    }

    func test_reviewQuestItemWithBacklogShowsSessionCountMatchingEstimatedMinutesAndWaitingBacklog() throws {
        var backlogPlan = TodayPlan(kind: .due, deckID: "d1", deckName: "N5", cardCount: 100, skill: .selfRecall)
        backlogPlan.dueCount = 87
        backlogPlan.sessionCardIDs = (1...15).map { "c\($0)" }
        backlogPlan.estimatedMinutes = 5 // 15 cards * 20s = 5 min

        let state = TodayQuestAssembler.make(
            plan: backlogPlan,
            lessonSlot: nil,
            lessonCompletedToday: false,
            radar: nil,
            radarCompletedToday: false
        )
        let item = try XCTUnwrap(state?.items.first)
        let sessionCards = String.localizedStringWithFormat(NSLocalizedString("%lld cards", comment: ""), 15)
        let estimate = String.localizedStringWithFormat(NSLocalizedString("About %lld minutes", comment: ""), 5)
        let waiting = String.localizedStringWithFormat(NSLocalizedString("%lld more are waiting", comment: ""), 72)
        XCTAssertEqual(item.detail, [sessionCards, estimate, waiting].joined(separator: " · "))
    }

    func test_questCompletionResetsAcrossMidnightIntoNewCalendarDayInPresenter() throws {
        let previousRealm = RealmService.shared.realm
        RealmService.shared.realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: UUID().uuidString, objectTypes: RealmService.storedTypes))
        defer { RealmService.shared.realm = previousRealm }

        let progressStore = RealmLessonProgressStore()
        let lessonProvider = TodayLessonSlotProvider(store: progressStore, cache: SlugCacheStub())
        let subject = LessonProgressSubject(slug: "l1", lessonId: "id-1", levelCode: "J5", sortOrder: 1, contentVersion: "v1", activityIds: ["a1"])
        _ = try progressStore.recordAnswer(LessonAnswer(activityId: "a1", optionKey: "A"), for: subject, ownerKey: "u1", at: day)
        _ = try progressStore.markCompleted(for: subject, ownerKey: "u1", at: day)

        var donePlan = TodayPlan(kind: .doneToday, deckID: "d1", deckName: "N5", cardCount: 10, skill: .selfRecall)
        donePlan.progress = TodayProgress(saved: 5, quizCorrect: 5, quizIncorrect: 0, selfRated: 0)
        let interactor = MutableQuestInteractor(plan: donePlan)
        let radar = QuestFakeRadar(item: sampleRadar(slug: "kentou", minutes: 3))
        let view = QuestSpyView()
        var currentNow = day

        let presenter = TodayPresenter(
            interactor: interactor,
            wireframe: QuestFakeWireframe(),
            ownerKey: { "u1" },
            now: { currentNow },
            lessons: lessonProvider,
            radar: radar,
            questStore: store,
            calendar: { [unowned self] in calendar }
        )
        presenter.view = view
        presenter.viewWillAppear()
        presenter.openRadar()

        XCTAssertEqual(view.last?.quest?.completedCount, 3)
        XCTAssertEqual(view.last?.quest?.isAllDone, true)

        // Advance past midnight into the next local calendar day
        currentNow = calendar.startOfDay(for: day).addingTimeInterval(24 * 3600 + 60)
        interactor.result = duePlan(due: 4, minutes: 2)
        presenter.refresh()

        XCTAssertEqual(view.last?.quest?.completedCount, 0, "All date-stamped quest completions must reset on the new day")
        XCTAssertEqual(view.last?.quest?.items.map(\.isDone), [false, false, false])
    }

    func test_questRowTitlesNeverClipVerticallyAtAccessibilityXXL() throws {
        let state = try XCTUnwrap(TodayQuestAssembler.make(
            plan: TodayPlan(kind: .noDeck),
            lessonSlot: .start,
            lessonCompletedToday: false,
            radar: sampleRadar(slug: "kentou", minutes: 4),
            radarCompletedToday: false
        ))
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
            .map(UIWindow.init(windowScene:))
        let host = UIViewController()
        host.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraLarge
        window?.rootViewController = host
        window?.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window?.makeKeyAndVisible()
        defer { window?.isHidden = true; window?.rootViewController = nil }

        host.loadViewIfNeeded()
        host.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let card = TodayQuestCardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: host.view.topAnchor),
            card.leadingAnchor.constraint(equalTo: host.view.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: host.view.trailingAnchor, constant: -16)
        ])
        card.configure(state)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        func allLabels(in root: UIView) -> [UILabel] {
            var found: [UILabel] = []
            for sub in root.subviews {
                if let label = sub as? UILabel { found.append(label) }
                found.append(contentsOf: allLabels(in: sub))
            }
            return found
        }
        let lessonTitle = try XCTUnwrap(allLabels(in: card).first { $0.text == state.items[0].title })
        let needed = lessonTitle.sizeThatFits(CGSize(width: lessonTitle.bounds.width, height: .greatestFiniteMagnitude))
        XCTAssertGreaterThanOrEqual(lessonTitle.bounds.height + 1, needed.height, "Quest row title clipped vertically at AX-XXL")
    }
}

private final class MutableQuestInteractor: TodayInteractorInterface {
    var result: TodayPlan
    init(plan: TodayPlan) { self.result = plan }
    func plan(ownerKey: String, now: Date) throws -> TodayPlan { result }
    func deckChoices() -> [TodayDeckChoice] { [] }
    func selectDeck(id: String, ownerKey: String) {}
    func budgetMinutes(ownerKey: String) -> Int { 5 }
    func setBudgetMinutes(_ minutes: Int, ownerKey: String) {}
}

private final class QuestFakeInteractor: TodayInteractorInterface {
    let result: TodayPlan
    init(plan: TodayPlan) { self.result = plan }
    func plan(ownerKey: String, now: Date) throws -> TodayPlan { result }
    func deckChoices() -> [TodayDeckChoice] { [] }
    func selectDeck(id: String, ownerKey: String) {}
    func budgetMinutes(ownerKey: String) -> Int { 5 }
    func setBudgetMinutes(_ minutes: Int, ownerKey: String) {}
}

private final class QuestFakeWireframe: TodayWireframeInterface {
    var studies = 0, levelsOpened = 0, radarsOpened = 0
    func showStudy(deckId: String, cardIDs: [String]?) { studies += 1 }
    func showCreateDeck(onFinish: @escaping () -> Void) {}
    func showDeckChooser(_ choices: [TodayDeckChoice], selectedID: String?, onSelect: @escaping (String) -> Void) {}
    func showBudgetChooser(current: Int, onSelect: @escaping (Int) -> Void) {}
    func showLevels() { levelsOpened += 1 }
    func showScenarios() {}
    func showLesson(slug: String, title: String) {}
    func showRadarCard(_ item: DailyRadarItem) { radarsOpened += 1 }
    func showLifeLesson(cityID: String, lesson: LifeLesson) {}
    func showCityChooser(selectedID: String, onSelect: @escaping (String) -> Void) {}
    func openAppSettings() {}
}

private final class QuestFakeLessons: TodayLessonSlotProviding {
    let currentSlot: TodayLessonSlot
    let doneToday: Bool
    init(slot: TodayLessonSlot, doneToday: Bool) { self.currentSlot = slot; self.doneToday = doneToday }
    func slot(ownerKey: String) -> TodayLessonSlot { currentSlot }
    func completedToday(ownerKey: String, now: Date, calendar: Calendar) -> Bool { doneToday }
}

private final class QuestFakeRadar: TodayRadarLoading {
    var item: DailyRadarItem?
    var onChange: (() -> Void)?
    init(item: DailyRadarItem?) { self.item = item }
    func refresh() {}
}

private final class QuestSpyView: TodayViewInterface {
    var last: TodayViewState?
    func render(_ state: TodayViewState) { last = state }
}
