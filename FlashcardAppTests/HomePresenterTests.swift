import RxSwift
import XCTest
@testable import FlashcardApp

final class HomePresenterTests: XCTestCase {
    private let level = BJTLevelDTO(code: "J5", nameVi: "J5 — Sơ cấp", descriptionVi: "Cơ bản", vocabCount: 60, kanjiCount: 10, grammarCount: 20)

    func testLevelRowsAndNavigationUseBackendValues() {
        let interactor = LevelHomeInteractorStub()
        interactor.levels = .just([level])
        let wireframe = LevelHomeWireframeSpy()
        let presenter = HomePresenter(interactor: interactor, wireframe: wireframe)
        presenter.viewDidLoad()
        XCTAssertEqual(presenter.rows.first?.title, "J5 — Sơ cấp")
        XCTAssertTrue(presenter.rows.first?.subtitle.contains("60") == true)
        presenter.selectRow(at: 0)
        XCTAssertEqual(wireframe.openedLevel?.code, "J5")
        presenter.viewDidLoad()
        XCTAssertEqual(interactor.listCalls, 1)
    }

    func testPaginationDoesNotOverlapRetriesSameOffsetAndEndsOnShortPage() {
        let interactor = LevelHomeInteractorStub()
        let wireframe = LevelHomeWireframeSpy()
        let presenter = HomePresenter(interactor: interactor, wireframe: wireframe, level: level)
        presenter.viewDidLoad()
        presenter.loadMore()
        XCTAssertEqual(interactor.offsets, [0])
        interactor.pages[0].onNext(makeRows(30))
        interactor.pages[0].onCompleted()
        XCTAssertTrue(presenter.canLoadMore)
        presenter.loadMore()
        interactor.pages[1].onError(URLError(.notConnectedToInternet))
        XCTAssertEqual(presenter.rows.count, 30)
        XCTAssertNotNil(presenter.errorMessage)
        presenter.retry()
        XCTAssertEqual(interactor.offsets, [0, 30, 30])
        interactor.pages[2].onNext(makeRows(1))
        interactor.pages[2].onCompleted()
        XCTAssertEqual(presenter.rows.count, 31)
        XCTAssertFalse(presenter.canLoadMore)
        XCTAssertNil(presenter.errorMessage)
        presenter.loadMore()
        XCTAssertEqual(interactor.offsets.count, 3)
    }

    func testCategoryChangeCancelsOldPageAndResetsOffset() {
        let interactor = LevelHomeInteractorStub()
        let presenter = HomePresenter(interactor: interactor, wireframe: LevelHomeWireframeSpy(), level: level)
        presenter.viewDidLoad()
        presenter.selectKind(.kanji)
        XCTAssertEqual(interactor.cancelledPages, [0])
        XCTAssertEqual(interactor.offsets, [0, 0])
        XCTAssertEqual(interactor.kinds, [.vocabulary, .kanji])
        interactor.pages[0].onNext(makeRows(30))
        interactor.pages[0].onCompleted()
        XCTAssertTrue(presenter.rows.isEmpty)
        interactor.pages[1].onNext([])
        interactor.pages[1].onCompleted()
        XCTAssertTrue(presenter.rows.isEmpty)
        XCTAssertFalse(presenter.isLoading)
        XCTAssertFalse(presenter.canLoadMore)
    }

    func testLeavingCancelsAndCanResumeInitialLoad() {
        let interactor = LevelHomeInteractorStub()
        let presenter = HomePresenter(interactor: interactor, wireframe: LevelHomeWireframeSpy(), level: level)
        presenter.viewDidLoad()
        presenter.cancelLoading()
        XCTAssertEqual(interactor.cancelledPages, [0])
        XCTAssertFalse(presenter.isLoading)
        presenter.viewDidLoad()
        XCTAssertEqual(interactor.offsets, [0, 0])
    }

    func testContentSelectionShowsAvailableMeaning() {
        let interactor = LevelHomeInteractorStub()
        let wireframe = LevelHomeWireframeSpy()
        let presenter = HomePresenter(interactor: interactor, wireframe: wireframe, level: level)
        presenter.viewDidLoad()
        interactor.pages[0].onNext(makeRows(1))
        interactor.pages[0].onCompleted()
        presenter.selectRow(at: 0)
        XCTAssertEqual(wireframe.detail, "Nghĩa đầy đủ")
    }

    private func makeRows(_ count: Int) -> [HomeRow] {
        (0..<count).map { HomeRow(id: "id-\($0)", title: "語", subtitle: "Nghĩa", detail: "Nghĩa đầy đủ") }
    }
}

private final class LevelHomeInteractorStub: HomeInteractorInterface {
    var levels: Single<[BJTLevelDTO]> = .just([])
    var listCalls = 0
    var pages: [PublishSubject<[HomeRow]>] = []
    var offsets: [Int] = []
    var kinds: [HomeContentKind] = []
    var cancelledPages: [Int] = []

    func listLevels() -> Single<[BJTLevelDTO]> { listCalls += 1; return levels }
    func content(code: String, kind: HomeContentKind, offset: Int) -> Single<[HomeRow]> {
        let page = PublishSubject<[HomeRow]>()
        let index = pages.count
        pages.append(page)
        offsets.append(offset)
        kinds.append(kind)
        return page.take(1).asSingle().do(onDispose: { [weak self] in self?.cancelledPages.append(index) })
    }
}

private final class LevelHomeWireframeSpy: HomeWireframeInterface {
    var openedLevel: BJTLevelDTO?
    var detail: String?
    func showLevel(_ level: BJTLevelDTO) { openedLevel = level }
    func showMeaning(title: String, message: String) { detail = message }
}
