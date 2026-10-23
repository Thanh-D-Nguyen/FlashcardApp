import UIKit

/// The example sentences of the card being studied: a heading with a count and a Show/Hide control, then one row per
/// sentence (Japanese, reading, Vietnamese) with read-aloud and copy. Plain rows on the screen background, separated
/// by hairlines: the card stays the one raised block. Mirrors the website's "Related example sentences" panel.
final class StudyExamplesView: UIView {
    var onSpeak: ((String) -> Void)?
    var onToggle: ((Bool) -> Void)?
    var onRetry: (() -> Void)?

    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let toggleButton = UIButton(configuration: .plain())
    private let bodyStack = UIStackView()
    private var expanded = true
    private var copiedID: String?
    private var examples: [CardExample] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.apply(.title)
        titleLabel.text = NSLocalizedString("Example sentences", comment: "Heading above the example sentences of a card")
        titleLabel.accessibilityTraits = .header
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        countLabel.apply(.figure)
        countLabel.textColor = Design.Color.textSecondary
        countLabel.setContentHuggingPriority(.required, for: .horizontal)
        toggleButton.setContentHuggingPriority(.required, for: .horizontal)
        toggleButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        toggleButton.accessibilityIdentifier = "study_examples_toggle"
        toggleButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onToggle?(!self.expanded)
        }, for: .primaryActionTriggered)

        let header = UIStackView(arrangedSubviews: [titleLabel, countLabel, UIView(), toggleButton])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = Design.Spacing.s
        bodyStack.axis = .vertical
        bodyStack.spacing = 0
        let root = UIStackView(arrangedSubviews: [header, bodyStack])
        root.axis = .vertical
        root.spacing = Design.Spacing.xs
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor), root.bottomAnchor.constraint(equalTo: bottomAnchor),
            root.leadingAnchor.constraint(equalTo: leadingAnchor), root.trailingAnchor.constraint(equalTo: trailingAnchor),
            toggleButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        accessibilityIdentifier = "study_examples"
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(state: ExamplesState, expanded: Bool) {
        self.expanded = expanded
        isHidden = state == .hidden
        guard state != .hidden else { return }
        if case .results(let found) = state { examples = found } else { examples = []; copiedID = nil }
        countLabel.text = examples.isEmpty ? nil : "\(examples.count)"
        countLabel.isHidden = examples.isEmpty
        toggleButton.configuration?.title = expanded ? NSLocalizedString("Hide", comment: "Collapse the example sentences") : NSLocalizedString("Show", comment: "Expand the example sentences")
        toggleButton.accessibilityLabel = expanded ? NSLocalizedString("Hide example sentences", comment: "") : NSLocalizedString("Show example sentences", comment: "")
        bodyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        bodyStack.isHidden = !expanded
        guard expanded else { return }
        switch state {
        case .hidden: break
        case .loading:
            bodyStack.addArrangedSubview(statusRow(NSLocalizedString("Looking for example sentences…", comment: ""), spinning: true))
        case .empty:
            bodyStack.addArrangedSubview(statusRow(NSLocalizedString("No example sentences found for this card yet.", comment: ""), spinning: false))
        case .unavailable:
            bodyStack.addArrangedSubview(statusRow(NSLocalizedString("Example sentences need a connection.", comment: ""), spinning: false))
            var retry = UIButton.Configuration.plain()
            retry.title = NSLocalizedString("Try again", comment: "")
            let button = UIButton(configuration: retry)
            button.accessibilityIdentifier = "study_examples_retry"
            button.contentHorizontalAlignment = .leading
            button.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .primaryActionTriggered)
            bodyStack.addArrangedSubview(button)
        case .results(let found):
            for (index, example) in found.enumerated() {
                if index > 0 { bodyStack.addArrangedSubview(separator()) }
                bodyStack.addArrangedSubview(row(for: example, index: index))
            }
        }
    }

    // MARK: Rows

    private func statusRow(_ text: String, spinning: Bool) -> UIView {
        let label = UILabel()
        label.apply(.metadata)
        label.text = text
        var views: [UIView] = []
        if spinning {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            views.append(spinner)
        }
        views.append(label)
        let stack = UIStackView(arrangedSubviews: views)
        stack.spacing = Design.Spacing.s
        stack.alignment = .center
        stack.layoutMargins = UIEdgeInsets(top: Design.Spacing.s, left: 0, bottom: Design.Spacing.s, right: 0)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.accessibilityIdentifier = "study_examples_status"
        return stack
    }

    private func separator() -> UIView {
        let line = UIView()
        line.backgroundColor = Design.Color.separator
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        line.isAccessibilityElement = false
        return line
    }

    private func row(for example: CardExample, index: Int) -> UIView {
        let sentence = UILabel()
        sentence.apply(.explanation)
        sentence.font = UIFont.preferredFont(forTextStyle: .body).withWeight(.semibold)
        sentence.text = example.japanese
        sentence.accessibilityLanguage = "ja"
        var lines: [UIView] = [sentence]
        if !example.reading.isEmpty {
            let reading = UILabel()
            reading.apply(.reading)
            reading.text = example.reading
            reading.accessibilityLanguage = "ja"
            lines.append(reading)
        }
        if !example.translation.isEmpty {
            let translation = UILabel()
            translation.apply(.meaning)
            translation.font = UIFont.preferredFont(forTextStyle: .subheadline)
            translation.text = example.translation
            lines.append(translation)
        }
        let text = UIStackView(arrangedSubviews: lines)
        text.axis = .vertical
        text.spacing = Design.Spacing.xs

        let speak = actionButton(symbol: "speaker.wave.2", label: NSLocalizedString("Read aloud", comment: ""), identifier: "study_example_speak_\(index)")
        speak.addAction(UIAction { [weak self] _ in self?.onSpeak?(example.id) }, for: .primaryActionTriggered)
        let copied = copiedID == example.id
        let copy = actionButton(symbol: copied ? "checkmark" : "doc.on.doc",
                                label: copied ? NSLocalizedString("Copied", comment: "") : NSLocalizedString("Copy", comment: ""),
                                identifier: "study_example_copy_\(index)")
        copy.addAction(UIAction { [weak self] _ in self?.copy(example) }, for: .primaryActionTriggered)
        let actions = UIStackView(arrangedSubviews: [speak, copy])
        actions.axis = .vertical
        actions.spacing = 0

        let row = UIStackView(arrangedSubviews: [text, actions])
        row.alignment = .top
        row.spacing = Design.Spacing.s
        row.layoutMargins = UIEdgeInsets(top: Design.Spacing.m, left: 0, bottom: Design.Spacing.m, right: 0)
        row.isLayoutMarginsRelativeArrangement = true
        row.accessibilityIdentifier = "study_example_row_\(index)"
        return row
    }

    private func actionButton(symbol: String, label: String, identifier: String) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbol)
        configuration.baseForegroundColor = Design.Color.accent
        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = label
        button.accessibilityIdentifier = identifier
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return button
    }

    private func copy(_ example: CardExample) {
        UIPasteboard.general.string = example.copyText
        copiedID = example.id
        configure(state: .results(examples), expanded: expanded)
        UIAccessibility.post(notification: .announcement, argument: NSLocalizedString("Copied", comment: ""))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self, self.copiedID == example.id else { return }
            self.copiedID = nil
            self.configure(state: .results(self.examples), expanded: self.expanded)
        }
    }
}
