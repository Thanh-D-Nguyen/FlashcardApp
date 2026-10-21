import UIKit

final class HomeViewController: BaseViewController {
    var presenter: HomePresenterInterface!
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override var preferredStatusBarStyle: UIStatusBarStyle { .default }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
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

    func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
        tableView.accessibilityIdentifier = presenter.isContent ? "level_content" : "home_levels"
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    func subscribe() {
        presenter.onChange = { [weak self] in self?.render() }
    }

    private func render() {
        if presenter.isContent {
            let actions = HomeContentKind.allCases.map { kind in
                UIAction(title: kind.title, state: kind == presenter.kind ? .on : .off) { [weak self] _ in
                    self?.presenter.selectKind(kind)
                }
            }
            let menu = UIMenu(title: "Nội dung", children: actions)
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: presenter.kind.title, menu: menu)
            navigationItem.rightBarButtonItem?.accessibilityLabel = "Loại nội dung: \(presenter.kind.title)"
            navigationItem.rightBarButtonItem?.accessibilityIdentifier = "level_content_kind"
        }
        tableView.reloadData()
    }

    private var statusText: String? {
        if presenter.isLoading { return "Đang tải…" }
        if let message = presenter.errorMessage { return "\(message)\nChạm để thử lại." }
        if presenter.canLoadMore { return "Tải thêm 30 mục" }
        if presenter.rows.isEmpty { return "Chưa có nội dung." }
        return nil
    }
}

extension HomeViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? presenter.rows.count : (statusText == nil ? 0 : 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "home_row")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "home_row")
        var content = cell.defaultContentConfiguration()
        content.textProperties.font = .preferredFont(forTextStyle: .body)
        content.textProperties.adjustsFontForContentSizeCategory = true
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
        content.secondaryTextProperties.adjustsFontForContentSizeCategory = true
        content.secondaryTextProperties.numberOfLines = 0
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.accessibilityTraits = .staticText
        if indexPath.section == 0 {
            let row = presenter.rows[indexPath.row]
            content.text = row.title
            content.secondaryText = row.subtitle
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityIdentifier = "home_row_\(row.id)"
            cell.accessibilityTraits = .button
            cell.selectionStyle = .default
        } else {
            content.text = statusText
            let actionable = !presenter.isLoading && (presenter.errorMessage != nil || presenter.canLoadMore)
            cell.selectionStyle = actionable ? .default : .none
            cell.accessibilityIdentifier = "home_status"
            cell.accessibilityTraits = actionable ? .button : .staticText
            if presenter.isLoading {
                let spinner = UIActivityIndicatorView(style: .medium)
                spinner.startAnimating()
                cell.accessoryView = spinner
            }
        }
        cell.contentConfiguration = content
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            presenter.selectRow(at: indexPath.row)
        } else if presenter.errorMessage != nil {
            presenter.retry()
        } else {
            presenter.loadMore()
        }
    }
}
