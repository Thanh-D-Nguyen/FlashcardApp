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

    func testLevelRowSeparatesCodeFromNameAndKeepsBackendCounts() {
        let interactor = LevelHomeInteractorStub()
        interactor.levels = .just([level])
        let presenter = HomePresenter(interactor: interactor, wireframe: LevelHomeWireframeSpy())
        presenter.viewDidLoad()
        let row = presenter.rows.first
        XCTAssertEqual(row?.mark, "J5")
        XCTAssertEqual(row?.name, "Sơ cấp")
        XCTAssertEqual(row?.summary, "Cơ bản")
        XCTAssertEqual(row?.counts, [HomeCount(value: 60, label: HomeContentKind.vocabulary.unit),
                                     HomeCount(value: 10, label: HomeContentKind.kanji.unit),
                                     HomeCount(value: 20, label: HomeContentKind.grammar.unit)])
        XCTAssertEqual(row?.title, "J5 — Sơ cấp")
    }

    func testLevelNameWithoutCodePrefixIsKeptAndEmptyLevelHasNoCounts() {
        let plain = BJTLevelDTO(code: "J1+", nameVi: "Chuyên sâu", descriptionVi: "", vocabCount: 0, kanjiCount: 0, grammarCount: 0)
        let row = HomePresenter.levelRow(plain)
        XCTAssertEqual(row.name, "Chuyên sâu")
        XCTAssertTrue(row.counts.isEmpty, "A level with no items must not print three zero counts")
        let dashed = BJTLevelDTO(code: "J1+", nameVi: "J1+ — Cao cấp+", descriptionVi: "", vocabCount: 0, kanjiCount: 0, grammarCount: 3)
        XCTAssertEqual(HomePresenter.levelRow(dashed).name, "Cao cấp+")
        XCTAssertEqual(HomePresenter.levelRow(dashed).counts.map(\.value), [0, 0, 3])
    }

    func testLevelRowCarriesKanjiNumeralForEachJLPTLevel() {
        func numeral(_ code: String) -> String? {
            HomePresenter.levelRow(BJTLevelDTO(code: code, nameVi: code, descriptionVi: "", vocabCount: 1, kanjiCount: 0, grammarCount: 0)).numeral
        }
        XCTAssertEqual(["J5", "J4", "J3", "J2", "J1", "J1+"].map(numeral), ["五", "四", "三", "二", "一", "一+"])
        XCTAssertNil(numeral("X9"), "An unknown code must fall back to the code mark, never an invented numeral")
    }

    func testFeaturedLevelIsFirstLevelWithContent() {
        let empty = BJTLevelDTO(code: "J1+", nameVi: "J1+", descriptionVi: "", vocabCount: 0, kanjiCount: 0, grammarCount: 0)
        let interactor = LevelHomeInteractorStub()
        interactor.levels = .just([empty, level])
        let presenter = HomePresenter(interactor: interactor, wireframe: LevelHomeWireframeSpy())
        XCTAssertNil(presenter.featuredIndex)
        presenter.viewDidLoad()
        XCTAssertEqual(presenter.featuredIndex, 1)
        let contentPresenter = HomePresenter(interactor: LevelHomeInteractorStub(), wireframe: LevelHomeWireframeSpy(), level: level)
        XCTAssertNil(contentPresenter.featuredIndex)
    }

    func testSectionsFollowFeaturedLevelEvenWhenNotFirst() {
        let empty = BJTLevelDTO(code: "J1+", nameVi: "J1+", descriptionVi: "", vocabCount: 0, kanjiCount: 0, grammarCount: 0)
        let interactor = LevelHomeInteractorStub()
        interactor.levels = .just([empty, level, empty])
        let presenter = HomePresenter(interactor: interactor, wireframe: LevelHomeWireframeSpy())
        XCTAssertEqual(HomeViewController.makeSections(presenter: presenter, hasStatus: false), [])
        presenter.viewDidLoad()
        XCTAssertEqual(HomeViewController.makeSections(presenter: presenter, hasStatus: false),
                       [.featured(1), .levels([0, 2])])
        presenter.selectRow(at: 1, kind: .kanji)
        XCTAssertEqual(presenter.featuredIndex, 1, "The index handed to the presenter is the row index, not the table row")
    }

    func testSectionsWithoutAnyContentHaveNoFeaturedLevelAndContentModeIsOneSection() {
        let empty = BJTLevelDTO(code: "J1+", nameVi: "J1+", descriptionVi: "", vocabCount: 0, kanjiCount: 0, grammarCount: 0)
        let interactor = LevelHomeInteractorStub()
        interactor.levels = .just([empty])
        let presenter = HomePresenter(interactor: interactor, wireframe: LevelHomeWireframeSpy())
        presenter.viewDidLoad()
        XCTAssertEqual(HomeViewController.makeSections(presenter: presenter, hasStatus: true), [.levels([0]), .status])
        let content = HomePresenter(interactor: LevelHomeInteractorStub(), wireframe: LevelHomeWireframeSpy(), level: level)
        XCTAssertEqual(HomeViewController.makeSections(presenter: content, hasStatus: true), [.content, .status])
    }

    func testSelectingLevelWithKindOpensThatKind() {
        let interactor = LevelHomeInteractorStub()
        interactor.levels = .just([level])
        let wireframe = LevelHomeWireframeSpy()
        let presenter = HomePresenter(interactor: interactor, wireframe: wireframe)
        presenter.viewDidLoad()
        presenter.selectRow(at: 0, kind: .grammar)
        XCTAssertEqual(wireframe.openedLevel?.code, "J5")
        XCTAssertEqual(wireframe.openedKind, .grammar)
        presenter.selectRow(at: 0)
        XCTAssertEqual(wireframe.openedKind, .vocabulary, "Opening a level without a chosen kind starts at vocabulary")
    }

    func testOpenLevelStartsInRequestedKindAndLoadsIt() {
        let interactor = LevelHomeInteractorStub()
        let presenter = HomePresenter(interactor: interactor, wireframe: LevelHomeWireframeSpy(), level: level, kind: .kanji)
        XCTAssertEqual(presenter.kind, .kanji)
        XCTAssertEqual(presenter.kindTotal, 10)
        presenter.viewDidLoad()
        XCTAssertEqual(interactor.kinds, [.kanji])
    }

    func testLevelNameAndDescriptionFollowTheAppLanguageWithVietnameseFallback() {
        let multilingual = BJTLevelDTO(code: "J5", nameVi: "J5 — Sơ cấp", descriptionVi: "Giao tiếp cơ bản.",
                                       vocabCount: 1, kanjiCount: 1, grammarCount: 1,
                                       nameEn: "J5 — Lower beginner", nameJa: "J5 — 初級前半",
                                       descriptionEn: "Handle basic greetings.", descriptionJa: "基本的な挨拶。")
        let vi = HomePresenter.levelRow(multilingual, language: .vietnamese)
        let en = HomePresenter.levelRow(multilingual, language: .english)
        let ja = HomePresenter.levelRow(multilingual, language: .japanese)
        XCTAssertEqual([vi.name, en.name, ja.name], ["Sơ cấp", "Lower beginner", "初級前半"])
        XCTAssertEqual([vi.summary, en.summary, ja.summary], ["Giao tiếp cơ bản.", "Handle basic greetings.", "基本的な挨拶。"])
        XCTAssertEqual(en.title, "J5 — Lower beginner", "The full name keeps its code prefix for the navigation title")
        XCTAssertEqual(ja.mark, "J5")

        let viOnly = BJTLevelDTO(code: "J4", nameVi: "J4 — Sơ trung cấp", descriptionVi: "Hội thoại đơn giản.",
                                 vocabCount: 1, kanjiCount: 0, grammarCount: 0, nameEn: "", descriptionEn: "  ")
        XCTAssertEqual(HomePresenter.levelRow(viOnly, language: .english).name, "Sơ trung cấp", "Blank translations fall back to Vietnamese")
        XCTAssertEqual(HomePresenter.levelRow(viOnly, language: .japanese).summary, "Hội thoại đơn giản.")
    }

    func testCountsAreFormattedForTheAppLanguage() {
        let big = BJTLevelDTO(code: "J3", nameVi: "J3 — Trung cấp", descriptionVi: "", vocabCount: 1538, kanjiCount: 0, grammarCount: 0)
        XCTAssertTrue(HomePresenter.levelRow(big, language: .vietnamese).subtitle.contains("1.538"))
        XCTAssertTrue(HomePresenter.levelRow(big, language: .english).subtitle.contains("1,538"))
    }

    func testKindTotalFollowsSelectedKindOfOpenLevel() {
        let presenter = HomePresenter(interactor: LevelHomeInteractorStub(), wireframe: LevelHomeWireframeSpy(), level: level)
        XCTAssertEqual(presenter.kindTotal, 60)
        presenter.selectKind(.kanji)
        XCTAssertEqual(presenter.kindTotal, 10)
        presenter.selectKind(.grammar)
        XCTAssertEqual(presenter.kindTotal, 20)
        let levels = HomePresenter(interactor: LevelHomeInteractorStub(), wireframe: LevelHomeWireframeSpy())
        XCTAssertNil(levels.kindTotal)
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
    var openedKind: HomeContentKind?
    func showLevel(_ level: BJTLevelDTO, kind: HomeContentKind) { openedLevel = level; openedKind = kind }
    func showMeaning(title: String, message: String) { detail = message }
}
