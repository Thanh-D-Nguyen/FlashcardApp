import UIKit

/// Today: the day and what was saved in it, then the life hub as the banner to learn from, then the deck being studied with its session
/// length (the learner scrolls for it), and the levels at the end. Native large title and tab bar; the hero is content, never glass.
final class TodayViewController: BaseViewController, TodayViewInterface {
    var presenter: TodayPresenterInterface!

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let dateHeader = TodayDateHeaderView()
    private let progressGroup = UIStackView()
    private let progressTitle = UILabel()
    private let progressDetail = UILabel()
    private let heroView = TodayHeroView()
    private let failureView = TodayFailureView()
    private let hubView = TodayLifeHubView()
    private let scenarioBanner = TodayScenarioBannerView()
    private let levelsRow = TodayRowView()
    private let lessonSlot = TodayLessonSlotView()
    private let streakView = TodayStreakView()
    private let radarCard = TodayLessonSlotView()
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

        // The title says "today" itself ("Hôm nay …"), so the block needs no separate heading.
        progressGroup.axis = .vertical
        progressGroup.spacing = Design.Spacing.xs
        progressTitle.apply(.meaning)
        progressTitle.accessibilityIdentifier = "today_progress"
        progressDetail.apply(.metadata)
        [progressTitle, progressDetail].forEach(progressGroup.addArrangedSubview)

        levelsRow.configure(title: NSLocalizedString("Study by level", comment: "Row that opens the JLPT levels"), value: nil)
        levelsRow.accessibilityIdentifier = "today_levels_row"

        dateHeader.isHidden = true
        hubView.isHidden = true
        hubView.accessibilityIdentifier = "today_life_hub"
        [dateHeader, progressGroup, streakView, hubView, scenarioBanner, heroView, failureView, lessonSlot, radarCard, levelsRow].forEach(stack.addArrangedSubview)
        stack.setCustomSpacing(Design.Spacing.m, after: progressGroup)
        stack.setCustomSpacing(Design.Spacing.m, after: streakView)
        streakView.isHidden = true
        stack.setCustomSpacing(Design.Spacing.m, after: hubView)
        stack.setCustomSpacing(Design.Spacing.l, after: scenarioBanner)
        stack.setCustomSpacing(Design.Spacing.l, after: heroView)

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
        heroView.onChangeDeck = { [weak self] in self?.presenter.changeDeck() }
        heroView.onChangeBudget = { [weak self] in self?.presenter.changeBudget() }
        failureView.onRetry = { [weak self] in self?.presenter.retry() }
        hubView.onCardAction = { [weak self] id in self?.presenter.openLifeCard(id: id) }
        hubView.onChangeCity = { [weak self] in self?.presenter.changeLifeCity() }
        scenarioBanner.addAction(UIAction { [weak self] _ in self?.presenter.openScenarios() }, for: .touchUpInside)
        levelsRow.addAction(UIAction { [weak self] _ in self?.presenter.openLevels() }, for: .touchUpInside)
        lessonSlot.isHidden = true
        lessonSlot.addAction(UIAction { [weak self] _ in self?.presenter.openLessonSlot() }, for: .touchUpInside)
        radarCard.isHidden = true
        radarCard.accessibilityIdentifier = "today_radar_card"
        radarCard.addAction(UIAction { [weak self] _ in self?.presenter.openRadar() }, for: .touchUpInside)
    }

    // MARK: TodayViewInterface

    func render(_ state: TodayViewState) {
        switch state.phase {
        case .failed:
            heroView.isHidden = true
            failureView.isHidden = false
            failureView.configure(title: state.failureTitle ?? "", message: state.failureMessage ?? "")
        case .loaded:
            failureView.isHidden = true
            heroView.isHidden = state.hero == nil
            if let hero = state.hero { heroView.configure(hero, rows: state.rows) }
        }
        lessonSlot.isHidden = state.lessonCard == nil
        if let card = state.lessonCard { lessonSlot.configure(card) }
        radarCard.isHidden = state.radar == nil
        if let radar = state.radar {
            radarCard.configure(eyebrow: radar.eyebrow.isEmpty ? NSLocalizedString("DAILY RADAR", comment: "Today: eyebrow of the Daily Radar card") : radar.eyebrow.uppercased(),
                                title: radar.expression, detail: [radar.title, radar.detail].compactMap { $0 }.joined(separator: "\n"),
                                cta: NSLocalizedString("Read the card", comment: "Today: opens the Daily Radar card"))
        }
        streakView.isHidden = state.streak == nil
        if let streak = state.streak { streakView.configure(streak) }
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

/// The raised indigo block of Today: the deck being studied, what is due in it, and its session length. The play icon at the top right
/// studies the deck; the title opens the deck choice; the session length is changed on its chip. Without a deck there is nothing to play,
/// so the one action is a text button.
final class TodayHeroView: UIView {
    var onPrimary: (() -> Void)?
    var onChangeDeck: (() -> Void)?
    var onChangeBudget: (() -> Void)?

    private let eyebrow = UILabel()
    private let titleControl = UIControl()
    private let titleLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let playButton = UIButton(configuration: Design.Button.heroIcon())
    private let figureLabel = UILabel()
    private let captionLabel = UILabel()
    private let figureSpacer = UIView()
    private let figureRow = UIStackView()
    private let linesStack = UIStackView()
    private let button = UIButton(configuration: Design.Button.hero(title: ""))
    private let sessionButton = UIButton(configuration: Design.Button.heroChip(title: ""))
    private var buttonTitle = ""
    private var sessionTitle = ""

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
        chevron.tintColor = Design.Color.onHeroSecondary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote)
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        // A plain UIControl sends touchUpInside (only a UIButton maps its tap to primaryActionTriggered).
        titleControl.accessibilityIdentifier = "today_deck_row"
        titleControl.addAction(UIAction { [weak self] _ in self?.onChangeDeck?() }, for: .touchUpInside)
        let titleRow = UIStackView(arrangedSubviews: [titleLabel, chevron])
        titleRow.alignment = .center
        titleRow.spacing = Design.Spacing.xs
        titleRow.isUserInteractionEnabled = false
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        titleControl.addSubview(titleRow)
        NSLayoutConstraint.activate([
            titleRow.topAnchor.constraint(equalTo: titleControl.topAnchor),
            titleRow.bottomAnchor.constraint(equalTo: titleControl.bottomAnchor),
            titleRow.leadingAnchor.constraint(equalTo: titleControl.leadingAnchor),
            titleRow.trailingAnchor.constraint(equalTo: titleControl.trailingAnchor)
        ])

        playButton.accessibilityIdentifier = "today_primary"
        playButton.addAction(UIAction { [weak self] _ in self?.onPrimary?() }, for: .primaryActionTriggered)
        playButton.setContentHuggingPriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            playButton.widthAnchor.constraint(equalToConstant: 44),
            playButton.heightAnchor.constraint(equalToConstant: 44)
        ])

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
        // The session length sits on the figure's row, at its trailing edge: one line instead of a row of its own.
        figureSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        sessionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        [figureLabel, captionLabel, figureSpacer, sessionButton].forEach(figureRow.addArrangedSubview)
        linesStack.axis = .vertical
        linesStack.spacing = Design.Spacing.xs

        button.accessibilityIdentifier = "today_primary"
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        button.addAction(UIAction { [weak self] _ in self?.onPrimary?() }, for: .primaryActionTriggered)
        sessionButton.accessibilityIdentifier = "today_time_row"
        sessionButton.addAction(UIAction { [weak self] _ in self?.onChangeBudget?() }, for: .primaryActionTriggered)
        sessionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        sessionButton.setContentHuggingPriority(.required, for: .horizontal)

        let titleBlock = UIStackView(arrangedSubviews: [eyebrow, titleControl])
        titleBlock.axis = .vertical
        titleBlock.spacing = Design.Spacing.xs
        let header = UIStackView(arrangedSubviews: [titleBlock, playButton])
        header.alignment = .top
        header.spacing = Design.Spacing.m

        let stack = UIStackView(arrangedSubviews: [header, figureRow, linesStack, button])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.s
        stack.setCustomSpacing(Design.Spacing.xs, after: figureRow)
        stack.setCustomSpacing(Design.Spacing.m, after: linesStack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.m),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.m),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.l),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.l)
        ])
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: TodayHeroView, _) in
            view.updateFigureAxis()
            view.updateButton()
            view.updateSessionButton()
        }
        updateFigureAxis()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Number above its caption at accessibility sizes, so neither is squeezed.
    private func updateFigureAxis() {
        figureRow.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
        figureRow.alignment = figureRow.axis == .vertical ? .leading : .lastBaseline
        figureSpacer.isHidden = figureRow.axis == .vertical
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

    private func updateSessionButton() {
        sessionButton.configuration = Design.Button.heroChip(title: sessionTitle)
    }

    func configure(_ hero: TodayHero, rows: TodayRows?) {
        let deckState = rows != nil
        eyebrow.text = hero.eyebrow
        titleLabel.text = hero.title
        // Only a deck can be changed from its title: without one the title is plain text, read on its own.
        titleControl.isUserInteractionEnabled = deckState
        titleControl.isAccessibilityElement = deckState
        titleControl.accessibilityTraits = deckState ? .button : []
        titleControl.accessibilityLabel = deckState ? "\(NSLocalizedString("Study deck", comment: "")), \(hero.title)" : nil
        titleLabel.isAccessibilityElement = !deckState
        chevron.isHidden = !deckState
        figureLabel.text = hero.figure
        captionLabel.text = hero.caption
        figureLabel.isHidden = hero.figure == nil
        captionLabel.isHidden = hero.caption == nil
        // The row stays for the session length even when there is no count to show (nothing due, done for today).
        figureRow.isHidden = hero.figure == nil && rows == nil
        linesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for line in hero.lines {
            let label = UILabel()
            label.apply(.meaning)
            label.textColor = Design.Color.onHeroSecondary
            label.text = line
            linesStack.addArrangedSubview(label)
        }
        linesStack.isHidden = hero.lines.isEmpty

        playButton.isHidden = !deckState
        playButton.accessibilityLabel = hero.ctaTitle
        button.isHidden = deckState
        buttonTitle = hero.ctaTitle
        updateButton()

        sessionButton.isHidden = rows == nil
        if let rows {
            sessionTitle = rows.sessionLength
            updateSessionButton()
            sessionButton.accessibilityLabel = "\(NSLocalizedString("Session length", comment: "")), \(rows.sessionLength)"
        }

        // VoiceOver reads the number with its caption as one thing, then each line, then the actions.
        figureLabel.accessibilityLabel = [hero.figure, hero.caption].compactMap { $0 }.joined(separator: " ")
        captionLabel.isAccessibilityElement = false
        let figure: [UIView] = hero.figure == nil ? [] : [figureLabel]
        if deckState {
            accessibilityElements = [titleControl] + figure + linesStack.arrangedSubviews + [playButton, sessionButton]
        } else {
            accessibilityElements = [eyebrow, titleLabel] + figure + linesStack.arrangedSubviews + [button]
        }
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
