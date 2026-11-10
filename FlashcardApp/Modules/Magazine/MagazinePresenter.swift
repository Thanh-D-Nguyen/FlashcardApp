import Foundation
import RxSwift

// MARK: View state

enum MagazineFilter: Equatable, CaseIterable {
    case all
    case kind(MagazineKind)

    static let allCases: [MagazineFilter] = [.all] + MagazineKind.allCases.map(MagazineFilter.kind)

    var kind: MagazineKind? {
        if case .kind(let kind) = self { return kind }
        return nil
    }

    var title: String {
        switch self {
        case .all: return NSLocalizedString("All", comment: "Filter that shows every kind")
        case .kind(let kind): return kind.title
        }
    }
}

struct MagazineRow: Equatable, Hashable {
    let slug: String
    let kind: MagazineKind
    let titleJapanese: String
    let titleVietnamese: String
    let summary: String?
    /// "Vocabulary · N4 · 26 Oct".
    let meta: String
    let words: [String]
    let isToday: Bool
}

struct MagazineSection: Equatable {
    enum Style: Equatable {
        /// The newest article, drawn large.
        case lead
        case rows
    }

    let title: String
    let style: Style
    let rows: [MagazineRow]
}

enum MagazineFooter: Equatable, Hashable {
    case none
    case loading
    case failed(message: String)
}

enum MagazineContent: Equatable {
    case loading(message: String)
    case empty(title: String, message: String)
    case failed(message: String)
    case list(sections: [MagazineSection], footer: MagazineFooter)
}

struct MagazineViewState: Equatable {
    let filter: MagazineFilter
    let content: MagazineContent
}

protocol MagazineViewInterface: AnyObject {
    func render(_ state: MagazineViewState)
    /// Ends the pull-to-refresh spinner.
    func endRefreshing()
}

protocol MagazinePresenterInterface: AnyObject {
    func viewDidLoad()
    func select(_ filter: MagazineFilter)
    /// Pull to refresh: reloads the first page and keeps what is on screen if that fails.
    func refresh()
    func retry()
    /// The list is near its end.
    func loadMore()
    func retryLoadMore()
    func open(slug: String)
}

// MARK: Presenter

/// The article list of one filter: a first page, then pages on demand. Changing the filter cancels what is loading, and a
/// reply for an earlier filter or request is dropped, so a slow reply can never show the wrong list.
final class MagazinePresenter {
    private enum Phase: Equatable {
        case loading, loaded, failed(String)
    }

    private let interactor: MagazineInteractorInterface
    private let wireframe: MagazineWireframeInterface
    private let language: () -> AppLanguage
    private let now: () -> Date
    private let scheduler: ImmediateSchedulerType
    weak var view: MagazineViewInterface?

    private var filter: MagazineFilter = .all
    private var phase: Phase = .loading
    private var items: [MagazineSummary] = []
    private var nextPage = 1
    private var hasMore = false
    private var loadingMore = false
    private var moreFailure: String?
    /// What the retry row under the list repeats: the next page, or the refresh that failed.
    private var footerRetry: FooterRetry = .nextPage
    private enum FooterRetry { case nextPage, refresh }
    private var generation = 0
    private let loading = SerialDisposable()
    private let loadingNext = SerialDisposable()

    init(interactor: MagazineInteractorInterface, wireframe: MagazineWireframeInterface,
         language: @escaping () -> AppLanguage = { AppLanguage.current }, now: @escaping () -> Date = Date.init,
         scheduler: ImmediateSchedulerType = MainScheduler.instance) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.language = language
        self.now = now
        self.scheduler = scheduler
    }

    deinit {
        loading.dispose()
        loadingNext.dispose()
    }

    private static func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    private func publish() {
        view?.render(MagazineViewState(filter: filter, content: content()))
    }

    // MARK: State building

    private func content() -> MagazineContent {
        switch phase {
        case .loading:
            return .loading(message: Self.text("Loading articles…"))
        case .failed(let message):
            return .failed(message: message)
        case .loaded:
            guard !items.isEmpty else {
                if loadingMore { return .loading(message: Self.text("Loading articles…")) }
                if let failure = moreFailure { return .failed(message: failure) }
                return .empty(title: Self.text("No articles yet"), message: Self.text("There are no articles in this category yet. Please check back later."))
            }
            let footer: MagazineFooter = loadingMore ? .loading : moreFailure.map { .failed(message: $0) } ?? .none
            return .list(sections: sections(), footer: footer)
        }
    }

    /// The newest article leads. When it is today's, the other articles of today follow under "Also today".
    private func sections() -> [MagazineSection] {
        let language = language()
        let today = MagazineDay.today(now: now())
        let rows = items.map { row($0, today: today, language: language) }
        guard let lead = rows.first else { return [] }
        var sections = [MagazineSection(title: lead.isToday ? Self.text("Today") : Self.text("Latest"), style: .lead, rows: [lead])]
        var rest = Array(rows.dropFirst())
        if lead.isToday {
            let sameDay = Array(rest.prefix { $0.isToday })
            if !sameDay.isEmpty {
                sections.append(MagazineSection(title: Self.text("Also today"), style: .rows, rows: sameDay))
                rest.removeFirst(sameDay.count)
            }
        }
        if !rest.isEmpty { sections.append(MagazineSection(title: Self.text("Earlier"), style: .rows, rows: rest)) }
        return sections
    }

    private func row(_ item: MagazineSummary, today: MagazineDay, language: AppLanguage) -> MagazineRow {
        var meta = [item.kind.title]
        if let level = item.level { meta.append(level) }
        if let day = item.day { meta.append(day.formatted(.short, locale: language.locale)) }
        return MagazineRow(slug: item.slug, kind: item.kind, titleJapanese: item.titleJapanese, titleVietnamese: item.titleVietnamese,
                           summary: item.summary, meta: meta.joined(separator: " · "), words: item.words, isToday: item.day == today)
    }

    // MARK: Loading

    private func loadFirstPage(keepingItems: Bool) {
        generation += 1
        let token = generation
        loadingNext.disposable = Disposables.create()
        loadingMore = false
        moreFailure = nil
        if !keepingItems {
            phase = .loading
            items = []
            nextPage = 1
            hasMore = false
            publish()
        }
        loading.disposable = interactor.loadPage(kind: filter.kind, page: 1)
            .observe(on: scheduler)
            .subscribe(onSuccess: { [weak self] page in
                guard let self, token == self.generation else { return }
                self.items = page.items
                self.nextPage = 2
                self.hasMore = page.hasMore
                self.phase = .loaded
                self.view?.endRefreshing()
                self.publish()
                self.fillIfNothingToShow()
            }, onFailure: { [weak self] error in
                guard let self, token == self.generation else { return }
                self.view?.endRefreshing()
                if keepingItems && !self.items.isEmpty {
                    // The list on screen is still good: say the refresh failed without replacing it.
                    self.moreFailure = Self.message(for: error)
                    self.footerRetry = .refresh
                } else {
                    self.phase = .failed(Self.message(for: error))
                }
                self.publish()
            })
    }

    /// A page can hold only articles the app does not show (for example lottery sets), so keep going until something shows or the pages end.
    private func fillIfNothingToShow() {
        if items.isEmpty, hasMore { loadMore() }
    }

    static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

extension MagazinePresenter: MagazinePresenterInterface {
    func viewDidLoad() { loadFirstPage(keepingItems: false) }

    func select(_ newFilter: MagazineFilter) {
        guard newFilter != filter else { return }
        filter = newFilter
        loadFirstPage(keepingItems: false)
    }

    func refresh() { loadFirstPage(keepingItems: !items.isEmpty) }

    func retry() { loadFirstPage(keepingItems: false) }

    func loadMore() {
        guard phase == .loaded, hasMore, !loadingMore else { return }
        loadingMore = true
        moreFailure = nil
        publish()
        let token = generation
        let page = nextPage
        loadingNext.disposable = interactor.loadPage(kind: filter.kind, page: page)
            .observe(on: scheduler)
            .subscribe(onSuccess: { [weak self] result in
                guard let self, token == self.generation else { return }
                let known = Set(self.items.map(\.slug))
                self.items += result.items.filter { !known.contains($0.slug) }
                self.nextPage = page + 1
                self.hasMore = result.hasMore
                self.loadingMore = false
                self.publish()
                self.fillIfNothingToShow()
            }, onFailure: { [weak self] error in
                guard let self, token == self.generation else { return }
                self.loadingMore = false
                self.moreFailure = Self.message(for: error)
                self.footerRetry = .nextPage
                self.publish()
            })
    }

    func retryLoadMore() {
        switch footerRetry {
        case .nextPage: loadMore()
        case .refresh: loadFirstPage(keepingItems: true)
        }
    }

    func open(slug: String) {
        guard let item = items.first(where: { $0.slug == slug }) else { return }
        wireframe.showArticle(slug: slug, day: item.day)
    }
}
