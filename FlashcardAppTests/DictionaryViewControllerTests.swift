import RxRelay
import RxSwift
import UIKit
import XCTest
@testable import FlashcardApp

/// What the search screen draws for each presenter state: the paging footer (spinner, retry, cap note) must follow the results
/// it belongs to and never outlive them.
final class DictionaryViewControllerTests: XCTestCase {
    private var presenter: FakeSearchPresenter!
    private var controller: DictionaryViewController!
    private var table: UITableView!

    override func setUp() {
        super.setUp()
        presenter = FakeSearchPresenter()
        controller = DictionaryViewController()
        controller.presenter = presenter
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.layoutIfNeeded()
        table = controller.view.subviews.compactMap { $0 as? UITableView }.first
    }

    private func items(_ count: Int) -> [DictionaryItem] {
        (0..<count).map { DictionaryItem(kind: .vocabulary, id: "id\($0)", title: "語\($0)", reading: nil, meaning: "nghĩa") }
    }

    private func results(_ count: Int, consumed: Int? = nil, hasMore: Bool = true, loading: Bool = false, failed: Bool = false) -> DictionaryState {
        .results(DictionaryResults(query: "語", items: items(count), consumed: consumed ?? count, hasMore: hasMore, isLoadingMore: loading, loadMoreFailed: failed))
    }

    func testTheNextPageSpinnerAndTheRetryButtonAppearEvenThoughTheRowsDidNotChange() {
        presenter.state.accept(results(30))
        XCTAssertNil(table.tableFooterView)
        presenter.state.accept(results(30, loading: true))
        XCTAssertTrue(table.tableFooterView is UIActivityIndicatorView, "Loading the next page shows a spinner")
        presenter.state.accept(results(30, failed: true))
        XCTAssertEqual((table.tableFooterView as? UIButton)?.accessibilityIdentifier, "dictionary_load_more_retry", "A failed page offers a retry, not silence")
        presenter.state.accept(results(60))
        XCTAssertNil(table.tableFooterView, "The page arrived")
    }

    func testTheCapNoteBelongsToItsResultsAndDisappearsWithThem() {
        presenter.state.accept(results(DictionaryPresenter.maximumResults, consumed: DictionaryPresenter.maximumResults, hasMore: false))
        XCTAssertNotNil(table.tableFooterView, "The learner is told the list was cut")
        presenter.state.accept(.idle)
        XCTAssertNil(table.tableFooterView, "…and the note must not follow them to the history")
        presenter.state.accept(results(DictionaryPresenter.maximumResults, consumed: DictionaryPresenter.maximumResults, hasMore: false))
        presenter.state.accept(.empty("zzzz"))
        XCTAssertNil(table.tableFooterView)
        presenter.state.accept(.error("x"))
        XCTAssertNil(table.tableFooterView)
    }
}

private final class FakeSearchPresenter: DictionaryPresenterInterface {
    let state = BehaviorRelay<DictionaryState>(value: .idle)
    let home = BehaviorRelay<DictionaryHome>(value: DictionaryHome())
    let requestedQuery = PublishRelay<String>()
    func searchText(_ text: String?, withType type: Int) {}
    func searchText(_ text: String?, scopeChangedTo type: Int) {}
    func commit(_ text: String?) {}
    func retry() {}
    func loadMore() {}
    func select(_ item: DictionaryItem) {}
    func beginSearch(_ text: String) {}
    func refreshHome() {}
    func deleteRecentQuery(_ query: String) {}
    func clearRecentQueries() {}
    func deleteViewedItem(_ item: DictionaryItem) {}
    func clearViewedItems() {}
    func showSaved() {}
    func showScanner() {}
    func showVoice() {}
    func showHandwriting() {}
}
