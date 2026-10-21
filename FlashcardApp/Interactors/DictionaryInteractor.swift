import RxSwift

protocol DictionaryInteractorInterface: AnyObject {
    func search(_ query: String, type: DictionarySearchType) -> Single<[BJTSearchResultDTO]>
}

final class DictionaryInteractor: DictionaryInteractorInterface {
    private let api: BJTSearchAPI
    init(api: BJTSearchAPI = .shared) { self.api = api }
    func search(_ query: String, type: DictionarySearchType) -> Single<[BJTSearchResultDTO]> {
        api.search(q: query, scope: type)
    }
}
