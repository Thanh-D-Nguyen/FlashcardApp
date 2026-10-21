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

/// One JLPT level: serif code mark on the leading side, Vietnamese name, description and counts.
final class LevelCell: UITableViewCell {
    static let reuseIdentifier = "level_cell"

    private let markLabel = UILabel()
    private let nameLabel = UILabel()
    private let summaryLabel = UILabel()
    private let countsLabel = UILabel()
    private let textStack = UIStackView()
    private let rootStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        applyHighlight(to: self)
        accessoryType = .disclosureIndicator
        markLabel.apply(.mark)
        markLabel.numberOfLines = 1
        markLabel.setContentHuggingPriority(.required, for: .horizontal)
        markLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        nameLabel.apply(.title)
        summaryLabel.apply(.reading)
        countsLabel.numberOfLines = 0
        textStack.axis = .vertical
        textStack.spacing = Design.Spacing.xs
        textStack.setCustomSpacing(Design.Spacing.s, after: summaryLabel)
        [nameLabel, summaryLabel, countsLabel].forEach(textStack.addArrangedSubview)
        rootStack.spacing = Design.Spacing.m
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        [markLabel, textStack].forEach(rootStack.addArrangedSubview)
        contentView.addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Design.Spacing.l),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Design.Spacing.l),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Design.Spacing.gutter),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Design.Spacing.s),
            markLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: LevelCell, _) in
            cell.updateAxis()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Beside the text at normal sizes; above it for accessibility sizes so the text keeps the full width.
    private func updateAxis() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        rootStack.axis = large ? .vertical : .horizontal
        rootStack.alignment = large ? .leading : .firstBaseline
    }

    func configure(with row: HomeRow) {
        markLabel.text = row.mark
        nameLabel.text = row.name ?? row.title
        summaryLabel.text = row.summary
        summaryLabel.isHidden = (row.summary ?? "").isEmpty
        countsLabel.attributedText = Self.countsText(row.counts)
        isAccessibilityElement = true
        accessibilityLabel = ([row.mark, row.name ?? row.title, row.summary].compactMap { $0 }
            + (row.counts.isEmpty ? ["Chưa có nội dung"] : row.counts.map { "\($0.value) \($0.label)" }))
            .joined(separator: ", ")
    }

    /// "574 từ vựng · 79 kanji · 194 ngữ pháp": tabular figures stand out from their units.
    static func countsText(_ counts: [HomeCount]) -> NSAttributedString {
        let unit: [NSAttributedString.Key: Any] = [.font: Design.TextRole.metadata.font,
                                                   .foregroundColor: Design.TextRole.metadata.color]
        let figure: [NSAttributedString.Key: Any] = [.font: Design.TextRole.figure.font,
                                                     .foregroundColor: Design.TextRole.figure.color]
        guard !counts.isEmpty else { return NSAttributedString(string: "Chưa có nội dung", attributes: unit) }
        let text = NSMutableAttributedString()
        for (index, count) in counts.enumerated() {
            if index > 0 { text.append(NSAttributedString(string: "  ·  ", attributes: unit)) }
            text.append(NSAttributedString(string: count.value.formatted(.number.locale(Locale(identifier: "vi_VN"))), attributes: figure))
            text.append(NSAttributedString(string: " \(count.label)", attributes: unit))
        }
        return text
    }
}

/// One vocabulary / kanji / grammar entry: headword first, then reading, then Vietnamese meaning.
final class ContentRowCell: UITableViewCell {
    static let reuseIdentifier = "content_cell"

    private let headwordLabel = UILabel()
    private let readingLabel = UILabel()
    private let meaningLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        applyHighlight(to: self)
        accessoryType = .disclosureIndicator
        headwordLabel.apply(.headword)
        readingLabel.apply(.reading)
        meaningLabel.apply(.meaning)
        let stack = UIStackView(arrangedSubviews: [headwordLabel, readingLabel, meaningLabel])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Design.Spacing.m),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Design.Spacing.m),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Design.Spacing.s)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(with row: HomeRow) {
        headwordLabel.text = row.title
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
