import Foundation
import RxRelay
import RxSwift

struct DictionaryResults: Equatable {
    let query: String
    var items: [DictionaryItem]
    /// How many rows the server has handed out so far; the next page starts here (rows of unknown kinds are not in `items`).
    var consumed: Int
    var hasMore: Bool
    var isLoadingMore = false
    var loadMoreFailed = false
    /// Kana for a query typed in romaji: offered, never applied on its own.
    var kanaCandidate: String?
}

enum DictionaryState: Equatable {
    /// Nothing typed: the screen shows the learner's history.
    case idle
    /// One Latin letter: the server needs two bytes.
    case tooShort
    case loading
    case results(DictionaryResults)
    case empty(String)
    case error(String)
}

struct DictionaryHome: Equatable {
    var queries: [String] = []
    var items: [DictionaryItem] = []
}

protocol DictionaryPresenterInterface: AnyObject {
    var state: BehaviorRelay<DictionaryState> { get }
    var home: BehaviorRelay<DictionaryHome> { get }
    /// Text the screen should put in its search field (from a camera scan, a selected word or the romaji offer).
    var requestedQuery: PublishRelay<String> { get }
    func searchText(_ text: String?, withType type: Int)
    func searchText(_ text: String?, scopeChangedTo type: Int)
    func commit(_ text: String?)
    func retry()
    func loadMore()
    func select(_ item: DictionaryItem)
    func beginSearch(_ text: String)
    func refreshHome()
    func deleteRecentQuery(_ query: String)
    func clearRecentQueries()
    func deleteViewedItem(_ item: DictionaryItem)
    func clearViewedItems()
    func showSaved()
    func showScanner()
    func showVoice()
    func showHandwriting()
}

final class DictionaryPresenter: DictionaryPresenterInterface {
    static let pageSize = DictionaryInteractor.pageSize
    /// The server is typo-tolerant, so a long tail is mostly noise; beyond this the learner should refine the query.
    static let maximumResults = 150

    let state = BehaviorRelay<DictionaryState>(value: .idle)
    let home = BehaviorRelay<DictionaryHome>(value: DictionaryHome())
    let requestedQuery = PublishRelay<String>()

    private struct Request {
        let validity: DictionaryQuery.Validity
        let type: DictionarySearchType
        let immediate: Bool
    }

    private let interactor: DictionaryInteractorInterface
    private let wireframe: DictionaryWireframeInterface
    private let requests = PublishRelay<Request>()
    private let bag = DisposeBag()
    private let pageRequest = SerialDisposable()
    private var lastKey: (query: String, type: DictionarySearchType)?
    private var lastRawText = ""

    init(interactor: DictionaryInteractorInterface, wireframe: DictionaryWireframeInterface, debounce: RxTimeInterval = .milliseconds(300)) {
        self.interactor = interactor
        self.wireframe = wireframe
        pageRequest.disposed(by: bag)
        requests
            .flatMapLatest { request -> Observable<DictionaryState> in
                switch request.validity {
                case .empty: return .just(.idle)
                case .tooShort: return .just(.tooShort)
                case .tooLong:
                    return .just(.error(NSLocalizedString("Enter a keyword between 2 and 200 bytes.", comment: "")))
                case .valid(let query):
                    // The delay lives inside the latest request, so typing on cancels the one waiting or running.
                    let wait: RxTimeInterval = request.immediate ? .milliseconds(0) : debounce
                    return Observable<Int>.timer(wait, scheduler: MainScheduler.instance)
                        .flatMap { _ in interactor.search(query.text, type: request.type, offset: 0).asObservable() }
                        .map { rows -> DictionaryState in Self.firstPage(rows, query: query) }
                        .catch { .just(.error(Self.message(for: $0))) }
                        .startWith(.loading)
                }
            }
            .observe(on: MainScheduler.instance)
            .bind(to: state)
            .disposed(by: bag)
    }

    // MARK: Searching

    func searchText(_ text: String?, withType type: Int) {
        guard let type = DictionarySearchType(rawValue: type) else { return }
        let raw = text ?? ""
        lastRawText = raw
        let validity = DictionaryQuery.validate(raw)
        if case .valid(let query) = validity {
            // The search controller repeats the same text when it gains focus; asking the server again would only flicker.
            if let lastKey, lastKey.query == query.text, lastKey.type == type, !isFailure(state.value) { return }
            lastKey = (query.text, type)
        } else {
            lastKey = nil
        }
        pageRequest.disposable = Disposables.create()
        requests.accept(Request(validity: validity, type: type, immediate: false))
    }

    /// The scope changed: same text, new category, no typing delay.
    func searchText(_ text: String?, scopeChangedTo type: Int) {
        guard let type = DictionarySearchType(rawValue: type) else { return }
        let validity = DictionaryQuery.validate(text ?? "")
        // Retry and paging need the key of the search that is now running, whichever path started it.
        if case .valid(let query) = validity { lastKey = (query.text, type) } else { lastKey = nil }
        lastRawText = text ?? ""
        pageRequest.disposable = Disposables.create()
        requests.accept(Request(validity: validity, type: type, immediate: true))
    }

    func retry() {
        guard let key = lastKey else { return }
        pageRequest.disposable = Disposables.create()
        requests.accept(Request(validity: .valid(DictionaryQuery(text: key.query)), type: key.type, immediate: true))
    }

    func loadMore() {
        guard case .results(var results) = state.value, results.hasMore, !results.isLoadingMore, let key = lastKey else { return }
        results.isLoadingMore = true
        results.loadMoreFailed = false
        state.accept(.results(results))
        pageRequest.disposable = interactor.search(results.query, type: key.type, offset: results.consumed)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] rows in self?.appendPage(rows) },
                       onFailure: { [weak self] _ in
                           guard case .results(var current)? = self?.state.value else { return }
                           current.isLoadingMore = false
                           current.loadMoreFailed = true
                           self?.state.accept(.results(current))
                       })
    }

    private func appendPage(_ rows: [BJTSearchResultDTO]) {
        guard case .results(var results) = state.value else { return }
        var known = Set(results.items.map { "\($0.kind.rawValue)|\($0.id)" })
        let fresh = rows.compactMap(DictionaryItem.init).filter { known.insert("\($0.kind.rawValue)|\($0.id)").inserted }
        results.items += fresh
        results.consumed += rows.count
        results.hasMore = rows.count >= Self.pageSize && results.consumed < Self.maximumResults
        results.isLoadingMore = false
        results.loadMoreFailed = false
        state.accept(.results(results))
    }

    private static func firstPage(_ rows: [BJTSearchResultDTO], query: DictionaryQuery) -> DictionaryState {
        let items = rows.compactMap(DictionaryItem.init)
        guard !items.isEmpty else { return .empty(query.text) }
        // Rows come back as the server ranked them; only an exact duplicate (same kind and id) is dropped.
        var known = Set<String>()
        let unique = items.filter { known.insert("\($0.kind.rawValue)|\($0.id)").inserted }
        return .results(DictionaryResults(query: query.text, items: unique, consumed: rows.count,
                                          hasMore: rows.count >= pageSize, kanaCandidate: query.kanaCandidate))
    }

    private func isFailure(_ state: DictionaryState) -> Bool {
        if case .error = state { return true }
        return false
    }

    // MARK: History and navigation

    func commit(_ text: String?) {
        interactor.recordQuery(text ?? "")
        refreshHome()
    }

    func select(_ item: DictionaryItem) {
        interactor.recordQuery(lastRawText)
        wireframe.showEntry(item)
    }

    func beginSearch(_ text: String) {
        let normalized: String
        if case .valid(let query) = DictionaryQuery.validate(text) { normalized = query.text } else { normalized = text.trimmingCharacters(in: .whitespacesAndNewlines) }
        requestedQuery.accept(normalized)
    }

    func refreshHome() {
        home.accept(DictionaryHome(queries: interactor.recentQueries, items: interactor.recentItems))
    }

    func deleteRecentQuery(_ query: String) { interactor.removeQuery(query); refreshHome() }
    func clearRecentQueries() { interactor.clearQueries(); refreshHome() }
    func deleteViewedItem(_ item: DictionaryItem) { interactor.removeItem(item); refreshHome() }
    func clearViewedItems() { interactor.clearItems(); refreshHome() }
    func showSaved() { wireframe.showSaved() }
    func showScanner() { wireframe.showScanner() }
    func showVoice() { wireframe.showVoice() }
    func showHandwriting() { wireframe.showHandwriting() }

    static func message(for error: Error) -> String {
        if let known = error as? LocalizedError, let text = known.errorDescription { return text }
        return error.localizedDescription
    }
}
