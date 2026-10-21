//
//  CommonCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import UIKit

final class CommonCell: UITableViewCell {

    @IBOutlet weak var configImageView: UIImageView!
    @IBOutlet weak var configTitleLabel: UILabel!
    @IBOutlet private weak var subTitleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        accessoryType = .none
        backgroundColor = .systemBackground
        selectedBackgroundView = UIView()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        configImageView.image = nil
        configImageView.tintColor = .label
        configTitleLabel.text = nil
        configTitleLabel.textColor = .label
        subTitleLabel.text = nil
        subTitleLabel.isHidden = true
        accessoryType = .none
    }

    func updateCell(title: String, subText: String, iconName: String, showDisclosure: Bool = true, isDestructive: Bool = false) {
        configTitleLabel.text = title
        subTitleLabel.text = subText
        subTitleLabel.isHidden = subText.isEmpty
        configImageView.image = UIImage(systemName: iconName)

        if isDestructive {
            configTitleLabel.textColor = .systemRed
            configImageView.tintColor = .systemRed
        } else {
            configTitleLabel.textColor = .label
            configImageView.tintColor = .label
        }

        accessoryType = showDisclosure ? .disclosureIndicator : .none
        accessibilityTraits = showDisclosure ? [.button] : []
    }
}