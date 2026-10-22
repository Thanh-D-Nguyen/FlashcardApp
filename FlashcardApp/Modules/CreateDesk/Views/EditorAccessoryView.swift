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
            // The bar is as tall as its (two-line, Dynamic Type scaled) chips instead of a fixed height that clips them.
            suggestionScroll.heightAnchor.constraint(equalTo: suggestionScroll.contentLayoutGuide.heightAnchor),
            suggestionScroll.heightAnchor.constraint(lessThanOrEqualToConstant: 96)
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

    /// Shows what the dictionary lookup is doing: chips to pick from, or one line of status.
    func setState(_ state: SuggestionsState) {
        suggestionStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        suggestionScroll.contentOffset = .zero
        switch state {
        case .hidden:
            suggestionScroll.isHidden = true
            return
        case .searching(let partial):
            partial.enumerated().forEach { suggestionStack.addArrangedSubview(chip(for: $1, number: $0 + 1)) }
            suggestionStack.addArrangedSubview(statusView(partial.isEmpty ? NSLocalizedString("Searching the dictionary…", comment: "") : nil, spinning: true))
        case .results(let suggestions):
            suggestions.enumerated().forEach { suggestionStack.addArrangedSubview(chip(for: $1, number: $0 + 1)) }
        case .empty:
            suggestionStack.addArrangedSubview(statusView(NSLocalizedString("No dictionary match", comment: ""), spinning: false))
        case .unavailable:
            suggestionStack.addArrangedSubview(statusView(NSLocalizedString("Online dictionary unavailable. Check your connection.", comment: ""), spinning: false))
        }
        suggestionScroll.isHidden = suggestionStack.arrangedSubviews.isEmpty
    }

    private func chip(for suggestion: CardSuggestion, number: Int) -> UIView {
        var configuration = UIButton.Configuration.gray()
        // A dictionary meaning can list dozens of glosses: the chip shows the beginning, the card gets the full text.
        let headword = Self.clipped(suggestion.japanese, 24)
        configuration.title = suggestion.reading.isEmpty ? headword : "\(headword)  \(Self.clipped(suggestion.reading, 24))"
        var detail = Self.clipped(suggestion.vietnamese, 34)
        if let level = Self.displayLevel(suggestion.jlptLevel) { detail += " · \(level)" }
        configuration.subtitle = detail
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.cornerStyle = .capsule
        configuration.titleAlignment = .leading
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = Design.TextRole.reading.font.withWeight(.semibold)
            return attributes
        }
        configuration.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = Design.TextRole.metadata.font
            return attributes
        }
        let chip = ChipButton(configuration: configuration)
        chip.titleLabel?.numberOfLines = 1
        chip.widthAnchor.constraint(lessThanOrEqualToConstant: 280).isActive = true
        chip.accessibilityLabel = [suggestion.japanese, suggestion.reading, suggestion.vietnamese].filter { !$0.isEmpty }.joined(separator: ", ")
        chip.accessibilityIdentifier = "dictionary_suggestion_\(number)"
        chip.addAction(UIAction { [weak self] _ in self?.onSelectSuggestion?(suggestion) }, for: .primaryActionTriggered)
        return chip
    }

    private func statusView(_ text: String?, spinning: Bool) -> UIView {
        let row = UIStackView()
        row.spacing = Design.Spacing.s
        row.alignment = .center
        if spinning {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            spinner.isAccessibilityElement = false
            row.addArrangedSubview(spinner)
        }
        if let text {
            let label = UILabel()
            label.apply(.metadata)
            label.textColor = Design.Color.textSecondary
            label.text = text
            label.numberOfLines = 1
            label.accessibilityIdentifier = "dictionary_suggestion_status"
            row.addArrangedSubview(label)
        }
        return row
    }

    static func clipped(_ text: String, _ length: Int) -> String {
        let single = text.replacingOccurrences(of: "\n", with: " ")
        return single.count > length ? String(single.prefix(length)).trimmingCharacters(in: .whitespaces) + "…" : single
    }

    /// "N5" from the service's "N5" or "J5"; anything else is not shown.
    static func displayLevel(_ level: String?) -> String? {
        guard let level = level?.uppercased(), level.count == 2, "NJ".contains(level.first!), "12345".contains(level.last!) else { return nil }
        return "N" + level.dropFirst()
    }
}
