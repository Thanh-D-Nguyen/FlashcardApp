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

    // MARK: View regression

    func test_willDisplayNearEndDefersLoadMoreSoDiffableSnapshotApplyNeverReenters() {
        final class ReentrantPresenter: MagazinePresenterInterface {
            weak var view: MagazineViewInterface?
            var loadMoreCount = 0
            private let sections: [MagazineSection]

            init(sections: [MagazineSection]) { self.sections = sections }
            func viewDidLoad() { view?.render(MagazineViewState(filter: .all, content: .list(sections: sections, footer: .none))) }
            func refresh() {}
            func select(_ filter: MagazineFilter) {}
            func loadMore() {
                loadMoreCount += 1
                view?.render(MagazineViewState(filter: .all, content: .list(sections: sections, footer: .loading)))
            }
            func retry() {}
            func retryLoadMore() {}
            func open(slug: String) {}
        }

        let rows = (0..<6).map { index in
            MagazineRow(slug: "slug-\(index)", kind: .weather, titleJapanese: "題 \(index)", titleVietnamese: "Bài \(index)", summary: nil, meta: "Weather", words: [], isToday: false)
        }
        let sections = [
            MagazineSection(title: "Today", style: .lead, rows: [rows[0]]),
            MagazineSection(title: "Earlier", style: .rows, rows: Array(rows.dropFirst()))
        ]
        let vc = MagazineViewController()
        let stubPresenter = ReentrantPresenter(sections: sections)
        vc.presenter = stubPresenter
        stubPresenter.view = vc

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UINavigationController(rootViewController: vc)
        window.makeKeyAndVisible()
        vc.view.layoutIfNeeded()

        // Must not call loadMore synchronously inside the initial diffable apply; it fires on the next main runloop turn.
        XCTAssertEqual(stubPresenter.loadMoreCount, 0)
        let exp = expectation(description: "deferred loadMore")
        DispatchQueue.main.async {
            if stubPresenter.loadMoreCount >= 1 { exp.fulfill() }
        }
        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(stubPresenter.loadMoreCount, 1)
    }

    func test_emptyAndFailedStatesKeepPinnedFilterBarTappableWhileRetryButtonWorks() throws {
        final class PassivePresenter: MagazinePresenterInterface {
            weak var view: MagazineViewInterface?
            var selectedFilters: [MagazineFilter] = []
            var retries = 0
            func viewDidLoad() {}
            func refresh() {}
            func select(_ filter: MagazineFilter) { selectedFilters.append(filter) }
            func loadMore() {}
            func retry() { retries += 1 }
            func retryLoadMore() {}
            func open(slug: String) {}
        }

        func findControl(in root: UIView, identifier: String) -> UIControl? {
            if let control = root as? UIControl, control.accessibilityIdentifier == identifier { return control }
            for child in root.subviews {
                if let match = findControl(in: child, identifier: identifier) { return match }
            }
            return nil
        }

        func findRetryButton(in root: UIView) -> UIButton? {
            if let stateView = root as? StateView {
                func button(in v: UIView) -> UIButton? {
                    if let b = v as? UIButton, !b.isHidden { return b }
                    return v.subviews.lazy.compactMap(button).first
                }
                return button(in: stateView)
            }
            return root.subviews.lazy.compactMap(findRetryButton).first
        }

        let vc = MagazineViewController()
        let stub = PassivePresenter()
        vc.presenter = stub
        stub.view = vc

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UINavigationController(rootViewController: vc)
        window.makeKeyAndVisible()
        vc.loadViewIfNeeded()

        vc.render(MagazineViewState(filter: .kind(.weather), content: .empty(title: "No articles yet", message: "Try another filter")))
        window.layoutIfNeeded()
        vc.view.layoutIfNeeded()

        let allFilterButton = try XCTUnwrap(findControl(in: vc.view, identifier: "magazine_filter_all"),
                                            "Filter bar must remain mounted when a filter is empty")
        let filterPointInRoot = allFilterButton.convert(CGPoint(x: allFilterButton.bounds.midX, y: allFilterButton.bounds.midY), to: vc.view)
        let hitInEmpty = try XCTUnwrap(vc.view.hitTest(filterPointInRoot, with: nil))
        XCTAssertTrue(hitInEmpty === allFilterButton || hitInEmpty.isDescendant(of: allFilterButton),
                      "StateView must not intercept touches over MagazineFilterBar in empty state")

        vc.render(MagazineViewState(filter: .kind(.weather), content: .failed(message: "Offline")))
        window.layoutIfNeeded()
        vc.view.layoutIfNeeded()

        let allFilterInError = try XCTUnwrap(findControl(in: vc.view, identifier: "magazine_filter_all"))
        let errorFilterPoint = allFilterInError.convert(CGPoint(x: allFilterInError.bounds.midX, y: allFilterInError.bounds.midY), to: vc.view)
        let hitFilterInError = try XCTUnwrap(vc.view.hitTest(errorFilterPoint, with: nil))
        XCTAssertTrue(hitFilterInError === allFilterInError || hitFilterInError.isDescendant(of: allFilterInError),
                      "Filter bar must remain tappable in failed state")

        let retryButton = try XCTUnwrap(findRetryButton(in: vc.view))
        let retryPoint = retryButton.convert(CGPoint(x: retryButton.bounds.midX, y: retryButton.bounds.midY), to: vc.view)
        let hitRetry = try XCTUnwrap(vc.view.hitTest(retryPoint, with: nil))
        XCTAssertTrue(hitRetry === retryButton || hitRetry.isDescendant(of: retryButton),
                      "StateView retry button must still receive touches in failed state")
    }

    func test_leadCellSizesEyebrowAndWordChipsWithoutCompressionAtAccessibilitySize() throws {
        let cell = MagazineLeadCell(frame: CGRect(x: 0, y: 0, width: 350, height: 400))
        cell.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraLarge
        let row = MagazineRow(
            slug: "bjt-1",
            kind: .weather,
            titleJapanese: "お忙しいところ恐れ入りますがご確認いただけますでしょうか",
            titleVietnamese: "Xin lỗi làm phiền lúc bận rộn, nhờ anh/chị xác nhận giúp",
            summary: "Cách mở lời lịch sự trong email công sở Nhật Bản.",
            meta: "Tiếng Nhật công sở · N3 · 25 thg 11",
            words: ["恐れ入りますが", "ご確認", "お忙しいところ", "いただけますでしょうか"],
            isToday: true
        )
        cell.configure(row)

        let fitted = cell.contentView.systemLayoutSizeFitting(
            CGSize(width: 350, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        cell.frame = CGRect(x: 0, y: 0, width: 350, height: fitted.height)
        cell.contentView.frame = cell.bounds
        cell.setNeedsLayout()
        cell.layoutIfNeeded()

        func allLabels(in view: UIView) -> [UILabel] {
            var result = (view as? UILabel).map { [$0] } ?? []
            for sub in view.subviews { result.append(contentsOf: allLabels(in: sub)) }
            return result
        }
        let eyebrow = try XCTUnwrap(allLabels(in: cell.contentView).first { ($0.text ?? "").contains("N3") })
        let neededEyebrowHeight = eyebrow.sizeThatFits(CGSize(width: eyebrow.bounds.width, height: .greatestFiniteMagnitude)).height
        XCTAssertGreaterThanOrEqual(eyebrow.bounds.height + 1, neededEyebrowHeight,
                                    "Lead eyebrow must get its full wrapped height on first pass without vertical truncation")
    }
}
