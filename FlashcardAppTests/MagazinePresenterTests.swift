import RxSwift
import XCTest
@testable import FlashcardApp

/// The article list: which section an article goes to, paging, filters, and that a slow or old reply never shows the wrong list.
final class MagazinePresenterTests: XCTestCase {
    private var interactor: FakeMagazineInteractor!
    private var wireframe: FakeMagazineWireframe!
    private var view: SpyMagazineView!
    private var presenter: MagazinePresenter!

    /// Monday 26 October 2026, noon in Tokyo.
    private let now = ISO8601DateFormatter().date(from: "2026-10-26T03:00:00Z")!

    override func setUp() {
        super.setUp()
        interactor = FakeMagazineInteractor()
        wireframe = FakeMagazineWireframe()
        view = SpyMagazineView()
        presenter = MagazinePresenter(interactor: interactor, wireframe: wireframe, language: { .english }, now: { self.now }, scheduler: CurrentThreadScheduler.instance)
        presenter.view = view
    }

    private func page(_ slugs: [String], days: [String]? = nil, hasMore: Bool = false, page: Int = 1) -> MagazinePage {
        MagazinePage(items: slugs.enumerated().map { MagazineFixtures.summary($1, day: days?[$0] ?? "2026-10-26") }, page: page, hasMore: hasMore)
    }

    private func sections() throws -> [MagazineSection] {
        guard case .list(let sections, _)? = view.last?.content else { throw XCTSkip("not a list: \(String(describing: view.last))") }
        return sections
    }

    private func footer() -> MagazineFooter? {
        if case .list(_, let footer)? = view.last?.content { return footer }
        return nil
    }

    // MARK: Loading

    func test_theFirstLoadShowsLoadingThenTheArticles() throws {
        let reply = PublishSubject<MagazinePage>()
        interactor.pageResult = { _, _ in reply.take(1).asSingle() }
        presenter.viewDidLoad()
        XCTAssertEqual(view.last?.content, .loading(message: "Loading articles…"))
        XCTAssertEqual(interactor.pageCalls.map(\.page), [1])
        XCTAssertNil(interactor.pageCalls.first?.kind)

        reply.onNext(page(["a", "b"]))
        XCTAssertEqual(try sections().flatMap(\.rows).map(\.slug), ["a", "b"])
    }

    func test_aFailureIsShownWithItsReasonAndRetryLoadsAgain() {
        interactor.pageResult = { _, _ in .error(LearnerAPIError.offline) }
        presenter.viewDidLoad()
        XCTAssertEqual(view.last?.content, .failed(message: LearnerAPIError.offline.errorDescription ?? ""))

        interactor.pageResult = { _, _ in .just(self.page(["a"])) }
        presenter.retry()
        XCTAssertEqual(interactor.pageCalls.count, 2)
        if case .list? = view.last?.content {} else { XCTFail("expected the list") }
    }

    func test_noArticlesIsAnEmptyStateNotABlankScreen() {
        interactor.pageResult = { _, _ in .just(self.page([])) }
        presenter.viewDidLoad()
        guard case .empty(let title, _)? = view.last?.content else { return XCTFail("expected empty") }
        XCTAssertEqual(title, "No articles yet")
    }

    // MARK: Sections

    func test_todaysNewestArticleLeadsAndTheRestOfTodayFollowsItThenEarlier() throws {
        interactor.pageResult = { _, _ in .just(self.page(["a", "b", "c", "d"], days: ["2026-10-26", "2026-10-26", "2026-10-25", "2026-10-24"])) }
        presenter.viewDidLoad()
        let sections = try sections()
        XCTAssertEqual(sections.map(\.title), ["Today", "Also today", "Earlier"])
        XCTAssertEqual(sections.map(\.style), [.lead, .rows, .rows])
        XCTAssertEqual(sections.map { $0.rows.map(\.slug) }, [["a"], ["b"], ["c", "d"]])
        XCTAssertTrue(sections[0].rows[0].isToday)
        XCTAssertFalse(sections[2].rows[0].isToday)
    }

    func test_whenNothingIsFromTodayTheNewestStillLeadsAsLatest() throws {
        interactor.pageResult = { _, _ in .just(self.page(["a", "b"], days: ["2026-10-24", "2026-10-23"])) }
        presenter.viewDidLoad()
        XCTAssertEqual(try sections().map(\.title), ["Latest", "Earlier"])
    }

    func test_aSingleArticleHasNoEarlierSection() throws {
        interactor.pageResult = { _, _ in .just(self.page(["a"])) }
        presenter.viewDidLoad()
        XCTAssertEqual(try sections().count, 1)
    }

    func test_aRowTellsTheKindLevelAndDateInTheAppsLanguage() throws {
        interactor.pageResult = { _, _ in .just(self.page(["a"])) }
        presenter.viewDidLoad()
        let row = try XCTUnwrap(sections().first?.rows.first)
        XCTAssertEqual(row.meta, "Vocabulary · N4 · Oct 26")
        XCTAssertEqual(row.titleJapanese, "題 a")
        XCTAssertEqual(row.words, ["梅雨"])
    }

    // MARK: Filters

    func test_choosingAFilterLoadsThatKindFromTheFirstPage() throws {
        interactor.pageResult = { _, _ in .just(self.page(["a"])) }
        presenter.viewDidLoad()
        presenter.select(.kind(.weather))
        XCTAssertEqual(interactor.pageCalls.last?.kind, .weather)
        XCTAssertEqual(interactor.pageCalls.last?.page, 1)
        XCTAssertEqual(view.last?.filter, .kind(.weather))
    }

    func test_choosingTheSameFilterAgainDoesNothing() {
        interactor.pageResult = { _, _ in .just(self.page(["a"])) }
        presenter.viewDidLoad()
        presenter.select(.all)
        XCTAssertEqual(interactor.pageCalls.count, 1)
    }

    func test_aSlowReplyForAnEarlierFilterNeverShowsOverTheNewOne() throws {
        let slowAll = PublishSubject<MagazinePage>()
        let weather = PublishSubject<MagazinePage>()
        interactor.pageResult = { kind, _ in (kind == nil ? slowAll : weather).take(1).asSingle() }
        presenter.viewDidLoad()
        presenter.select(.kind(.weather))
        weather.onNext(page(["weather-1"]))
        slowAll.onNext(page(["all-1"]))
        XCTAssertEqual(try sections().flatMap(\.rows).map(\.slug), ["weather-1"])
    }

    func test_everyFilterHasATitleAndTheKindsFollowAll() {
        XCTAssertEqual(MagazineFilter.allCases.first, .all)
        XCTAssertEqual(MagazineFilter.allCases.count, MagazineKind.allCases.count + 1)
        XCTAssertTrue(MagazineFilter.allCases.allSatisfy { !$0.title.isEmpty })
    }

    // MARK: Paging

    func test_nearTheEndTheNextPageIsLoadedAndAppended() throws {
        interactor.pageResult = { _, number in .just(number == 1 ? self.page(["a", "b"], hasMore: true) : self.page(["c"], hasMore: false, page: 2)) }
        presenter.viewDidLoad()
        presenter.loadMore()
        XCTAssertEqual(interactor.pageCalls.map(\.page), [1, 2])
        XCTAssertEqual(try sections().flatMap(\.rows).map(\.slug), ["a", "b", "c"])
        XCTAssertEqual(footer(), MagazineFooter.none)
        presenter.loadMore()
        XCTAssertEqual(interactor.pageCalls.count, 2, "There is no third page")
    }

    func test_whileANextPageLoadsAnotherRequestIsNotStartedAndTheFooterSpins() throws {
        let second = PublishSubject<MagazinePage>()
        interactor.pageResult = { _, number in number == 1 ? .just(self.page(["a"], hasMore: true)) : second.take(1).asSingle() }
        presenter.viewDidLoad()
        presenter.loadMore()
        presenter.loadMore()
        XCTAssertEqual(interactor.pageCalls.map(\.page), [1, 2])
        XCTAssertEqual(footer(), .loading)
        second.onNext(page(["b"], page: 2))
        XCTAssertEqual(footer(), MagazineFooter.none)
    }

    func test_anArticleThatComesAgainOnTheNextPageIsNotRepeated() throws {
        interactor.pageResult = { _, number in .just(number == 1 ? self.page(["a", "b"], hasMore: true) : self.page(["b", "c"], page: 2)) }
        presenter.viewDidLoad()
        presenter.loadMore()
        XCTAssertEqual(try sections().flatMap(\.rows).map(\.slug), ["a", "b", "c"])
    }

    func test_aFailedNextPageKeepsTheListAndOffersARetryThatLoadsThatPage() throws {
        interactor.pageResult = { _, number in number == 1 ? .just(self.page(["a"], hasMore: true)) : .error(LearnerAPIError.rateLimited) }
        presenter.viewDidLoad()
        presenter.loadMore()
        XCTAssertEqual(footer(), .failed(message: LearnerAPIError.rateLimited.errorDescription ?? ""))
        XCTAssertEqual(try sections().flatMap(\.rows).map(\.slug), ["a"])

        interactor.pageResult = { _, number in .just(number == 1 ? self.page(["a"], hasMore: true) : self.page(["b"], page: 2)) }
        presenter.retryLoadMore()
        XCTAssertEqual(interactor.pageCalls.map(\.page), [1, 2, 2])
        XCTAssertEqual(try sections().flatMap(\.rows).map(\.slug), ["a", "b"])
    }

    func test_pagesWithNothingToShowAreSkippedUntilSomethingShows() throws {
        // A page can hold only articles the app does not show (lottery sets).
        interactor.pageResult = { _, number in
            switch number {
            case 1: return .just(self.page([], hasMore: true))
            case 2: return .just(self.page([], hasMore: true, page: 2))
            default: return .just(self.page(["a"], page: 3))
            }
        }
        presenter.viewDidLoad()
        XCTAssertEqual(interactor.pageCalls.map(\.page), [1, 2, 3])
        XCTAssertEqual(try sections().flatMap(\.rows).map(\.slug), ["a"])
    }

    func test_ifAllPagesAreEmptyTheLearnerSeesTheEmptyState() {
        interactor.pageResult = { _, number in .just(self.page([], hasMore: number < 2, page: number)) }
        presenter.viewDidLoad()
        guard case .empty? = view.last?.content else { return XCTFail("expected empty, got \(String(describing: view.last))") }
    }

    // MARK: Refresh

    func test_refreshReplacesTheListAndEndsTheSpinner() throws {
        interactor.pageResult = { _, _ in .just(self.page(["a"])) }
        presenter.viewDidLoad()
        interactor.pageResult = { _, _ in .just(self.page(["new", "a"])) }
        presenter.refresh()
        XCTAssertEqual(try sections().flatMap(\.rows).map(\.slug), ["new", "a"])
        XCTAssertGreaterThanOrEqual(view.endedRefreshing, 1)
    }

    func test_aFailedRefreshKeepsWhatIsOnScreenAndSaysItFailed() throws {
        interactor.pageResult = { _, _ in .just(self.page(["a"])) }
        presenter.viewDidLoad()
        interactor.pageResult = { _, _ in .error(LearnerAPIError.offline) }
        presenter.refresh()
        XCTAssertEqual(try sections().flatMap(\.rows).map(\.slug), ["a"])
        XCTAssertEqual(footer(), .failed(message: LearnerAPIError.offline.errorDescription ?? ""))

        interactor.pageResult = { _, _ in .just(self.page(["fresh"])) }
        presenter.retryLoadMore()
        XCTAssertEqual(try sections().flatMap(\.rows).map(\.slug), ["fresh"], "Retrying a failed refresh refreshes, it does not load page 2")
    }

    // MARK: Opening

    func test_openingAnArticleHandsOverItsSlugAndItsDay() {
        interactor.pageResult = { _, _ in .just(self.page(["a"], days: ["2026-10-25"])) }
        presenter.viewDidLoad()
        presenter.open(slug: "a")
        XCTAssertEqual(wireframe.opened.first?.slug, "a")
        XCTAssertEqual(wireframe.opened.first?.day, MagazineDay(key: "2026-10-25"))
        presenter.open(slug: "not-in-the-list")
        XCTAssertEqual(wireframe.opened.count, 1)
    }
}
