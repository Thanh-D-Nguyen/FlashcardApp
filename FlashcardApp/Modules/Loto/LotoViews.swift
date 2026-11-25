import UIKit

private func label(_ role: Design.TextRole, _ text: String? = nil, color: UIColor? = nil) -> UILabel {
    let label = UILabel()
    label.apply(role)
    label.text = text
    if let color { label.textColor = color }
    return label
}

/// A white (dark: raised) panel with the screen's standard padding.
class LotoPanel: UIView {
    let content = UIStackView()

    init(spacing: CGFloat = Design.Spacing.m, fill: UIColor = Design.Color.surface) {
        super.init(frame: .zero)
        applyCardSurface(radius: Design.Radius.card, background: fill)
        content.axis = .vertical
        content.spacing = spacing
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.l),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.l),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.l),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.l)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

// MARK: Hero with countdown

/// The next draw: which game, when, and a ticking countdown in four tiles.
final class LotoHeroView: UIView {
    private let draw: LotoDraw
    private let now: () -> Date
    private let gradient = CAGradientLayer()
    private let tiles = (0..<4).map { _ in LotoCountdownTile() }
    private let countdownStack = UIStackView()
    private let finishedLabel = UILabel()
    private var timer: Timer?

    init(draw: LotoDraw, now: @escaping () -> Date = Date.init) {
        self.draw = draw
        self.now = now
        super.init(frame: .zero)
        layer.cornerRadius = Design.Radius.panel
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradient, at: 0)
        addDecoration()

        let eyebrow = label(.eyebrow, NSLocalizedString("Next draw", comment: "Loto hero eyebrow").uppercased(), color: LotoPalette.gold)
        let title = label(.display, draw.game.title, color: Design.Color.onHero)
        let when = label(.reading, Self.whenText(draw), color: Design.Color.onHeroSecondary)
        var lines: [UIView] = [eyebrow, title, when]
        if let number = draw.drawNumber {
            let text = String(format: draw.drawNumberIsEstimate ? NSLocalizedString("Draw no. %@ (estimated)", comment: "Loto draw number, estimated")
                                                                : NSLocalizedString("Draw no. %@", comment: "Loto draw number"),
                              number.formatted(.number.locale(AppLanguage.current.locale).grouping(.never)))
            lines.append(label(.metadata, text, color: Design.Color.onHeroSecondary))
        }

        countdownStack.spacing = Design.Spacing.s
        rebuildCountdownLayout()
        finishedLabel.apply(.title)
        finishedLabel.textColor = Design.Color.onHero
        finishedLabel.text = NSLocalizedString("The draw time has come. Check the official result.", comment: "Loto hero when the draw is due")
        finishedLabel.isHidden = true

        let stack = UIStackView(arrangedSubviews: lines + [countdownStack, finishedLabel])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.xs
        stack.setCustomSpacing(Design.Spacing.l, after: lines.last ?? title)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.xl),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.xl)
        ])
        isAccessibilityElement = false
        applyGradientColors()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: LotoHeroView, _) in
            view.applyGradientColors()
        }
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: LotoHeroView, _) in
            view.rebuildCountdownLayout()
        }
        update()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func applyGradientColors() {
        gradient.colors = [
            Design.Color.hero.resolvedColor(with: traitCollection).cgColor,
            Design.Color.heroDeep.resolvedColor(with: traitCollection).cgColor
        ]
    }

    /// Four tiles across at normal text sizes; a 2x2 grid at accessibility sizes so unit captions never truncate.
    private func rebuildCountdownLayout() {
        countdownStack.arrangedSubviews.forEach {
            countdownStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        tiles.forEach { $0.removeFromSuperview() }
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            let topRow = UIStackView(arrangedSubviews: Array(tiles.prefix(2)))
            topRow.axis = .horizontal
            topRow.distribution = .fillEqually
            topRow.spacing = Design.Spacing.s
            let bottomRow = UIStackView(arrangedSubviews: Array(tiles.suffix(2)))
            bottomRow.axis = .horizontal
            bottomRow.distribution = .fillEqually
            bottomRow.spacing = Design.Spacing.s
            countdownStack.axis = .vertical
            countdownStack.distribution = .fillEqually
            countdownStack.addArrangedSubview(topRow)
            countdownStack.addArrangedSubview(bottomRow)
        } else {
            countdownStack.axis = .horizontal
            countdownStack.distribution = .fillEqually
            tiles.forEach(countdownStack.addArrangedSubview)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        timer?.invalidate()
        guard window != nil, draw.drawInstant != nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.update() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        update()
    }

    deinit { timer?.invalidate() }

    private func update() {
        guard let instant = draw.drawInstant else {
            countdownStack.isHidden = true
            return
        }
        guard let left = LotoCountdown.until(instant, now: now()) else {
            countdownStack.isHidden = true
            finishedLabel.isHidden = false
            timer?.invalidate()
            return
        }
        let values = [left.days, left.hours, left.minutes, left.seconds]
        let captions = [NSLocalizedString("days", comment: "Countdown unit"), NSLocalizedString("hours", comment: "Countdown unit"),
                        NSLocalizedString("min", comment: "Countdown unit"), NSLocalizedString("sec", comment: "Countdown unit")]
        for (tile, pair) in zip(tiles, zip(values, captions)) { tile.set(value: pair.0, caption: pair.1) }
        // VoiceOver reads minutes, not a number that changes every second.
        countdownStack.isAccessibilityElement = true
        countdownStack.accessibilityLabel = String(format: NSLocalizedString("Time until the draw: %d days, %d hours, %d minutes", comment: "VoiceOver countdown"),
                                                   left.days, left.hours, left.minutes)
    }

    static func whenText(_ draw: LotoDraw) -> String {
        [draw.day.formatted(.full), draw.drawTime].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// A few faint balls behind the text, for depth. Decorative.
    private func addDecoration() {
        for (x, y, d, alpha) in [(-30, 40, 90, 0.10), (-120, 120, 46, 0.07), (10, 170, 120, 0.06)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            let ball = UIView()
            ball.backgroundColor = UIColor.white.withAlphaComponent(alpha)
            ball.layer.cornerRadius = d / 2
            ball.isUserInteractionEnabled = false
            ball.translatesAutoresizingMaskIntoConstraints = false
            addSubview(ball)
            NSLayoutConstraint.activate([
                ball.widthAnchor.constraint(equalToConstant: d), ball.heightAnchor.constraint(equalToConstant: d),
                ball.centerXAnchor.constraint(equalTo: trailingAnchor, constant: x),
                ball.centerYAnchor.constraint(equalTo: topAnchor, constant: y)
            ])
        }
    }
}

private final class LotoCountdownTile: UIView {
    private let valueLabel = UILabel()
    private let captionLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.white.withAlphaComponent(0.12)
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        let metrics = UIFontMetrics(forTextStyle: .title1)
        let base = UIFont.systemFont(ofSize: 30, weight: .heavy)
        let rounded = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 30) } ?? base
        valueLabel.font = metrics.scaledFont(for: rounded, maximumPointSize: 44)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.6
        valueLabel.textColor = Design.Color.onHero
        valueLabel.textAlignment = .center
        captionLabel.apply(.metadata)
        captionLabel.textColor = Design.Color.onHeroSecondary
        captionLabel.textAlignment = .center
        captionLabel.numberOfLines = 1
        captionLabel.adjustsFontSizeToFitWidth = true
        captionLabel.minimumScaleFactor = 0.75
        let stack = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.m),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.m),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.xs),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.xs)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func set(value: Int, caption: String) {
        valueLabel.text = String(format: "%02d", value)
        captionLabel.text = caption
    }
}

// MARK: Notice

/// The statement that every combination has the same chance, with the real odds. It sits above the numbers, not under them.
final class LotoNoticeView: LotoPanel {
    init(draw: LotoDraw) {
        super.init(spacing: Design.Spacing.s, fill: Design.Color.warning.withAlphaComponent(0.12))
        let icon = UIImageView(image: UIImage(systemName: "info.circle.fill"))
        icon.tintColor = Design.Color.warning
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let heading = label(.title, NSLocalizedString("Every combination has the same chance", comment: "Loto notice title"), color: Design.Color.textPrimary)
        let header = UIStackView(arrangedSubviews: [icon, heading])
        header.spacing = Design.Spacing.s
        header.alignment = .firstBaseline
        let odds = String(format: NSLocalizedString("Chance of the top prize: 1 in %@", comment: "Loto notice odds"),
                          draw.game.combinations.formatted(.number.locale(AppLanguage.current.locale)))
        let body = label(.reading, draw.disclaimer, color: Design.Color.textPrimary)
        let oddsLabel = label(.metadata, odds, color: Design.Color.textSecondary)
        [header, body, oddsLabel].forEach(content.addArrangedSubview)
        isAccessibilityElement = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

// MARK: Set card

final class LotoSetCardView: LotoPanel {
    private let set: LotoSet
    private let onCopy: (LotoSet) -> Void
    private var balls: [LotoBallView] = []
    private let detailsStack = UIStackView()
    private let detailsButton = UIButton(type: .system)

    init(set: LotoSet, draw: LotoDraw, onCopy: @escaping (LotoSet) -> Void) {
        self.set = set
        self.onCopy = onCopy
        super.init(spacing: Design.Spacing.m)

        let rank = label(.eyebrow, String(format: NSLocalizedString("Set %d", comment: "Loto: number of a set"), max(set.rank, 1)).uppercased(), color: Design.Color.textSecondary)
        let title = label(.title, NSLocalizedString("Numbers for this draw", comment: "Loto set card title"), color: Design.Color.textPrimary)
        [rank, title].forEach(content.addArrangedSubview)
        content.setCustomSpacing(Design.Spacing.l, after: title)

        let byNumber = Dictionary(set.numbers.map { ($0.number, $0) }, uniquingKeysWith: { first, _ in first })
        let diameter = min(UIFontMetrics(forTextStyle: .body).scaledValue(for: 44), 60)
        balls = set.main.map { LotoBallView(number: $0, tag: byNumber[$0]?.primaryTag ?? draw.signals.tag(of: $0), diameter: diameter) }
        let bonus = set.bonus.map { LotoBallView(number: $0, tag: nil, isBonus: true, diameter: diameter) }
        let flow = LotoFlowView(views: balls + bonus)
        flow.spacing = Design.Spacing.s + 2
        content.addArrangedSubview(flow)
        if !set.bonus.isEmpty {
            content.addArrangedSubview(label(.metadata, NSLocalizedString("Ring = bonus number", comment: "Loto: bonus number legend"), color: Design.Color.textSecondary))
        }

        if let shape = set.shape { content.addArrangedSubview(Self.shapeRow(shape)) }

        detailsStack.axis = .vertical
        detailsStack.spacing = Design.Spacing.s
        detailsStack.isHidden = true
        for number in set.main.compactMap({ byNumber[$0] }) { detailsStack.addArrangedSubview(Self.detailRow(number)) }

        var copyConfiguration = Design.Button.primary(title: NSLocalizedString("Copy numbers", comment: "Loto: copy a set"), traits: traitCollection)
        copyConfiguration.image = UIImage(systemName: "doc.on.doc")
        copyConfiguration.imagePadding = Design.Spacing.s
        copyConfiguration.buttonSize = .large
        let copy = UIButton(configuration: copyConfiguration)
        copy.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        copy.enableAdaptiveCornerStyle()
        copy.accessibilityIdentifier = "loto_copy_\(set.rank)"
        copy.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onCopy(self.set)
        }, for: .touchUpInside)

        if !detailsStack.arrangedSubviews.isEmpty {
            detailsButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
            detailsButton.addAction(UIAction { [weak self] _ in self?.toggleDetails() }, for: .touchUpInside)
            detailsButton.accessibilityIdentifier = "loto_why_\(set.rank)"
            updateDetailsButton()
            content.addArrangedSubview(detailsButton)
            content.addArrangedSubview(detailsStack)
        }
        content.addArrangedSubview(copy)
        isAccessibilityElement = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Plays the pop-in of the balls one after the other.
    func animateBalls() {
        for (index, ball) in balls.enumerated() { ball.popIn(delay: 0.06 * Double(index)) }
    }

    private func toggleDetails() {
        let show = detailsStack.isHidden
        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.25) {
            self.detailsStack.isHidden = !show
            self.detailsStack.alpha = show ? 1 : 0
            self.superview?.layoutIfNeeded()
        }
        updateDetailsButton()
    }

    private func updateDetailsButton() {
        var configuration = UIButton.Configuration.plain()
        configuration.title = detailsStack.isHidden ? NSLocalizedString("Why these numbers?", comment: "Loto: show the reasons") : NSLocalizedString("Hide details", comment: "Loto: hide the reasons")
        configuration.image = UIImage(systemName: detailsStack.isHidden ? "chevron.down" : "chevron.up")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = Design.Spacing.s
        configuration.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.s, leading: 0, bottom: Design.Spacing.s, trailing: 0)
        detailsButton.configuration = configuration
        detailsButton.contentHorizontalAlignment = .leading
        detailsButton.accessibilityValue = detailsStack.isHidden ? nil : NSLocalizedString("Expanded", comment: "")
    }

    private static func shapeRow(_ shape: LotoShape) -> UIView {
        let chips = [
            String(format: NSLocalizedString("Odd %d · Even %d", comment: "Loto shape"), shape.odd, shape.even),
            String(format: NSLocalizedString("Low %d · High %d", comment: "Loto shape"), shape.low, shape.high),
            String(format: NSLocalizedString("Sum %d", comment: "Loto shape"), shape.sum),
            String(format: NSLocalizedString("Consecutive pairs %d", comment: "Loto shape"), shape.consecutivePairs)
        ].map(chip)
        let flow = LotoFlowView(views: chips)
        flow.spacing = Design.Spacing.s
        return flow
    }

    private static func chip(_ text: String) -> UIView {
        let chip = LotoChip()
        chip.text = text
        return chip
    }

    private static func detailRow(_ number: LotoNumber) -> UIView {
        let ball = LotoBallView(number: number.number, tag: number.primaryTag, diameter: 34)
        ball.isAccessibilityElement = false
        let tags = number.tags.map(\.title).joined(separator: " · ")
        var facts: [String] = []
        if let count = number.count { facts.append(String(format: NSLocalizedString("Drawn %d times", comment: "Loto detail"), count)) }
        if let gap = number.gap { facts.append(gap == 0 ? NSLocalizedString("In the latest draw", comment: "Loto detail") : String(format: NSLocalizedString("Last seen %d draws ago", comment: "Loto detail"), gap)) }
        let title = label(.title, tags.isEmpty ? NSLocalizedString("No special signal", comment: "Loto detail") : tags, color: Design.Color.textPrimary)
        title.font = Design.TextRole.weighted(.subheadline, weight: .semibold)
        let detail = label(.metadata, facts.joined(separator: " · "), color: Design.Color.textSecondary)
        let text = UIStackView(arrangedSubviews: [title, detail])
        text.axis = .vertical
        let row = UIStackView(arrangedSubviews: [ball, text])
        row.alignment = .center
        row.spacing = Design.Spacing.m
        row.isAccessibilityElement = true
        row.accessibilityLabel = ["\(number.number)", tags, facts.joined(separator: ", ")].filter { !$0.isEmpty }.joined(separator: ", ")
        ball.setContentHuggingPriority(.required, for: .horizontal)
        ball.widthAnchor.constraint(equalToConstant: 34).isActive = true
        ball.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return row
    }
}

/// A small rounded label.
final class LotoChip: UIView {
    private let textLabel = UILabel()
    var text: String? { didSet { textLabel.text = text; invalidateIntrinsicContentSize() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Design.Color.surfaceTint
        layer.cornerRadius = Design.Radius.chip
        layer.cornerCurve = .continuous
        textLabel.apply(.metadata)
        textLabel.numberOfLines = 1
        addSubview(textLabel)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let inner = textLabel.sizeThatFits(CGSize(width: max(size.width - Design.Spacing.m * 2, 0), height: .greatestFiniteMagnitude))
        return CGSize(width: min(inner.width + Design.Spacing.m * 2, size.width), height: inner.height + Design.Spacing.xs * 2)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textLabel.frame = bounds.insetBy(dx: Design.Spacing.m, dy: Design.Spacing.xs)
    }
}

// MARK: Signals

final class LotoSignalsView: LotoPanel {
    init(signals: LotoSignals, historyDraws: Int?) {
        super.init(spacing: Design.Spacing.l)
        content.addArrangedSubview(label(.title, NSLocalizedString("Signals from the history", comment: "Loto signals title"), color: Design.Color.textPrimary))
        if let historyDraws {
            content.addArrangedSubview(label(.metadata, String(format: NSLocalizedString("Based on %@ past draws", comment: "Loto history size"),
                                                                historyDraws.formatted(.number.locale(AppLanguage.current.locale))), color: Design.Color.textSecondary))
        }
        for (tag, numbers) in [(LotoTag.hot, signals.hot), (.overdue, signals.overdue), (.cold, signals.cold)] where !numbers.isEmpty {
            let heading = UIStackView(arrangedSubviews: [Self.icon(tag), label(.title, tag.title, color: Design.Color.textPrimary), UIView()])
            heading.spacing = Design.Spacing.s
            heading.alignment = .center
            let flow = LotoFlowView(views: numbers.map { LotoBallView(number: $0, tag: tag, diameter: 36) })
            let block = UIStackView(arrangedSubviews: [heading, label(.metadata, tag.explanation, color: Design.Color.textSecondary), flow])
            block.axis = .vertical
            block.spacing = Design.Spacing.s
            block.isAccessibilityElement = false
            content.addArrangedSubview(block)
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private static func icon(_ tag: LotoTag) -> UIView {
        let image = UIImageView(image: UIImage(systemName: tag.symbol))
        image.tintColor = tag.ballColor
        image.setContentHuggingPriority(.required, for: .horizontal)
        return image
    }
}

// MARK: Method

final class LotoMethodView: LotoPanel {
    init(weights: [LotoWeight]) {
        super.init(spacing: Design.Spacing.m)
        content.addArrangedSubview(label(.title, NSLocalizedString("How the numbers are chosen", comment: "Loto method title"), color: Design.Color.textPrimary))
        content.addArrangedSubview(label(.reading, NSLocalizedString("A weighted mix of the factors below, computed from past draws. It orders combinations; it cannot predict a draw.", comment: "Loto method text"), color: Design.Color.textSecondary))
        let maximum = max(weights.map(\.value).max() ?? 1, 0.01)
        for weight in weights.sorted(by: { $0.value > $1.value }) {
            content.addArrangedSubview(LotoWeightBar(title: weight.kind.title, value: weight.value, relative: weight.value / maximum))
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

private final class LotoWeightBar: UIView {
    private let header: UIStackView
    private let nameLabel: UILabel
    private let percentLabel: UILabel

    init(title: String, value: Double, relative: Double) {
        nameLabel = label(.metadata, title, color: Design.Color.textPrimary)
        percentLabel = label(.figure, value.formatted(.percent.precision(.fractionLength(0)).locale(AppLanguage.current.locale)), color: Design.Color.textSecondary)
        header = UIStackView(arrangedSubviews: [nameLabel, percentLabel])
        super.init(frame: .zero)
        percentLabel.numberOfLines = 1
        percentLabel.setContentHuggingPriority(.required, for: .horizontal)
        let track = UIView()
        track.backgroundColor = Design.Color.surfaceTint
        track.layer.cornerRadius = 4
        let fill = UIView()
        fill.backgroundColor = Design.Color.accent
        fill.layer.cornerRadius = 4
        track.addSubview(fill)
        fill.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor), fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: CGFloat(min(max(relative, 0.03), 1)))
        ])
        track.heightAnchor.constraint(equalToConstant: 8).isActive = true
        let stack = UIStackView(arrangedSubviews: [header, track])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        updateHeaderAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: LotoWeightBar, _) in
            view.updateHeaderAxis()
        }
        isAccessibilityElement = true
        accessibilityLabel = "\(title), \(percentLabel.text ?? "")"
    }

    private func updateHeaderAxis() {
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        header.axis = isAX ? .vertical : .horizontal
        header.alignment = isAX ? .leading : .firstBaseline
        header.spacing = isAX ? 2 : Design.Spacing.s
        nameLabel.numberOfLines = isAX ? 0 : 1
        percentLabel.textAlignment = isAX ? .left : .right
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
