//
//  CardViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import UIKit

/// The Cards tab. Four sections like the website: cards to review, the learner's decks, public decks and recent ones. The
/// learner's decks work offline and are the default; the others need the account. Tapping a deck on the device studies it;
/// creating, editing and deleting are one step away (bar button, swipe, context menu). The bars are the system's own Liquid Glass.
final class CardViewController: BaseViewController, CardViewInterface {
    var presenter: CardPresenterInterface!

    private enum Item {
        case local(DeckRowModel)
        case remote(RemoteDeckRowModel)
        case review(due: Int, capped: Bool)
    }

    private struct Section {
        var title: String?
        var items: [Item]
    }

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let stateView = StateView()
    private var dueCount: Int?
    private let refreshControl = UIRefreshControl()
    private let searchController = UISearchController(searchResultsController: nil)
    private var sections: [Section] = [Section(title: nil, items: [])]
    private var content: CardLibraryContent = .empty
    private var scope: CardLibraryScope = .mine

    private lazy var addItem: UIBarButtonItem = {
        let item = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in self?.presenter.createDeck() })
        item.accessibilityLabel = NSLocalizedString("Create Deck", comment: "")
        item.accessibilityIdentifier = "create_deck_button"
        return item
    }()

    private lazy var sortItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "arrow.up.arrow.down"), menu: makeSortMenu())
        item.accessibilityLabel = NSLocalizedString("Sort decks", comment: "")
        item.accessibilityIdentifier = "deck_sort_button"
        return item
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        presenter.viewWillAppear()
    }

    func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItems = [addItem, sortItem]

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = NSLocalizedString("Search decks and cards", comment: "")
        searchController.searchBar.accessibilityIdentifier = "deck_search"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 96
        tableView.sectionHeaderTopPadding = 0
        tableView.separatorColor = Design.Color.separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: Design.Spacing.gutter, bottom: 0, right: 0)
        tableView.keyboardDismissMode = .onDrag
        tableView.register(DeckLibraryCell.self, forCellReuseIdentifier: DeckLibraryCell.reuseIdentifier)
        tableView.register(ReviewHeroCell.self, forCellReuseIdentifier: ReviewHeroCell.reuseIdentifier)
        tableView.register(CardSectionHeaderView.self, forHeaderFooterViewReuseIdentifier: CardSectionHeaderView.reuseIdentifier)
        tableView.register(CardScopeHeaderView.self, forHeaderFooterViewReuseIdentifier: CardScopeHeaderView.reuseIdentifier)
        tableView.accessibilityIdentifier = "deck_library"
        tableView.backgroundView = stateView
        refreshControl.addAction(UIAction { [weak self] _ in self?.presenter.refresh() }, for: .valueChanged)
        tableView.refreshControl = refreshControl
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        stateView.accessibilityIdentifier = "deck_library_state"
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: CardViewController, _) in
            controller.updateSubtitle()
        }
    }

    func subscribe() {}

    // MARK: CardViewInterface

    func render(_ state: CardLibraryState) {
        if scope != state.scope { needsScrollToTop = true }
        scope = state.scope
        content = state.content
        sections = [Section(title: nil, items: [])]
        var placeholder: StateView.State?
        var action: (() -> Void)?
        // With decks of the account to list, the empty message would sit behind their rows: the section header says enough.
        var hasAccountRows = false
        if state.scope == .mine, case .decks? = state.accountDecks { hasAccountRows = true }
        switch state.content {
        case .decks(let models):
            sections[0].items = models.map(Item.local)
        case .empty where hasAccountRows:
            break
        case .noMatches where hasAccountRows:
            break
        case .empty:
            placeholder = .call(symbol: "rectangle.stack.badge.plus",
                                title: NSLocalizedString("No decks yet", comment: ""),
                                message: NSLocalizedString("Make a deck of your own words and study it offline, anywhere.", comment: ""),
                                actionTitle: NSLocalizedString("Create your first deck", comment: ""))
            action = { [weak self] in self?.presenter.createDeck() }
        case .noMatches(let query):
            placeholder = .empty(title: NSLocalizedString("No matching decks", comment: ""),
                                 message: String(format: NSLocalizedString("Nothing matches “%@”.", comment: ""), query))
        case .review(let entry):
            (placeholder, action) = reviewPlaceholder(for: entry, into: &sections)
        case .remote(let list):
            (placeholder, action) = remotePlaceholder(for: list, scope: state.scope, into: &sections)
        }
        if state.scope == .mine, let account = state.accountDecks {
            switch account {
            case .decks(let rows):
                sections.append(Section(title: NSLocalizedString("On your account", comment: "Header of the decks that live on the account, not on this device"),
                                        items: rows.map(Item.remote)))
            case .failed(let message):
                sections.append(Section(title: NSLocalizedString("On your account", comment: ""), items: []))
                accountFailure = message
            default: break
            }
        }
        if case .failed? = state.accountDecks {} else { accountFailure = nil }

        if let placeholder {
            stateView.configure(placeholder, onRetry: action)
            stateView.isHidden = false
        } else {
            stateView.isHidden = true
        }
        stateView.accessibilityIdentifier = "deck_library_state"
        dueCount = state.reviewDueCount
        updateBarItems(for: state)
        updateSubtitle(for: state)
        tableView.reloadData()
        var isLoading = false
        if case .loading? = placeholder { isLoading = true }
        if !isLoading {
            refreshControl.endRefreshing()
            // A new section starts at its top, whatever the previous one was scrolled to; once its rows are there.
            if needsScrollToTop {
                needsScrollToTop = false
                tableView.layoutIfNeeded()
                tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top), animated: false)
            }
        }
        // Attached once in setupUI (changing the bar's height after the list was laid out left the first row under it);
        // with nothing to search it is simply inactive.
        let searchable = state.scope != .review && (state.scope == .mine ? state.deckCount > 0 : true)
        searchController.searchBar.isUserInteractionEnabled = searchable
        searchController.searchBar.alpha = searchable ? 1 : 0.4
    }

    private var accountFailure: String?
    private var needsScrollToTop = false

    private func reviewPlaceholder(for entry: ReviewEntryModel, into sections: inout [Section]) -> (StateView.State?, (() -> Void)?) {
        switch entry.phase {
        case .loading:
            return (.loading(NSLocalizedString("Loading your cards…", comment: "")), nil)
        case .signInRequired:
            return (signInPlaceholder(NSLocalizedString("Sign in to review your cards", comment: ""),
                                      message: NSLocalizedString("Your review schedule lives on your account, so it follows you between the app and the website.", comment: "")),
                    { [weak self] in self?.presenter.signIn() })
        case .failed(let message):
            return (.error(message: message, retryTitle: NSLocalizedString("Try again", comment: "")), { [weak self] in self?.presenter.refresh() })
        case .ready(let due, let capped):
            if due == 0 {
                return (.empty(title: NSLocalizedString("All caught up", comment: ""),
                               message: NSLocalizedString("No cards are due right now. Come back later, or study one of your decks.", comment: "")), nil)
            }
            sections[0].items = [.review(due: due, capped: capped)]
            return (nil, nil)
        }
    }

    private func remotePlaceholder(for list: RemoteListContent, scope: CardLibraryScope,
                                   into sections: inout [Section]) -> (StateView.State?, (() -> Void)?) {
        switch list {
        case .loading:
            return (.loading(NSLocalizedString("Loading decks…", comment: "")), nil)
        case .signInRequired:
            return (signInPlaceholder(NSLocalizedString("Sign in to see these decks", comment: ""),
                                      message: NSLocalizedString("Public and recent decks come from your account and the website.", comment: "")),
                    { [weak self] in self?.presenter.signIn() })
        case .failed(let message):
            return (.error(message: message, retryTitle: NSLocalizedString("Try again", comment: "")), { [weak self] in self?.presenter.refresh() })
        case .empty:
            let message = scope == .publicDecks
                ? NSLocalizedString("Decks that people share will appear here.", comment: "")
                : NSLocalizedString("Decks you create or change will appear here.", comment: "")
            let title = scope == .publicDecks ? NSLocalizedString("No public decks yet", comment: "") : NSLocalizedString("Nothing recent yet", comment: "")
            return (.empty(title: title, message: message), nil)
        case .noMatches(let query):
            return (.empty(title: NSLocalizedString("No matching decks", comment: ""),
                           message: String(format: NSLocalizedString("Nothing matches “%@”.", comment: ""), query)), nil)
        case .decks(let rows):
            sections[0].items = rows.map(Item.remote)
            return (nil, nil)
        }
    }

    private func signInPlaceholder(_ title: String, message: String) -> StateView.State {
        .call(symbol: "person.crop.circle", title: title, message: message, actionTitle: NSLocalizedString("Sign In", comment: ""))
    }

    private func updateBarItems(for state: CardLibraryState) {
        // Sorting orders the decks on the device only.
        navigationItem.rightBarButtonItems = state.scope == .mine ? [addItem, sortItem] : [addItem]
        sortItem.menu = makeSortMenu()
        sortItem.isEnabled = state.deckCount > 1
    }

    private var subtitleText: String?

    private func updateSubtitle(for state: CardLibraryState) {
        switch state.content {
        case .decks(let rows): subtitleText = String.localizedStringWithFormat(NSLocalizedString("%lld decks", comment: "Number of decks in the library"), rows.count)
        case .remote(.decks(let rows)): subtitleText = String.localizedStringWithFormat(NSLocalizedString("%lld decks", comment: ""), rows.count)
        case .review(let entry):
            if case .ready(let due, let capped) = entry.phase, due > 0 {
                subtitleText = String.localizedStringWithFormat(NSLocalizedString("%lld cards due", comment: "Cards waiting for review"), due)
                    + (capped ? "+" : "")
            } else { subtitleText = nil }
        default: subtitleText = nil
        }
        updateSubtitle()
    }

    private func updateSubtitle() {
        // Static count line under the large title; dropped at accessibility sizes where the system would truncate it.
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        navigationItem.subtitle = large ? nil : subtitleText
    }

    private func makeSortMenu() -> UIMenu {
        UIMenu(title: NSLocalizedString("Sort by", comment: ""), options: .singleSelection, children: CardLibrarySort.allCases.map { option in
            UIAction(title: option.title, state: option == presenter.sort ? .on : .off) { [weak self] _ in self?.presenter.setSort(option) }
        })
    }
}

extension CardViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        presenter.updateQuery(searchController.searchBar.text)
    }
}

extension CardViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].items.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section].items[indexPath.row] {
        case .local(let row):
            let cell = tableView.dequeueReusableCell(withIdentifier: DeckLibraryCell.reuseIdentifier, for: indexPath)
            (cell as? DeckLibraryCell)?.configure(with: row)
            return cell
        case .remote(let row):
            let cell = tableView.dequeueReusableCell(withIdentifier: DeckLibraryCell.reuseIdentifier, for: indexPath)
            (cell as? DeckLibraryCell)?.configure(with: row)
            return cell
        case .review(let due, let capped):
            let cell = tableView.dequeueReusableCell(withIdentifier: ReviewHeroCell.reuseIdentifier, for: indexPath)
            (cell as? ReviewHeroCell)?.configure(due: due, capped: capped) { [weak self] in self?.presenter.startReview() }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: CardScopeHeaderView.reuseIdentifier) as? CardScopeHeaderView
            header?.configure(selected: scope, dueCount: dueCount) { [weak self] scope in self?.presenter.selectScope(scope) }
            return header
        }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: CardSectionHeaderView.reuseIdentifier) as? CardSectionHeaderView
        header?.configure(title: sections[section].title ?? "", failure: accountFailure, onRetry: { [weak self] in self?.presenter.refresh() })
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? CardScopeBar.height : UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? CardScopeBar.height : 44
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section].items[indexPath.row] {
        case .local(let row): presenter.studyDeck(id: row.id)
        case .remote(let row): presenter.openAccountDeck(id: row.id)
        case .review: break
        }
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        if case .review = sections[indexPath.section].items[indexPath.row] { return false }
        return true
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard case .local(let row) = sections[indexPath.section].items[indexPath.row] else { return nil }
        let id = row.id
        let delete = UIContextualAction(style: .destructive, title: NSLocalizedString("Delete", comment: "")) { [weak self] _, _, done in
            self?.presenter.requestDelete(id: id)
            done(true)
        }
        delete.image = UIImage(systemName: "trash")
        let edit = UIContextualAction(style: .normal, title: NSLocalizedString("Edit", comment: "")) { [weak self] _, _, done in
            self?.presenter.editDeck(id: id)
            done(true)
        }
        edit.image = UIImage(systemName: "pencil")
        edit.backgroundColor = Design.Color.hero
        return UISwipeActionsConfiguration(actions: [delete, edit])
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard case .local(let row) = sections[indexPath.section].items[indexPath.row] else { return nil }
        let id = row.id
        return UIContextMenuConfiguration(identifier: id as NSString, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [
                UIAction(title: NSLocalizedString("Study", comment: ""), image: UIImage(systemName: "rectangle.on.rectangle")) { _ in self?.presenter.studyDeck(id: id) },
                UIAction(title: NSLocalizedString("Edit", comment: ""), image: UIImage(systemName: "pencil")) { _ in self?.presenter.editDeck(id: id) },
                UIAction(title: NSLocalizedString("Delete", comment: ""), image: UIImage(systemName: "trash"), attributes: .destructive) { _ in self?.presenter.requestDelete(id: id) }
            ])
        }
    }
}
