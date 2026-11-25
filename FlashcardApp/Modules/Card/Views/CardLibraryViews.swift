import UIKit

/// A button that sinks a little under the finger, so a touch is acknowledged before its action runs. With Reduce Motion it stays still.
final class PressableButton: UIButton {
    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted, !UIAccessibility.isReduceMotionEnabled else { return }
            UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }
}

/// What a list looks like while it loads: the same shapes as the rows that will replace it, softly pulsing. It replaces a spinner,
/// so the screen keeps its layout when the content arrives. With Reduce Motion it does not pulse.
final class SkeletonCell: UITableViewCell {
    static let reuseIdentifier = "card_skeleton_cell"

    enum Shape {
        case deckRow
        case hero
    }

    private let content = UIView()
    private var widthConstraints: [NSLayoutConstraint] = []

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundConfiguration = .clear()
        selectionStyle = .none
        content.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: contentView.topAnchor),
            content.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func prepareForReuse() {
        super.prepareForReuse()
        content.layer.removeAnimation(forKey: "pulse")
        content.subviews.forEach { $0.removeFromSuperview() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return content.layer.removeAnimation(forKey: "pulse") }
        startPulse()
    }

    private func startPulse() {
        guard !UIAccessibility.isReduceMotionEnabled, content.layer.animation(forKey: "pulse") == nil else { return }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1
        pulse.toValue = 0.45
        pulse.duration = 0.9
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        content.layer.add(pulse, forKey: "pulse")
    }

    private func block(radius: CGFloat) -> UIView {
        let view = UIView()
        view.backgroundColor = .tertiarySystemFill
        view.layer.cornerRadius = radius
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    /// `index` varies the line lengths from row to row; only the first skeleton is announced, once, as "loading".
    func configure(_ shape: Shape, index: Int, announcement: String) {
        content.subviews.forEach { $0.removeFromSuperview() }
        isAccessibilityElement = index == 0
        accessibilityLabel = announcement
        switch shape {
        case .hero:
            let panel = block(radius: Design.Radius.panel)
            content.addSubview(panel)
            NSLayoutConstraint.activate([
                panel.topAnchor.constraint(equalTo: content.topAnchor, constant: Design.Spacing.l),
                panel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Design.Spacing.l),
                panel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Design.Spacing.gutter),
                panel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Design.Spacing.gutter),
                panel.heightAnchor.constraint(equalToConstant: 250)
            ])
        case .deckRow:
            let tile = block(radius: Design.Spacing.m)
            let lines = [(CGFloat(14), [0.55, 0.7, 0.45][index % 3]), (CGFloat(11), [0.9, 0.8, 0.95][index % 3]), (CGFloat(11), [0.4, 0.5, 0.35][index % 3])]
            let text = UIStackView()
            text.axis = .vertical
            text.alignment = .leading
            text.spacing = 9
            text.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(tile)
            content.addSubview(text)
            NSLayoutConstraint.activate([
                tile.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Design.Spacing.gutter),
                tile.topAnchor.constraint(equalTo: content.topAnchor, constant: Design.Spacing.m),
                tile.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Design.Spacing.m),
                tile.widthAnchor.constraint(equalToConstant: 56),
                tile.heightAnchor.constraint(equalToConstant: 56),
                text.leadingAnchor.constraint(equalTo: tile.trailingAnchor, constant: Design.Spacing.m),
                text.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Design.Spacing.gutter),
                text.centerYAnchor.constraint(equalTo: tile.centerYAnchor)
            ])
            for (height, fraction) in lines {
                let bar = block(radius: height / 2)
                text.addArrangedSubview(bar)
                bar.heightAnchor.constraint(equalToConstant: height).isActive = true
                bar.widthAnchor.constraint(equalTo: text.widthAnchor, multiplier: fraction).isActive = true
            }
        }
        startPulse()
    }
}

/// The row of sections under the large title. It stays pinned while the list scrolls, scrolls sideways when the words do not fit
/// (large text, longer languages), and shows the number of cards due on "Review".
final class CardScopeBar: UIView {
    static let height: CGFloat = 60

    var onSelect: ((CardLibraryScope) -> Void)?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var chips: [CardLibraryScope: UIButton] = [:]
    private var selected: CardLibraryScope = .mine
    private var dueCount: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Design.Color.background
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceHorizontal = true
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Design.Spacing.s),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.s),
            scrollView.heightAnchor.constraint(equalTo: stack.heightAnchor, constant: Design.Spacing.s * 2)
        ])
        for scope in CardLibraryScope.allCases {
            let chip = PressableButton(configuration: .filled())
            chip.accessibilityIdentifier = "cards_scope_\(scope.rawValue)"
            chip.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
            chip.setContentCompressionResistancePriority(.required, for: .horizontal)
            chip.addAction(UIAction { [weak self] _ in self?.onSelect?(scope) }, for: .primaryActionTriggered)
            chips[scope] = chip
            stack.addArrangedSubview(chip)
        }
        refreshChips()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (bar: CardScopeBar, _) in
            bar.refreshChips()
        }
        // Everything inside is one list of choices for VoiceOver, with the badge read as part of the name.
        isAccessibilityElement = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(selected: CardLibraryScope, dueCount: Int?) {
        guard selected != self.selected || dueCount != self.dueCount else { return }
        let selectionChanged = selected != self.selected
        self.selected = selected
        self.dueCount = dueCount
        // The selection moves from one chip to the next: a short cross-fade says which, instead of a jump.
        if selectionChanged, window != nil, !UIAccessibility.isReduceMotionEnabled {
            UIView.transition(with: stack, duration: 0.2, options: [.transitionCrossDissolve, .allowUserInteraction]) { self.refreshChips() }
        } else {
            refreshChips()
        }
    }

    private func refreshChips() {
        for (scope, chip) in chips {
            let isSelected = scope == selected
            var configuration = UIButton.Configuration.filled()
            configuration.cornerStyle = .capsule
            configuration.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.s, leading: 11, bottom: Design.Spacing.s, trailing: 11)
            configuration.baseBackgroundColor = isSelected ? Design.Color.accent : Design.Color.surface
            configuration.baseForegroundColor = isSelected ? Design.Color.onAccent : Design.Color.textPrimary
            configuration.background.strokeColor = isSelected ? .clear : Design.Color.separator
            configuration.background.strokeWidth = 1
            var title = AttributedString(scope.title)
            title.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(isSelected ? .semibold : .regular)
            let badge = scope == .review ? dueCount.flatMap { $0 > 0 ? $0 : nil } : nil
            if let badge {
                var number = AttributedString(" \(badge.formatted(.number.locale(AppLanguage.current.locale)))")
                number.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(.semibold)
                title += number
            }
            configuration.attributedTitle = title
            chip.configuration = configuration
            chip.accessibilityTraits = isSelected ? [.button, .selected] : .button
            chip.accessibilityLabel = badge.map {
                scope.title + ", " + String.localizedStringWithFormat(NSLocalizedString("%lld cards due", comment: "Cards waiting for review"), $0)
            } ?? scope.title
        }
    }
}

/// The pinned header of the list: hosts the section bar. A reusable header view (not one shared view handed to the table) keeps
/// the chips in the accessibility tree once.
final class CardScopeHeaderView: UITableViewHeaderFooterView {
    static let reuseIdentifier = "card_scope_header"

    private let bar = CardScopeBar()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        bar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: contentView.topAnchor),
            bar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(selected: CardLibraryScope, dueCount: Int?, onSelect: @escaping (CardLibraryScope) -> Void) {
        bar.onSelect = onSelect
        bar.configure(selected: selected, dueCount: dueCount)
    }
}

/// "On your account" and the like: the title of a group of rows, with a retry when the group could not be loaded.
final class CardSectionHeaderView: UITableViewHeaderFooterView {
    static let reuseIdentifier = "card_section_header"

    private let titleLabel = UILabel()
    private let failureLabel = UILabel()
    private let retryButton = UIButton(configuration: .plain())
    private var onRetry: (() -> Void)?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        contentView.backgroundColor = Design.Color.background
        titleLabel.apply(.eyebrow)
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header
        failureLabel.apply(.metadata)
        failureLabel.textColor = Design.Color.error
        failureLabel.numberOfLines = 0
        retryButton.configuration?.title = NSLocalizedString("Try again", comment: "")
        retryButton.contentHorizontalAlignment = .leading
        retryButton.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .primaryActionTriggered)
        let stack = UIStackView(arrangedSubviews: [titleLabel, failureLabel, retryButton])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = Design.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Design.Spacing.l),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Design.Spacing.s),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Design.Spacing.gutter)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(title: String, failure: String?, onRetry: @escaping () -> Void) {
        titleLabel.text = title.uppercased(with: AppLanguage.current.locale)
        failureLabel.text = failure
        failureLabel.isHidden = failure == nil
        retryButton.isHidden = failure == nil
        self.onRetry = onRetry
    }
}

/// The Review section when cards are due: a panel with the number, what it means, and the one action.
final class ReviewHeroCell: UITableViewCell {
    static let reuseIdentifier = "review_hero_cell"

    private let panel = UIView()
    private let figureLabel = UILabel()
    private let captionLabel = UILabel()
    private let explanationLabel = UILabel()
    private let startButton = PressableButton(configuration: Design.Button.hero(title: NSLocalizedString("Start review", comment: "")))
    private var onStart: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundConfiguration = .clear()
        selectionStyle = .none
        separatorInset = UIEdgeInsets(top: 0, left: 10_000, bottom: 0, right: 0)
        panel.backgroundColor = Design.Color.hero
        panel.layer.cornerRadius = Design.Radius.panel
        panel.layer.cornerCurve = .continuous
        panel.translatesAutoresizingMaskIntoConstraints = false

        figureLabel.apply(.numeralDisplay)
        figureLabel.adjustsFontSizeToFitWidth = true
        figureLabel.minimumScaleFactor = 0.5
        figureLabel.accessibilityIdentifier = "review_due_count"
        captionLabel.apply(.title)
        captionLabel.textColor = Design.Color.onHero
        captionLabel.numberOfLines = 0
        explanationLabel.apply(.reading)
        explanationLabel.textColor = Design.Color.onHeroSecondary
        explanationLabel.numberOfLines = 0
        explanationLabel.text = NSLocalizedString("Each card comes back at the right moment, based on how well you remember it.", comment: "")
        startButton.accessibilityIdentifier = "review_start"
        startButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        startButton.addAction(UIAction { [weak self] _ in self?.onStart?() }, for: .primaryActionTriggered)
        updateStartButton()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: ReviewHeroCell, _) in
            cell.updateStartButton()
        }

        let stack = UIStackView(arrangedSubviews: [figureLabel, captionLabel, explanationLabel, startButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Design.Spacing.xs
        stack.setCustomSpacing(Design.Spacing.s, after: captionLabel)
        stack.setCustomSpacing(Design.Spacing.xl, after: explanationLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)
        contentView.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Design.Spacing.l),
            panel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Design.Spacing.l),
            panel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Design.Spacing.gutter),
            panel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Design.Spacing.gutter),
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: Design.Spacing.xl),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: Design.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -Design.Spacing.xl)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func updateStartButton() {
        startButton.configuration = Design.Button.hero(title: NSLocalizedString("Start review", comment: ""), traits: traitCollection)
    }

    func configure(due: Int, capped: Bool, onStart: @escaping () -> Void) {
        let number = due.formatted(.number.locale(AppLanguage.current.locale))
        figureLabel.text = capped ? number + "+" : number
        captionLabel.text = String.localizedStringWithFormat(NSLocalizedString("%lld cards to review", comment: "Under the due count; plural by count"), due)
        self.onStart = onStart
        // One announcement for the panel; the button stays its own element.
        figureLabel.accessibilityLabel = captionLabel.text
    }
}

extension DeckLibraryCell {
    /// A deck of the account: the same row as a deck on the device. Its decks have no Japanese mark to show (the list carries no cards),
    /// so the tile carries what the list does know: how many cards. The line under the text keeps to the age and at most one state.
    func configure(with row: RemoteDeckRowModel) {
        var facts: [String] = []
        if let updated = row.updatedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = AppLanguage.current.locale
            formatter.unitsStyle = .short
            facts.append(formatter.localizedString(for: updated, relativeTo: Date()))
        }
        // One state at most: that it is on this device matters more than that it is private.
        if row.isOnDevice {
            facts.append(NSLocalizedString("On this device", comment: "A copy of the deck is stored on the device"))
        } else if row.isOwned, row.visibility == .private {
            facts.append(NSLocalizedString("Private", comment: ""))
        }
        let count = String.localizedStringWithFormat(NSLocalizedString("%lld cards", comment: ""), row.cardCount)
        configureRow(monogram: row.cardCount.formatted(.number.locale(AppLanguage.current.locale)),
                     unit: NSLocalizedString("cards", comment: "Unit under a number of cards, in a small tile"), title: row.title, details: row.details, preview: "", meta: facts.joined(separator: " · "),
                     identifier: "remote_deck_row_\(row.id)", hint: NSLocalizedString("Open this deck", comment: ""),
                     accessibility: ([row.title, row.details, count] + facts).filter { !$0.isEmpty }.joined(separator: ", "))
    }
}
