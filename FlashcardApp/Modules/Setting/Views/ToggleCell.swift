//
//  ToggleCell.swift
//  FlashcardApp
//
//  Created by Claude on 2026/09/07.
//

import UIKit

final class ToggleCell: UITableViewCell {

    static let reuseIdentifier = "ToggleCell"

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .label
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabel
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let toggleSwitch: UISwitch = {
        let sw = UISwitch()
        sw.translatesAutoresizingMaskIntoConstraints = false
        return sw
    }()

    var onToggleChanged: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .systemBackground
        setupSubviews()
        toggleSwitch.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onToggleChanged = nil
        iconImageView.image = nil
        titleLabel.text = nil
        subtitleLabel.text = nil
        subtitleLabel.isHidden = true
        toggleSwitch.isOn = false
        toggleSwitch.isEnabled = true
        iconImageView.tintColor = .label
        titleLabel.textColor = .label
    }

    func configure(with config: ToggleConfig) {
        titleLabel.text = config.title
        iconImageView.image = UIImage(systemName: config.iconName)
        toggleSwitch.isOn = config.isOn
        toggleSwitch.isEnabled = config.isEnabled
        accessibilityLabel = config.title
        toggleSwitch.accessibilityLabel = config.title

        if let subtitle = config.subtitle, !subtitle.isEmpty {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.text = nil
            subtitleLabel.isHidden = true
        }

        if !config.isEnabled {
            iconImageView.tintColor = .tertiaryLabel
            titleLabel.textColor = .tertiaryLabel
        } else {
            iconImageView.tintColor = .label
            titleLabel.textColor = .label
        }
    }

    @objc private func switchValueChanged(_ sender: UISwitch) {
        onToggleChanged?(sender.isOn)
    }

    private func setupSubviews() {
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(toggleSwitch)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            textStack.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: toggleSwitch.leadingAnchor, constant: -8),

            toggleSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            toggleSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])
    }
}