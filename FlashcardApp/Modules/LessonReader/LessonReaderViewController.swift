import UIKit

/// Reads one lesson: the server's text in reading order, one table section per kind of material. Draws the presenter's state.
final class LessonReaderViewController: BaseVC {
    var presenter: LessonReaderPresenterInterface!

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let stateView = StateView()
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let offlineLabel = UILabel()

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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeHeaderToFit()
    }

    private func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "entry")
        tableView.estimatedRowHeight = 72
        tableView.rowHeight = UITableView.automaticDimension
        tableView.accessibilityIdentifier = "lesson_reader"
        tableView.backgroundView = stateView
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        stateView.accessibilityIdentifier = "lesson_reader_status"

        titleLabel.apply(.title)
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header
        titleLabel.accessibilityIdentifier = "lesson_reader_title"
        metaLabel.apply(.metadata)
        offlineLabel.apply(.metadata)
        offlineLabel.numberOfLines = 0
        offlineLabel.textColor = Design.Color.accent
        offlineLabel.accessibilityIdentifier = "lesson_reader_offline"
        let stack = UIStackView(arrangedSubviews: [titleLabel, metaLabel, offlineLabel])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        headerView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: Design.Spacing.s, leading: Design.Spacing.gutter, bottom: Design.Spacing.m, trailing: Design.Spacing.gutter)
        headerView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: headerView.layoutMarginsGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: headerView.layoutMarginsGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.trailingAnchor)
        ])
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

    private func render() {
        titleLabel.text = presenter.title
        metaLabel.text = presenter.minutes.map { String(format: NSLocalizedString("%lld min", comment: ""), $0) }
        metaLabel.isHidden = metaLabel.text == nil
        offlineLabel.text = presenter.isFromCache
            ? NSLocalizedString("You're offline. This is the copy saved on this device.", comment: "Lesson reader banner") : nil
        offlineLabel.isHidden = offlineLabel.text == nil
        switch presenter.state {
        case .idle, .loading:
            stateView.configure(.loading(NSLocalizedString("Loading…", comment: "")), onRetry: nil)
        case .failed(let message):
            stateView.configure(.error(message: message, retryTitle: NSLocalizedString("Retry", comment: "")),
                                onRetry: { [weak self] in self?.presenter.retry() })
        case .loaded:
            break
        }
        stateView.isHidden = presenter.state == .loaded
        tableView.reloadData()
        view.setNeedsLayout()
    }

    private var showsPractice: Bool { presenter.state == .loaded && presenter.practiceActivityCount > 0 }
}

extension LessonReaderViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { presenter.sections.count + (showsPractice ? 1 : 0) }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section < presenter.sections.count ? presenter.sections[section].entries.count : 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section < presenter.sections.count ? presenter.sections[section].title : NSLocalizedString("Practice", comment: "")
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "entry", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        cell.selectionStyle = .none
        cell.accessibilityTraits = .staticText
        if indexPath.section >= presenter.sections.count {
            // Practice: shown with the server's activity count, but off until the activities exist (K-04).
            content.text = NSLocalizedString("Practice", comment: "")
            content.textProperties.apply(.title)
            content.textProperties.color = Design.Color.textSecondary
            content.secondaryText = String(format: NSLocalizedString("%lld activities", comment: ""), presenter.practiceActivityCount)
            content.secondaryTextProperties.apply(.metadata)
            cell.accessibilityTraits = [.button, .notEnabled]
            cell.accessibilityIdentifier = "lesson_practice"
            cell.contentConfiguration = content
            return cell
        }
        let section = presenter.sections[indexPath.section]
        let entry = section.entries[indexPath.row]
        if let headline = entry.headline {
            content.text = headline
            content.textProperties.apply(section.kind == .context ? .explanation : .headword)
            content.secondaryText = [entry.reading, entry.body, entry.note].compactMap { $0 }.joined(separator: "\n")
            content.secondaryTextProperties.apply(.explanation)
        } else if let label = entry.label {
            content.text = label
            content.textProperties.apply(.metadata)
            content.secondaryText = entry.body
            content.secondaryTextProperties.apply(.explanation)
        } else {
            content.text = entry.body
            content.textProperties.apply(.explanation)
        }
        cell.accessibilityIdentifier = "lesson_entry_\(indexPath.section)_\(indexPath.row)"
        cell.contentConfiguration = content
        return cell
    }
}
