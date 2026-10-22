//
//  SettingsRowCell.swift
//  FlashcardApp
//
//  One row of the Settings list: monochrome icon, title, optional subtitle and a trailing control
//  (value + disclosure, switch, or pop-up menu button). Built on UIListContentConfiguration so Dynamic
//  Type, margins and VoiceOver behave like system lists.
//

import UIKit

final class SettingsRowCell: UITableViewCell {

    static let reuseIdentifier = "settings_row_cell"

    var onToggle: ((Bool) -> Void)?
    private let toggle = UISwitch()
    private let menuButton = UIButton(configuration: .plain())

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        toggle.onTintColor = Design.Color.accent
        toggle.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onToggle?(self.toggle.isOn)
        }, for: .valueChanged)
        menuButton.showsMenuAsPrimaryAction = true
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: SettingsRowCell, _) in
            guard let state = cell.choiceState else { return }
            cell.configureChoice(title: state.title, iconName: state.icon, selectedTitle: state.selected, menu: state.menu)
        }
        configurationUpdateHandler = { cell, state in
            var background = UIBackgroundConfiguration.clear()
            if state.isHighlighted || state.isSelected { background.backgroundColor = Design.Color.highlight }
            cell.backgroundConfiguration = background
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func prepareForReuse() {
        super.prepareForReuse()
        onToggle = nil
        accessoryView = nil
        accessoryType = .none
        choiceState = nil
        accessibilityElements = nil
        isAccessibilityElement = false
        accessibilityLabel = nil
        accessibilityHint = nil
    }

    /// `value` is shown on the trailing side in the secondary color (value cell); `subtitle` under the title.
    private func setContent(title: String, subtitle: String?, value: String = "", iconName: String,
                            dimmed: Bool = false, destructive: Bool = false) {
        var content = value.isEmpty ? UIListContentConfiguration.subtitleCell() : UIListContentConfiguration.valueCell()
        content.text = title
        content.textProperties.font = .preferredFont(forTextStyle: .body)
        content.textProperties.adjustsFontForContentSizeCategory = true
        content.textProperties.numberOfLines = 0
        content.textProperties.color = destructive ? Design.Color.error : (dimmed ? .tertiaryLabel : Design.Color.textPrimary)
        let secondary = value.isEmpty ? subtitle : value
        content.secondaryText = (secondary ?? "").isEmpty ? nil : secondary
        content.secondaryTextProperties.font = .preferredFont(forTextStyle: .footnote)
        content.secondaryTextProperties.adjustsFontForContentSizeCategory = true
        content.secondaryTextProperties.numberOfLines = 0
        content.secondaryTextProperties.color = Design.Color.textSecondary
        content.image = UIImage(systemName: iconName)
        content.imageProperties.tintColor = destructive ? Design.Color.error : (dimmed ? .tertiaryLabel : Design.Color.accent)
        content.imageProperties.reservedLayoutSize = CGSize(width: 28, height: 0)
        content.imageToTextPadding = Design.Spacing.m
        contentConfiguration = content
    }

    /// Opens something: optional trailing value and a disclosure chevron (or none for an action).
    func configureNavigation(title: String, iconName: String, value: String, disclosure: Bool, destructive: Bool = false) {
        setContent(title: title, subtitle: nil, value: value, iconName: iconName, destructive: destructive)
        accessoryView = nil
        accessoryType = disclosure ? .disclosureIndicator : .none
        selectionStyle = .default
        // A reused cell may have been a toggle/choice container; this row is one "title, value, button" element.
        isAccessibilityElement = true
        accessibilityElements = nil
        accessibilityTraits = disclosure || destructive ? .button : []
    }

    func configureToggle(title: String, subtitle: String?, iconName: String, isOn: Bool, isEnabled: Bool) {
        setContent(title: title, subtitle: subtitle, iconName: iconName, dimmed: !isEnabled)
        toggle.isOn = isOn
        toggle.isEnabled = isEnabled
        toggle.accessibilityLabel = title
        toggle.accessibilityHint = subtitle
        toggle.sizeToFit()
        accessoryView = toggle
        selectionStyle = .none
        // The switch is the one VoiceOver element: its label is the title, its hint the subtitle.
        isAccessibilityElement = false
        accessibilityElements = [toggle]
    }

    /// Pop-up menu button: shows the selected option and opens the menu in place. At accessibility sizes the
    /// value moves under the title and the button keeps only its chevrons, so the title is never squeezed out.
    func configureChoice(title: String, iconName: String, selectedTitle: String, menu: UIMenu) {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        setContent(title: title, subtitle: large ? selectedTitle : nil, iconName: iconName)
        var configuration = UIButton.Configuration.plain()
        if !large {
            var text = AttributedString(selectedTitle)
            text.font = .preferredFont(forTextStyle: .body)
            configuration.attributedTitle = text
        }
        configuration.image = UIImage(systemName: "chevron.up.chevron.down")
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .small)
        configuration.imagePlacement = .trailing
        configuration.imagePadding = Design.Spacing.xs
        configuration.baseForegroundColor = Design.Color.textSecondary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.s, leading: Design.Spacing.s,
                                                              bottom: Design.Spacing.s, trailing: 0)
        menuButton.configuration = configuration
        menuButton.menu = menu
        menuButton.accessibilityLabel = title
        menuButton.accessibilityValue = selectedTitle
        menuButton.sizeToFit()
        accessoryView = menuButton
        accessoryType = .none
        selectionStyle = .none
        isAccessibilityElement = false
        accessibilityElements = [menuButton]
        choiceState = (title, iconName, selectedTitle, menu)
    }

    /// Last choice configuration, re-applied when the text size changes while the row is on screen.
    private var choiceState: (title: String, icon: String, selected: String, menu: UIMenu)?
}
