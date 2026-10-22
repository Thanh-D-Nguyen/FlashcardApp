import UIKit

final class HomeViewController: BaseViewController {
    var presenter: HomePresenterInterface!
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let stateView = StateView()
    private let kindControl = UISegmentedControl(items: HomeContentKind.allCases.map(\.title))
    private let totalLabel = UILabel()
    private let headerView = UIView()
    private var sections: [Section] = []

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
        tableView.estimatedRowHeight = 160
        tableView.estimatedSectionHeaderHeight = 32
        tableView.separatorColor = Design.Color.separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: Design.Spacing.gutter, bottom: 0, right: 0)
        tableView.register(LevelCell.self, forCellReuseIdentifier: LevelCell.reuseIdentifier)
        tableView.register(FeaturedLevelCell.self, forCellReuseIdentifier: FeaturedLevelCell.reuseIdentifier)
        tableView.register(SectionHeaderView.self, forHeaderFooterViewReuseIdentifier: SectionHeaderView.reuseIdentifier)
        tableView.sectionHeaderTopPadding = 0
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
        if presenter.isContent { buildHeader() }
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: HomeViewController, _) in
            controller.render()
        }
    }

    func subscribe() {
        presenter.onChange = { [weak self] in self?.render() }
    }

    // MARK: Header

    /// Level content: the kind switch and its total. The level list has no header; its first
    /// section is the featured level.
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
        kindControl.selectedSegmentIndex = presenter.kind.rawValue
        kindControl.accessibilityIdentifier = "level_content_kind"
        kindControl.addAction(UIAction { [weak self] _ in
            guard let self, let kind = HomeContentKind(rawValue: self.kindControl.selectedSegmentIndex) else { return }
            self.presenter.selectKind(kind)
        }, for: .valueChanged)
        totalLabel.apply(.metadata)
        [kindControl, totalLabel].forEach(stack.addArrangedSubview)
        tableView.tableHeaderView = headerView
    }

    private func sizeHeaderToFit() {
        guard presenter.isContent else { return }
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
        if presenter.isContent { renderKindChooser() } else { renderSubtitle() }
        sections = Self.makeSections(presenter: presenter, hasStatus: statusText != nil)
        stateView.configure(screenState ?? .empty(title: "", message: nil), onRetry: { [weak self] in self?.presenter.retry() })
        stateView.isHidden = screenState == nil
        stateView.accessibilityIdentifier = "home_status"
        tableView.reloadData()
        // The header's content (kind chooser, total) can change without a view layout pass.
        view.setNeedsLayout()
    }

    /// One line under the large title. Static text (never data-dependent) so the title keeps its height
    /// when rows arrive; dropped at accessibility sizes, where the system would truncate it.
    private func renderSubtitle() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        navigationItem.subtitle = large ? nil : NSLocalizedString("Pick a JLPT level to start studying", comment: "")
    }

    /// Segmented control at regular sizes; the system menu from the bar once text no longer fits three segments.
    private func renderKindChooser() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        kindControl.isHidden = large
        kindControl.selectedSegmentIndex = presenter.kind.rawValue
        if let total = presenter.kindTotal, total > 0 {
            totalLabel.text = "\(total.formatted(.number.locale(AppLanguage.current.locale))) \(presenter.kind.unit)"
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
        let item = UIBarButtonItem(title: presenter.kind.title, menu: UIMenu(title: NSLocalizedString("Content", comment: ""), children: actions))
        item.accessibilityLabel = String(format: NSLocalizedString("Content type: %@", comment: ""), presenter.kind.title)
        item.accessibilityIdentifier = "level_content_kind"
        navigationItem.rightBarButtonItem = item
    }

    /// Full-area state while there is nothing to list yet.
    private var screenState: StateView.State? {
        guard presenter.rows.isEmpty else { return nil }
        if presenter.isLoading { return .loading(NSLocalizedString("Loading…", comment: "")) }
        if let message = presenter.errorMessage { return .error(message: message, retryTitle: NSLocalizedString("Retry", comment: "")) }
        return .empty(title: presenter.isContent ? NSLocalizedString("No content in this section yet.", comment: "") : NSLocalizedString("No levels yet.", comment: ""), message: nil)
    }

    /// Footer row once rows exist: loading more, failed page (tap to retry) or "load more".
    private var statusText: String? {
        guard !presenter.rows.isEmpty else { return nil }
        if presenter.isLoading { return NSLocalizedString("Loading…", comment: "") }
        if let message = presenter.errorMessage { return String(format: NSLocalizedString("%@\nTap to retry.", comment: ""), message) }
        if presenter.canLoadMore { return NSLocalizedString("Load 30 more", comment: "") }
        return nil
    }
}

extension HomeViewController {
    /// What a table section shows. Level list: featured level, then the other levels; content: its rows.
    enum Section: Equatable {
        case featured(Int)
        case levels([Int])
        case content
        case status
    }

    static func makeSections(presenter: HomePresenterInterface, hasStatus: Bool) -> [Section] {
        var sections: [Section] = []
        if presenter.isContent {
            sections.append(.content)
        } else if !presenter.rows.isEmpty {
            let featured = presenter.featuredIndex
            if let featured { sections.append(.featured(featured)) }
            let others = presenter.rows.indices.filter { $0 != featured }
            if !others.isEmpty { sections.append(.levels(others)) }
        }
        if hasStatus { sections.append(.status) }
        return sections
    }

    /// The level's numeral inside the visible cell; the zoom transition grows out of it.
    func transitionSourceView(forLevelCode code: String) -> UIView? {
        let numerals: [UILabel] = tableView.visibleCells
            .filter { $0.accessibilityIdentifier == "home_row_\(code)" }
            .compactMap { ($0 as? LevelCell)?.numeralLabel ?? ($0 as? FeaturedLevelCell)?.numeralLabel }
        // A level without a numeral hides its label; zooming from a hidden view would look broken.
        return numerals.first { !$0.isHidden }
    }
}

extension HomeViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .featured: return 1
        case .levels(let indices): return indices.count
        case .content: return presenter.rows.count
        case .status: return 1
        }
    }

    /// Presenter row index behind a table position, nil for the status footer.
    private func rowIndex(at indexPath: IndexPath) -> Int? {
        switch sections[indexPath.section] {
        case .featured(let index): return index
        case .levels(let indices): return indices[indexPath.row]
        case .content: return indexPath.row
        case .status: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let index = rowIndex(at: indexPath) else { return statusCell(for: tableView) }
        let row = presenter.rows[index]
        let cell: UITableViewCell
        switch sections[indexPath.section] {
        case .featured:
            let featured = tableView.dequeueReusableCell(withIdentifier: FeaturedLevelCell.reuseIdentifier) as! FeaturedLevelCell
            featured.configure(with: row)
            featured.onStart = { [weak self] in self?.presenter.selectRow(at: index, kind: .vocabulary) }
            cell = featured
        case .levels:
            let level = tableView.dequeueReusableCell(withIdentifier: LevelCell.reuseIdentifier) as! LevelCell
            level.configure(with: row)
            level.onSelectKind = { [weak self] kind in self?.presenter.selectRow(at: index, kind: kind) }
            level.setActivation { [weak self] in self?.presenter.selectRow(at: index) }
            cell = level
        default:
            let content = tableView.dequeueReusableCell(withIdentifier: ContentRowCell.reuseIdentifier) as! ContentRowCell
            content.configure(with: row)
            cell = content
        }
        cell.accessibilityIdentifier = "home_row_\(row.id)"
        if case .content = sections[indexPath.section] { cell.accessibilityTraits = .button }
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard case .levels = sections[section] else { return nil }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: SectionHeaderView.reuseIdentifier) as! SectionHeaderView
        header.configure(title: NSLocalizedString("More levels", comment: ""))
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if case .levels = sections[section] { return UITableView.automaticDimension }
        return .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { nil }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { .leastNormalMagnitude }

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
        if let index = rowIndex(at: indexPath) {
            presenter.selectRow(at: index)
        } else if presenter.errorMessage != nil {
            presenter.retry()
        } else {
            presenter.loadMore()
        }
    }
}
