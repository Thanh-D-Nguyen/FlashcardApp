import XCTest
@testable import FlashcardApp

final class CardPresenterTests: XCTestCase {
    private var defaults: UserDefaults!
    private var interactor: FakeDeskInteractor!
    private var wireframe: FakeCardWireframe!
    private var view: SpyCardView!
    private var presenter: CardPresenter!

    override func setUp() {
        super.setUp()
        let suite = "card-presenter-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        interactor = FakeDeskInteractor()
        wireframe = FakeCardWireframe()
        view = SpyCardView()
        presenter = makePresenter()
    }

    private func makePresenter() -> CardPresenter {
        let result = CardPresenter(interactor: CardInteractor(), deskInteractor: interactor, wireframe: wireframe, defaults: defaults)
        result.view = view
        return result
    }

    private func desk(_ id: String, _ name: String, cards: [(String, String)] = [("犬", "chó"), ("猫", "mèo")], age: TimeInterval = 0,
                      details: String = "") -> DeskEntity {
        let entity = DeskEntity()
        entity.id = id
        entity.name = name
        entity.description = details
        entity.date = Date(timeIntervalSinceNow: -age)
        entity.cards = cards.map { front, back in
            let card = CardEntity()
            card.frontText = front
            card.backText = back
            return card
        }
        return entity
    }

    private var rows: [DeckRowModel] {
        if case .decks(let rows) = view.states.last?.content { return rows }
        return []
    }

    func test_oftenMissedOpensTheLocalListOnce() {
        presenter.showOftenMissed()
        XCTAssertEqual(wireframe.oftenMissedOpened, 1)
    }

    func test_noDecksShowsTheEmptyState() {
        presenter.viewWillAppear()
        XCTAssertEqual(view.states.last?.content, .empty)
        XCTAssertEqual(view.states.last?.deckCount, 0)
    }

    func test_decksAreListedNewestFirstWithPreviewAndCount() {
        interactor.decks = [desk("old", "Old", age: 500), desk("new", "New", cards: [("会議", "họp"), ("資料", "tài liệu"), ("予定", "kế hoạch"), ("締め切り", "hạn")], age: 5)]
        presenter.viewWillAppear()
        XCTAssertEqual(rows.map(\.id), ["new", "old"])
        XCTAssertEqual(rows.first?.preview, "会議 · 資料 · 予定 …")
        XCTAssertEqual(rows.first?.cardCount, 4)
        XCTAssertEqual(rows.first?.monogram, "会")
    }

    func test_searchMatchesDeckNameDescriptionAndCardText() {
        interactor.decks = [desk("a", "Office", cards: [("会議", "họp"), ("資料", "tài liệu")], details: "Meetings"), desk("b", "Animals", cards: [("犬", "chó"), ("猫", "mèo")])]
        presenter.viewWillAppear()
        presenter.updateQuery("meet")
        XCTAssertEqual(rows.map(\.id), ["a"])
        presenter.updateQuery("MÈO")
        XCTAssertEqual(rows.map(\.id), ["b"], "Search ignores case and diacritics, and looks inside cards")
        presenter.updateQuery("zzz")
        XCTAssertEqual(view.states.last?.content, .noMatches(query: "zzz"))
        presenter.updateQuery("")
        XCTAssertEqual(rows.count, 2)
    }

    func test_sortOrdersAndIsRememberedAcrossLaunches() {
        interactor.decks = [desk("a", "Banana", cards: [("1", "1")], age: 1), desk("b", "apple", cards: [("1", "1"), ("2", "2"), ("3", "3")], age: 2), desk("c", "Cherry", cards: [("1", "1"), ("2", "2")], age: 3)]
        presenter.viewWillAppear()
        presenter.setSort(.name)
        XCTAssertEqual(rows.map(\.id), ["b", "a", "c"])
        presenter.setSort(.cardCount)
        XCTAssertEqual(rows.map(\.id), ["b", "c", "a"])
        XCTAssertEqual(makePresenter().sort, .cardCount)
    }

    func test_tappingADeckStudiesItAndAMissingDeckJustRefreshes() {
        interactor.decks = [desk("a", "A")]
        presenter.studyDeck(id: "a")
        XCTAssertEqual(wireframe.studied, ["a"])
        presenter.studyDeck(id: "gone")
        XCTAssertEqual(wireframe.studied, ["a"])
        XCTAssertFalse(view.states.isEmpty, "A stale row triggers a reload")
    }

    func test_createAndEditOpenTheEditorAndReloadWhenItFinishes() {
        interactor.decks = [desk("a", "A")]
        presenter.createDeck()
        XCTAssertEqual(wireframe.optionSheets, 1, "Creating a deck first offers typing it or generating it")
        XCTAssertTrue(wireframe.editors.isEmpty)
        wireframe.choose(.manual)
        presenter.editDeck(id: "a")
        XCTAssertEqual(wireframe.editors, [nil, "a"])
        let before = view.states.count
        wireframe.finishEditor()
        XCTAssertEqual(view.states.count, before + 1)
    }

    func test_generatingADeckListsItAndOpensItInTheEditor() {
        interactor.decks = [desk("generated", "N5")]
        presenter.createDeck()
        wireframe.choose(.automatic)
        XCTAssertEqual(wireframe.generators, 1)
        XCTAssertTrue(wireframe.editors.isEmpty, "The editor opens only once a deck was imported")
        let before = view.states.count
        wireframe.finishGenerator(deckId: "generated")
        XCTAssertEqual(wireframe.editors, ["generated"])
        XCTAssertGreaterThan(view.states.count, before, "The library lists the imported deck right away")
    }

    func test_deleteAsksFirstAndOnlyDeletesAfterConfirmation() {
        interactor.decks = [desk("a", "A"), desk("b", "B")]
        presenter.requestDelete(id: "a")
        XCTAssertEqual(wireframe.deleteRequests, ["A"])
        XCTAssertTrue(interactor.deleted.isEmpty)
        wireframe.confirmDelete()
        XCTAssertEqual(interactor.deleted, ["a"])
        XCTAssertEqual(rows.map(\.id), ["b"])
    }

    func test_deleteFailureIsReportedAndTheDeckStays() {
        interactor.decks = [desk("a", "A")]
        interactor.deleteError = AppError.databaseWriteFailed("disk full")
        presenter.requestDelete(id: "a")
        wireframe.confirmDelete()
        XCTAssertEqual(wireframe.alerts.count, 1)
        XCTAssertEqual(rows.map(\.id), ["a"])
    }
}

final class SpyCardView: CardViewInterface {
    var states: [CardLibraryState] = []
    func render(_ state: CardLibraryState) { states.append(state) }
}

final class FakeDeskInteractor: DeskInteractorInterface {
    var decks: [DeskEntity] = []
    var deleted: [String] = []
    var deleteError: Error?

    var desks: [DeskEntity] { decks }
    func desk(withId id: String) -> DeskEntity? { decks.first { $0.id == id } }
    func deleteDesk(withId id: String) throws {
        if let deleteError { throw deleteError }
        deleted.append(id)
        decks.removeAll { $0.id == id }
    }
}

final class FakeCardWireframe: CardWireframeInterface {
    var uploadConfirmations: [(name: String, cards: Int, pictures: Int)] = []
    var progressMessages: [String] = []
    var progressCancellable: [Bool] = []
    var hidden = 0
    private var uploadConfirm: (() -> Void)?
    private(set) var cancelUpload: (() -> Void)?
    func confirmUpload(deckName: String, cardCount: Int, pictureCount: Int, onConfirm: @escaping () -> Void) {
        uploadConfirmations.append((deckName, cardCount, pictureCount)); uploadConfirm = onConfirm
    }
    func confirmTheUpload() { uploadConfirm?() }
    func showUploadProgress(message: String, onCancel: (() -> Void)?) {
        progressMessages.append(message); progressCancellable.append(onCancel != nil); cancelUpload = onCancel
    }
    func hideUploadProgress(then: @escaping () -> Void) { hidden += 1; then() }
    var editors: [String?] = []
    var studied: [String] = []
    private(set) var oftenMissedOpened = 0
    func showOftenMissed() { oftenMissedOpened += 1 }
    var deleteRequests: [String] = []
    var alerts: [String?] = []
    private var editorFinish: (() -> Void)?
    private var deleteConfirmation: (() -> Void)?

    func showEditor(deckId: String?, onFinish: @escaping () -> Void) { editors.append(deckId); editorFinish = onFinish }
    var optionSheets = 0
    var generators = 0
    private var chooseMethod: ((NewDeckMethod) -> Void)?
    private var generatorFinish: ((String) -> Void)?

    func showNewDeckOptions(onChoose: @escaping (NewDeckMethod) -> Void) { optionSheets += 1; chooseMethod = onChoose }
    func showDeckGenerator(onImported: @escaping (String) -> Void) { generators += 1; generatorFinish = onImported }
    func choose(_ method: NewDeckMethod) { chooseMethod?(method) }
    func finishGenerator(deckId: String) { generatorFinish?(deckId) }
    func showStudy(deckId: String) { studied.append(deckId) }
    var reviews: [[DueCard]] = []
    var remoteDecks: [String] = []
    var signIns = 0
    private var signInFinish: (() -> Void)?
    func showReview(cards: [DueCard]) { reviews.append(cards) }
    func showRemoteDeck(deckId: String) { remoteDecks.append(deckId) }
    func showSignIn(onFinish: @escaping () -> Void) { signIns += 1; signInFinish = onFinish }
    func finishSignIn() { signInFinish?() }
    func confirmDelete(deckName: String, onConfirm: @escaping () -> Void) { deleteRequests.append(deckName); deleteConfirmation = onConfirm }
    func showAlert(with title: String?, message: String?) { alerts.append(message) }
    func finishEditor() { editorFinish?() }
    func confirmDelete() { deleteConfirmation?() }
}
