import UIKit

// MARK: Filter bar

/// The row of filters pinned under the navigation bar: "All" and one chip per kind. The chosen chip is filled and also
/// announced as selected, so the state never depends on color alone.
final class MagazineFilterBar: UICollectionReusableView {
    static let elementKind = "magazine-filter-bar"

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var buttons: [(filter: MagazineFilter, button: UIButton)] = []
    private var onSelect: ((MagazineFilter) -> Void)?
    private var selected: MagazineFilter = .all

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Design.Color.background
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = Design.Spacing.s
        stack.distribution = .fill
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.xs),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.s),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
        for filter in MagazineFilter.allCases {
            let button = UIButton(type: .system)
            button.addAction(UIAction { [weak self] _ in self?.onSelect?(filter) }, for: .primaryActionTriggered)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
            // Chips keep their own width and the row scrolls; they are never stretched to fill it.
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.accessibilityIdentifier = "magazine_filter_\(filter.kind?.apiValue ?? "all")"
            buttons.append((filter, button))
            stack.addArrangedSubview(button)
        }
        apply()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self, UITraitUserInterfaceStyle.self]) { (view: MagazineFilterBar, _) in view.apply() }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(selected: MagazineFilter, onSelect: @escaping (MagazineFilter) -> Void) {
        self.onSelect = onSelect
        self.selected = selected
        apply()
    }

    func select(_ filter: MagazineFilter) {
        guard filter != selected else { return }
        selected = filter
        apply()
    }

    private func apply() {
        let cornerStyle = Design.Button.cornerStyle(for: traitCollection)
        for (filter, button) in buttons {
            let isSelected = filter == selected
            var configuration = UIButton.Configuration.filled()
            configuration.cornerStyle = cornerStyle
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
            configuration.imagePadding = Design.Spacing.xs
            configuration.image = UIImage(systemName: filter.kind?.symbol ?? "square.grid.2x2.fill")
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .small)
            configuration.baseBackgroundColor = isSelected ? Design.Color.accent : Design.Color.surface
            configuration.baseForegroundColor = isSelected ? Design.Color.onAccent : Design.Color.textPrimary
            configuration.background.strokeColor = isSelected ? .clear : Design.Color.border
            configuration.background.strokeWidth = isSelected ? 0 : 1
            var title = AttributedString(filter.title)
            title.font = Design.TextRole.weighted(.subheadline, weight: isSelected ? .semibold : .regular)
            configuration.attributedTitle = title
            button.configuration = configuration
            button.accessibilityLabel = filter.title
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }
}

// MARK: Section header

final class MagazineSectionHeaderView: UICollectionReusableView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.apply(.sectionTitle)
        label.accessibilityTraits = .header
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.m),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.s),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.xs),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.xs)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(_ title: String) {
        label.text = title
        isHidden = title.isEmpty
    }
}

// MARK: Lead card

/// The newest article, drawn large: kind and date, the Japanese title in print type, the Vietnamese title, a summary and a few words.
final class MagazineLeadCell: UICollectionViewCell {
    private let card = UIView()
    private let tile = MagazineSymbolTile(side: 40)
    private let eyebrow = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let wordsHolder = UIView()
    private var words: DiscoverTagFlow?
    private let cta = UILabel()
    private let arrow = UIImageView(image: UIImage(systemName: "arrow.right"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        card.applyCardSurface(radius: Design.Radius.card)
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        eyebrow.apply(.eyebrow)
        titleLabel.apply(.articleTitle)
        titleLabel.markJapanese()
        subtitleLabel.apply(.meaning)
        subtitleLabel.textColor = Design.Color.textSecondary
        summaryLabel.apply(.reading)
        updateSummaryLines()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: MagazineLeadCell, _) in
            cell.updateSummaryLines()
        }
        cta.apply(.sectionTitle)
        cta.textColor = Design.Color.accent
        cta.text = NSLocalizedString("Read article", comment: "Magazine lead card call to action")
        arrow.tintColor = Design.Color.accent
        arrow.setContentHuggingPriority(.required, for: .horizontal)

        let head = UIStackView(arrangedSubviews: [tile, eyebrow])
        head.alignment = .center
        head.spacing = Design.Spacing.m
        let footer = UIStackView(arrangedSubviews: [cta, arrow, UIView()])
        footer.alignment = .center
        footer.spacing = Design.Spacing.xs
        let content = UIStackView(arrangedSubviews: [head, titleLabel, subtitleLabel, summaryLabel, wordsHolder, footer])
        content.axis = .vertical
        content.spacing = Design.Spacing.s
        content.setCustomSpacing(Design.Spacing.l, after: head)
        content.setCustomSpacing(Design.Spacing.m, after: summaryLabel)
        content.setCustomSpacing(Design.Spacing.m, after: wordsHolder)
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: Design.Spacing.l),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Design.Spacing.l),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Design.Spacing.l),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Design.Spacing.l)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "magazine_lead"
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { card.backgroundColor = isHighlighted ? Design.Color.highlight.blended(over: Design.Color.surface) : Design.Color.surface }
    }

    private func updateSummaryLines() {
        summaryLabel.numberOfLines = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 0 : 3
    }

    func configure(_ row: MagazineRow) {
        tile.configure(symbol: row.kind.symbol, tint: row.kind.tint)
        eyebrow.text = row.meta.uppercased()
        titleLabel.text = row.titleJapanese
        subtitleLabel.text = row.titleVietnamese
        subtitleLabel.isHidden = row.titleVietnamese.isEmpty
        summaryLabel.text = row.summary
        summaryLabel.isHidden = row.summary == nil
        words?.removeFromSuperview()
        words = nil
        wordsHolder.isHidden = row.words.isEmpty
        if !row.words.isEmpty {
            let flow = DiscoverTagFlow(tags: Array(row.words.prefix(4)))
            flow.translatesAutoresizingMaskIntoConstraints = false
            wordsHolder.addSubview(flow)
            NSLayoutConstraint.activate([
                flow.topAnchor.constraint(equalTo: wordsHolder.topAnchor), flow.bottomAnchor.constraint(equalTo: wordsHolder.bottomAnchor),
                flow.leadingAnchor.constraint(equalTo: wordsHolder.leadingAnchor), flow.trailingAnchor.constraint(equalTo: wordsHolder.trailingAnchor)
            ])
            words = flow
        }
        accessibilityLabel = [row.titleJapanese, row.titleVietnamese, row.summary, row.meta].compactMap { $0 }.joined(separator: ". ")
        accessibilityHint = NSLocalizedString("Read article", comment: "Magazine lead card call to action")
    }
}

// MARK: Row

final class MagazineRowCell: UICollectionViewListCell {
    private let tile = MagazineSymbolTile(side: 44)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let metaLabel = UILabel()
    private let row = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.apply(.title)
        titleLabel.markJapanese()
        subtitleLabel.apply(.reading)
        metaLabel.apply(.metadata)
        let text = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, metaLabel])
        text.axis = .vertical
        text.spacing = 2
        row.addArrangedSubview(tile)
        row.addArrangedSubview(text)
        row.spacing = Design.Spacing.m
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Design.Spacing.m),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Design.Spacing.m),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Design.Spacing.l),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Design.Spacing.s)
        ])
        updateRowAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: MagazineRowCell, _) in
            cell.updateRowAxis()
        }
        accessories = [.disclosureIndicator()]
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    private func updateRowAxis() {
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        row.axis = isAX ? .vertical : .horizontal
        row.alignment = isAX ? .leading : .top
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func updateConfiguration(using state: UICellConfigurationState) {
        var background = UIBackgroundConfiguration.listCell().updated(for: state)
        background.backgroundColor = state.isHighlighted || state.isSelected ? Design.Color.highlight.blended(over: Design.Color.surface) : Design.Color.surface
        backgroundConfiguration = background
    }

    func configure(_ row: MagazineRow) {
        tile.configure(symbol: row.kind.symbol, tint: row.kind.tint)
        titleLabel.text = row.titleJapanese
        subtitleLabel.text = row.titleVietnamese
        subtitleLabel.isHidden = row.titleVietnamese.isEmpty
        metaLabel.text = row.meta
        accessibilityLabel = [row.titleJapanese, row.titleVietnamese, row.meta].filter { !$0.isEmpty }.joined(separator: ". ")
        accessibilityIdentifier = "magazine_row_\(row.slug)"
    }
}

// MARK: Footer

/// Under the list: a spinner while the next page loads, or what went wrong with a retry.
final class MagazineFooterCell: UICollectionViewCell {
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let message = UILabel()
    private let retry = UIButton(type: .system)
    private var onRetry: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        message.apply(.reading)
        message.textAlignment = .center
        retry.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .primaryActionTriggered)
        retry.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        retry.enableAdaptiveCornerStyle()
        let stack = UIStackView(arrangedSubviews: [spinner, message, retry])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Design.Spacing.s
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Design.Spacing.m),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Design.Spacing.gutter)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(_ footer: MagazineFooter, onRetry: @escaping () -> Void) {
        self.onRetry = onRetry
        switch footer {
        case .none:
            spinner.stopAnimating()
            message.isHidden = true
            retry.isHidden = true
        case .loading:
            spinner.startAnimating()
            spinner.accessibilityLabel = NSLocalizedString("Loading articles…", comment: "")
            message.isHidden = true
            retry.isHidden = true
        case .failed(let text):
            spinner.stopAnimating()
            message.text = text
            message.isHidden = false
            retry.configuration = Design.Button.secondary(title: NSLocalizedString("Try again", comment: ""), traits: traitCollection)
            retry.isHidden = false
        }
    }
}
