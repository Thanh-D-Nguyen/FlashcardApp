import UIKit

/// The last row of the cards section: one obvious way to add a card.
final class AddCardCell: UITableViewCell {
    static let reuseIdentifier = "add_card_cell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Design.Color.surface
        var content = UIListContentConfiguration.cell()
        content.text = NSLocalizedString("Add card", comment: "")
        content.textProperties.apply(.title)
        content.textProperties.color = Design.Color.accent
        content.image = UIImage(systemName: "plus.circle.fill")
        content.imageProperties.tintColor = Design.Color.accent
        contentConfiguration = content
        accessibilityTraits = .button
        accessibilityIdentifier = "add_card"
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
