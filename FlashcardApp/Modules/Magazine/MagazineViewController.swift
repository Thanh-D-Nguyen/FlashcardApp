import UIKit

/// The article list. The newest article is drawn large, the rest is a quiet list, and a row of filters stays pinned under
/// the navigation bar. All decisions (paging, cancelling, what counts as today) belong to the presenter; this class draws state.
final class MagazineViewController: BaseVC, MagazineViewInterface, UICollectionViewDelegate {
    var presenter: MagazinePresenterInterface!

    private enum SectionID: Hashable {
        case lead(String)
        case rows(String)
        case footer
    }

    private enum Item: Hashable {
        case lead(MagazineRow)
        case row(MagazineRow)
        case footer(MagazineFooter)
    }

    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
    private var dataSource: UICollectionViewDiffableDataSource<SectionID, Item>!
    private let stateView = StateView()
    private let refreshControl = UIRefreshControl()
    private var filter: MagazineFilter = .all
    private var filterBar: MagazineFilterBar?
    private var lastContent: MagazineContent?
    private var isApplyingSnapshot = false
    private var queuedWillDisplayIndexPaths: [IndexPath] = []
    private var loadMoreScheduled = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let barHeight = filterBar?.bounds.height ?? 60
        stateView.topContentInset = barHeight + Design.Spacing.s
    }

    #if DEBUG
    private var handledLaunchArguments = false

    /// `-MagazineFilter <vocab|weather|horoscope|bjt_phrase>` picks a filter and `-MagazineOpenFirst` opens the first article
    /// once the list has loaded, for screenshots and UI tests.
    private func applyDebugLaunchArguments(_ state: MagazineViewState) {
        guard !handledLaunchArguments else { return }
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-MagazineFilter"), index + 1 < arguments.count,
           let filter = MagazineFilter.allCases.first(where: { $0.kind?.apiValue == arguments[index + 1] }) {
            if filter != state.filter { presenter.select(filter); return }
        }
        guard case .list(let sections, _) = state.content else { return }
        handledLaunchArguments = true
        if arguments.contains("-MagazineOpenFirst"), let slug = sections.first?.rows.first?.slug { presenter.open(slug: slug) }
    }
    #endif

    // MARK: Setup

    private func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.backButtonDisplayMode = .minimal

        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.alwaysBounceVertical = true
        collectionView.accessibilityIdentifier = "magazine_list"
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        refreshControl.addAction(UIAction { [weak self] _ in self?.presenter.refresh() }, for: .valueChanged)
        collectionView.refreshControl = refreshControl
        view.addSubview(collectionView)

        stateView.translatesAutoresizingMaskIntoConstraints = false
        stateView.isHidden = true
        view.addSubview(stateView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stateView.topAnchor.constraint(equalTo: view.topAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        let lead = UICollectionView.CellRegistration<MagazineLeadCell, MagazineRow> { cell, _, row in cell.configure(row) }
        let rowCell = UICollectionView.CellRegistration<MagazineRowCell, MagazineRow> { cell, _, row in cell.configure(row) }
        let footer = UICollectionView.CellRegistration<MagazineFooterCell, MagazineFooter> { [weak self] cell, _, footer in
            cell.configure(footer) { self?.presenter.retryLoadMore() }
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .lead(let row): return collectionView.dequeueConfiguredReusableCell(using: lead, for: indexPath, item: row)
            case .row(let row): return collectionView.dequeueConfiguredReusableCell(using: rowCell, for: indexPath, item: row)
            case .footer(let state): return collectionView.dequeueConfiguredReusableCell(using: footer, for: indexPath, item: state)
            }
        }
        let sectionHeader = UICollectionView.SupplementaryRegistration<MagazineSectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] header, _, indexPath in
            guard let id = self?.dataSource.snapshot().sectionIdentifiers[indexPath.section] else { return }
            switch id {
            case .lead(let title), .rows(let title): header.configure(title)
            case .footer: header.configure("")
            }
        }
        let filters = UICollectionView.SupplementaryRegistration<MagazineFilterBar>(elementKind: MagazineFilterBar.elementKind) { [weak self] bar, _, _ in
            guard let self else { return }
            self.filterBar = bar
            bar.configure(selected: self.filter) { [weak self] in self?.presenter.select($0) }
        }
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            if kind == MagazineFilterBar.elementKind { return collectionView.dequeueConfiguredReusableSupplementary(using: filters, for: indexPath) }
            return collectionView.dequeueConfiguredReusableSupplementary(using: sectionHeader, for: indexPath)
        }
    }

    // MARK: Layout

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        let bar = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60)),
            elementKind: MagazineFilterBar.elementKind, alignment: .top)
        bar.pinToVisibleBounds = true
        configuration.boundarySupplementaryItems = [bar]
        return UICollectionViewCompositionalLayout(sectionProvider: { [weak self] index, environment in
            guard let self, let identifiers = self.dataSource?.snapshot().sectionIdentifiers, identifiers.indices.contains(index) else { return nil }
            let id = identifiers[index]
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)),
                elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
            switch id {
            case .lead:
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(280)))
                let group = NSCollectionLayoutGroup.vertical(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(280)), subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = Design.Spacing.m
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: Design.Spacing.gutter, bottom: Design.Spacing.s, trailing: Design.Spacing.gutter)
                section.boundarySupplementaryItems = [header]
                return section
            case .rows:
                var list = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                list.backgroundColor = .clear
                list.headerMode = .none
                list.showsSeparators = true
                let section = NSCollectionLayoutSection.list(using: list, layoutEnvironment: environment)
                section.boundarySupplementaryItems = [header]
                return section
            case .footer:
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(64)))
                let group = NSCollectionLayoutGroup.vertical(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(64)), subitems: [item])
                return NSCollectionLayoutSection(group: group)
            }
        }, configuration: configuration)
    }

    // MARK: MagazineViewInterface

    func render(_ state: MagazineViewState) {
        loadViewIfNeeded()
        let filterChanged = state.filter != filter
        filter = state.filter
        filterBar?.select(state.filter)
        let changed = state.content != lastContent
        lastContent = state.content
        #if DEBUG
        defer { DispatchQueue.main.async { [weak self] in self?.applyDebugLaunchArguments(state) } }
        #endif

        switch state.content {
        case .loading(let message):
            show(.loading(message))
        case .empty(let title, let message):
            show(.empty(title: title, message: message))
        case .failed(let message):
            show(.error(message: message, retryTitle: NSLocalizedString("Try again", comment: ""))) { [weak self] in self?.presenter.retry() }
        case .list(let sections, let footer):
            stateView.isHidden = true
            collectionView.isHidden = false
            guard changed else { return }
            var snapshot = NSDiffableDataSourceSnapshot<SectionID, Item>()
            for section in sections {
                let id: SectionID = section.style == .lead ? .lead(section.title) : .rows(section.title)
                snapshot.appendSections([id])
                snapshot.appendItems(section.rows.map { section.style == .lead ? .lead($0) : .row($0) }, toSection: id)
            }
            if footer != .none {
                snapshot.appendSections([.footer])
                snapshot.appendItems([.footer(footer)], toSection: .footer)
            }
            applySnapshot(snapshot, animatingDifferences: !filterChanged && UIView.areAnimationsEnabled && !UIAccessibility.isReduceMotionEnabled)
            if filterChanged { collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.adjustedContentInset.top), animated: false) }
        }
    }

    private func applySnapshot(_ snapshot: NSDiffableDataSourceSnapshot<SectionID, Item>, animatingDifferences: Bool) {
        isApplyingSnapshot = true
        defer { isApplyingSnapshot = false }
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    private func show(_ state: StateView.State, retry: (() -> Void)? = nil) {
        // Keep an empty section so the compositional layout's pinned `MagazineFilterBar` stays mounted and tappable.
        var empty = NSDiffableDataSourceSnapshot<SectionID, Item>()
        empty.appendSections([.rows("")])
        applySnapshot(empty, animatingDifferences: false)
        collectionView.isHidden = false
        stateView.isHidden = false
        stateView.configure(state, onRetry: retry)
    }

    func endRefreshing() {
        if refreshControl.isRefreshing { refreshControl.endRefreshing() }
    }

    // MARK: UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch dataSource.itemIdentifier(for: indexPath) {
        case .lead(let row)?, .row(let row)?: presenter.open(slug: row.slug)
        case .footer?, nil: break
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        // UIKit may invoke willDisplay synchronously while a diffable snapshot apply is on the stack;
        // deferring loadMore avoids re-entrant dataSource.apply crashes when the presenter renders a loading footer.
        queuedWillDisplayIndexPaths.append(indexPath)
        guard !loadMoreScheduled else { return }
        loadMoreScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.drainQueuedWillDisplay()
        }
    }

    private func drainQueuedWillDisplay() {
        loadMoreScheduled = false
        let paths = queuedWillDisplayIndexPaths
        queuedWillDisplayIndexPaths.removeAll(keepingCapacity: true)
        guard !isApplyingSnapshot else { return }
        let snapshot = dataSource.snapshot()
        let rows = snapshot.itemIdentifiers.filter { if case .row = $0 { return true } else { return false } }
        guard !rows.isEmpty else { return }
        for indexPath in paths {
            guard let item = dataSource.itemIdentifier(for: indexPath), case .row = item else { continue }
            if let position = rows.firstIndex(of: item), position >= rows.count - 4 {
                presenter.loadMore()
                return
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if case .footer? = dataSource.itemIdentifier(for: indexPath) { return false }
        return true
    }
}
