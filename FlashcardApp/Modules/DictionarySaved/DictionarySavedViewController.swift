import RxSwift
import UIKit

/// The account's saved words, kanji and grammar points (the same list as on the website), one category at a time.
final class DictionarySavedViewController: BaseVC, UITableViewDataSource, UITableViewDelegate {
    var presenter: DictionarySavedPresenterInterface!

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let stateView = StateView()
    private let kinds = UISegmentedControl(items: [])
    private let toast = NoticeToastView()
    private var list = SavedList(items: [], pendingIDs: [], missing: 0)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Design.Color.background
        title = NSLocalizedString("Saved entries", comment: "")
        navigationItem.largeTitleDisplayMode = .never
        for (index, kind) in DictionarySavedPresenter.kinds.enumerated() {
            kinds.insertSegment(withTitle: kind.searchType.title, at: index, animated: false)
        }
        kinds.selectedSegmentIndex = 0
        kinds.accessibilityIdentifier = "saved_kinds"
        kinds.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.presenter.selectKind(self.kinds.selectedSegmentIndex)
        }, for: .valueChanged)
        navigationItem.titleView = kinds

        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = 88
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorInset = UIEdgeInsets(top: 0, left: Design.Spacing.gutter, bottom: 0, right: Design.Spacing.gutter)
        tableView.register(DictionaryResultCell.self, forCellReuseIdentifier: DictionaryResultCell.identifier)
        tableView.accessibilityIdentifier = "saved_list"
        tableView.backgroundView = stateView
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        presenter.state.observe(on: MainScheduler.instance).subscribe(onNext: { [weak self] in self?.render($0) }).disposed(by: disposeBag)
        presenter.notices.observe(on: MainScheduler.instance).subscribe(onNext: { [weak self] in
            guard let self else { return }
            self.toast.show($0, in: self.view, duration: 3.6)
        }).disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        presenter.viewWillAppear()
    }

    private func render(_ state: SavedState) {
        switch state {
        case .signedOut:
            list = SavedList(items: [], pendingIDs: [], missing: 0)
            tableView.reloadData()
            stateView.isHidden = false
            stateView.configure(.call(symbol: "bookmark", title: NSLocalizedString("Sign in to see your saved entries", comment: ""),
                                      message: NSLocalizedString("Saved entries belong to your account, so they are the same here and on the website.", comment: ""),
                                      actionTitle: NSLocalizedString("Sign in", comment: ""))) { [weak self] in self?.presenter.signIn() }
        case .loading:
            list = SavedList(items: [], pendingIDs: [], missing: 0)
            tableView.reloadData()
            stateView.isHidden = false
            stateView.configure(.loading(NSLocalizedString("Loading…", comment: "")))
        case .empty:
            list = SavedList(items: [], pendingIDs: [], missing: 0)
            tableView.reloadData()
            stateView.isHidden = false
            stateView.configure(.empty(title: NSLocalizedString("Nothing saved yet", comment: ""),
                                       message: NSLocalizedString("Tap Save on an entry to keep it here.", comment: "")))
        case .error(let message):
            list = SavedList(items: [], pendingIDs: [], missing: 0)
            tableView.reloadData()
            stateView.isHidden = false
            stateView.configure(.error(message: message, retryTitle: NSLocalizedString("Try again", comment: ""))) { [weak self] in self?.presenter.retry() }
        case .loaded(let loaded):
            stateView.isHidden = true
            let previous = list
            list = loaded
            if loaded.items.count > previous.items.count, Array(loaded.items.prefix(previous.items.count)) == previous.items, !previous.items.isEmpty {
                let added = (previous.items.count..<loaded.items.count).map { IndexPath(row: $0, section: 0) }
                tableView.performBatchUpdates { tableView.insertRows(at: added, with: .none) }
            } else {
                tableView.reloadData()
            }
            tableView.tableFooterView = footer(for: loaded)
        }
    }

    private func footer(for list: SavedList) -> UIView? {
        if list.isLoadingMore {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            spinner.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 56)
            return spinner
        }
        if list.loadMoreFailed {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.plain()
            configuration.title = NSLocalizedString("Couldn’t load more. Tap to retry.", comment: "")
            button.configuration = configuration
            button.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 56)
            button.addAction(UIAction { [weak self] _ in self?.presenter.loadMore() }, for: .touchUpInside)
            return button
        }
        guard list.missing > 0 else { return nil }
        let note = UILabel()
        note.apply(.metadata)
        note.textAlignment = .center
        note.text = String.localizedStringWithFormat(NSLocalizedString("%lld saved entries are no longer in the dictionary.", comment: ""), list.missing)
        note.frame = CGRect(x: Design.Spacing.gutter, y: 0, width: tableView.bounds.width - 2 * Design.Spacing.gutter, height: 64)
        let holder = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 64))
        holder.addSubview(note)
        return holder
    }

    // MARK: Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { list.items.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DictionaryResultCell.identifier, for: indexPath) as! DictionaryResultCell
        cell.configure(list.items[indexPath.row], terms: [], showReading: UserDefaultsDictionaryPreferences.shared.showReadings)
        cell.accessibilityIdentifier = "saved_row_\(indexPath.row + 1)"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.select(list.items[indexPath.row])
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row >= list.items.count - 3 { presenter.loadMore() }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = list.items[indexPath.row]
        let remove = UIContextualAction(style: .destructive, title: NSLocalizedString("Remove", comment: "")) { [weak self] _, _, done in
            self?.presenter.remove(item)
            done(true)
        }
        remove.image = UIImage(systemName: "bookmark.slash")
        return UISwipeActionsConfiguration(actions: [remove])
    }
}
