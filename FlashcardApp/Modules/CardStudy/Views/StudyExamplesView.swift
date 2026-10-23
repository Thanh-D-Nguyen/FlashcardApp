import UIKit

/// The example sentences of the card being studied: a heading with a count, an Add button and a Show/Hide control, then
/// one row per sentence (Japanese, reading, Vietnamese) with read-aloud, copy and a menu to edit or remove it. Sentences
/// the learner wrote or changed carry a small tag. Plain rows on the screen background, separated by hairlines: the card
/// stays the one raised block. Mirrors the website's "Related example sentences" panel and adds the learner's own changes.
final class StudyExamplesView: UIView {
    var onSpeak: ((String) -> Void)?
    var onToggle: ((Bool) -> Void)?
    var onRetry: (() -> Void)?
    var onAdd: (() -> Void)?
    var onEdit: ((String) -> Void)?
    var onRemove: ((String) -> Void)?
    var onRestoreOriginal: ((String) -> Void)?
    var onRestoreRemoved: (() -> Void)?

    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let addButton = UIButton(configuration: .plain())
    private let toggleButton = UIButton(configuration: .plain())
    private let bodyStack = UIStackView()
    private var expanded = true
    private var copiedID: String?
    private var panel = ExamplesPanelState.hidden

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.apply(.title)
        titleLabel.text = NSLocalizedString("Example sentences", comment: "Heading above the example sentences of a card")
        titleLabel.accessibilityTraits = .header
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        countLabel.apply(.figure)
        countLabel.textColor = Design.Color.textSecondary
        countLabel.setContentHuggingPriority(.required, for: .horizontal)
        addButton.configuration?.image = UIImage(systemName: "plus")
        addButton.accessibilityLabel = NSLocalizedString("Add example sentence", comment: "")
        addButton.accessibilityIdentifier = "study_examples_add"
        addButton.addAction(UIAction { [weak self] _ in self?.onAdd?() }, for: .primaryActionTriggered)
        toggleButton.setContentHuggingPriority(.required, for: .horizontal)
        toggleButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        toggleButton.accessibilityIdentifier = "study_examples_toggle"
        toggleButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.onToggle?(!self.expanded)
        }, for: .primaryActionTriggered)

        let header = UIStackView(arrangedSubviews: [titleLabel, countLabel, UIView(), addButton, toggleButton])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = Design.Spacing.xs
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
            toggleButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            addButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44), addButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        accessibilityIdentifier = "study_examples"
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(state: ExamplesPanelState, expanded: Bool) {
        self.expanded = expanded
        panel = state
        isHidden = !state.isVisible
        guard state.isVisible else { copiedID = nil; return }
        if !state.items.contains(where: { $0.id == copiedID }) { copiedID = nil }
        countLabel.text = state.items.isEmpty ? nil : "\(state.items.count)"
        countLabel.isHidden = state.items.isEmpty
        addButton.isHidden = !expanded
        toggleButton.configuration?.title = expanded ? NSLocalizedString("Hide", comment: "Collapse the example sentences") : NSLocalizedString("Show", comment: "Expand the example sentences")
        toggleButton.accessibilityLabel = expanded ? NSLocalizedString("Hide example sentences", comment: "") : NSLocalizedString("Show example sentences", comment: "")
        bodyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        bodyStack.isHidden = !expanded
        guard expanded else { return }

        for (index, item) in state.items.enumerated() {
            if index > 0 { bodyStack.addArrangedSubview(separator()) }
            bodyStack.addArrangedSubview(row(for: item, index: index))
        }
        switch state.server {
        case .loading:
            bodyStack.addArrangedSubview(statusRow(NSLocalizedString("Looking for example sentences…", comment: ""), spinning: true))
        case .unavailable:
            bodyStack.addArrangedSubview(statusRow(NSLocalizedString("Example sentences need a connection.", comment: ""), spinning: false))
            var retry = UIButton.Configuration.plain()
            retry.title = NSLocalizedString("Try again", comment: "")
            let button = UIButton(configuration: retry)
            button.accessibilityIdentifier = "study_examples_retry"
            button.contentHorizontalAlignment = .leading
            button.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .primaryActionTriggered)
            bodyStack.addArrangedSubview(button)
        case .loaded, .notApplicable:
            if state.items.isEmpty {
                bodyStack.addArrangedSubview(statusRow(NSLocalizedString("No example sentences yet. Add your own with the + button.", comment: ""), spinning: false))
            }
        }
        if state.removedCount > 0 {
            var restore = UIButton.Configuration.plain()
            restore.title = String.localizedStringWithFormat(NSLocalizedString("Restore %lld removed", comment: "Bring back example sentences the learner removed"), state.removedCount)
            restore.image = UIImage(systemName: "arrow.uturn.backward")
            restore.imagePadding = Design.Spacing.s
            let button = UIButton(configuration: restore)
            button.accessibilityIdentifier = "study_examples_restore"
            button.contentHorizontalAlignment = .leading
            button.addAction(UIAction { [weak self] _ in self?.onRestoreRemoved?() }, for: .primaryActionTriggered)
            bodyStack.addArrangedSubview(button)
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

    private func originTag(for origin: ExampleOrigin) -> String? {
        switch origin {
        case .server: return nil
        case .edited: return NSLocalizedString("Edited by you", comment: "Tag on a server example sentence the learner changed")
        case .custom: return NSLocalizedString("Your sentence", comment: "Tag on an example sentence the learner wrote")
        }
    }

    private func row(for item: ExampleItem, index: Int) -> UIView {
        let example = item.example
        var lines: [UIView] = []
        if let tag = originTag(for: item.origin) {
            let label = UILabel()
            label.apply(.eyebrow)
            label.textColor = Design.Color.accent
            label.text = tag.uppercased(with: AppLanguage.current.locale)
            label.accessibilityIdentifier = "study_example_tag_\(index)"
            lines.append(label)
        }
        let sentence = UILabel()
        sentence.apply(.explanation)
        sentence.font = UIFont.preferredFont(forTextStyle: .body).withWeight(.semibold)
        sentence.text = example.japanese
        sentence.accessibilityLanguage = "ja"
        lines.append(sentence)
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
        speak.addAction(UIAction { [weak self] _ in self?.onSpeak?(item.id) }, for: .primaryActionTriggered)
        let copied = copiedID == item.id
        let copy = actionButton(symbol: copied ? "checkmark" : "doc.on.doc",
                                label: copied ? NSLocalizedString("Copied", comment: "") : NSLocalizedString("Copy", comment: ""),
                                identifier: "study_example_copy_\(index)")
        copy.addAction(UIAction { [weak self] _ in self?.copy(item) }, for: .primaryActionTriggered)
        let more = actionButton(symbol: "ellipsis", label: NSLocalizedString("More actions", comment: ""), identifier: "study_example_more_\(index)")
        more.menu = menu(for: item)
        more.showsMenuAsPrimaryAction = true
        let actions = UIStackView(arrangedSubviews: [speak, copy, more])
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

    private func menu(for item: ExampleItem) -> UIMenu {
        let edit = UIAction(title: NSLocalizedString("Edit", comment: ""), image: UIImage(systemName: "pencil")) { [weak self] _ in self?.onEdit?(item.id) }
        edit.accessibilityIdentifier = "study_example_edit"
        var actions = [edit]
        if item.origin == .edited {
            actions.append(UIAction(title: NSLocalizedString("Restore original", comment: ""), image: UIImage(systemName: "arrow.uturn.backward")) { [weak self] _ in
                self?.onRestoreOriginal?(item.id)
            })
        }
        let isMine = item.origin == .custom
        let remove = UIAction(title: isMine ? NSLocalizedString("Delete", comment: "") : NSLocalizedString("Remove from my examples", comment: ""),
                              image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in self?.onRemove?(item.id) }
        remove.accessibilityIdentifier = "study_example_remove"
        return UIMenu(children: actions + [remove])
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

    private func copy(_ item: ExampleItem) {
        UIPasteboard.general.string = item.example.copyText
        copiedID = item.id
        configure(state: panel, expanded: expanded)
        UIAccessibility.post(notification: .announcement, argument: NSLocalizedString("Copied", comment: ""))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self, self.copiedID == item.id else { return }
            self.copiedID = nil
            self.configure(state: self.panel, expanded: self.expanded)
        }
    }
}
