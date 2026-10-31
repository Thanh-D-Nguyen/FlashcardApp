import UIKit

/// The catalogue of everyday situations: a row of group chips under the navigation bar, then the situations grouped as on the website.
/// All decisions (loading, filtering, order) belong to the presenter; this class draws state.
final class ScenarioListViewController: BaseVC, ScenarioListViewInterface, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {
    var presenter: ScenarioListPresenterInterface!

    private let chipScroll = UIScrollView()
    private let chipStack = UIStackView()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let stateView = StateView()
    private let searchController = UISearchController(searchResultsController: nil)
    private var sections: [ScenarioSectionState] = []
    private var chipHeight: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        presenter.viewWillAppear()
    }

    private func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = NSLocalizedString("Search situations", comment: "Search field of the situation list")
        searchController.searchBar.accessibilityIdentifier = "scenario_search"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true

        chipScroll.showsHorizontalScrollIndicator = false
        chipScroll.alwaysBounceHorizontal = true
        chipScroll.translatesAutoresizingMaskIntoConstraints = false
        chipScroll.accessibilityIdentifier = "scenario_chips"
        chipStack.axis = .horizontal
        chipStack.spacing = Design.Spacing.s
        chipStack.translatesAutoresizingMaskIntoConstraints = false
        chipScroll.addSubview(chipStack)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.keyboardDismissMode = .onDrag
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "header")
        tableView.estimatedRowHeight = 72
        tableView.rowHeight = UITableView.automaticDimension
        tableView.accessibilityIdentifier = "scenario_list"
        tableView.translatesAutoresizingMaskIntoConstraints = false

        stateView.translatesAutoresizingMaskIntoConstraints = false
        stateView.isHidden = true

        [chipScroll, tableView, stateView].forEach(view.addSubview)
        chipHeight = chipScroll.heightAnchor.constraint(equalToConstant: 52)
        NSLayoutConstraint.activate([
            chipScroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            chipScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chipScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chipHeight,
            chipStack.topAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.topAnchor, constant: Design.Spacing.xs),
            chipStack.bottomAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.xs),
            chipStack.leadingAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            chipStack.trailingAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter),
            chipStack.heightAnchor.constraint(equalTo: chipScroll.frameLayoutGuide.heightAnchor, constant: -Design.Spacing.s),
            tableView.topAnchor.constraint(equalTo: chipScroll.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stateView.topAnchor.constraint(equalTo: chipScroll.bottomAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // MARK: ScenarioListViewInterface

    func render(_ state: ScenarioListState) {
        loadViewIfNeeded()
        sections = state.sections
        let showsList: Bool
        switch state.screen {
        case .content:
            showsList = true
        case .noMatches(let query):
            showsList = false
            let message = query.trimmingCharacters(in: .whitespaces).isEmpty ? nil : String(format: NSLocalizedString("No situation matches “%@”.", comment: ""), query)
            stateView.configure(.empty(title: NSLocalizedString("Nothing found", comment: ""), message: message))
        case .loading:
            showsList = false
            stateView.configure(.loading(NSLocalizedString("Loading situations…", comment: "")))
        case .signInRequired:
            showsList = false
            stateView.configure(.call(symbol: "person.crop.circle", title: NSLocalizedString("Sign in to practise situations", comment: ""),
                                      message: NSLocalizedString("Situations are part of your account, so your practice follows you between the app and the website.", comment: ""),
                                      actionTitle: NSLocalizedString("Sign in", comment: ""))) { [weak self] in self?.presenter.signIn() }
        case .failed(let message, let canRetry):
            showsList = false
            if canRetry {
                stateView.configure(.error(message: message, retryTitle: NSLocalizedString("Try again", comment: ""))) { [weak self] in self?.presenter.retry() }
            } else {
                stateView.configure(.empty(title: message, message: nil))
            }
        case .empty:
            showsList = false
            stateView.configure(.empty(title: NSLocalizedString("No situations yet", comment: ""),
                                       message: NSLocalizedString("New situations appear here as they are added.", comment: "")))
        }
        let hasCatalogue = !state.chips.isEmpty
        chipScroll.isHidden = !hasCatalogue
        chipHeight.constant = hasCatalogue ? 52 : 0
        tableView.isHidden = !showsList
        // The chips stay above "no matches", so the learner can clear a group.
        stateView.isHidden = showsList
        renderChips(state.chips)
        tableView.reloadData()
        if showsList, !state.totalText.isEmpty { tableView.accessibilityLabel = state.totalText }
    }

    private func renderChips(_ chips: [ScenarioChipState]) {
        chipStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for chip in chips {
            var configuration = UIButton.Configuration.filled()
            configuration.cornerStyle = .capsule
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
            configuration.imagePadding = Design.Spacing.xs
            configuration.image = UIImage(systemName: chip.symbol)
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .small)
            configuration.baseBackgroundColor = chip.isSelected ? Design.Color.accent : Design.Color.surface
            configuration.baseForegroundColor = chip.isSelected ? Design.Color.onAccent : Design.Color.textPrimary
            var title = AttributedString(chip.title)
            title.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(chip.isSelected ? .semibold : .regular)
            configuration.attributedTitle = title
            let button = UIButton(configuration: configuration)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.accessibilityLabel = chip.title
            button.accessibilityTraits = chip.isSelected ? [.button, .selected] : .button
            button.accessibilityIdentifier = "scenario_chip_\(chip.key)"
            let key = chip.key
            button.addAction(UIAction { [weak self] _ in self?.presenter.toggleCategory(key) }, for: .primaryActionTriggered)
            chipStack.addArrangedSubview(button)
        }
    }

    // MARK: Table

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header")
        let group = sections[section]
        var content = UIListContentConfiguration.header()
        content.text = group.title
        content.image = UIImage(systemName: group.symbol)
        content.imageProperties.tintColor = Design.Color.accent
        content.textProperties.font = Design.TextRole.sectionTitle.font
        content.textProperties.color = Design.Color.textPrimary
        header?.contentConfiguration = content
        header?.accessibilityTraits = .header
        header?.accessibilityLabel = String.localizedStringWithFormat(NSLocalizedString("%1$@, %2$lld situations", comment: "Group header: name, count"), group.title, group.rows.count)
        return header
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        let row = sections[indexPath.section].rows[indexPath.row]
        var content = UIListContentConfiguration.subtitleCell()
        content.text = row.title
        content.textProperties.apply(.title)
        content.secondaryText = [row.subtitle, row.meta].compactMap { $0 }.joined(separator: "\n")
        content.secondaryTextProperties.apply(.metadata)
        content.secondaryTextProperties.color = Design.Color.textSecondary
        content.textToSecondaryTextVerticalPadding = Design.Spacing.xs
        cell.contentConfiguration = content
        cell.backgroundColor = Design.Color.surface
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "scenario_row_\(row.id)"
        cell.accessibilityLabel = [row.title, row.subtitle, row.meta].compactMap { $0 }.joined(separator: ", ")
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.select(id: sections[indexPath.section].rows[indexPath.row].id)
    }

    // MARK: Search

    func updateSearchResults(for searchController: UISearchController) {
        presenter.search(searchController.searchBar.text ?? "")
    }
}
