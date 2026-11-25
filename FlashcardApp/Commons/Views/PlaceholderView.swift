//
//  PlaceholderView.swift
//  FlashcardApp
//
//  Legacy placeholder helper migrated onto `Design` tokens and Auto Layout.
//  Prefer `StateView` for all new list/screen empty & error states.
//

import UIKit

final class PlaceholderView: UIView {

    private(set) var text: String
    private(set) var imageTintColor: UIColor
    private(set) var placeholderImage: UIImage?

    enum PlaceholderImage: String {
        case empty = "photo.on.rectangle"
        case warning = "exclamationmark.triangle"
    }

    private let stack = UIStackView()
    private let imageView = UIImageView()
    private let label = UILabel()

    init(text: String, image: PlaceholderImage, imageTintColor: UIColor) {
        self.text = text
        self.imageTintColor = imageTintColor
        self.placeholderImage = UIImage(systemName: image.rawValue)
        super.init(frame: .zero)
        setupViews()
    }

    @available(*, unavailable) required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(text: String, image: PlaceholderImage, imageTintColor: UIColor) {
        self.text = text
        self.imageTintColor = imageTintColor
        self.placeholderImage = UIImage(systemName: image.rawValue)
        label.text = text
        imageView.image = placeholderImage
        imageView.tintColor = imageTintColor
    }

    private func setupViews() {
        backgroundColor = Design.Color.background

        imageView.image = placeholderImage
        imageView.tintColor = imageTintColor
        imageView.contentMode = .scaleAspectFit
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .largeTitle)

        label.apply(.reading)
        label.textAlignment = .center
        label.text = text

        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Design.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(imageView)
        stack.addArrangedSubview(label)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: Design.Spacing.l),
            stack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -Design.Spacing.l)
        ])
    }
}
