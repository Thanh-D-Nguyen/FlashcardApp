import UIKit

/// "Card direction": which language is on the front. A pull-down menu inside the row (not an accessory view,
/// whose frame-based layout clips longer values), under a small caption so the value always has the full width.
final class DeckDirectionCell: UITableViewCell {
    static let reuseIdentifier = "deck_direction_cell"

    private let captionLabel = UILabel()
    private let button = UIButton(configuration: .plain())

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Design.Color.surface
        captionLabel.apply(.eyebrow)
        captionLabel.text = NSLocalizedString("Card direction", comment: "").uppercased(with: AppLanguage.current.locale)
        captionLabel.isAccessibilityElement = false
        button.showsMenuAsPrimaryAction = true
        button.contentHorizontalAlignment = .leading
        button.accessibilityIdentifier = "deck_direction"
        let stack = UIStackView(arrangedSubviews: [captionLabel, button])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    static func title(for direction: LanguageSortingType) -> String {
        direction == .normal ? NSLocalizedString("Japanese – Vietnamese", comment: "") : NSLocalizedString("Vietnamese – Japanese", comment: "")
    }

    func configure(direction: LanguageSortingType, onSelect: @escaping (LanguageSortingType) -> Void) {
        var configuration = UIButton.Configuration.plain()
        configuration.title = Self.title(for: direction)
        configuration.image = UIImage(systemName: "chevron.up.chevron.down")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = Design.Spacing.s
        configuration.titleLineBreakMode = .byWordWrapping
        configuration.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.xs, leading: 0, bottom: Design.Spacing.xs, trailing: 0)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = Design.TextRole.meaning.font
            return attributes
        }
        button.configuration = configuration
        button.menu = UIMenu(options: .singleSelection, children: [LanguageSortingType.normal, .opposite].map { option in
            UIAction(title: Self.title(for: option), state: option == direction ? .on : .off) { _ in onSelect(option) }
        })
        button.accessibilityLabel = String(format: NSLocalizedString("Card direction: %@", comment: ""), Self.title(for: direction))
    }
}
