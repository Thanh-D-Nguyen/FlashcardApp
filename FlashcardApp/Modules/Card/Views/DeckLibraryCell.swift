import UIKit

/// One deck in the library: a Mincho mark of its first card, the name, what is inside and how many cards.
/// The row is one VoiceOver element; swipe actions and the context menu are exposed as custom actions by the table.
final class DeckLibraryCell: UITableViewCell {
    static let reuseIdentifier = "deck_library_cell"

    private let monogramBox = UIView()
    private let monogramLabel = UILabel()
    private let unitLabel = UILabel()
    private let markStack = UIStackView()
    private let titleLabel = UILabel()
    private let detailsLabel = UILabel()
    private let previewLabel = UILabel()
    private let metaLabel = UILabel()
    private let textStack = UIStackView()
    private let rootStack = UIStackView()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundConfiguration = .clear()
        configurationUpdateHandler = { cell, state in
            var background = UIBackgroundConfiguration.clear()
            if state.isHighlighted || state.isSelected { background.backgroundColor = Design.Color.highlight }
            cell.backgroundConfiguration = background
        }

        monogramBox.backgroundColor = Design.Color.highlight
        monogramBox.layer.cornerRadius = Design.Spacing.m
        monogramBox.layer.cornerCurve = .continuous
        monogramBox.isAccessibilityElement = false
        monogramBox.translatesAutoresizingMaskIntoConstraints = false
        monogramLabel.apply(.monogram)
        monogramLabel.numberOfLines = 1
        monogramLabel.textAlignment = .center
        unitLabel.apply(.metadata)
        unitLabel.font = UIFont.preferredFont(forTextStyle: .caption2)
        unitLabel.textAlignment = .center
        unitLabel.numberOfLines = 1
        unitLabel.isHidden = true
        markStack.axis = .vertical
        markStack.alignment = .center
        markStack.translatesAutoresizingMaskIntoConstraints = false
        [monogramLabel, unitLabel].forEach(markStack.addArrangedSubview)
        monogramBox.addSubview(markStack)
        monogramBox.setContentHuggingPriority(.required, for: .horizontal)
        monogramBox.setContentCompressionResistancePriority(.required, for: .horizontal)
        let preferredWidth = monogramBox.widthAnchor.constraint(equalToConstant: 56)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            markStack.centerXAnchor.constraint(equalTo: monogramBox.centerXAnchor),
            markStack.centerYAnchor.constraint(equalTo: monogramBox.centerYAnchor),
            preferredWidth,
            monogramBox.heightAnchor.constraint(equalTo: monogramBox.widthAnchor),
            monogramBox.widthAnchor.constraint(greaterThanOrEqualTo: markStack.widthAnchor, constant: Design.Spacing.l),
            monogramBox.heightAnchor.constraint(greaterThanOrEqualTo: markStack.heightAnchor, constant: Design.Spacing.l)
        ])

        titleLabel.apply(.title)
        detailsLabel.apply(.reading)
        previewLabel.apply(.reading)
        previewLabel.font = Design.TextRole.headword.font.withSize(UIFont.preferredFont(forTextStyle: .subheadline).pointSize)
        metaLabel.apply(.metadata)
        textStack.axis = .vertical
        textStack.spacing = Design.Spacing.xs
        [titleLabel, detailsLabel, previewLabel, metaLabel].forEach(textStack.addArrangedSubview)
        textStack.setCustomSpacing(Design.Spacing.s, after: previewLabel)

        chevron.tintColor = .tertiaryLabel
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .small)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)
        chevron.isAccessibilityElement = false

        rootStack.spacing = Design.Spacing.m
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        [monogramBox, textStack, chevron].forEach(rootStack.addArrangedSubview)
        contentView.addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Design.Spacing.m),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Design.Spacing.m),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Design.Spacing.gutter),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Design.Spacing.gutter)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: DeckLibraryCell, _) in cell.updateAxis() }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Mark beside the text normally; above it at accessibility sizes so the text keeps the full width.
    private func updateAxis() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        rootStack.axis = large ? .vertical : .horizontal
        rootStack.alignment = large ? .leading : .top
        chevron.isHidden = large
    }

    func configure(with row: DeckRowModel) {
        let count = String.localizedStringWithFormat(NSLocalizedString("%lld cards", comment: ""), row.cardCount)
        let direction = row.direction == .normal
            ? NSLocalizedString("Japanese – Vietnamese", comment: "") : NSLocalizedString("Vietnamese – Japanese", comment: "")
        configureRow(monogram: row.monogram, title: row.title, details: row.details, preview: row.preview,
                     meta: [count, direction].joined(separator: " · "), identifier: "deck_row_\(row.id)",
                     hint: NSLocalizedString("Study this deck", comment: ""),
                     accessibility: [row.title, row.details, row.preview, count].filter { !$0.isEmpty }.joined(separator: ", "))
    }

    /// `unit` turns the tile into a count (the number large, its unit small beneath); without it the tile carries a one-line mark.
    func configureRow(monogram: String, unit: String? = nil, title: String, details: String, preview: String, meta: String,
                      identifier: String, hint: String, accessibility: String) {
        monogramLabel.text = monogram
        monogramLabel.font = unit == nil
            ? Design.TextRole.monogram.font
            : UIFontMetrics(forTextStyle: .title3).scaledFont(for: Design.TextRole.monogram.font.withSize(24), maximumPointSize: 34)
        unitLabel.text = unit
        unitLabel.isHidden = unit == nil
        titleLabel.text = title
        detailsLabel.text = details
        detailsLabel.isHidden = details.isEmpty
        previewLabel.text = preview
        previewLabel.isHidden = preview.isEmpty
        metaLabel.text = meta
        accessibilityIdentifier = identifier
        accessibilityLabel = accessibility
        accessibilityHint = hint
    }
}
