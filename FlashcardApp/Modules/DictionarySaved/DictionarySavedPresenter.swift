import Foundation
import RxRelay
import RxSwift

struct SavedList: Equatable {
    var items: [DictionaryItem]
    /// Ids not resolved yet (the next pages).
    var pendingIDs: [String]
    var missing: Int
    var isLoadingMore = false
    var loadMoreFailed = false
}

enum SavedState: Equatable {
    case signedOut
    case loading
    case empty
    case loaded(SavedList)
    case error(String)
}

protocol DictionarySavedPresenterInterface: AnyObject {
    var state: BehaviorRelay<SavedState> { get }
    var kind: DictionaryItemKind { get }
    var notices: PublishRelay<String> { get }
    func viewWillAppear()
    func selectKind(_ index: Int)
    func retry()
    func loadMore()
    func select(_ item: DictionaryItem)
    func remove(_ item: DictionaryItem)
    func signIn()
    static var kinds: [DictionaryItemKind] { get }
}

final class DictionarySavedPresenter: DictionarySavedPresenterInterface {
    static let kinds: [DictionaryItemKind] = [.vocabulary, .kanji, .grammar]
    static let pageSize = 30

    let state = BehaviorRelay<SavedState>(value: .loading)
    let notices = PublishRelay<String>()
    private(set) var kind: DictionaryItemKind = .vocabulary

    private let interactor: DictionarySavedInteractorInterface
    private let wireframe: DictionarySavedWireframeInterface
    private var loadBag = DisposeBag()
    private var removeBag = DisposeBag()
    private var hasLoaded = false
    /// An entry was opened from the list: its bookmark may have changed, so the list is read again on return.
    private var needsRefresh = false
    /// Entries being removed (kind|id): a second swipe must not send a second toggle.
    private var removing = Set<String>()

    init(interactor: DictionarySavedInteractorInterface, wireframe: DictionarySavedWireframeInterface) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    func viewWillAppear() {
        // Back from an entry the learner may have removed a bookmark there: reload the list, quietly when it is already shown.
        // Otherwise leave it as it is, so a list scrolled to page three does not collapse every time the screen reappears.
        guard !hasLoaded || needsRefresh else { return }
        needsRefresh = false
        load(showSpinner: !hasLoaded)
    }

    func selectKind(_ index: Int) {
        guard Self.kinds.indices.contains(index), Self.kinds[index] != kind else { return }
        kind = Self.kinds[index]
        load(showSpinner: true)
    }

    func retry() { load(showSpinner: true) }

    func signIn() {
        wireframe.showSignIn { [weak self] in self?.load(showSpinner: true) }
    }

    private func load(showSpinner: Bool) {
        loadBag = DisposeBag()
        guard interactor.isSignedIn else { return state.accept(.signedOut) }
        if showSpinner { state.accept(.loading) }
        let kind = kind
        interactor.savedIDs(kind)
            .flatMap { [interactor] ids -> Single<(page: SavedPage, rest: [String])> in
                let first = Array(ids.prefix(Self.pageSize))
                return interactor.resolve(first, kind: kind).map { ($0, Array(ids.dropFirst(Self.pageSize))) }
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] result in
                guard let self, self.kind == kind else { return }
                self.hasLoaded = true
                if result.page.items.isEmpty, result.rest.isEmpty, result.page.missing == 0 {
                    self.state.accept(.empty)
                } else {
                    self.state.accept(.loaded(SavedList(items: result.page.items, pendingIDs: result.rest, missing: result.page.missing)))
                }
            }, onFailure: { [weak self] error in
                guard let self, self.kind == kind else { return }
                if case LearnerAPIError.signInRequired = error { return self.state.accept(.signedOut) }
                // Rows already shown stay when only a refresh failed (and no page is left spinning).
                if case .loaded(var shown) = self.state.value, !showSpinner {
                    if shown.isLoadingMore { shown.isLoadingMore = false; self.state.accept(.loaded(shown)) }
                    return
                }
                self.state.accept(.error(DictionaryPresenter.message(for: error)))
            })
            .disposed(by: loadBag)
    }

    func loadMore() {
        guard case .loaded(var list) = state.value, !list.pendingIDs.isEmpty, !list.isLoadingMore else { return }
        list.isLoadingMore = true
        list.loadMoreFailed = false
        state.accept(.loaded(list))
        let next = Array(list.pendingIDs.prefix(Self.pageSize))
        let kind = kind
        interactor.resolve(next, kind: kind)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] page in
                guard let self, self.kind == kind, case .loaded(var current) = self.state.value else { return }
                current.items += page.items
                current.pendingIDs = Array(current.pendingIDs.dropFirst(next.count))
                current.missing += page.missing
                current.isLoadingMore = false
                self.state.accept(.loaded(current))
            }, onFailure: { [weak self] _ in
                guard let self, case .loaded(var current) = self.state.value else { return }
                current.isLoadingMore = false
                current.loadMoreFailed = true
                self.state.accept(.loaded(current))
            })
            .disposed(by: loadBag)
    }

    func select(_ item: DictionaryItem) {
        needsRefresh = true
        wireframe.showEntry(item)
    }

    func remove(_ item: DictionaryItem) {
        let key = "\(item.kind.rawValue)|\(item.id)"
        guard removing.insert(key).inserted else { return }
        interactor.remove(item)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                guard let self else { return }
                self.removing.remove(key)
                guard case .loaded(var list) = self.state.value else { return }
                list.items.removeAll { $0.kind == item.kind && $0.id == item.id }
                if list.items.isEmpty, list.pendingIDs.isEmpty { self.state.accept(.empty) } else { self.state.accept(.loaded(list)) }
            }, onFailure: { [weak self] error in
                self?.removing.remove(key)
                self?.notices.accept(DictionaryPresenter.message(for: error))
            })
            .disposed(by: removeBag)
    }
}
