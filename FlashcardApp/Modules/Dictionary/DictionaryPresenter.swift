import Foundation
import RxRelay
import RxSwift

enum DictionaryState: Equatable {
    case idle, loading
    case results([BJTSearchResultDTO])
    case error(String)
}

protocol DictionaryPresenterInterface: AnyObject {
    var state: BehaviorRelay<DictionaryState> { get }
    func searchText(_ text: String?, withType type: Int)
    func select(_ row: BJTSearchResultDTO)
}

final class DictionaryPresenter: DictionaryPresenterInterface {
    private let wireframe: DictionaryWireframeInterface
    private let queries = PublishRelay<(String, DictionarySearchType)>()
    private let bag = DisposeBag()
    let state = BehaviorRelay<DictionaryState>(value: .idle)

    init(interactor: DictionaryInteractorInterface, wireframe: DictionaryWireframeInterface) {
        self.wireframe = wireframe
        queries
            .flatMapLatest { query, type -> Observable<DictionaryState> in
                guard !query.isEmpty else { return .just(.idle) }
                // Delay inside the latest query so changes cancel stale requests immediately.
                return Observable<Int>.timer(.milliseconds(300), scheduler: MainScheduler.instance)
                    .flatMap { _ in interactor.search(query, type: type).asObservable() }
                    .map(DictionaryState.results)
                    .catch { .just(.error($0.localizedDescription)) }
                    .startWith(.loading)
            }
            .observe(on: MainScheduler.instance)
            .bind(to: state)
            .disposed(by: bag)
    }

    func searchText(_ text: String?, withType type: Int) {
        guard let type = DictionarySearchType(rawValue: type) else { return }
        queries.accept(((text ?? "").trimmingCharacters(in: .whitespacesAndNewlines), type))
    }

    func select(_ row: BJTSearchResultDTO) { wireframe.showResult(row) }
}
