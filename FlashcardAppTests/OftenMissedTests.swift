import RealmSwift
import XCTest
@testable import FlashcardApp

/// K-08: the cards a learner keeps getting wrong, from the local review history only.
final class OftenMissedQueueTests: XCTestCase {
    private func card(_ id: String, front: String = "犬", back: String = "chó", reading: String = "いぬ") -> StudyCard {
        StudyCard(id: id, front: front, back: back, reading: reading)
    }

    private func schedule(_ card: StudyCard, skill: ReviewSkill = .recognition, lapses: Int, reviews: Int = 5, version: String? = nil,
                          at seconds: TimeInterval = 1_700_000_000) -> ReviewSchedule {
        ReviewSchedule(cardID: card.id, skill: skill,
                       state: ReviewState(contentVersion: version ?? card.contentVersion, algorithm: FSRSParameters.algorithm, stability: 3, difficulty: 5,
                                          due: Date(timeIntervalSince1970: seconds + 86_400), lastReview: Date(timeIntervalSince1970: seconds),
                                          reviews: reviews, lapses: lapses))
    }

    private func deck(_ id: String, _ cards: [StudyCard]) -> OftenMissedDeck { OftenMissedDeck(id: id, name: "Deck \(id)", cards: cards) }

    func test_aCardMissedTwiceOrMoreIsQueuedWithItsRealNumbers() {
        let dog = card("a")
        let queue = OftenMissedQueue.build(decks: [deck("d1", [dog])], schedules: [schedule(dog, lapses: 3, reviews: 7)])
        guard let first = queue.first else { return XCTFail("expected the card to be queued") }
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(first.cardID, "a")
        XCTAssertEqual(first.deckID, "d1")
        XCTAssertEqual(first.deckName, "Deck d1")
        XCTAssertEqual(first.front, "犬")
        XCTAssertEqual(first.reading, "いぬ")
        XCTAssertEqual(first.back, "chó")
        XCTAssertEqual(first.lapses, 3)
        XCTAssertEqual(first.answers, 7)
        XCTAssertEqual(first.lastAnsweredAt, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func test_aSingleSlipOrNoMissIsNotAPattern() {
        let one = card("one"), none = card("none")
        XCTAssertTrue(OftenMissedQueue.build(decks: [deck("d", [one, none])], schedules: [schedule(one, lapses: 1), schedule(none, lapses: 0)]).isEmpty)
    }

    func test_bothKindsOfAnswerAddUp() {
        let dog = card("a")
        let queue = OftenMissedQueue.build(decks: [deck("d", [dog])], schedules: [schedule(dog, skill: .recognition, lapses: 1, reviews: 3),
                                                                                 schedule(dog, skill: .selfRecall, lapses: 1, reviews: 2, at: 1_700_100_000)])
        XCTAssertEqual(queue.map(\.lapses), [2])
        XCTAssertEqual(queue.map(\.answers), [5])
        XCTAssertEqual(queue.first?.lastAnsweredAt, Date(timeIntervalSince1970: 1_700_100_000), "The latest answer of either kind")
    }

    func test_missesOfAnEarlierWordingDoNotFollowAnEditedCard() {
        let edited = card("a", back: "con chó")
        XCTAssertTrue(OftenMissedQueue.build(decks: [deck("d", [edited])], schedules: [schedule(edited, lapses: 5, version: card("a").contentVersion)]).isEmpty)
    }

    func test_aDeletedCardIsLeftOut() {
        let gone = card("gone"), kept = card("kept")
        let queue = OftenMissedQueue.build(decks: [deck("d", [kept])], schedules: [schedule(gone, lapses: 4), schedule(kept, lapses: 2)])
        XCTAssertEqual(queue.map(\.cardID), ["kept"])
    }

    func test_mostMissedFirstThenMostRecentThenId() {
        let a = card("a"), b = card("b"), c = card("c"), d = card("d")
        let queue = OftenMissedQueue.build(decks: [deck("x", [a, b, c, d])],
                                           schedules: [schedule(a, lapses: 2, at: 1_700_000_000), schedule(b, lapses: 5, at: 1_600_000_000),
                                                       schedule(c, lapses: 2, at: 1_700_500_000), schedule(d, lapses: 2, at: 1_700_500_000)])
        XCTAssertEqual(queue.map(\.cardID), ["b", "c", "d", "a"])
    }

    func test_theQueueIsCappedAtFifty() {
        let cards = (0..<60).map { card(String(format: "c%02d", $0)) }
        let queue = OftenMissedQueue.build(decks: [deck("x", cards)], schedules: cards.map { schedule($0, lapses: 2) })
        XCTAssertEqual(queue.count, OftenMissedQueue.limit)
        XCTAssertEqual(OftenMissedQueue.limit, 50)
    }

    func test_aCardThatSitsInTwoDecksIsListedOnce() {
        let dog = card("a")
        let queue = OftenMissedQueue.build(decks: [deck("first", [dog]), deck("second", [dog])], schedules: [schedule(dog, lapses: 2)])
        XCTAssertEqual(queue.map(\.deckID), ["first"])
    }
}

/// The queue read from a real Realm: attempts in, queue out, per account.
final class OftenMissedInteractorTests: XCTestCase {
    private var decks: DeskManagement!
    private var history: RealmReviewHistoryStore!
    private let owner = "11111111-1111-1111-1111-111111111111"
    private let other = "22222222-2222-2222-2222-222222222222"

    override func setUpWithError() throws {
        let configuration = Realm.Configuration(inMemoryIdentifier: "missed-\(UUID().uuidString)", objectTypes: RealmService.storedTypes)
        RealmService.shared.realm = try Realm(configuration: configuration)
        decks = DeskManagement()
        history = RealmReviewHistoryStore()
    }

    override func tearDownWithError() throws {
        RealmService.shared.realm = nil
    }

    private func addDeck(cards: [(id: String, front: String, back: String)]) throws {
        let deck = DeskEntity()
        deck.id = "deck-1"
        deck.name = "Từ vựng"
        deck.cards = cards.map { item in
            let entity = CardEntity()
            entity.id = item.id
            entity.frontText = item.front
            entity.backText = item.back
            return entity
        }
        try decks.add(deck)
    }

    private func answer(_ card: String, _ results: [ReviewResult], owner: String, version: String) throws {
        for (index, result) in results.enumerated() {
            try history.save(ReviewAttempt(id: "\(card)-\(owner.prefix(2))/\(index)", cardID: card, result: result, hints: [], contentVersion: version,
                                           answeredAt: Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(index) * 86_400)), ownerKey: owner)
        }
    }

    private func version(of id: String) throws -> String {
        let entity = try XCTUnwrap(decks.getAll().first?.cards.first { $0.id == id })
        return StudyCard(entity: entity).contentVersion
    }

    func test_wrongAnswersAfterTheFirstBecomeLapsesThatQueueTheCard() throws {
        try addDeck(cards: [("a", "犬", "chó"), ("b", "猫", "mèo")])
        try answer("a", [.correct, .incorrect, .incorrect], owner: owner, version: try version(of: "a"))
        try answer("b", [.incorrect, .correct, .incorrect], owner: owner, version: try version(of: "b"))
        let queue = try OftenMissedInteractor(decks: decks, schedules: history).queue(ownerKey: owner)
        XCTAssertEqual(queue.map(\.cardID), ["a"], "b missed once after its first answer: a slip, not a pattern")
        XCTAssertEqual(queue.first?.lapses, 2)
        XCTAssertEqual(queue.first?.answers, 3)
        XCTAssertEqual(queue.first?.deckName, "Từ vựng")
    }

    func test_anotherAccountsHistoryIsNeverShown() throws {
        try addDeck(cards: [("a", "犬", "chó")])
        try answer("a", [.correct, .incorrect, .incorrect], owner: other, version: try version(of: "a"))
        XCTAssertTrue(try OftenMissedInteractor(decks: decks, schedules: history).queue(ownerKey: owner).isEmpty)
        XCTAssertTrue(try OftenMissedInteractor(decks: decks, schedules: history).queue(ownerKey: "").isEmpty, "Guest history is separate too")
        XCTAssertEqual(try OftenMissedInteractor(decks: decks, schedules: history).queue(ownerKey: other).count, 1)
    }

    func test_missesOfTheOldWordingStopCountingAfterTheCardIsEdited() throws {
        try addDeck(cards: [("a", "犬", "chó")])
        try answer("a", [.correct, .incorrect, .incorrect], owner: owner, version: "an-earlier-wording")
        XCTAssertTrue(try OftenMissedInteractor(decks: decks, schedules: history).queue(ownerKey: owner).isEmpty)
    }

    func test_aHistoryThatCannotBeReadIsAnErrorNotAnEmptyList() {
        struct Broken: Error {}
        final class BrokenSchedules: ReviewScheduleStoreInterface {
            func schedules(ownerKey: String) -> [ReviewSchedule] { [] }
            func dueSchedules(ownerKey: String, at date: Date, currentVersions: [String: String]) -> [ReviewSchedule] { [] }
            func attempts(ownerKey: String, answeredSince date: Date) -> [ReviewAttempt] { [] }
            func rebuildSchedules(ownerKey: String) throws { throw Broken() }
            func ensureSchedules(ownerKey: String) throws { throw Broken() }
        }
        XCTAssertThrowsError(try OftenMissedInteractor(decks: decks, schedules: BrokenSchedules()).queue(ownerKey: owner))
    }
}

private final class FakeMissedInteractor: OftenMissedInteractorInterface {
    var result: Result<[OftenMissedCard], Error> = .success([])
    private(set) var owners: [String] = []
    func queue(ownerKey: String) throws -> [OftenMissedCard] {
        owners.append(ownerKey)
        return try result.get()
    }
}

private final class FakeMissedWireframe: OftenMissedWireframeInterface {
    private(set) var studied: [(deckId: String, cardIDs: [String])] = []
    func showStudy(deckId: String, cardIDs: [String]) { studied.append((deckId, cardIDs)) }
}

final class OftenMissedPresenterTests: XCTestCase {
    private var interactor: FakeMissedInteractor!
    private var wireframe: FakeMissedWireframe!
    private var presenter: OftenMissedPresenter!
    private var changes = 0

    override func setUp() {
        super.setUp()
        interactor = FakeMissedInteractor()
        wireframe = FakeMissedWireframe()
        presenter = OftenMissedPresenter(interactor: interactor, ownerKey: { "owner-1" })
        presenter.wireframe = wireframe
        changes = 0
        presenter.onChange = { [unowned self] in changes += 1 }
    }

    private func missed(_ id: String, deck: String = "deck-1", lapses: Int = 3, answers: Int = 7) -> OftenMissedCard {
        OftenMissedCard(cardID: id, deckID: deck, deckName: "Từ vựng", front: "犬", reading: "いぬ", back: "chó", lapses: lapses, answers: answers,
                        lastAnsweredAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    func test_beforeTheScreenAppearsNothingIsLoaded() {
        XCTAssertEqual(presenter.state, .idle)
        XCTAssertTrue(interactor.owners.isEmpty)
    }

    func test_rowsCarryTheCardAndTheRealCounts() {
        interactor.result = .success([missed("a", lapses: 3, answers: 7)])
        presenter.viewWillAppear()
        guard case .rows(let rows) = presenter.state else { return XCTFail("expected rows") }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].front, "犬")
        XCTAssertEqual(rows[0].back, "chó")
        XCTAssertEqual(rows[0].deckName, "Từ vựng")
        XCTAssertEqual(rows[0].detail, String.localizedStringWithFormat(NSLocalizedString("Missed %1$lld times in %2$lld answers", comment: ""), 3, 7))
        XCTAssertEqual(interactor.owners, ["owner-1"])
        XCTAssertGreaterThan(changes, 0)
    }

    func test_nothingQueuedIsAnHonestEmptyState() {
        presenter.viewWillAppear()
        XCTAssertEqual(presenter.state, .empty)
    }

    func test_anUnreadableHistoryIsReportedAndCanBeRetried() {
        struct Broken: LocalizedError { var errorDescription: String? { "boom" } }
        interactor.result = .failure(Broken())
        presenter.viewWillAppear()
        XCTAssertEqual(presenter.state, .failed("boom"))
        interactor.result = .success([missed("a")])
        presenter.retry()
        guard case .rows = presenter.state else { return XCTFail("expected rows after retry") }
    }

    func test_comingBackShowsTheLatestHistory() {
        interactor.result = .success([missed("a")])
        presenter.viewWillAppear()
        interactor.result = .success([])
        presenter.viewWillAppear()
        XCTAssertEqual(presenter.state, .empty)
    }

    func test_selectingARowOpensTargetedMissedCardsOfThatDeckWithTappedCardFirst() {
        interactor.result = .success([
            missed("a", deck: "deck-1"),
            missed("b", deck: "deck-2"),
            missed("c", deck: "deck-1")
        ])
        presenter.viewWillAppear()
        presenter.selectRow(at: 2)
        XCTAssertEqual(wireframe.studied.count, 1)
        XCTAssertEqual(wireframe.studied.first?.deckId, "deck-1")
        XCTAssertEqual(wireframe.studied.first?.cardIDs, ["c", "a"])

        presenter.selectRow(at: 1)
        XCTAssertEqual(wireframe.studied.last?.deckId, "deck-2")
        XCTAssertEqual(wireframe.studied.last?.cardIDs, ["b"])

        presenter.selectRow(at: 5)
        presenter.selectRow(at: -1)
        XCTAssertEqual(wireframe.studied.count, 2)
    }
}
