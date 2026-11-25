import RxSwift
import UIKit

/// The dictionary's search screen. Idle, it is the learner's history; typing shows results of the chosen category.
/// All decisions (debounce, cancellation, paging, what counts as a query) belong to the presenter; this class only draws state.
final class DictionaryViewController: BaseVC, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating, UISearchBarDelegate {
    var presenter: DictionaryPresenterInterface!

    private enum Section: Equatable {
        case romaji(String)
        case results
        case queries
        case viewed
    }

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let search = UISearchController(searchResultsController: nil)
    private let stateView = StateView()
    private let busy = UIActivityIndicatorView(style: .medium)
    private let preferences: DictionaryPreferencesInterface = UserDefaultsDictionaryPreferences.shared

    private var sections: [Section] = []
    private var items: [DictionaryItem] = []
    private var footer: ResultsFooter = .none
    private var home = DictionaryHome()
    private var renderedResults: DictionaryResults?
    private var terms: [String] = []
    private var isDimmed = false

    private enum ResultsFooter: Equatable { case none, loading, failed, capped }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
        #if DEBUG
        applyDebugLaunchArguments()
        #endif
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        presenter.refreshHome()
    }

    // MARK: Setup

    private func setupUI() {
        view.backgroundColor = Design.Color.background
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag
        tableView.estimatedRowHeight = 88
        tableView.rowHeight = UITableView.automaticDimension
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 44
        tableView.separatorInset = UIEdgeInsets(top: 0, left: Design.Spacing.gutter, bottom: 0, right: Design.Spacing.gutter)
        tableView.register(DictionaryResultCell.self, forCellReuseIdentifier: DictionaryResultCell.identifier)
        tableView.register(DictionaryQueryCell.self, forCellReuseIdentifier: DictionaryQueryCell.identifier)
        tableView.register(DictionaryHistoryHeader.self, forHeaderFooterViewReuseIdentifier: DictionaryHistoryHeader.identifier)
        tableView.accessibilityIdentifier = "dictionary_results"
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        busy.hidesWhenStopped = true
        busy.accessibilityLabel = NSLocalizedString("Searching", comment: "")
        busy.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(busy)
        NSLayoutConstraint.activate([
            busy.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            busy.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Design.Spacing.xxl)
        ])

        search.obscuresBackgroundDuringPresentation = false
        search.searchResultsUpdater = self
        search.searchBar.delegate = self
        search.searchBar.placeholder = NSLocalizedString("Search in Japanese or Vietnamese", comment: "")
        search.searchBar.accessibilityIdentifier = "dictionary_search"
        search.searchBar.autocapitalizationType = .none
        search.searchBar.autocorrectionType = .no
        search.searchBar.spellCheckingType = .no
        search.searchBar.returnKeyType = .search
        search.searchBar.scopeButtonTitles = DictionarySearchType.allCases.map(\.title)
        search.searchBar.showsScopeBar = true
        // The search field's own trailing button is the microphone: voice input belongs where the text goes.
        search.searchBar.showsBookmarkButton = true
        let microphone = UIImage(systemName: "mic")
        // UIKit reads an image's accessibility label for a button that has no title (otherwise VoiceOver would say "mic").
        microphone?.accessibilityLabel = NSLocalizedString("Voice search", comment: "")
        search.searchBar.setImage(microphone, for: .bookmark, state: .normal)
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true

        let saved = UIBarButtonItem(image: UIImage(systemName: "bookmark"), style: .plain, target: self, action: #selector(openSaved))
        saved.accessibilityLabel = NSLocalizedString("Saved entries", comment: "")
        saved.accessibilityIdentifier = "dictionary_saved"
        let scan = UIBarButtonItem(image: UIImage(systemName: "text.viewfinder"), style: .plain, target: self, action: #selector(openScanner))
        scan.accessibilityLabel = NSLocalizedString("Scan text", comment: "")
        scan.accessibilityIdentifier = "dictionary_scan"
        let handwriting = UIBarButtonItem(image: UIImage(systemName: "pencil.and.scribble"), style: .plain, target: self, action: #selector(openHandwriting))
        handwriting.accessibilityLabel = NSLocalizedString("Handwriting search", comment: "")
        handwriting.accessibilityIdentifier = "dictionary_handwriting"
        navigationItem.rightBarButtonItems = [saved, scan, handwriting]
        tableView.backgroundView = stateView
    }

    private func subscribe() {
        presenter.state.observe(on: MainScheduler.instance).subscribe(onNext: { [weak self] in self?.render($0) }).disposed(by: disposeBag)
        presenter.home.observe(on: MainScheduler.instance).subscribe(onNext: { [weak self] home in
            guard let self else { return }
            self.home = home
            if self.presenter.state.value == .idle { self.render(.idle) }
        }).disposed(by: disposeBag)
        presenter.requestedQuery.observe(on: MainScheduler.instance).subscribe(onNext: { [weak self] text in
            guard let self else { return }
            self.search.searchBar.text = text
            self.search.searchBar.searchTextField.resignFirstResponder()
            self.presenter.searchText(text, scopeChangedTo: self.search.searchBar.selectedScopeButtonIndex)
            self.presenter.commit(text)
        }).disposed(by: disposeBag)
    }

    @objc private func openSaved() { presenter.showSaved() }
    @objc private func openScanner() { presenter.showScanner() }
    @objc private func openHandwriting() { presenter.showHandwriting() }

    // MARK: Search field

    func updateSearchResults(for searchController: UISearchController) {
        // While a Japanese IME is composing, the field holds unconverted letters (t, ta, tab…): wait for the committed text.
        guard searchController.searchBar.searchTextField.markedTextRange == nil else { return }
        presenter.searchText(searchController.searchBar.text, withType: searchController.searchBar.selectedScopeButtonIndex)
    }

    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        UISelectionFeedbackGenerator().selectionChanged()
        presenter.searchText(searchBar.text, scopeChangedTo: selectedScope)
    }

    func searchBarBookmarkButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        presenter.showVoice()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        presenter.commit(searchBar.text)
        searchBar.resignFirstResponder()
    }

    // MARK: Rendering

    private func render(_ state: DictionaryState) {
        busy.stopAnimating()
        setDimmed(false)
        // A footer belongs to one list of results: it must not outlive them (history, empty and error screens have none).
        if case .results = state {} else if case .loading = state, renderedResults != nil {} else { tableView.tableFooterView = nil }
        switch state {
        case .idle:
            renderedResults = nil
            let hasHistory = !home.queries.isEmpty || !home.items.isEmpty
            sections = (home.queries.isEmpty ? [] : [.queries]) + (home.items.isEmpty ? [] : [.viewed])
            items = []
            footer = .none
            if hasHistory {
                stateView.isHidden = true
            } else {
                stateView.isHidden = false
                stateView.configure(.call(symbol: "character.book.closed.ja", title: NSLocalizedString("Look up Japanese", comment: ""),
                                          message: NSLocalizedString("Search a word, kanji, grammar point or sentence in Japanese, Vietnamese or romaji.", comment: ""),
                                          actionTitle: NSLocalizedString("Scan text", comment: ""))) { [weak self] in self?.presenter.showScanner() }
            }
            tableView.reloadData()
        case .tooShort:
            showMessage(.empty(title: NSLocalizedString("Type a little more", comment: ""),
                               message: NSLocalizedString("Enter at least two letters, or one Japanese character.", comment: "")))
        case .loading:
            if renderedResults != nil, !items.isEmpty {
                // Rows of the previous query stay visible but dimmed and inert until the new answer arrives.
                setDimmed(true)
                busy.startAnimating()
            } else {
                sections = []
                items = []
                tableView.reloadData()
                stateView.isHidden = false
                stateView.configure(.loading(NSLocalizedString("Searching…", comment: "")))
            }
        case .results(let results):
            apply(results)
        case .empty(let query):
            renderedResults = nil
            let kana = DictionaryQuery(text: query).kanaCandidate
            if let kana {
                showMessage(.call(symbol: "magnifyingglass", title: String(format: NSLocalizedString("No results for “%@”", comment: ""), query),
                                  message: NSLocalizedString("If you typed Japanese in romaji, search the kana reading instead.", comment: ""),
                                  actionTitle: String(format: NSLocalizedString("Search “%@”", comment: ""), kana))) { [weak self] in self?.presenter.beginSearch(kana) }
            } else {
                showMessage(.empty(title: String(format: NSLocalizedString("No results for “%@”", comment: ""), query),
                                   message: NSLocalizedString("Check the spelling, or try another category.", comment: "")))
            }
        case .error(let message):
            showMessage(.error(message: message, retryTitle: NSLocalizedString("Try again", comment: ""))) { [weak self] in self?.presenter.retry() }
        }
    }

    private func showMessage(_ state: StateView.State, onAction: (() -> Void)? = nil) {
        renderedResults = nil
        sections = []
        items = []
        footer = .none
        tableView.reloadData()
        stateView.isHidden = false
        stateView.configure(state, onRetry: onAction)
    }

    private func apply(_ results: DictionaryResults) {
        stateView.isHidden = true
        let sameQuery = renderedResults?.query == results.query
        let newFooter: ResultsFooter = results.isLoadingMore ? .loading : (results.loadMoreFailed ? .failed
            : (!results.hasMore && results.consumed >= DictionaryPresenter.maximumResults ? .capped : .none))
        terms = results.query.split(separator: " ").map(String.init)
        var newSections: [Section] = []
        if let kana = results.kanaCandidate { newSections.append(.romaji(kana)) }
        newSections.append(.results)

        if let previous = renderedResults, sameQuery, results.items.count > previous.items.count,
           Array(results.items.prefix(previous.items.count)) == previous.items, sections == newSections {
            // Next page: add the rows below the ones on screen so the scroll position does not move.
            let added = (previous.items.count..<results.items.count).map { IndexPath(row: $0, section: sections.count - 1) }
            items = results.items
            footer = newFooter
            tableView.performBatchUpdates { tableView.insertRows(at: added, with: .none) }
        } else {
            sections = newSections
            items = results.items
            footer = newFooter
            tableView.reloadData()
            if !sameQuery { scrollToTop() }
        }
        reloadFooter()
        renderedResults = results
    }

    private func reloadFooter() {
        tableView.tableFooterView = footerView()
    }

    private func scrollToTop() {
        tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top), animated: false)
    }

    private func setDimmed(_ dimmed: Bool) {
        guard dimmed != isDimmed else { return }
        isDimmed = dimmed
        tableView.alpha = dimmed ? 0.4 : 1
        tableView.isUserInteractionEnabled = !dimmed
    }

    // MARK: Table

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .romaji: return 1
        case .results: return items.count
        case .queries: return home.queries.count
        case .viewed: return home.items.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .romaji(let kana):
            let cell = tableView.dequeueReusableCell(withIdentifier: DictionaryQueryCell.identifier, for: indexPath) as! DictionaryQueryCell
            cell.configure(query: String(format: NSLocalizedString("Search “%@” (romaji)", comment: "Offer to search the kana for a romaji query"), kana),
                           symbol: "character.textbox", hint: NSLocalizedString("Searches the kana reading of what you typed.", comment: ""))
            cell.accessibilityIdentifier = "dictionary_romaji"
            return cell
        case .results:
            let cell = tableView.dequeueReusableCell(withIdentifier: DictionaryResultCell.identifier, for: indexPath) as! DictionaryResultCell
            cell.configure(items[indexPath.row], terms: terms, showReading: preferences.showReadings)
            cell.accessibilityIdentifier = "dictionary_row_\(indexPath.row + 1)"
            return cell
        case .queries:
            let cell = tableView.dequeueReusableCell(withIdentifier: DictionaryQueryCell.identifier, for: indexPath) as! DictionaryQueryCell
            cell.configure(query: home.queries[indexPath.row], hint: NSLocalizedString("Searches again.", comment: ""))
            cell.accessibilityIdentifier = "dictionary_recent_\(indexPath.row + 1)"
            return cell
        case .viewed:
            let cell = tableView.dequeueReusableCell(withIdentifier: DictionaryResultCell.identifier, for: indexPath) as! DictionaryResultCell
            cell.configure(home.items[indexPath.row], terms: [], showReading: preferences.showReadings)
            cell.accessibilityIdentifier = "dictionary_viewed_\(indexPath.row + 1)"
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section] {
        case .romaji(let kana): presenter.beginSearch(kana)
        case .results: presenter.select(items[indexPath.row])
        case .queries: presenter.beginSearch(home.queries[indexPath.row])
        case .viewed: presenter.select(home.items[indexPath.row])
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Near the end of the list: ask for the next page.
        if case .results = sections[indexPath.section], indexPath.row >= items.count - 5 { presenter.loadMore() }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title: String, clear: () -> Void, identifier: String
        switch sections[section] {
        case .queries:
            title = NSLocalizedString("Recent searches", comment: "")
            clear = { [weak self] in self?.presenter.clearRecentQueries() }
            identifier = "dictionary_clear_queries"
        case .viewed:
            title = NSLocalizedString("Recently viewed", comment: "")
            clear = { [weak self] in self?.presenter.clearViewedItems() }
            identifier = "dictionary_clear_viewed"
        default:
            return nil
        }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: DictionaryHistoryHeader.identifier) as! DictionaryHistoryHeader
        header.configure(title: title, clearTitle: NSLocalizedString("Clear", comment: ""), identifier: identifier, clear: clear)
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch sections[section] {
        case .queries, .viewed: return UITableView.automaticDimension
        default: return 0.01
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let remove: () -> Void
        switch sections[indexPath.section] {
        case .queries:
            let query = home.queries[indexPath.row]
            remove = { [weak self] in self?.presenter.deleteRecentQuery(query) }
        case .viewed:
            let item = home.items[indexPath.row]
            remove = { [weak self] in self?.presenter.deleteViewedItem(item) }
        default:
            return nil
        }
        let delete = UIContextualAction(style: .destructive, title: NSLocalizedString("Delete", comment: "")) { _, _, done in
            remove()
            done(true)
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let item: DictionaryItem
        switch sections[indexPath.section] {
        case .results: item = items[indexPath.row]
        case .viewed: item = home.items[indexPath.row]
        default: return nil
        }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let copy = UIAction(title: NSLocalizedString("Copy", comment: ""), image: UIImage(systemName: "doc.on.doc")) { _ in UIPasteboard.general.string = item.summary }
            let share = UIAction(title: NSLocalizedString("Share", comment: ""), image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                self?.present(UIActivityViewController(activityItems: [item.summary], applicationActivities: nil), animated: true)
            }
            return UIMenu(children: [copy, share])
        }
    }

    // MARK: Footer

    private func footerView() -> UIView? {
        let width = max(tableView.bounds.width, view.bounds.width)
        func sized(_ content: UIView) -> UIView {
            let holder = UIView()
            content.translatesAutoresizingMaskIntoConstraints = false
            holder.addSubview(content)
            NSLayoutConstraint.activate([
                content.topAnchor.constraint(equalTo: holder.topAnchor, constant: Design.Spacing.m),
                content.bottomAnchor.constraint(equalTo: holder.bottomAnchor, constant: -Design.Spacing.m),
                content.leadingAnchor.constraint(equalTo: holder.leadingAnchor, constant: Design.Spacing.gutter),
                content.trailingAnchor.constraint(equalTo: holder.trailingAnchor, constant: -Design.Spacing.gutter)
            ])
            let height = holder.systemLayoutSizeFitting(
                CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
            holder.frame = CGRect(x: 0, y: 0, width: width, height: max(height, Design.HitTarget.minimum + Design.Spacing.l))
            return holder
        }
        switch footer {
        case .none:
            return nil
        case .loading:
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            spinner.frame = CGRect(x: 0, y: 0, width: width, height: 56)
            return spinner
        case .failed:
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.plain()
            configuration.title = NSLocalizedString("Couldn’t load more. Tap to retry.", comment: "")
            configuration.titleAlignment = .center
            configuration.titleLineBreakMode = .byWordWrapping
            configuration.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.m, leading: Design.Spacing.gutter, bottom: Design.Spacing.m, trailing: Design.Spacing.gutter)
            configuration.baseForegroundColor = Design.Color.accent
            button.configuration = configuration
            let fitHeight = button.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
            button.frame = CGRect(x: 0, y: 0, width: width, height: max(fitHeight, Design.HitTarget.minimum + Design.Spacing.m))
            button.addAction(UIAction { [weak self] _ in self?.presenter.loadMore() }, for: .touchUpInside)
            button.accessibilityIdentifier = "dictionary_load_more_retry"
            return button
        case .capped:
            let note = UILabel()
            note.apply(.metadata)
            note.textAlignment = .center
            note.text = String(format: NSLocalizedString("Showing the first %lld results. Refine your search to narrow them.", comment: ""), DictionaryPresenter.maximumResults)
            return sized(note)
        }
    }

    #if DEBUG
    /// `-DictionaryQuery <text>` and `-DictionaryScope <0…3>` fill the search in at launch, for screenshots and UI tests
    /// (a Japanese keyboard cannot be driven by the simulator tooling).
    private func applyDebugLaunchArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-DictionaryOpenScanner") { DispatchQueue.main.async { [weak self] in self?.presenter.showScanner() } }
        if arguments.contains("-DictionaryOpenHandwriting") { DispatchQueue.main.async { [weak self] in self?.presenter.showHandwriting() } }
        if arguments.contains("-DictionaryOpenVoice") { DispatchQueue.main.async { [weak self] in self?.presenter.showVoice() } }
        if let index = arguments.firstIndex(of: "-DictionaryScope"), index + 1 < arguments.count, let scope = Int(arguments[index + 1]) {
            search.searchBar.selectedScopeButtonIndex = scope
        }
        if let index = arguments.firstIndex(of: "-DictionaryOpen"), index + 1 < arguments.count {
            // `<kind>:<backend id>`, e.g. vocabulary:9adc769d-…; a sentence carries its text: sentence:<id>|<japanese>|<reading>|<meaning>
            let parts = arguments[index + 1].split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2, let kind = DictionaryItemKind(rawValue: parts[0]) {
                let fields = parts[1].split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                let item = DictionaryItem(kind: kind, id: fields[0], title: fields.count > 1 ? fields[1] : "",
                                          reading: fields.count > 2 ? fields[2] : nil, meaning: fields.count > 3 ? fields[3] : nil)
                DispatchQueue.main.async { [weak self] in self?.presenter.select(item) }
            }
        }
        if let index = arguments.firstIndex(of: "-DictionaryQuery"), index + 1 < arguments.count {
            let text = arguments[index + 1]
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.search.searchBar.text = text
                self.presenter.searchText(text, scopeChangedTo: self.search.searchBar.selectedScopeButtonIndex)
            }
        }
    }
    #endif
}
