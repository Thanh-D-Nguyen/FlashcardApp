import UIKit

/// Sits on top of the keyboard while editing: dictionary suggestions for the word being typed, where the
/// learner is in the deck, and the three actions that make entering many cards fast.
final class EditorAccessoryView: UIInputView {
    var onNext: (() -> Void)?
    var onAddCard: (() -> Void)?
    var onDismissKeyboard: (() -> Void)?
    var onSelectSuggestion: ((CardSuggestion) -> Void)?

    private let positionLabel = UILabel()
    private let suggestionScroll = UIScrollView()
    private let suggestionStack = UIStackView()
    private let nextButton = UIButton(configuration: .plain())
    private let addButton = UIButton(configuration: .plain())
    private let dismissButton = UIButton(configuration: .plain())
    private var suggestions: [CardSuggestion] = []

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 52), inputViewStyle: .keyboard)
        allowsSelfSizing = true
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityIdentifier = "deck_keyboard_toolbar"

        positionLabel.apply(.figure)
        positionLabel.numberOfLines = 1
        positionLabel.textColor = Design.Color.textSecondary
        positionLabel.adjustsFontSizeToFitWidth = true
        positionLabel.minimumScaleFactor = 0.6
        positionLabel.accessibilityIdentifier = "deck_position"

        func style(_ button: UIButton, symbol: String, label: String, identifier: String, action: @escaping () -> Void) {
            var configuration = UIButton.Configuration.plain()
            configuration.image = UIImage(systemName: symbol)
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
            button.configuration = configuration
            button.accessibilityLabel = label
            button.accessibilityIdentifier = identifier
            button.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        }
        style(nextButton, symbol: "arrow.right.to.line", label: NSLocalizedString("Next field", comment: ""), identifier: "deck_next_field") { [weak self] in self?.onNext?() }
        style(addButton, symbol: "plus.rectangle.on.rectangle", label: NSLocalizedString("Add card", comment: ""), identifier: "deck_add_card_toolbar") { [weak self] in self?.onAddCard?() }
        style(dismissButton, symbol: "keyboard.chevron.compact.down", label: NSLocalizedString("Hide keyboard", comment: ""), identifier: "deck_dismiss_keyboard") { [weak self] in self?.onDismissKeyboard?() }

        let toolbar = UIStackView(arrangedSubviews: [positionLabel, UIView(), nextButton, addButton, dismissButton])
        toolbar.alignment = .center
        toolbar.spacing = Design.Spacing.xs
        toolbar.isLayoutMarginsRelativeArrangement = true
        toolbar.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: Design.Spacing.l, bottom: 0, trailing: Design.Spacing.s)

        suggestionStack.spacing = Design.Spacing.s
        suggestionStack.translatesAutoresizingMaskIntoConstraints = false
        suggestionScroll.showsHorizontalScrollIndicator = false
        suggestionScroll.addSubview(suggestionStack)
        NSLayoutConstraint.activate([
            suggestionStack.topAnchor.constraint(equalTo: suggestionScroll.contentLayoutGuide.topAnchor, constant: Design.Spacing.xs),
            suggestionStack.bottomAnchor.constraint(equalTo: suggestionScroll.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.xs),
            suggestionStack.leadingAnchor.constraint(equalTo: suggestionScroll.contentLayoutGuide.leadingAnchor, constant: Design.Spacing.l),
            suggestionStack.trailingAnchor.constraint(equalTo: suggestionScroll.contentLayoutGuide.trailingAnchor, constant: -Design.Spacing.l),
            suggestionScroll.heightAnchor.constraint(equalToConstant: 44)
        ])
        suggestionScroll.isHidden = true

        let root = UIStackView(arrangedSubviews: [suggestionScroll, toolbar])
        root.axis = .vertical
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor),
            root.bottomAnchor.constraint(equalTo: bottomAnchor),
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setPosition(_ text: String) { positionLabel.text = text }

    func setSuggestions(_ newSuggestions: [CardSuggestion]) {
        suggestions = newSuggestions
        suggestionStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for suggestion in newSuggestions {
            var configuration = UIButton.Configuration.gray()
            configuration.title = suggestion.title
            configuration.cornerStyle = .capsule
            configuration.buttonSize = .medium
            let chip = ChipButton(configuration: configuration)
            chip.accessibilityLabel = suggestion.title
            chip.addAction(UIAction { [weak self] _ in self?.onSelectSuggestion?(suggestion) }, for: .primaryActionTriggered)
            suggestionStack.addArrangedSubview(chip)
        }
        suggestionScroll.isHidden = newSuggestions.isEmpty
        suggestionScroll.contentOffset = .zero
    }
}
