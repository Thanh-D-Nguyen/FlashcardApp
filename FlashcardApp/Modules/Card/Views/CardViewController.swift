//
//  CardViewController.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//  
//

import UIKit

/// The Cards tab: the learner's decks. Tapping a deck studies it; creating, editing and deleting are one
/// step away (bar button, swipe, context menu). The bars are the system's own Liquid Glass.
final class CardViewController: BaseViewController, CardViewInterface {
    var presenter: CardPresenterInterface!

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let stateView = StateView()
    private let searchController = UISearchController(searchResultsController: nil)
    private var rows: [DeckRowModel] = []
    private var content: CardLibraryContent = .empty

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
        tableView.separatorColor = Design.Color.separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: Design.Spacing.gutter, bottom: 0, right: 0)
        tableView.keyboardDismissMode = .onDrag
        tableView.register(DeckLibraryCell.self, forCellReuseIdentifier: DeckLibraryCell.reuseIdentifier)
        tableView.accessibilityIdentifier = "deck_library"
        tableView.backgroundView = stateView
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
        content = state.content
        switch state.content {
        case .decks(let models):
            rows = models
            stateView.isHidden = true
        case .empty:
            rows = []
            stateView.configure(.call(symbol: "rectangle.stack.badge.plus",
                                      title: NSLocalizedString("No decks yet", comment: ""),
                                      message: NSLocalizedString("Make a deck of your own words and study it offline, anywhere.", comment: ""),
                                      actionTitle: NSLocalizedString("Create your first deck", comment: "")),
                                onRetry: { [weak self] in self?.presenter.createDeck() })
            stateView.isHidden = false
        case .noMatches(let query):
            rows = []
            stateView.configure(.empty(title: NSLocalizedString("No matching decks", comment: ""),
                                       message: String(format: NSLocalizedString("Nothing matches “%@”.", comment: ""), query)))
            stateView.isHidden = false
        }
        stateView.accessibilityIdentifier = "deck_library_state"
        sortItem.menu = makeSortMenu()
        sortItem.isEnabled = state.deckCount > 1
        updateSubtitle(deckCount: state.deckCount)
        tableView.reloadData()
        // Attached once in setupUI (changing the bar's height after the list was laid out left the first row under it);
        // with nothing to search it is simply inactive.
        searchController.searchBar.isUserInteractionEnabled = state.deckCount > 0
        searchController.searchBar.alpha = state.deckCount > 0 ? 1 : 0.4
    }

    private var lastDeckCount = 0

    private func updateSubtitle(deckCount: Int? = nil) {
        if let deckCount { lastDeckCount = deckCount }
        // Static count line under the large title; dropped at accessibility sizes where the system would truncate it.
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        navigationItem.subtitle = (large || lastDeckCount == 0) ? nil
            : String.localizedStringWithFormat(NSLocalizedString("%lld decks", comment: "Number of decks in the library"), lastDeckCount)
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
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DeckLibraryCell.reuseIdentifier, for: indexPath)
        (cell as? DeckLibraryCell)?.configure(with: rows[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.studyDeck(id: rows[indexPath.row].id)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let id = rows[indexPath.row].id
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
        let id = rows[indexPath.row].id
        return UIContextMenuConfiguration(identifier: id as NSString, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [
                UIAction(title: NSLocalizedString("Study", comment: ""), image: UIImage(systemName: "rectangle.on.rectangle")) { _ in self?.presenter.studyDeck(id: id) },
                UIAction(title: NSLocalizedString("Edit", comment: ""), image: UIImage(systemName: "pencil")) { _ in self?.presenter.editDeck(id: id) },
                UIAction(title: NSLocalizedString("Delete", comment: ""), image: UIImage(systemName: "trash"), attributes: .destructive) { _ in self?.presenter.requestDelete(id: id) }
            ])
        }
    }
}
