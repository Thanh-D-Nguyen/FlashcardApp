import UIKit

/// Today: one raised block with where the learner is and the one thing to do next, the deck and session length they can change,
/// what was saved today, and the way into the levels. Native large title and tab bar; the hero is content, never glass.
final class TodayViewController: BaseViewController, TodayViewInterface {
    var presenter: TodayPresenterInterface!

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let dateHeader = TodayDateHeaderView()
    private let subtitleLabel = UILabel()
    private let heroView = TodayHeroView()
    private let failureView = TodayFailureView()
    private let settingsGroup = UIStackView()
    private let deckRow = TodayRowView()
    private let timeRow = TodayRowView()
    private let progressGroup = UIStackView()
    private let progressHeader = UILabel()
    private let progressTitle = UILabel()
    private let progressDetail = UILabel()
    private let levelsRow = TodayRowView()
    private let hubView = TodayLifeHubView()
    private var refreshObservers: [NSObjectProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        presenter.viewWillAppear()
        observeRefreshes()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshObservers.forEach(NotificationCenter.default.removeObserver)
        refreshObservers = []
    }

    /// What is due and what was saved "today" change while the screen stays open: coming back to the app, a new day, a change of
    /// time or time zone. Refresh then, not only when the screen next appears.
    private func observeRefreshes() {
        guard refreshObservers.isEmpty else { return }
        let names: [Notification.Name] = [UIApplication.willEnterForegroundNotification, .NSCalendarDayChanged,
                                          UIApplication.significantTimeChangeNotification, NSNotification.Name.NSSystemTimeZoneDidChange]
        refreshObservers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.presenter.refresh() }
        }
    }

    func subscribe() {}

    func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .always
        title = NSLocalizedString("Today", comment: "Tab and screen title")

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "today_screen"
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)

        subtitleLabel.apply(.reading)
        subtitleLabel.accessibilityIdentifier = "today_subtitle"

        settingsGroup.axis = .vertical
        deckRow.accessibilityIdentifier = "today_deck_row"
        timeRow.accessibilityIdentifier = "today_time_row"
        [deckRow, timeRow].forEach(settingsGroup.addArrangedSubview)

        progressGroup.axis = .vertical
        progressGroup.spacing = Design.Spacing.xs
        progressHeader.apply(.metadata)
        progressHeader.font = Design.TextRole.metadata.font.withWeight(.semibold)
        progressHeader.text = NSLocalizedString("Today's progress", comment: "")
        progressHeader.accessibilityTraits = .header
        progressTitle.apply(.meaning)
        progressTitle.accessibilityIdentifier = "today_progress"
        progressDetail.apply(.metadata)
        [progressHeader, progressTitle, progressDetail].forEach(progressGroup.addArrangedSubview)
        progressGroup.setCustomSpacing(Design.Spacing.s, after: progressHeader)

        levelsRow.configure(title: NSLocalizedString("Study by level", comment: "Row that opens the JLPT levels"), value: nil)
        levelsRow.accessibilityIdentifier = "today_levels_row"

        dateHeader.isHidden = true
        hubView.isHidden = true
        hubView.accessibilityIdentifier = "today_life_hub"
        [dateHeader, subtitleLabel, heroView, failureView, hubView, settingsGroup, progressGroup, levelsRow].forEach(stack.addArrangedSubview)
        stack.setCustomSpacing(Design.Spacing.s, after: subtitleLabel)
        stack.setCustomSpacing(Design.Spacing.xl, after: hubView)
        stack.setCustomSpacing(Design.Spacing.xl, after: settingsGroup)
        stack.setCustomSpacing(Design.Spacing.xl, after: progressGroup)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Design.Spacing.s),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter)
        ])

        heroView.onPrimary = { [weak self] in self?.presenter.primaryAction() }
        failureView.onRetry = { [weak self] in self?.presenter.retry() }
        hubView.onCardAction = { [weak self] id in self?.presenter.openLifeCard(id: id) }
        hubView.onChangeCity = { [weak self] in self?.presenter.changeLifeCity() }
        // A plain UIControl sends touchUpInside (only a UIButton maps its tap to primaryActionTriggered).
        deckRow.addAction(UIAction { [weak self] _ in self?.presenter.changeDeck() }, for: .touchUpInside)
        timeRow.addAction(UIAction { [weak self] _ in self?.presenter.changeBudget() }, for: .touchUpInside)
        levelsRow.addAction(UIAction { [weak self] _ in self?.presenter.openLevels() }, for: .touchUpInside)
    }

    // MARK: TodayViewInterface

    func render(_ state: TodayViewState) {
        subtitleLabel.text = state.subtitle
        subtitleLabel.isHidden = state.subtitle.isEmpty
        switch state.phase {
        case .failed:
            heroView.isHidden = true
            failureView.isHidden = false
            failureView.configure(title: state.failureTitle ?? "", message: state.failureMessage ?? "")
        case .loaded:
            failureView.isHidden = true
            heroView.isHidden = state.hero == nil
            if let hero = state.hero { heroView.configure(hero) }
        }
        settingsGroup.isHidden = state.rows == nil
        if let rows = state.rows {
            deckRow.configure(title: NSLocalizedString("Study deck", comment: ""), value: rows.deckName)
            timeRow.configure(title: NSLocalizedString("Session length", comment: ""), value: rows.sessionLength)
        }
        progressGroup.isHidden = state.progress == nil
        if let progress = state.progress {
            progressTitle.text = progress.title
            progressDetail.text = progress.detail
            progressDetail.isHidden = progress.detail == nil
        }
        dateHeader.isHidden = state.life == nil
        hubView.isHidden = state.life == nil
        if let life = state.life {
            dateHeader.configure(life.header, monthNumber: life.header.month)
            hubView.configure(life)
        }
    }
}

/// The raised indigo block of Today.
final class TodayHeroView: UIView {
    var onPrimary: (() -> Void)?

    private let eyebrow = UILabel()
    private let titleLabel = UILabel()
    private let figureLabel = UILabel()
    private let captionLabel = UILabel()
    private let figureRow = UIStackView()
    private let linesStack = UIStackView()
    private let button = UIButton(configuration: Design.Button.hero(title: ""))
    private var buttonTitle = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Design.Color.hero
        layer.cornerRadius = Design.Radius.panel
        layer.cornerCurve = .continuous

        eyebrow.apply(.eyebrow)
        eyebrow.textColor = Design.Color.onHeroSecondary
        titleLabel.apply(.title)
        titleLabel.textColor = Design.Color.onHero
        titleLabel.accessibilityTraits = .header
        titleLabel.accessibilityIdentifier = "today_hero_title"
        figureLabel.apply(.heroFigure)
        figureLabel.numberOfLines = 1
        figureLabel.adjustsFontSizeToFitWidth = true
        figureLabel.minimumScaleFactor = 0.5
        figureLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        figureLabel.accessibilityIdentifier = "today_figure"
        captionLabel.apply(.meaning)
        captionLabel.textColor = Design.Color.onHeroSecondary
        figureRow.alignment = .lastBaseline
        figureRow.spacing = Design.Spacing.m
        [figureLabel, captionLabel].forEach(figureRow.addArrangedSubview)
        linesStack.axis = .vertical
        linesStack.spacing = Design.Spacing.xs
        button.accessibilityIdentifier = "today_primary"
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        button.addAction(UIAction { [weak self] _ in self?.onPrimary?() }, for: .primaryActionTriggered)

        let stack = UIStackView(arrangedSubviews: [eyebrow, titleLabel, figureRow, linesStack, button])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.xs
        stack.setCustomSpacing(Design.Spacing.m, after: titleLabel)
        stack.setCustomSpacing(Design.Spacing.m, after: figureRow)
        stack.setCustomSpacing(Design.Spacing.l, after: linesStack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.xl - Design.Spacing.xs),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -(Design.Spacing.xl - Design.Spacing.xs)),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.xl - Design.Spacing.xs),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -(Design.Spacing.xl - Design.Spacing.xs))
        ])
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: TodayHeroView, _) in
            view.updateFigureAxis()
            view.updateButton()
        }
        updateFigureAxis()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Number above its caption at accessibility sizes, so neither is squeezed.
    private func updateFigureAxis() {
        figureRow.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
        figureRow.alignment = figureRow.axis == .vertical ? .leading : .lastBaseline
    }

    /// A capsule with an arrow turns into a blob that breaks words at accessibility sizes; there the arrow (decoration) goes and
    /// the corners are those of a rounded rectangle, so the label keeps whole words.
    private func updateButton() {
        var configuration = Design.Button.hero(title: buttonTitle)
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            configuration.image = nil
            configuration.cornerStyle = .large
        }
        button.configuration = configuration
    }

    func configure(_ hero: TodayHero) {
        eyebrow.text = hero.eyebrow
        titleLabel.text = hero.title
        figureLabel.text = hero.figure
        captionLabel.text = hero.caption
        figureRow.isHidden = hero.figure == nil
        linesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for line in hero.lines {
            let label = UILabel()
            label.apply(.meaning)
            label.textColor = Design.Color.onHeroSecondary
            label.text = line
            linesStack.addArrangedSubview(label)
        }
        linesStack.isHidden = hero.lines.isEmpty
        buttonTitle = hero.ctaTitle
        updateButton()
        // VoiceOver reads the number with its caption as one thing, then each line, then the button.
        figureLabel.accessibilityLabel = [hero.figure, hero.caption].compactMap { $0 }.joined(separator: " ")
        captionLabel.isAccessibilityElement = false
        accessibilityElements = [eyebrow, titleLabel] + (hero.figure == nil ? [] : [figureLabel]) + linesStack.arrangedSubviews + [button]
    }
}

/// A row that opens something: a title, an optional value, and a chevron.
final class TodayRowView: UIControl {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let separator = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.apply(.meaning)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.apply(.reading)
        valueLabel.textAlignment = .right
        valueLabel.isUserInteractionEnabled = false
        chevron.tintColor = Design.Color.textSecondary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        separator.backgroundColor = Design.Color.separator
        let row = UIStackView(arrangedSubviews: [titleLabel, valueLabel, chevron])
        row.alignment = .center
        row.spacing = Design.Spacing.s
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        addSubview(separator)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.m),
            row.bottomAnchor.constraint(equalTo: separator.topAnchor, constant: -Design.Spacing.m),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: TodayRowView, _) in
            view.valueLabel.textAlignment = view.traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .left : .right
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? Design.Color.highlight : .clear }
    }

    func configure(title: String, value: String?) {
        titleLabel.text = title
        valueLabel.text = value
        valueLabel.isHidden = value == nil
        accessibilityLabel = [title, value].compactMap { $0 }.joined(separator: ", ")
    }
}

/// Shown instead of the hero when the saved progress cannot be read.
final class TodayFailureView: UIView {
    var onRetry: (() -> Void)?

    private let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let retryButton = UIButton(configuration: Design.Button.primary(title: NSLocalizedString("Try again", comment: "")))

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Design.Color.surface
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        icon.tintColor = Design.Color.warning
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title1)
        icon.isAccessibilityElement = false
        titleLabel.apply(.title)
        titleLabel.textAlignment = .center
        titleLabel.accessibilityTraits = .header
        messageLabel.apply(.reading)
        messageLabel.textAlignment = .center
        retryButton.accessibilityIdentifier = "today_retry"
        retryButton.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .primaryActionTriggered)
        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, messageLabel, retryButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Design.Spacing.s
        stack.setCustomSpacing(Design.Spacing.l, after: messageLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.xl),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.l),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.l)
        ])
        isHidden = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(title: String, message: String) {
        titleLabel.text = title
        messageLabel.text = message
    }
}
