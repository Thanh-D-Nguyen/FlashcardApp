//
//  AccountCell.swift
//  FlashcardApp
//
//  Account header of the Settings screen. Signed in: monogram or photo, name, email.
//  Signed out: the same layout plus the screen's one primary action, "Đăng nhập".
//

import UIKit
import Kingfisher

final class AccountCell: UITableViewCell {

    static let reuseIdentifier = "account_cell"
    private static let avatarSize: CGFloat = 64

    var onSignIn: (() -> Void)?

    private let avatarView = UIView()
    private let photoView = UIImageView()
    private let monogramLabel = UILabel()
    private let glyphView = UIImageView()
    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let infoView = UIView()
    private let signInButton = UIButton(configuration: Design.Button.primary(title: NSLocalizedString("Sign In", comment: "")))
    private let headerStack = UIStackView()
    private let rootStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        configurationUpdateHandler = { cell, state in
            var background = UIBackgroundConfiguration.clear()
            if state.isHighlighted || state.isSelected { background.backgroundColor = Design.Color.highlight }
            cell.backgroundConfiguration = background
        }

        avatarView.layer.cornerRadius = Self.avatarSize / 2
        avatarView.layer.borderWidth = 1
        avatarView.observeAdaptiveBorder { Design.Color.accent }
        avatarView.clipsToBounds = true
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.isAccessibilityElement = false
        photoView.contentMode = .scaleAspectFill
        monogramLabel.apply(.monogram)
        monogramLabel.numberOfLines = 1
        monogramLabel.textAlignment = .center
        glyphView.image = UIImage(systemName: "person")
        glyphView.tintColor = Design.Color.accent
        glyphView.contentMode = .scaleAspectFit
        for view in [photoView, monogramLabel, glyphView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            avatarView.addSubview(view)
        }
        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarView.heightAnchor.constraint(equalToConstant: Self.avatarSize),
            photoView.topAnchor.constraint(equalTo: avatarView.topAnchor),
            photoView.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor),
            photoView.leadingAnchor.constraint(equalTo: avatarView.leadingAnchor),
            photoView.trailingAnchor.constraint(equalTo: avatarView.trailingAnchor),
            monogramLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            monogramLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            glyphView.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            glyphView.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            glyphView.widthAnchor.constraint(equalToConstant: 28),
            glyphView.heightAnchor.constraint(equalToConstant: 28)
        ])

        nameLabel.apply(.title)
        nameLabel.font = Design.TextRole.weighted(.title3, weight: .semibold)
        detailLabel.apply(.reading)
        let textStack = UIStackView(arrangedSubviews: [nameLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = Design.Spacing.xs
        textStack.translatesAutoresizingMaskIntoConstraints = false
        infoView.addSubview(textStack)
        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: infoView.topAnchor),
            textStack.bottomAnchor.constraint(equalTo: infoView.bottomAnchor),
            textStack.leadingAnchor.constraint(equalTo: infoView.leadingAnchor),
            textStack.trailingAnchor.constraint(equalTo: infoView.trailingAnchor)
        ])
        infoView.isAccessibilityElement = true

        headerStack.spacing = Design.Spacing.l
        headerStack.alignment = .center
        [avatarView, infoView].forEach(headerStack.addArrangedSubview)

        signInButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        signInButton.enableAdaptiveCornerStyle()
        signInButton.accessibilityIdentifier = "setting_sign_in"
        signInButton.addAction(UIAction { [weak self] _ in self?.onSignIn?() }, for: .primaryActionTriggered)

        rootStack.axis = .vertical
        rootStack.spacing = Design.Spacing.l
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        [headerStack, signInButton].forEach(rootStack.addArrangedSubview)
        contentView.addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Design.Spacing.s),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Design.Spacing.l),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Design.Spacing.gutter),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Design.Spacing.gutter)
        ])
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: AccountCell, _) in
            cell.updateAxis()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func prepareForReuse() {
        super.prepareForReuse()
        photoView.kf.cancelDownloadTask()
        photoView.image = nil
        onSignIn = nil
    }

    /// Avatar beside the text at regular sizes; above it at accessibility sizes.
    private func updateAxis() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        headerStack.axis = large ? .vertical : .horizontal
        headerStack.alignment = large ? .leading : .center
    }

    func configure(with user: SocialUserEntity?) {
        photoView.kf.cancelDownloadTask()
        photoView.image = nil
        photoView.isHidden = true
        if let user {
            let name = user.displayName ?? user.email ?? ""
            nameLabel.text = user.displayName ?? NSLocalizedString("User", comment: "")
            detailLabel.text = user.email
            detailLabel.isHidden = (user.email ?? "").isEmpty
            let initial = name.first.map { String($0).uppercased() }
            monogramLabel.text = initial
            monogramLabel.isHidden = initial == nil
            glyphView.isHidden = initial != nil
            signInButton.isHidden = true
            selectionStyle = .none
            infoView.accessibilityLabel = [nameLabel.text, user.email].compactMap { $0 }.joined(separator: ", ")
            infoView.accessibilityTraits = .staticText
            if let photoUrl = user.photoUrl {
                photoView.kf.setImage(with: photoUrl, options: [.transition(.fade(0.2))]) { [weak self] result in
                    // Keep the monogram if the photo cannot be loaded.
                    if case .success = result {
                        self?.photoView.isHidden = false
                        self?.monogramLabel.isHidden = true
                        self?.glyphView.isHidden = true
                    }
                }
            }
        } else {
            nameLabel.text = NSLocalizedString("Account", comment: "")
            detailLabel.text = NSLocalizedString("Use your website account to sign in.", comment: "")
            detailLabel.isHidden = false
            monogramLabel.isHidden = true
            glyphView.isHidden = false
            signInButton.isHidden = false
            selectionStyle = .default
            infoView.accessibilityLabel = [nameLabel.text, detailLabel.text].compactMap { $0 }.joined(separator: ". ")
            infoView.accessibilityTraits = .staticText
        }
        // Container cell: the text and the sign-in button are separate VoiceOver elements.
        isAccessibilityElement = false
        accessibilityElements = user == nil ? [infoView, signInButton] : [infoView]
    }
}
