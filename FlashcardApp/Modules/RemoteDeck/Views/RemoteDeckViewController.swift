import UIKit

/// A deck of the account: a header with its name, kind and size, the cards in order, and the actions pinned at the bottom.
/// "Study" is the one primary action; saving a copy is explicit and secondary.
final class RemoteDeckViewController: BaseViewController, RemoteDeckViewInterface {
    var presenter: RemoteDeckPresenterInterface!

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let stateView = StateView()
    private let header = RemoteDeckHeaderView()
    private let studyButton = UIButton(configuration: Design.Button.primary(title: NSLocalizedString("Study", comment: "")))
    private let saveButton = UIButton(configuration: .plain())
    private let noticeLabel = UILabel()
    private let footnoteLabel = UILabel()
    private let actions = UIStackView()
    private var state = RemoteDeckState()

    private lazy var menuItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu())
        item.accessibilityLabel = NSLocalizedString("Deck options", comment: "")
        item.accessibilityIdentifier = "remote_deck_menu"
        return item
    }()

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

    func subscribe() {}

    func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = menuItem

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.allowsSelection = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.separatorColor = Design.Color.separator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: Design.Spacing.gutter, bottom: 0, right: 0)
        tableView.register(RemoteDeckCardCell.self, forCellReuseIdentifier: RemoteDeckCardCell.reuseIdentifier)
        tableView.accessibilityIdentifier = "remote_deck_cards"
        tableView.tableHeaderView = header

        studyButton.accessibilityIdentifier = "remote_deck_study"
        studyButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        studyButton.addAction(UIAction { [weak self] _ in self?.presenter.study() }, for: .primaryActionTriggered)
        saveButton.configuration?.title = NSLocalizedString("Save to this device", comment: "")
        saveButton.configuration?.image = UIImage(systemName: "arrow.down.circle")
        saveButton.configuration?.imagePadding = Design.Spacing.s
        saveButton.accessibilityIdentifier = "remote_deck_save"
        saveButton.addAction(UIAction { [weak self] _ in self?.presenter.saveToDevice() }, for: .primaryActionTriggered)
        for label in [noticeLabel, footnoteLabel] {
            label.apply(.metadata)
            label.textAlignment = .center
        }
        noticeLabel.textColor = Design.Color.error
        noticeLabel.accessibilityIdentifier = "remote_deck_notice"
        footnoteLabel.text = NSLocalizedString("Studying saves a copy on this device so it also works offline.", comment: "")
        actions.axis = .vertical
        actions.spacing = Design.Spacing.s
        actions.translatesAutoresizingMaskIntoConstraints = false
        actions.isLayoutMarginsRelativeArrangement = true
        actions.directionalLayoutMargins = NSDirectionalEdgeInsets(top: Design.Spacing.m, leading: Design.Spacing.gutter, bottom: Design.Spacing.s,
                                                                  trailing: Design.Spacing.gutter)
        actions.backgroundColor = Design.Color.background
        [noticeLabel, studyButton, saveButton, footnoteLabel].forEach(actions.addArrangedSubview)

        stateView.translatesAutoresizingMaskIntoConstraints = false
        [tableView, actions, stateView].forEach(view.addSubview)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: actions.topAnchor),
            actions.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            actions.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            actions.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stateView.topAnchor.constraint(equalTo: view.topAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        stateView.accessibilityIdentifier = "remote_deck_state"
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // A table header does not size itself: measure it at the table's width and reassign it when it changes.
        let size = header.systemLayoutSizeFitting(CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height),
                                                  withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        if header.frame.height != size.height || header.frame.width != tableView.bounds.width {
            header.frame = CGRect(origin: .zero, size: CGSize(width: tableView.bounds.width, height: size.height))
            tableView.tableHeaderView = header
        }
    }

    // MARK: RemoteDeckViewInterface

    func render(_ newState: RemoteDeckState) {
        state = newState
        title = newState.phase == .loaded ? nil : NSLocalizedString("Deck", comment: "")
        var showsState = true
        switch newState.phase {
        case .loading:
            stateView.configure(.loading(NSLocalizedString("Loading the deck…", comment: "")))
        case .failed(let message):
            stateView.configure(.error(message: message, retryTitle: NSLocalizedString("Try again", comment: "")),
                                onRetry: { [weak self] in self?.presenter.retry() })
        case .signInRequired:
            stateView.configure(.call(symbol: "person.crop.circle", title: NSLocalizedString("Sign in to open this deck", comment: ""),
                                      message: nil, actionTitle: NSLocalizedString("Sign In", comment: "")),
                                onRetry: { [weak self] in self?.presenter.signIn() })
        case .loaded:
            showsState = false
        }
        stateView.isHidden = !showsState
        tableView.isHidden = showsState
        actions.isHidden = showsState
        navigationItem.rightBarButtonItem = newState.phase == .loaded ? menuItem : nil
        guard newState.phase == .loaded else { return }

        header.configure(title: newState.title, details: newState.details, visibility: newState.visibility, isOwned: newState.isOwned,
                         cardCount: newState.cards.count)
        tableView.reloadData()
        view.setNeedsLayout()

        let busy = newState.busy
        studyButton.isEnabled = newState.canStudy
        studyButton.configuration?.showsActivityIndicator = false
        saveButton.isHidden = newState.isOnDevice
        saveButton.isEnabled = busy == nil
        saveButton.configuration?.showsActivityIndicator = busy == .saving
        footnoteLabel.isHidden = newState.isOnDevice || newState.cards.isEmpty
        noticeLabel.text = newState.notice
        noticeLabel.isHidden = newState.notice == nil
        menuItem.menu = makeMenu(for: newState)
        menuItem.isEnabled = busy == nil
        if newState.notice != nil { UIAccessibility.post(notification: .announcement, argument: newState.notice) }
    }

    private func makeMenu(for state: RemoteDeckState) -> UIMenu {
        var children: [UIMenuElement] = []
        if !state.isOnDevice {
            children.append(UIAction(title: NSLocalizedString("Save to this device", comment: ""), image: UIImage(systemName: "arrow.down.circle")) { [weak self] _ in
                self?.presenter.saveToDevice()
            })
        }
        if state.isOwned {
            children.append(UIAction(title: NSLocalizedString("Archive", comment: ""), image: UIImage(systemName: "archivebox"), attributes: .destructive) { [weak self] _ in
                self?.presenter.archive()
            })
        }
        return UIMenu(children: children)
    }
}

extension RemoteDeckViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { state.cards.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RemoteDeckCardCell.reuseIdentifier, for: indexPath)
        if let cell = cell as? RemoteDeckCardCell { cell.configure(with: state.cards[indexPath.row], position: indexPath.row + 1) }
        return cell
    }
}

/// Top of the deck screen: a Mincho mark, the name, a line of facts and the description.
final class RemoteDeckHeaderView: UIView {
    private let monogramBox = UIView()
    private let monogramLabel = UILabel()
    private let titleLabel = UILabel()
    private let factsLabel = UILabel()
    private let detailsLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        monogramBox.backgroundColor = Design.Color.highlight
        monogramBox.layer.cornerRadius = Design.Spacing.m
        monogramBox.layer.cornerCurve = .continuous
        monogramBox.isAccessibilityElement = false
        monogramBox.translatesAutoresizingMaskIntoConstraints = false
        monogramLabel.apply(.monogram)
        monogramLabel.textAlignment = .center
        monogramLabel.translatesAutoresizingMaskIntoConstraints = false
        monogramBox.addSubview(monogramLabel)
        NSLayoutConstraint.activate([
            monogramLabel.centerXAnchor.constraint(equalTo: monogramBox.centerXAnchor),
            monogramLabel.centerYAnchor.constraint(equalTo: monogramBox.centerYAnchor),
            monogramBox.widthAnchor.constraint(equalToConstant: 64),
            monogramBox.heightAnchor.constraint(equalToConstant: 64)
        ])
        titleLabel.apply(.headword)
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header
        factsLabel.apply(.metadata)
        factsLabel.numberOfLines = 0
        detailsLabel.apply(.reading)
        detailsLabel.numberOfLines = 0

        let text = UIStackView(arrangedSubviews: [titleLabel, factsLabel])
        text.axis = .vertical
        text.spacing = Design.Spacing.xs
        let top = UIStackView(arrangedSubviews: [monogramBox, text])
        top.spacing = Design.Spacing.m
        top.alignment = .center
        let stack = UIStackView(arrangedSubviews: [top, detailsLabel])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.s),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.l),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.gutter)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(title: String, details: String, visibility: ServerDeckVisibility, isOwned: Bool, cardCount: Int) {
        monogramLabel.text = title.first.map { String($0).uppercased() } ?? "札"
        titleLabel.text = title
        let count = String.localizedStringWithFormat(NSLocalizedString("%lld cards", comment: ""), cardCount)
        let kind = isOwned
            ? (visibility == .public ? NSLocalizedString("Yours · Public", comment: "") : NSLocalizedString("Yours · Private", comment: ""))
            : NSLocalizedString("Public deck", comment: "")
        factsLabel.text = [count, kind].joined(separator: " · ")
        detailsLabel.text = details
        detailsLabel.isHidden = details.isEmpty
    }
}

/// One card of the deck: the front as the headword, its reading, and the back.
final class RemoteDeckCardCell: UITableViewCell {
    static let reuseIdentifier = "remote_deck_card_cell"

    private let frontLabel = UILabel()
    private let readingLabel = UILabel()
    private let backLabel = UILabel()
    private let positionLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundConfiguration = .clear()
        frontLabel.apply(.headword)
        frontLabel.numberOfLines = 0
        readingLabel.apply(.reading)
        readingLabel.numberOfLines = 0
        backLabel.apply(.meaning)
        backLabel.textColor = Design.Color.textSecondary
        backLabel.numberOfLines = 0
        positionLabel.apply(.figure)
        positionLabel.textColor = .tertiaryLabel
        positionLabel.setContentHuggingPriority(.required, for: .horizontal)
        positionLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        positionLabel.isAccessibilityElement = false
        let text = UIStackView(arrangedSubviews: [frontLabel, readingLabel, backLabel])
        text.axis = .vertical
        text.spacing = Design.Spacing.xs
        let row = UIStackView(arrangedSubviews: [text, positionLabel])
        row.spacing = Design.Spacing.m
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Design.Spacing.m),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Design.Spacing.m),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Design.Spacing.gutter),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Design.Spacing.gutter)
        ])
        isAccessibilityElement = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(with card: ServerDeckCard, position: Int) {
        frontLabel.text = card.front
        readingLabel.text = card.reading
        readingLabel.isHidden = card.reading.isEmpty
        backLabel.text = card.back
        positionLabel.text = "\(position)"
        accessibilityLabel = [card.front, card.reading, card.back].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
