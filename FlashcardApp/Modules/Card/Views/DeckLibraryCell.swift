import UIKit

/// One deck in the library: a Mincho mark of its first card, the name, what is inside and how many cards.
/// The row is one VoiceOver element; swipe actions and the context menu are exposed as custom actions by the table.
final class DeckLibraryCell: UITableViewCell {
    static let reuseIdentifier = "deck_library_cell"

    private let monogramBox = UIView()
    private let monogramLabel = UILabel()
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
        monogramLabel.translatesAutoresizingMaskIntoConstraints = false
        monogramBox.addSubview(monogramLabel)
        monogramBox.setContentHuggingPriority(.required, for: .horizontal)
        monogramBox.setContentCompressionResistancePriority(.required, for: .horizontal)
        let preferredWidth = monogramBox.widthAnchor.constraint(equalToConstant: 56)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            monogramLabel.centerXAnchor.constraint(equalTo: monogramBox.centerXAnchor),
            monogramLabel.centerYAnchor.constraint(equalTo: monogramBox.centerYAnchor),
            preferredWidth,
            monogramBox.heightAnchor.constraint(equalTo: monogramBox.widthAnchor),
            monogramBox.widthAnchor.constraint(greaterThanOrEqualTo: monogramLabel.widthAnchor, constant: Design.Spacing.l),
            monogramBox.heightAnchor.constraint(greaterThanOrEqualTo: monogramLabel.heightAnchor, constant: Design.Spacing.l)
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
        monogramLabel.text = row.monogram
        titleLabel.text = row.title
        detailsLabel.text = row.details
        detailsLabel.isHidden = row.details.isEmpty
        previewLabel.text = row.preview
        previewLabel.isHidden = row.preview.isEmpty
        let count = String.localizedStringWithFormat(NSLocalizedString("%lld cards", comment: ""), row.cardCount)
        let direction = row.direction == .normal
            ? NSLocalizedString("Japanese – Vietnamese", comment: "") : NSLocalizedString("Vietnamese – Japanese", comment: "")
        metaLabel.text = [count, direction].joined(separator: " · ")
        accessibilityIdentifier = "deck_row_\(row.id)"
        accessibilityLabel = [row.title, row.details, row.preview, count].filter { !$0.isEmpty }.joined(separator: ", ")
        accessibilityHint = NSLocalizedString("Study this deck", comment: "")
    }
}
