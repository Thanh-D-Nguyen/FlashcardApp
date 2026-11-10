import RxSwift

/// Use cases of the dictionary search screen: the search itself and the device-local history shown on its home. History is
/// not the account's bookmark list; that is the entry screens' business.
protocol DictionaryInteractorInterface: AnyObject {
    func search(_ query: String, type: DictionarySearchType, offset: Int) -> Single<[BJTSearchResultDTO]>
    var recentQueries: [String] { get }
    var recentItems: [DictionaryItem] { get }
    func recordQuery(_ query: String)
    func removeQuery(_ query: String)
    func clearQueries()
    func removeItem(_ item: DictionaryItem)
    func clearItems()
}

final class DictionaryInteractor: DictionaryInteractorInterface {
    static let pageSize = 30

    private let api: BJTSearchAPI
    private let history: DictionaryHistoryStoreInterface

    init(api: BJTSearchAPI = .shared, history: DictionaryHistoryStoreInterface = UserDefaultsDictionaryHistoryStore.shared) {
        self.api = api
        self.history = history
    }

    func search(_ query: String, type: DictionarySearchType, offset: Int) -> Single<[BJTSearchResultDTO]> {
        api.search(q: query, scope: type, limit: Self.pageSize, offset: offset)
    }

    var recentQueries: [String] { history.recentQueries }
    var recentItems: [DictionaryItem] { history.recentItems }
    func recordQuery(_ query: String) { history.recordQuery(query) }
    func removeQuery(_ query: String) { history.removeQuery(query) }
    func clearQueries() { history.clearQueries() }
    func removeItem(_ item: DictionaryItem) { history.removeItem(item) }
    func clearItems() { history.clearItems() }
}
