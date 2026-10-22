import UIKit
import RxSwift

final class DictionaryViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating, UISearchBarDelegate {
    var presenter: DictionaryPresenterInterface!
    private let tableView = UITableView()
    private let search = UISearchController(searchResultsController: nil)
    private let message = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private lazy var refreshItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(performSearch))
    private lazy var spinnerItem: UIBarButtonItem = {
        spinner.accessibilityLabel = "Đang tìm"
        return UIBarButtonItem(customView: spinner)
    }()
    private var rows: [BJTSearchResultDTO] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
    }

    func setupUI() {
        view.backgroundColor = Design.Color.background
        tableView.backgroundColor = .clear
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        tableView.accessibilityIdentifier = "dictionary_results"
        search.obscuresBackgroundDuringPresentation = false
        search.searchResultsUpdater = self
        search.searchBar.delegate = self
        search.searchBar.placeholder = "Nhập tiếng Nhật hoặc tiếng Việt"
        search.searchBar.accessibilityIdentifier = "dictionary_search"
        search.searchBar.scopeButtonTitles = DictionarySearchType.allCases.map(\.title)
        search.searchBar.showsScopeBar = true
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.rightBarButtonItem = refreshItem
        definesPresentationContext = true
        message.numberOfLines = 0
        message.textAlignment = .center
        message.font = .preferredFont(forTextStyle: .body)
        message.adjustsFontForContentSizeCategory = true
        tableView.backgroundView = message
    }

    func subscribe() {
        presenter.state.subscribe(onNext: { [weak self] in self?.render($0) }).disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    func updateSearchResults(for searchController: UISearchController) { performSearch() }
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) { performSearch() }

    @objc private func performSearch() {
        presenter.searchText(search.searchBar.text, withType: search.searchBar.selectedScopeButtonIndex)
    }

    private func render(_ state: DictionaryState) {
        spinner.stopAnimating()
        // One trailing item at a time: a glass pill holding only an idle spinner reads as an empty button.
        navigationItem.rightBarButtonItem = refreshItem
        rows = []
        switch state {
        case .idle: message.text = "Nhập từ khóa để tra cứu."
        case .loading:
            message.text = "Đang tìm…"
            spinner.startAnimating()
            navigationItem.rightBarButtonItem = spinnerItem
        case .results(let results):
            rows = results
            message.text = results.isEmpty ? "Không tìm thấy kết quả." : nil
        case .error(let reason): message.text = "\(reason)\nNhấn tải lại để thử lại."
        }
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "result") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "result")
        let row = rows[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = row.title
        content.secondaryText = [row.reading, row.description, row.jlptLevel].compactMap { $0 }.joined(separator: "\n")
        content.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.isAccessibilityElement = true
        cell.accessibilityTraits = .button
        cell.accessibilityLabel = [row.title, row.reading, row.description, row.jlptLevel]
            .compactMap { $0 }.joined(separator: ", ")
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.select(rows[indexPath.row])
    }
}
