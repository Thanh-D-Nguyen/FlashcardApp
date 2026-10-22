import UIKit

/// Shared press / selection feedback: a faint accent wash instead of the system gray.
private func applyHighlight(to cell: UITableViewCell) {
    cell.backgroundConfiguration = .clear()
    cell.configurationUpdateHandler = { cell, state in
        var background = UIBackgroundConfiguration.clear()
        if state.isHighlighted || state.isSelected { background.backgroundColor = Design.Color.highlight }
        cell.backgroundConfiguration = background
    }
}

/// Numeral text for a level. A trailing "+" (J1+) is set small and raised, like a superscript,
/// so it does not widen the numeral column or compete with the kanji.
private func numeralText(_ numeral: String, font: UIFont) -> NSAttributedString {
    guard numeral.hasSuffix("+"), numeral.count > 1 else { return NSAttributedString(string: numeral) }
    let text = NSMutableAttributedString(string: String(numeral.dropLast()))
    let plus = UIFont.systemFont(ofSize: font.pointSize * 0.4, weight: .semibold)
    text.append(NSAttributedString(string: "+", attributes: [
        .font: plus, .baselineOffset: font.pointSize * 0.38]))
    return text
}

/// A view VoiceOver reads as one button; activation opens the level. Touch handling stays with the cell.
final class ActionableView: UIView {
    var onActivate: (() -> Void)?

    override func accessibilityActivate() -> Bool {
        guard let onActivate else { return false }
        onActivate()
        return true
    }
}

/// Counts of a level as three direct entry points: "574 từ vựng | 79 kanji | 194 ngữ pháp".
/// Tabular figures in the accent color; hairlines between columns instead of chips.
final class LevelKindStrip: UIStackView {
    private var buttons: [UIButton] = []
    private var dividers: [UIView] = []
    var onSelect: ((HomeContentKind) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        distribution = .fillEqually
        for kind in HomeContentKind.allCases {
            let button = UIButton(configuration: .plain())
            button.addAction(UIAction { [weak self] _ in self?.onSelect?(kind) }, for: .primaryActionTriggered)
            button.configurationUpdateHandler = { button in
                var configuration = button.configuration
                configuration?.background.backgroundColor = button.isHighlighted ? Design.Color.highlight : .clear
                button.configuration = configuration
            }
            if kind != .vocabulary {
                let divider = UIView()
                divider.backgroundColor = Design.Color.separator
                divider.translatesAutoresizingMaskIntoConstraints = false
                divider.isUserInteractionEnabled = false
                button.addSubview(divider)
                dividers.append(divider)
                NSLayoutConstraint.activate([
                    divider.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                    divider.widthAnchor.constraint(equalToConstant: 0.5),
                    divider.topAnchor.constraint(equalTo: button.topAnchor, constant: Design.Spacing.s),
                    divider.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -Design.Spacing.s)
                ])
            }
            buttons.append(button)
            addArrangedSubview(button)
        }
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (strip: LevelKindStrip, _) in
            strip.updateAxis()
        }
    }

    @available(*, unavailable) required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Columns at regular sizes; full-width rows once three columns no longer fit.
    private func updateAxis() {
        axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
        // Column hairlines only make sense between columns.
        dividers.forEach { $0.isHidden = axis == .vertical }
    }

    /// `identifierPrefix` makes each column addressable by UI tests: `<prefix>_vocabulary|kanji|grammar`.
    func configure(with counts: [HomeCount], identifierPrefix: String) {
        for (index, (button, count)) in zip(buttons, counts).enumerated() {
            button.accessibilityIdentifier = "\(identifierPrefix)_\(String(describing: HomeContentKind(rawValue: index) ?? .vocabulary))"
            var configuration = button.configuration ?? .plain()
            var figure = AttributedString(count.value.formatted(.number.locale(Locale(identifier: "vi_VN"))))
            figure.font = Design.TextRole.figure.font
            figure.foregroundColor = Design.Color.accent
            var unit = AttributedString(count.label)
            unit.font = Design.TextRole.metadata.font
            unit.foregroundColor = Design.Color.textSecondary
            configuration.attributedTitle = figure
            configuration.attributedSubtitle = unit
            configuration.titleAlignment = .leading
            configuration.contentInsets = NSDirectionalEdgeInsets(
                top: Design.Spacing.s, leading: Design.Spacing.m, bottom: Design.Spacing.s, trailing: Design.Spacing.xs)
            configuration.background.cornerRadius = Design.Spacing.s
            button.configuration = configuration
            button.contentHorizontalAlignment = .leading
            button.isEnabled = count.value > 0
            button.accessibilityLabel = "\(count.value) \(count.label)"
            button.accessibilityHint = count.value > 0 ? "Mở \(count.label) của cấp độ này" : nil
        }
    }
}

/// One JLPT level in the list: kanji numeral hung on the leading side, name and description,
/// then the level's contents as direct entry points. Tapping elsewhere opens the level.
final class LevelCell: UITableViewCell {
    static let reuseIdentifier = "level_cell"

    /// The numeral, used as the source of the zoom transition into the level.
    let numeralLabel = UILabel()
    var onSelectKind: ((HomeContentKind) -> Void)?

    private let headerView = ActionableView()
    private let nameLabel = UILabel()
    private let summaryLabel = UILabel()
    private let emptyLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let strip = LevelKindStrip()
    private let stripContainer = UIView()
    private let textStack = UIStackView()
    private let headerStack = UIStackView()
    private let rootStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        applyHighlight(to: self)
        numeralLabel.apply(.numeral)
        numeralLabel.numberOfLines = 1
        numeralLabel.isAccessibilityElement = false
        numeralLabel.setContentHuggingPriority(.required, for: .horizontal)
        numeralLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        nameLabel.apply(.title)
        summaryLabel.apply(.reading)
        emptyLabel.apply(.metadata)
        emptyLabel.text = "Chưa có nội dung"
        chevron.tintColor = .tertiaryLabel
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .small)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)
        chevron.isAccessibilityElement = false
        textStack.axis = .vertical
        textStack.spacing = Design.Spacing.xs
        [nameLabel, summaryLabel, emptyLabel].forEach(textStack.addArrangedSubview)
        headerStack.spacing = Design.Spacing.m
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        [numeralLabel, textStack, chevron].forEach(headerStack.addArrangedSubview)
        headerView.addSubview(headerStack)
        headerView.isAccessibilityElement = true
        headerView.accessibilityTraits = .button
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: headerView.topAnchor),
            headerStack.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            headerStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            numeralLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 64)
        ])
        rootStack.axis = .vertical
        rootStack.spacing = Design.Spacing.s
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        // The first column's own inset is cancelled so its figure lines up with the numeral above.
        strip.translatesAutoresizingMaskIntoConstraints = false
        stripContainer.addSubview(strip)
        NSLayoutConstraint.activate([
            strip.topAnchor.constraint(equalTo: stripContainer.topAnchor),
            strip.bottomAnchor.constraint(equalTo: stripContainer.bottomAnchor),
            strip.leadingAnchor.constraint(equalTo: stripContainer.leadingAnchor, constant: -Design.Spacing.m),
            strip.trailingAnchor.constraint(equalTo: stripContainer.trailingAnchor)
        ])
        [headerView, stripContainer].forEach(rootStack.addArrangedSubview)
        contentView.addSubview(rootStack)
        // Strip columns start under the text column, shifted by their own inset so figures align with the name.
        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Design.Spacing.l),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Design.Spacing.s),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Design.Spacing.gutter),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Design.Spacing.gutter)
        ])
        strip.onSelect = { [weak self] kind in self?.onSelectKind?(kind) }
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: LevelCell, _) in
            cell.updateAxis()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func prepareForReuse() {
        super.prepareForReuse()
        onSelectKind = nil
    }

    /// Beside the text at normal sizes; above it for accessibility sizes so the text keeps the full width.
    private func updateAxis() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        headerStack.axis = large ? .vertical : .horizontal
        headerStack.alignment = large ? .leading : .top
        chevron.isHidden = large
    }

    func configure(with row: HomeRow) {
        if let numeral = row.numeral {
            numeralLabel.font = Design.TextRole.numeral.font
            numeralLabel.attributedText = numeralText(numeral, font: Design.TextRole.numeral.font)
        } else {
            numeralLabel.font = Design.TextRole.mark.font
            numeralLabel.text = row.mark
        }
        nameLabel.text = row.name ?? row.title
        summaryLabel.text = row.summary
        summaryLabel.isHidden = (row.summary ?? "").isEmpty
        emptyLabel.isHidden = !row.counts.isEmpty
        stripContainer.isHidden = row.counts.isEmpty
        strip.configure(with: row.counts, identifierPrefix: "home_kind_\(row.id)")
        headerView.accessibilityLabel = ([row.mark, row.name ?? row.title, row.summary].compactMap { $0 }
            + (row.counts.isEmpty ? ["Chưa có nội dung"] : []))
            .joined(separator: ", ")
        headerView.accessibilityHint = "Mở cấp độ"
        // The cell is a container: header and each count are separate VoiceOver elements.
        isAccessibilityElement = false
        accessibilityElements = [headerView] + (row.counts.isEmpty ? [] : strip.arrangedSubviews)
    }

    /// Opening a level by VoiceOver activation behaves as a tap on the row.
    func setActivation(_ handler: @escaping () -> Void) { headerView.onActivate = handler }
}

/// The featured level: a single deep-indigo panel with the primary action. This is the one place
/// the screen asks the user to start; everything else is an alternative.
final class FeaturedLevelCell: UITableViewCell {
    static let reuseIdentifier = "featured_level_cell"
    private static let startTitle = "Bắt đầu học từ vựng"

    let numeralLabel = UILabel()
    var onStart: (() -> Void)?

    private let panel = UIView()
    private let infoView = ActionableView()
    private let eyebrowLabel = UILabel()
    private let codeLabel = UILabel()
    private let nameLabel = UILabel()
    private let summaryLabel = UILabel()
    private let countsLabel = UILabel()
    private let startButton = UIButton(configuration: Design.Button.hero(title: FeaturedLevelCell.startTitle))
    private let headerStack = UIStackView()
    private let titleStack = UIStackView()
    private let contentStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        panel.backgroundColor = Design.Color.hero
        panel.layer.cornerRadius = Design.Radius.panel
        panel.layer.cornerCurve = .continuous
        panel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(panel)

        eyebrowLabel.apply(.eyebrow)
        eyebrowLabel.textColor = Design.Color.onHeroSecondary
        eyebrowLabel.text = "Bắt đầu từ đây"
        numeralLabel.apply(.numeralDisplay)
        numeralLabel.numberOfLines = 1
        numeralLabel.setContentHuggingPriority(.required, for: .horizontal)
        numeralLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        codeLabel.apply(.eyebrow)
        codeLabel.textColor = Design.Color.onHeroSecondary
        nameLabel.apply(.title)
        nameLabel.font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: .systemFont(ofSize: 22, weight: .semibold))
        nameLabel.textColor = Design.Color.onHero
        summaryLabel.apply(.reading)
        summaryLabel.textColor = Design.Color.onHeroSecondary
        countsLabel.numberOfLines = 0
        startButton.addAction(UIAction { [weak self] _ in self?.onStart?() }, for: .primaryActionTriggered)
        startButton.accessibilityIdentifier = "home_start"

        titleStack.axis = .vertical
        titleStack.spacing = Design.Spacing.xs
        titleStack.alignment = .leading
        [codeLabel, nameLabel].forEach(titleStack.addArrangedSubview)
        headerStack.spacing = Design.Spacing.l
        headerStack.alignment = .lastBaseline
        [numeralLabel, titleStack].forEach(headerStack.addArrangedSubview)

        contentStack.axis = .vertical
        contentStack.spacing = Design.Spacing.m
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        infoView.translatesAutoresizingMaskIntoConstraints = false
        let info = UIStackView(arrangedSubviews: [eyebrowLabel, headerStack, summaryLabel, countsLabel])
        info.axis = .vertical
        info.spacing = Design.Spacing.m
        info.translatesAutoresizingMaskIntoConstraints = false
        infoView.addSubview(info)
        infoView.isAccessibilityElement = true
        infoView.accessibilityTraits = .staticText
        NSLayoutConstraint.activate([
            info.topAnchor.constraint(equalTo: infoView.topAnchor),
            info.bottomAnchor.constraint(equalTo: infoView.bottomAnchor),
            info.leadingAnchor.constraint(equalTo: infoView.leadingAnchor),
            info.trailingAnchor.constraint(equalTo: infoView.trailingAnchor)
        ])
        [infoView, startButton].forEach(contentStack.addArrangedSubview)
        contentStack.setCustomSpacing(Design.Spacing.xl, after: infoView)
        panel.addSubview(contentStack)
        let pad = Design.Spacing.xl
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Design.Spacing.s),
            panel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Design.Spacing.xl),
            panel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Design.Spacing.gutter),
            panel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Design.Spacing.gutter),
            contentStack.topAnchor.constraint(equalTo: panel.topAnchor, constant: pad),
            contentStack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -pad),
            contentStack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: pad),
            contentStack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -pad)
        ])
        configurationUpdateHandler = { [weak self] _, state in
            guard let self else { return }
            let pressed = state.isHighlighted || state.isSelected
            // A small press-in; skipped entirely when the user asked for reduced motion.
            let transform: CGAffineTransform = pressed && !UIAccessibility.isReduceMotionEnabled
                ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
            UIView.animate(withDuration: 0.18, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.panel.transform = transform
            }
        }
        selectionStyle = .default
        selectedBackgroundView = UIView()
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: FeaturedLevelCell, _) in
            cell.updateAxis()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func prepareForReuse() {
        super.prepareForReuse()
        onStart = nil
    }

    /// Numeral beside the name at regular sizes, above it at accessibility sizes.
    private func updateAxis() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        headerStack.axis = large ? .vertical : .horizontal
        headerStack.alignment = large ? .leading : .lastBaseline
        // Rebuilt so the title font follows a Dynamic Type change made while the app is open.
        // A capsule becomes a circle once the title wraps onto several lines.
        var configuration = Design.Button.hero(title: Self.startTitle)
        configuration.cornerStyle = large ? .large : .capsule
        startButton.configuration = configuration
        needsCountsUpdate()
    }

    private var counts: [HomeCount] = []

    private func needsCountsUpdate() {
        let stacked = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        countsLabel.attributedText = LevelCell.countsText(counts, onHero: true, stacked: stacked)
    }

    func configure(with row: HomeRow) {
        if let numeral = row.numeral {
            numeralLabel.attributedText = numeralText(numeral, font: Design.TextRole.numeralDisplay.font)
        } else {
            numeralLabel.attributedText = nil
        }
        numeralLabel.isHidden = row.numeral == nil
        codeLabel.text = row.mark
        nameLabel.text = row.name ?? row.title
        summaryLabel.text = row.summary
        summaryLabel.isHidden = (row.summary ?? "").isEmpty
        counts = row.counts
        needsCountsUpdate()
        countsLabel.isHidden = row.counts.isEmpty
        infoView.accessibilityLabel = ([row.mark, row.name ?? row.title, row.summary].compactMap { $0 }
            + row.counts.map { "\($0.value) \($0.label)" }).joined(separator: ", ")
        isAccessibilityElement = false
        accessibilityElements = [infoView, startButton]
        startButton.accessibilityLabel = "Bắt đầu học từ vựng \(row.mark ?? row.name ?? "")"
    }
}

extension LevelCell {
    /// "574 từ vựng · 79 kanji · 194 ngữ pháp": tabular figures stand out from their units.
    static func countsText(_ counts: [HomeCount], onHero: Bool = false, stacked: Bool = false) -> NSAttributedString {
        let unit: [NSAttributedString.Key: Any] = [
            .font: Design.TextRole.metadata.font,
            .foregroundColor: onHero ? Design.Color.onHeroSecondary : Design.TextRole.metadata.color]
        let figure: [NSAttributedString.Key: Any] = [
            .font: Design.TextRole.figure.font,
            .foregroundColor: onHero ? Design.Color.onHero : Design.TextRole.figure.color]
        guard !counts.isEmpty else { return NSAttributedString(string: "Chưa có nội dung", attributes: unit) }
        let text = NSMutableAttributedString()
        for (index, count) in counts.enumerated() {
            if index > 0 { text.append(NSAttributedString(string: stacked ? "\n" : "  ·  ", attributes: unit)) }
            text.append(NSAttributedString(string: count.value.formatted(.number.locale(Locale(identifier: "vi_VN"))), attributes: figure))
            text.append(NSAttributedString(string: " \(count.label)", attributes: unit))
        }
        return text
    }
}

/// Quiet label above the remaining levels.
final class SectionHeaderView: UITableViewHeaderFooterView {
    static let reuseIdentifier = "section_header"
    private let label = UILabel()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        label.apply(.eyebrow)
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Design.Spacing.s),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Design.Spacing.xs),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Design.Spacing.gutter),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Design.Spacing.gutter)
        ])
        label.accessibilityTraits = .header
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(title: String) { label.text = title }
}

/// One vocabulary / kanji / grammar entry. Vocabulary and grammar read top-down (headword, reading,
/// meaning); a kanji hangs its glyph on the leading side like a level numeral, with meaning and readings beside it.
final class ContentRowCell: UITableViewCell {
    static let reuseIdentifier = "content_cell"

    private let headwordLabel = UILabel()
    private let readingLabel = UILabel()
    private let meaningLabel = UILabel()
    private let textStack = UIStackView()
    private let rootStack = UIStackView()
    private var isGlyph = false
    /// Which text order `textStack` currently holds; nil until the first layout.
    private var arrangedForGlyph: Bool?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        applyHighlight(to: self)
        accessoryType = .disclosureIndicator
        headwordLabel.apply(.headword)
        readingLabel.apply(.reading)
        meaningLabel.apply(.meaning)
        headwordLabel.setContentHuggingPriority(.required, for: .horizontal)
        headwordLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        textStack.axis = .vertical
        textStack.spacing = Design.Spacing.xs
        rootStack.spacing = Design.Spacing.m
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.addArrangedSubview(headwordLabel)
        rootStack.addArrangedSubview(textStack)
        contentView.addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Design.Spacing.m),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Design.Spacing.m),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Design.Spacing.gutter),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Design.Spacing.s)
        ])
        updateLayout()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: ContentRowCell, _) in
            cell.updateLayout()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Side by side for a kanji glyph at regular sizes; stacked for everything else and at accessibility sizes.
    private func updateLayout() {
        let sideBySide = isGlyph && !traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        rootStack.axis = sideBySide ? .horizontal : .vertical
        rootStack.alignment = sideBySide ? .top : .fill
        rootStack.spacing = sideBySide ? Design.Spacing.l : Design.Spacing.xs
        headwordLabel.numberOfLines = sideBySide ? 1 : 0
        guard arrangedForGlyph != isGlyph else { return }
        arrangedForGlyph = isGlyph
        for view in textStack.arrangedSubviews { view.removeFromSuperview() }
        let order = isGlyph ? [meaningLabel, readingLabel] : [readingLabel, meaningLabel]
        order.forEach(textStack.addArrangedSubview)
    }

    func configure(with row: HomeRow) {
        isGlyph = row.isGlyph
        headwordLabel.font = row.isGlyph ? Design.TextRole.numeral.font : Design.TextRole.headword.font
        headwordLabel.text = row.title
        updateLayout()
        // Rows built without structured fields (older callers) fall back to the combined subtitle.
        let structured = row.reading != nil || row.meaning != nil
        readingLabel.text = structured ? row.reading : nil
        meaningLabel.text = structured ? row.meaning : row.subtitle
        readingLabel.isHidden = (readingLabel.text ?? "").isEmpty
        meaningLabel.isHidden = (meaningLabel.text ?? "").isEmpty
        isAccessibilityElement = true
        accessibilityLabel = [row.title, readingLabel.text, meaningLabel.text]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
