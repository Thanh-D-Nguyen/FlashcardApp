import UIKit

/// One search result or history row. The layout follows what each kind of entry is: a headword with its reading and meaning,
/// a kanji as a large character with its Sino-Vietnamese meaning, or a whole sentence with its translation.
final class DictionaryResultCell: UITableViewCell {
    static let identifier = "DictionaryResultCell"

    private let glyph = UILabel()
    private let lead = UILabel()
    private let level = UILabel()
    private let second = UILabel()
    private let third = UILabel()
    private let textStack = UIStackView()
    private let headRow = UIStackView()
    private let rowStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .default
        accessoryType = .none
        let selected = UIView()
        selected.backgroundColor = Design.Color.highlight
        selectedBackgroundView = selected

        glyph.font = Design.TextRole.numeral.font
        glyph.textColor = Design.Color.accent
        glyph.adjustsFontForContentSizeCategory = true
        glyph.setContentHuggingPriority(.required, for: .horizontal)
        glyph.setContentCompressionResistancePriority(.required, for: .horizontal)
        glyph.textAlignment = .center
        glyph.widthAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true

        level.apply(.metadata)
        level.font = Design.TextRole.weighted(.caption1, weight: .semibold)
        level.textColor = Design.Color.accent
        level.numberOfLines = 1
        level.setContentHuggingPriority(.required, for: .horizontal)
        level.setContentCompressionResistancePriority(.required, for: .horizontal)

        lead.numberOfLines = 0
        lead.adjustsFontForContentSizeCategory = true
        second.numberOfLines = 0
        [second, third].forEach { $0.adjustsFontForContentSizeCategory = true }

        headRow.axis = .horizontal
        headRow.alignment = .firstBaseline
        headRow.spacing = Design.Spacing.s
        headRow.addArrangedSubview(lead)
        headRow.addArrangedSubview(level)

        textStack.axis = .vertical
        textStack.spacing = 2
        [headRow, second, third].forEach(textStack.addArrangedSubview)

        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = Design.Spacing.m
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.addArrangedSubview(glyph)
        rowStack.addArrangedSubview(textStack)
        contentView.addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Design.Spacing.m),
            rowStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Design.Spacing.m),
            rowStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        updateDensity()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: DictionaryResultCell, _) in
            cell.updateDensity()
        }
    }

    private func updateDensity() {
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        rowStack.axis = isAX ? .vertical : .horizontal
        rowStack.alignment = isAX ? .leading : .center
        third.numberOfLines = isAX ? 0 : 3
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// `terms` are marked inside the text; `showReading` is the learner's readings preference (sentences only).
    func configure(_ item: DictionaryItem, terms: [String], showReading: Bool) {
        let isKanji = item.kind == .kanji
        glyph.isHidden = !isKanji
        level.text = item.level
        level.isHidden = item.level == nil

        switch item.kind {
        case .kanji:
            glyph.text = item.title
            lead.attributedText = nil
            lead.text = item.meaning ?? item.title
            lead.font = Design.TextRole.title.font
            lead.textColor = Design.Color.textPrimary
            second.text = item.reading
            third.text = nil
        case .sentence:
            lead.attributedText = TextHighlight.attributed(item.title, terms: terms, font: Design.TextRole.sentence.font, color: Design.Color.textPrimary)
            second.text = showReading ? item.reading : nil
            second.font = Design.TextRole.metadata.font
            second.textColor = Design.Color.textSecondary
            third.attributedText = item.meaning.map {
                TextHighlight.attributed($0, terms: terms, font: Design.TextRole.meaning.font, color: Design.Color.textSecondary)
            }
        case .vocabulary, .grammar:
            lead.attributedText = TextHighlight.attributed(item.title, terms: terms, font: Design.TextRole.weighted(.title2, weight: .semibold), color: Design.Color.textPrimary)
            second.text = item.reading
            second.font = Design.TextRole.reading.font
            second.textColor = Design.Color.textSecondary
            third.attributedText = item.meaning.map {
                TextHighlight.attributed($0, terms: terms, font: Design.TextRole.meaning.font, color: Design.Color.textPrimary)
            }
        }
        if isKanji {
            second.font = Design.TextRole.reading.font
            second.textColor = Design.Color.textSecondary
        }
        second.isHidden = (second.text ?? "").isEmpty && second.attributedText == nil
        third.isHidden = third.attributedText == nil && (third.text ?? "").isEmpty
        updateDensity()
        accessibilityLabel = [item.title, item.reading, item.meaning, item.level.map { String(format: NSLocalizedString("JLPT level %@", comment: ""), $0) }]
            .compactMap { $0 }.joined(separator: ", ")
    }
}

/// A history query row: the text with a clock icon.
final class DictionaryQueryCell: UITableViewCell {
    static let identifier = "DictionaryQueryCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        let selected = UIView()
        selected.backgroundColor = Design.Color.highlight
        selectedBackgroundView = selected
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(query: String, symbol: String = "clock.arrow.circlepath", hint: String? = nil) {
        var content = defaultContentConfiguration()
        content.text = query
        content.textProperties.font = Design.TextRole.sentence.font
        content.textProperties.adjustsFontForContentSizeCategory = true
        content.textProperties.numberOfLines = 0
        content.image = UIImage(systemName: symbol)
        content.imageProperties.tintColor = Design.Color.textSecondary
        contentConfiguration = content
        accessibilityLabel = query
        accessibilityHint = hint
    }
}

/// The header of a history section ("Recent searches" with its Clear button). A real header/footer view, so the table
/// exposes it to VoiceOver once.
final class DictionaryHistoryHeader: UITableViewHeaderFooterView {
    static let identifier = "DictionaryHistoryHeader"
    private var content: SectionTitleView?

    func configure(title: String, clearTitle: String, identifier: String, clear: @escaping () -> Void) {
        content?.removeFromSuperview()
        let view = SectionTitleView(title: title, actionTitle: clearTitle, action: clear, actionIdentifier: identifier)
        view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Design.Spacing.m),
            view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Design.Spacing.xs),
            view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Design.Spacing.gutter),
            view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Design.Spacing.gutter)
        ])
        content = view
    }
}
