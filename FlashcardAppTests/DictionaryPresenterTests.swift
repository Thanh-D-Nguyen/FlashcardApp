import RxSwift
import XCTest
@testable import FlashcardApp

final class DictionaryPresenterTests: XCTestCase {
    func testNewQueryCancelsRequestAndIgnoresLateResult() {
        let interactor = SearchInteractorStub()
        let presenter = DictionaryPresenter(interactor: interactor, wireframe: SearchWireframeStub())
        let started = expectation(description: "first request")
        interactor.onSearch = { started.fulfill() }
        presenter.searchText("日本", withType: 0)
        wait(for: [started], timeout: 2)
        XCTAssertEqual(presenter.state.value, .loading)

        presenter.searchText("", withType: 0)
        XCTAssertTrue(interactor.cancelled)
        interactor.complete?(.success([]))
        XCTAssertEqual(presenter.state.value, .idle)
    }

    func testLatestQueryAndScopeReachInteractor() {
        let interactor = SearchInteractorStub()
        let presenter = DictionaryPresenter(interactor: interactor, wireframe: SearchWireframeStub())
        let started = expectation(description: "latest request")
        interactor.onSearch = { started.fulfill() }
        presenter.searchText("古い", withType: 0)
        presenter.searchText(" 日本 ", withType: 1)
        wait(for: [started], timeout: 2)
        XCTAssertEqual(interactor.calls.count, 1)
        XCTAssertEqual(interactor.calls.first?.0, "日本")
        XCTAssertEqual(interactor.calls.first?.1, .kanji)
        interactor.complete?(.success([]))
        XCTAssertEqual(presenter.state.value, .results([]))
    }

    func testFailureCanBeRetriedWithSameQuery() {
        let interactor = SearchInteractorStub()
        let presenter = DictionaryPresenter(interactor: interactor, wireframe: SearchWireframeStub())
        let first = expectation(description: "first request")
        interactor.onSearch = { first.fulfill() }
        presenter.searchText("日本", withType: 0)
        wait(for: [first], timeout: 2)
        interactor.complete?(.failure(AppError.networkRequestFailed("offline")))
        guard case .error = presenter.state.value else { return XCTFail("error must be visible") }
        let retry = expectation(description: "retry")
        interactor.onSearch = { retry.fulfill() }
        presenter.searchText("日本", withType: 0)
        wait(for: [retry], timeout: 2)
        interactor.complete?(.success([]))
        XCTAssertEqual(presenter.state.value, .results([]))
    }

    func testSelectionIsRoutedThroughWireframe() {
        let wireframe = SearchWireframeStub()
        let presenter = DictionaryPresenter(interactor: SearchInteractorStub(), wireframe: wireframe)
        let row = BJTSearchResultDTO(id: "uuid", kind: "kanji", title: "日", description: "ngày", reading: nil, jlptLevel: "N5")
        presenter.select(row)
        XCTAssertEqual(wireframe.selected, row)
    }
}

private final class SearchInteractorStub: DictionaryInteractorInterface {
    var calls: [(String, DictionarySearchType)] = []
    var onSearch: (() -> Void)?
    var complete: ((SingleEvent<[BJTSearchResultDTO]>) -> Void)?
    var cancelled = false

    func search(_ query: String, type: DictionarySearchType) -> Single<[BJTSearchResultDTO]> {
        calls.append((query, type))
        return Single.create { observer in
            self.complete = observer
            self.onSearch?()
            return Disposables.create { self.cancelled = true }
        }
    }
}

private final class SearchWireframeStub: DictionaryWireframeInterface {
    var selected: BJTSearchResultDTO?
    func showResult(_ result: BJTSearchResultDTO) { selected = result }
}
