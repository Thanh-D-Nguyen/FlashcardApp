//
//  AccountCell.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/19.
//

import UIKit
import Kingfisher

final class AccountCell: UITableViewCell {

    @IBOutlet private weak var accountImageView: RoundedImageView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var emailLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .default
        backgroundColor = .systemBackground
        accountImageView.contentMode = .scaleAspectFill
        accountImageView.clipsToBounds = true
        nameLabel.font = .preferredFont(forTextStyle: .headline)
        nameLabel.adjustsFontForContentSizeCategory = true
        emailLabel.font = .preferredFont(forTextStyle: .subheadline)
        emailLabel.adjustsFontForContentSizeCategory = true
        emailLabel.textColor = .secondaryLabel
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        accountImageView.kf.cancelDownloadTask()
        accountImageView.image = nil
        nameLabel.text = nil
        emailLabel.text = nil
        accessoryType = .none
    }

    func configure(with user: SocialUserEntity?) {
        if let user = user {
            nameLabel.text = user.displayName ?? NSLocalizedString("User", comment: "")
            emailLabel.text = user.email ?? ""
            emailLabel.isHidden = emailLabel.text?.isEmpty ?? true
            accessoryType = .disclosureIndicator

            if let photoUrl = user.photoUrl {
                accountImageView.kf.setImage(
                    with: photoUrl,
                    placeholder: UIImage(systemName: "person.circle.fill"),
                    options: [.transition(.fade(0.2))]
                )
            } else {
                accountImageView.image = UIImage(systemName: "person.circle.fill")
            }
            accountImageView.tintColor = .systemBlue
            accessibilityLabel = nameLabel.text
            accessibilityHint = NSLocalizedString("Double tap to view account details", comment: "")
        } else {
            nameLabel.text = NSLocalizedString("Sign In", comment: "")
            emailLabel.text = NSLocalizedString("Use your existing website account", comment: "")
            emailLabel.isHidden = false
            accountImageView.image = UIImage(systemName: "person.crop.circle.badge.plus")
            accountImageView.tintColor = .systemBlue
            accessoryType = .disclosureIndicator
            accessibilityLabel = NSLocalizedString("Sign In", comment: "")
            accessibilityHint = NSLocalizedString("Double tap to sign in", comment: "")
        }
    }
}