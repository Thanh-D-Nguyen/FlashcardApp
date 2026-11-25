import UIKit

/// The Discover tab: the features of the website that the app offers, one card each. It grows by one card per feature.
final class DiscoverViewController: BaseVC, DiscoverViewInterface {
    var presenter: DiscoverPresenterInterface!

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let hero = DiscoverHeroView()
    private var hasEntered = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        stack.addArrangedSubview(hero)
        for section in DiscoverFeature.Section.allCases {
            let features = presenter.features.filter { $0.section == section }
            guard !features.isEmpty else { continue }
            if let title = section.title {
                let header = UILabel()
                header.apply(.sectionTitle)
                header.text = title
                header.accessibilityTraits = .header
                stack.addArrangedSubview(header)
                stack.setCustomSpacing(Design.Spacing.s, after: header)
            }
            features.forEach { stack.addArrangedSubview(card(for: $0)) }
        }
        prepareEntrance()
        presenter.viewDidLoad()
    }

    /// The blocks wait out of sight until the tab appears, then rise one after another.
    private func prepareEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        for view in stack.arrangedSubviews {
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 0, y: 28).scaledBy(x: 0.96, y: 0.96)
        }
    }

    private func playEntrance() {
        guard !hasEntered else { return }
        hasEntered = true
        for (index, view) in stack.arrangedSubviews.enumerated() {
            UIView.animate(withDuration: 0.7, delay: 0.07 * Double(index), usingSpringWithDamping: 0.78, initialSpringVelocity: 0.5, options: [.allowUserInteraction]) {
                view.alpha = 1
                view.transform = .identity
            }
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playEntrance()
        stack.arrangedSubviews.compactMap { $0 as? DiscoverFeatureCard }.forEach { $0.startAmbient() }
        #if DEBUG
        debugActions()
        #endif
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stack.arrangedSubviews.compactMap { $0 as? DiscoverFeatureCard }.forEach { $0.stopAmbient() }
    }

    #if DEBUG
    private var openedFromLaunchArgument = false

    private func debugActions() {
        let arguments = ProcessInfo.processInfo.arguments
        // `-DiscoverRevealFind` breaks the seal of the find card at launch, for screenshots.
        if arguments.contains("-DiscoverRevealFind") { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.hero.findCard.reveal() } }
        // `-DiscoverOpenLoto` / `-DiscoverOpenMagazine` push that screen at launch, for screenshots and UI tests.
        if !openedFromLaunchArgument, arguments.contains("-DiscoverOpenLoto") {
            openedFromLaunchArgument = true
            presenter.select(.loto)
        } else if !openedFromLaunchArgument, arguments.contains("-DiscoverOpenMagazine") {
            openedFromLaunchArgument = true
            presenter.select(.magazine)
        }
    }
    #endif

    private func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .always
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "discover_screen"
        stack.axis = .vertical
        stack.spacing = Design.Spacing.l
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Design.Spacing.s),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter)
        ])
    }

    private func card(for feature: DiscoverFeature) -> UIView {
        let card = DiscoverFeatureCard(feature: feature)
        card.addAction(UIAction { [weak self] _ in self?.presenter.select(feature) }, for: .touchUpInside)
        return card
    }
}

extension DiscoverViewController {
    func showNextDraw(_ draw: DiscoverNextDraw?) {
        stack.arrangedSubviews.compactMap { $0 as? DiscoverFeatureCard }.forEach { $0.show(nextDraw: draw) }
    }
    func showFind(_ find: DiscoverFind?) { hero.show(find: find, animated: true) }
}

/// One feature as a tappable card: its symbol, name, a line about it and what it contains.
final class DiscoverFeatureCard: UIControl {
    private let tile = MagazineSymbolTile(side: 44)
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let isFeatured: Bool
    private let isCompact: Bool
    private let restingColor: UIColor
    private let contentStack = UIStackView()
    private let compactTopRow = UIStackView()
    private let compactText = UIStackView()
    private let compactSpacer = UIView()
    private var spheres: [UIView] = []
    private let countdownLabel = UILabel()
    private var nextDraw: DiscoverNextDraw?
    private var timer: Timer?
    private let sheen = CAGradientLayer()

    init(feature: DiscoverFeature) {
        isFeatured = feature.isFeatured
        isCompact = feature.tags.isEmpty
        restingColor = feature.isFeatured ? Design.Color.hero : Design.Color.surface
        super.init(frame: .zero)
        if feature.isFeatured {
            backgroundColor = restingColor
            layer.cornerRadius = Design.Radius.card
            layer.cornerCurve = .continuous
        } else {
            applyCardSurface(radius: Design.Radius.card, background: restingColor)
        }

        tile.configure(symbol: feature.symbol, tint: Design.Color.accent)
        chevron.tintColor = Design.Color.textSecondary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline, scale: .medium)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.apply(.headword)
        titleLabel.font = Design.TextRole.weighted(.title3, weight: .semibold)
        titleLabel.text = feature.title
        subtitleLabel.apply(.reading)
        subtitleLabel.text = feature.subtitle

        if isCompact {
            // A plain entry is one compact row (symbol, name and line, chevron): six of them fit a phone screen.
            tile.setContentHuggingPriority(.required, for: .horizontal)
            compactText.axis = .vertical
            compactText.spacing = Design.Spacing.xs
            compactText.addArrangedSubview(titleLabel)
            compactText.addArrangedSubview(subtitleLabel)
            compactTopRow.axis = .horizontal
            compactTopRow.alignment = .center
            compactTopRow.spacing = Design.Spacing.m
            updateCompactLayout()
            registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (card: DiscoverFeatureCard, _) in
                card.updateCompactLayout()
            }
        } else {
            // The featured entry keeps room for what it contains. Tags wrap on a narrow screen or at large text.
            let tagFlow = DiscoverTagFlow(tags: feature.tags, isOnHero: feature.isFeatured)
            let top = UIStackView(arrangedSubviews: [tile, UIView(), chevron])
            top.alignment = .center
            countdownLabel.apply(.metadata)
            countdownLabel.textColor = LotoPalette.gold
            countdownLabel.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .monospacedDigitSystemFont(ofSize: 14, weight: .bold))
            countdownLabel.isHidden = true
            [top, titleLabel, subtitleLabel, countdownLabel, tagFlow].forEach { contentStack.addArrangedSubview($0) }
            contentStack.axis = .vertical
            contentStack.spacing = Design.Spacing.s
            contentStack.setCustomSpacing(Design.Spacing.m, after: top)
            contentStack.setCustomSpacing(Design.Spacing.m, after: subtitleLabel)
        }
        contentStack.isUserInteractionEnabled = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum),
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.l),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.l),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.l),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.l)
        ])

        isAccessibilityElement = true
        accessibilityLabel = feature.title
        accessibilityHint = feature.subtitle
        accessibilityTraits = .button
        accessibilityIdentifier = feature.accessibilityIdentifier
        if feature.isFeatured { styleAsHero() }
    }

    private func updateCompactLayout() {
        guard isCompact else { return }
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        contentStack.arrangedSubviews.forEach { contentStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        compactTopRow.arrangedSubviews.forEach { compactTopRow.removeArrangedSubview($0); $0.removeFromSuperview() }
        if isAX {
            contentStack.axis = .vertical
            contentStack.alignment = .fill
            contentStack.spacing = Design.Spacing.m
            [tile, compactSpacer, chevron].forEach { compactTopRow.addArrangedSubview($0) }
            contentStack.addArrangedSubview(compactTopRow)
            contentStack.addArrangedSubview(compactText)
        } else {
            contentStack.axis = .horizontal
            contentStack.alignment = .center
            contentStack.spacing = Design.Spacing.m
            [tile, compactText, chevron].forEach { contentStack.addArrangedSubview($0) }
        }
    }

    /// The featured entry sits on the indigo hero block with a row of plain spheres: light, not a promise of any number.
    private func styleAsHero() {
        tile.configure(symbol: "circle.hexagongrid.fill", tint: LotoPalette.gold)
        tile.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        titleLabel.textColor = Design.Color.onHero
        subtitleLabel.textColor = Design.Color.onHeroSecondary
        chevron.tintColor = Design.Color.onHero
        layer.masksToBounds = true
        for (index, tag) in ([LotoTag.hot, .overdue, .recent, .cold, .hot]).enumerated() {
            let size: CGFloat = [64, 40, 28, 52, 34][index]
            let sphere = UIView()
            sphere.isUserInteractionEnabled = false
            sphere.backgroundColor = tag.ballColor.withAlphaComponent(0.55)
            sphere.layer.cornerRadius = size / 2
            sphere.translatesAutoresizingMaskIntoConstraints = false
            insertSubview(sphere, at: 0)
            spheres.append(sphere)
            NSLayoutConstraint.activate([
                sphere.widthAnchor.constraint(equalToConstant: size), sphere.heightAnchor.constraint(equalToConstant: size),
                sphere.centerXAnchor.constraint(equalTo: trailingAnchor, constant: [-26, -92, -150, -56, -120][index]),
                sphere.centerYAnchor.constraint(equalTo: topAnchor, constant: [32, 58, 24, 112, 128][index])
            ])
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        sheen.frame = CGRect(x: -bounds.width, y: 0, width: bounds.width * 3, height: bounds.height)
    }

    /// The spheres of the featured card float, each at its own pace, and a band of light sweeps across now and then.
    func startAmbient() {
        guard isFeatured, !UIAccessibility.isReduceMotionEnabled else { return }
        for (index, sphere) in spheres.enumerated() where sphere.layer.animation(forKey: "float") == nil {
            let float = CABasicAnimation(keyPath: "transform.translation.y")
            float.fromValue = -6 - Double(index)
            float.toValue = 6 + Double(index)
            float.duration = 2.2 + 0.45 * Double(index)
            float.autoreverses = true
            float.repeatCount = .infinity
            float.timeOffset = 0.5 * Double(index)
            float.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            sphere.layer.add(float, forKey: "float")
        }
        if sheen.superlayer == nil {
            sheen.colors = [UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.16).cgColor, UIColor.clear.cgColor]
            sheen.startPoint = CGPoint(x: 0, y: 0.4)
            sheen.endPoint = CGPoint(x: 1, y: 0.6)
            sheen.locations = [0.4, 0.5, 0.6]
            layer.addSublayer(sheen)
        }
        let sweep = CABasicAnimation(keyPath: "transform.translation.x")
        sweep.fromValue = -bounds.width
        sweep.toValue = bounds.width
        sweep.duration = 1.6
        let pause = CAAnimationGroup()
        pause.animations = [sweep]
        pause.duration = 5
        pause.repeatCount = .infinity
        sheen.add(pause, forKey: "sweep")
    }

    /// The time left to the next draw, ticking, on the Loto card only.
    func show(nextDraw: DiscoverNextDraw?) {
        guard isFeatured else { return }
        self.nextDraw = nextDraw
        tick()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        timer?.invalidate()
        timer = nil
        guard window != nil, isFeatured else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard let nextDraw, let left = LotoCountdown.until(nextDraw.instant, now: Date()) else { countdownLabel.isHidden = true; return }
        let time = String(format: NSLocalizedString("%d days %02d:%02d:%02d", comment: "Discover: time left to the draw"), left.days, left.hours, left.minutes, left.seconds)
        countdownLabel.text = String(format: NSLocalizedString("%@ · next draw in %@", comment: "Discover: game and time left to its draw"), nextDraw.game.title, time)
        countdownLabel.isHidden = false
        // Without the seconds, so VoiceOver does not read a stream of changing numbers.
        accessibilityValue = nextDraw.game.title + ": " + String(format: NSLocalizedString("Time until the draw: %d days, %d hours, %d minutes", comment: "VoiceOver countdown"),
                                                                 left.days, left.hours, left.minutes)
    }

    deinit { timer?.invalidate() }

    func stopAmbient() {
        spheres.forEach { $0.layer.removeAnimation(forKey: "float") }
        sheen.removeAnimation(forKey: "sweep")
    }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? (isFeatured ? restingColor.withAlphaComponent(0.85) : Design.Color.highlight.blended(over: Design.Color.surface)) : restingColor
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            if isHighlighted { UISelectionFeedbackGenerator().selectionChanged() }
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0, options: [.allowUserInteraction]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.965, y: 0.965) : .identity
            }
        }
    }

}

/// Short labels laid out left to right and wrapped to the next row when they do not fit.
final class DiscoverTagFlow: UIView {
    private let tags: [String]
    private var labels: [UIView] = []
    private let rowSpacing = Design.Spacing.s
    private let columnSpacing = Design.Spacing.s

    init(tags: [String], isOnHero: Bool = false) {
        self.tags = tags
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        labels = tags.map { Self.chip($0, isOnHero: isOnHero) }
        labels.forEach(addSubview)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: DiscoverTagFlow, _) in
            view.invalidateIntrinsicContentSize()
            view.setNeedsLayout()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private static func chip(_ text: String, isOnHero: Bool) -> UIView {
        let label = UILabel()
        label.apply(.metadata)
        label.numberOfLines = 1
        label.text = text
        label.textAlignment = .center
        label.layer.cornerRadius = Design.Radius.chip
        label.layer.cornerCurve = .continuous
        label.layer.masksToBounds = true
        label.backgroundColor = isOnHero ? Design.Color.heroChipFill : Design.Color.surfaceTint
        label.textColor = isOnHero ? Design.Color.onHero : Design.Color.textSecondary
        return label
    }

    private func chipSize(_ view: UIView, maxWidth: CGFloat) -> CGSize {
        guard let label = view as? UILabel else { return .zero }
        let size = label.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        return CGSize(width: min(size.width + Design.Spacing.m * 2, maxWidth), height: size.height + Design.Spacing.xs * 2)
    }

    private func arrange(width: CGFloat, apply: Bool) -> CGSize {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in labels {
            let size = chipSize(view, maxWidth: width)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            if apply { view.frame = CGRect(origin: CGPoint(x: x, y: y), size: size) }
            x += size.width + columnSpacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    /// Height at the width the view was last laid out with; the stack reads it through `intrinsicContentSize`.
    private var fittedHeight: CGFloat = 0

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = arrange(width: bounds.width, apply: true)
        if abs(size.height - fittedHeight) > 0.5 {
            fittedHeight = size.height
            invalidateIntrinsicContentSize()
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize { arrange(width: size.width, apply: false) }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: fittedHeight)
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
                                          verticalFittingPriority: UILayoutPriority) -> CGSize {
        let width = targetSize.width > 0 ? targetSize.width : (bounds.width > 0 ? bounds.width : 320)
        let height = arrange(width: width, apply: false).height
        if abs(height - fittedHeight) > 0.5 {
            fittedHeight = height
            invalidateIntrinsicContentSize()
        }
        return CGSize(width: targetSize.width, height: height)
    }
}

extension UIColor {
    /// This color drawn over an opaque one, as a flat color (so a pressed state does not reveal what is behind it).
    func blended(over base: UIColor) -> UIColor {
        UIColor { traits in
            let top = self.resolvedColor(with: traits), bottom = base.resolvedColor(with: traits)
            var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
            var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
            top.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
            bottom.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
            return UIColor(red: tr * ta + br * (1 - ta), green: tg * ta + bg * (1 - ta), blue: tb * ta + bb * (1 - ta), alpha: 1)
        }
    }
}
