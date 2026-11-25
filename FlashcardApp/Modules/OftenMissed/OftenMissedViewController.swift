import UIKit

/// The cards the learner keeps getting wrong. Draws the presenter's state; every decision lives there.
final class OftenMissedViewController: BaseVC {
    var presenter: OftenMissedPresenterInterface!

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let stateView = StateView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Design.Color.background
        title = NSLocalizedString("Often missed", comment: "Screen of the cards the learner keeps getting wrong")
        navigationItem.largeTitleDisplayMode = .never
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "missed")
        tableView.estimatedRowHeight = 88
        tableView.rowHeight = UITableView.automaticDimension
        tableView.accessibilityIdentifier = "often_missed_list"
        tableView.backgroundView = stateView
        stateView.accessibilityIdentifier = "often_missed_status"
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        presenter.onChange = { [weak self] in self?.render() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        presenter.viewWillAppear()
        render()
    }

    private var rows: [OftenMissedRow] {
        if case .rows(let rows) = presenter.state { return rows }
        return []
    }

    private func render() {
        switch presenter.state {
        case .idle:
            stateView.configure(.loading(NSLocalizedString("Loading…", comment: "")), onRetry: nil)
        case .failed(let message):
            stateView.configure(.error(message: message, retryTitle: NSLocalizedString("Retry", comment: "")), onRetry: { [weak self] in self?.presenter.retry() })
        case .empty:
            stateView.configure(.empty(title: NSLocalizedString("No often-missed cards yet", comment: ""),
                                       message: NSLocalizedString("Cards you get wrong more than once after the first answer will appear here.", comment: "")), onRetry: nil)
        case .rows:
            break
        }
        stateView.isHidden = !rows.isEmpty
        tableView.reloadData()
    }
}

extension OftenMissedViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "missed", for: indexPath)
        let row = rows[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = row.reading.isEmpty ? row.front : "\(row.front) (\(row.reading))"
        content.textProperties.apply(.title)
        content.secondaryText = [row.back, row.detail, row.deckName].filter { !$0.isEmpty }.joined(separator: "\n")
        content.secondaryTextProperties.apply(.metadata)
        content.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = content
        let selected = UIView()
        selected.backgroundColor = Design.Color.highlight
        cell.selectedBackgroundView = selected
        cell.accessoryType = .disclosureIndicator
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = [content.text, row.back, row.detail, row.deckName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ". ")
        cell.accessibilityHint = String(format: NSLocalizedString("Opens the deck “%@” to study", comment: "Accessibility hint of an often-missed card"), row.deckName)
        cell.accessibilityTraits = .button
        cell.accessibilityIdentifier = "often_missed_row_\(indexPath.row)"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.selectRow(at: indexPath.row)
    }
}
