import UIKit

/// The lessons of one level, one table section per week. Draws the presenter's state; every decision lives there.
final class LessonListViewController: BaseVC {
    var presenter: LessonListPresenterInterface!

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let stateView = StateView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.onChange = { [weak self] in self?.render() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        presenter.viewDidLoad()
        render()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter.cancelLoading()
    }

    private func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "lesson")
        tableView.estimatedRowHeight = 88
        tableView.rowHeight = UITableView.automaticDimension
        tableView.allowsSelection = false
        tableView.accessibilityIdentifier = "lesson_list"
        tableView.backgroundView = stateView
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        stateView.accessibilityIdentifier = "lesson_status"
    }

    private func render() {
        switch presenter.state {
        case .idle, .loading:
            stateView.configure(.loading(NSLocalizedString("Loading…", comment: "")), onRetry: nil)
        case .failed(let message):
            stateView.configure(.error(message: message, retryTitle: NSLocalizedString("Retry", comment: "")),
                                onRetry: { [weak self] in self?.presenter.retry() })
        case .empty:
            stateView.configure(.empty(title: NSLocalizedString("No lessons in this level yet.", comment: ""), message: nil), onRetry: nil)
        case .loaded:
            break
        }
        stateView.isHidden = presenter.state == .loaded
        tableView.reloadData()
    }

    /// "25 min · 5 activities", only the parts the server sent.
    static func metadata(for row: LessonRow, language: AppLanguage = .current) -> String {
        var parts: [String] = []
        switch row.unitType {
        case "review": parts.append(NSLocalizedString("Weekly review", comment: "Lesson kind"))
        case "checkpoint": parts.append(NSLocalizedString("Checkpoint", comment: "Lesson kind"))
        default: break
        }
        if let minutes = row.minutes {
            parts.append(String(format: NSLocalizedString("%lld min", comment: ""), minutes))
        }
        if let count = row.activityCount {
            parts.append(String(format: NSLocalizedString("%lld activities", comment: "Number of practice activities in a lesson"), count))
        }
        return parts.joined(separator: " · ")
    }
}

extension LessonListViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { presenter.sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { presenter.sections[section].rows.count }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        String(format: NSLocalizedString("Week %lld", comment: "Lesson list section"), presenter.sections[section].weekNumber)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "lesson", for: indexPath)
        let row = presenter.sections[indexPath.section].rows[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = row.title
        content.textProperties.apply(.title)
        content.secondaryText = [row.summary, Self.metadata(for: row)].filter { !$0.isEmpty }.joined(separator: "\n")
        content.secondaryTextProperties.apply(.metadata)
        content.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = content
        cell.accessibilityIdentifier = "lesson_row_\(row.slug)"
        return cell
    }
}
