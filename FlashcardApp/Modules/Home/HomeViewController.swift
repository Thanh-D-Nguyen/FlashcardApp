import UIKit

final class HomeViewController: BaseViewController {
    var presenter: HomePresenterInterface!
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let stateView = StateView()
    private let kindControl = UISegmentedControl(items: HomeContentKind.allCases.map(\.title))
    private let totalLabel = UILabel()
    private let introLabel = UILabel()
    private let headerView = UIView()

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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeHeaderToFit()
    }

    func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = presenter.isContent ? .never : .always
        // Table runs edge to edge so content scrolls under the system bars (scroll-edge effect);
        // the table's automatic inset adjustment keeps rows clear of them.
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.separatorColor = Design.Color.separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: Design.Spacing.gutter, bottom: 0, right: 0)
        tableView.register(LevelCell.self, forCellReuseIdentifier: LevelCell.reuseIdentifier)
        tableView.register(ContentRowCell.self, forCellReuseIdentifier: ContentRowCell.reuseIdentifier)
        tableView.accessibilityIdentifier = presenter.isContent ? "level_content" : "home_levels"
        tableView.backgroundView = stateView
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        buildHeader()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: HomeViewController, _) in
            controller.render()
        }
    }

    func subscribe() {
        presenter.onChange = { [weak self] in self?.render() }
    }

    // MARK: Header

    /// Levels: one line telling what a level contains. Level content: the kind switch and its total.
    private func buildHeader() {
        headerView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: Design.Spacing.s, leading: Design.Spacing.gutter, bottom: Design.Spacing.l, trailing: Design.Spacing.gutter)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: headerView.layoutMarginsGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: headerView.layoutMarginsGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.trailingAnchor)
        ])
        if presenter.isContent {
            kindControl.selectedSegmentIndex = presenter.kind.rawValue
            kindControl.accessibilityIdentifier = "level_content_kind"
            kindControl.addAction(UIAction { [weak self] _ in
                guard let self, let kind = HomeContentKind(rawValue: self.kindControl.selectedSegmentIndex) else { return }
                self.presenter.selectKind(kind)
            }, for: .valueChanged)
            totalLabel.apply(.metadata)
            [kindControl, totalLabel].forEach(stack.addArrangedSubview)
        } else {
            introLabel.apply(.reading)
            introLabel.text = "Chọn cấp độ để xem từ vựng, kanji và ngữ pháp."
            stack.addArrangedSubview(introLabel)
        }
        tableView.tableHeaderView = headerView
    }

    private func sizeHeaderToFit() {
        let width = tableView.bounds.width
        guard width > 0 else { return }
        let height = headerView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        guard headerView.frame.size != CGSize(width: width, height: height) else { return }
        headerView.frame.size = CGSize(width: width, height: height)
        tableView.tableHeaderView = headerView
    }

    // MARK: Rendering

    private func render() {
        if presenter.isContent { renderKindChooser() }
        stateView.configure(screenState ?? .empty(title: "", message: nil), onRetry: { [weak self] in self?.presenter.retry() })
        stateView.isHidden = screenState == nil
        stateView.accessibilityIdentifier = "home_status"
        tableView.reloadData()
        // The header's content (kind chooser, total) can change without a view layout pass.
        view.setNeedsLayout()
    }

    /// Segmented control at regular sizes; the system menu from the bar once text no longer fits three segments.
    private func renderKindChooser() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        kindControl.isHidden = large
        kindControl.selectedSegmentIndex = presenter.kind.rawValue
        if let total = presenter.kindTotal, total > 0 {
            totalLabel.text = "\(total.formatted(.number.locale(Locale(identifier: "vi_VN")))) \(presenter.kind.title.lowercased())"
        } else {
            totalLabel.text = nil
        }
        totalLabel.isHidden = totalLabel.text == nil
        guard large else {
            navigationItem.rightBarButtonItem = nil
            return
        }
        let actions = HomeContentKind.allCases.map { kind in
            UIAction(title: kind.title, state: kind == presenter.kind ? .on : .off) { [weak self] _ in
                self?.presenter.selectKind(kind)
            }
        }
        let item = UIBarButtonItem(title: presenter.kind.title, menu: UIMenu(title: "Nội dung", children: actions))
        item.accessibilityLabel = "Loại nội dung: \(presenter.kind.title)"
        item.accessibilityIdentifier = "level_content_kind"
        navigationItem.rightBarButtonItem = item
    }

    /// Full-area state while there is nothing to list yet.
    private var screenState: StateView.State? {
        guard presenter.rows.isEmpty else { return nil }
        if presenter.isLoading { return .loading("Đang tải…") }
        if let message = presenter.errorMessage { return .error(message: message, retryTitle: "Thử lại") }
        return .empty(title: presenter.isContent ? "Chưa có nội dung ở mục này." : "Chưa có cấp độ nào.", message: nil)
    }

    /// Footer row once rows exist: loading more, failed page (tap to retry) or "load more".
    private var statusText: String? {
        guard !presenter.rows.isEmpty else { return nil }
        if presenter.isLoading { return "Đang tải…" }
        if let message = presenter.errorMessage { return "\(message)\nChạm để thử lại." }
        if presenter.canLoadMore { return "Tải thêm 30 mục" }
        return nil
    }
}

extension HomeViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? presenter.rows.count : (statusText == nil ? 0 : 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.section == 0 else { return statusCell(for: tableView) }
        let row = presenter.rows[indexPath.row]
        let cell: UITableViewCell
        if presenter.isContent {
            let content = tableView.dequeueReusableCell(withIdentifier: ContentRowCell.reuseIdentifier) as! ContentRowCell
            content.configure(with: row)
            cell = content
        } else {
            let level = tableView.dequeueReusableCell(withIdentifier: LevelCell.reuseIdentifier) as! LevelCell
            level.configure(with: row)
            cell = level
        }
        cell.accessibilityIdentifier = "home_row_\(row.id)"
        cell.accessibilityTraits = .button
        return cell
    }

    private func statusCell(for tableView: UITableView) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "home_status_cell")
            ?? UITableViewCell(style: .default, reuseIdentifier: "home_status_cell")
        var content = cell.defaultContentConfiguration()
        let isError = presenter.errorMessage != nil && !presenter.isLoading
        let actionable = !presenter.isLoading && (isError || presenter.canLoadMore)
        content.text = statusText
        content.textProperties.apply(.metadata)
        content.textProperties.alignment = .center
        cell.accessoryView = nil
        if isError {
            // Color is never the only signal: icon + text + retry hint.
            content.textProperties.color = Design.Color.error
            content.image = UIImage(systemName: "exclamationmark.triangle")
            content.imageProperties.tintColor = Design.Color.error
        } else if actionable {
            content.textProperties.color = Design.Color.accent
        }
        if presenter.isLoading {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            cell.accessoryView = spinner
        }
        cell.backgroundColor = .clear
        cell.selectionStyle = actionable ? .default : .none
        cell.accessibilityIdentifier = "home_status"
        cell.accessibilityTraits = actionable ? .button : .staticText
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
