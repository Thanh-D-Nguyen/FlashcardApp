import UIKit

/// One card in the editor. Front and back are always there; reading, note and picture are offered as small
/// "+" chips so a plain card stays two fields (progressive disclosure) and a rich card keeps everything.
final class CardEditorCell: UITableViewCell, UITextViewDelegate {
    static let reuseIdentifier = "card_editor_cell"

    private let numberLabel = UILabel()
    private let optionsButton = UIButton(configuration: .plain())
    private let frontView = PlaceholderTextView(role: .headword)
    private let readingView = PlaceholderTextView(role: .reading)
    private let divider = UIView()
    private let backView = PlaceholderTextView(role: .meaning)
    private let noteView = PlaceholderTextView(role: .reading)
    private let pictureView = CardImageView()
    private let pictureSpinner = UIActivityIndicatorView(style: .medium)
    private let pictureRow = UIView()
    private let readingChip = ChipButton(configuration: .tinted())
    private let noteChip = ChipButton(configuration: .tinted())
    private let pictureChip = ChipButton(configuration: .tinted())
    private let chips = UIStackView()
    private let errorLabel = ErrorMessageLabel()
    private let stack = UIStackView()

    /// Field, its text, and whether an IME composition (marked text) is still open in it.
    var onTextChange: ((CardField, String, Bool) -> Void)?
    var onBeginEditing: ((CardField) -> Void)?
    var onHeightChange: (() -> Void)?
    var onReveal: ((CardField) -> Void)?
    private var revealed = Set<CardField>()
    private var composingField: CardField?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Design.Color.surface

        numberLabel.apply(.eyebrow)
        numberLabel.numberOfLines = 1
        optionsButton.configuration?.image = UIImage(systemName: "ellipsis.circle")
        optionsButton.showsMenuAsPrimaryAction = true
        optionsButton.accessibilityLabel = NSLocalizedString("Card options", comment: "")
        optionsButton.setContentHuggingPriority(.required, for: .horizontal)
        optionsButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        optionsButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        let header = UIStackView(arrangedSubviews: [numberLabel, UIView(), optionsButton])
        header.alignment = .center

        let fields: [(PlaceholderTextView, CardField, String, String)] = [
            (frontView, .front, NSLocalizedString("Front", comment: "Card field"), "card_front"),
            (readingView, .reading, NSLocalizedString("Reading", comment: "Card field"), "card_reading"),
            (backView, .back, NSLocalizedString("Back", comment: "Card field"), "card_back"),
            (noteView, .note, NSLocalizedString("Note", comment: "Card field"), "card_note")
        ]
        for (view, field, placeholder, identifier) in fields {
            view.delegate = self
            view.tag = field.rawValue
            view.placeholder = placeholder
            view.accessibilityIdentifier = identifier
            view.returnKeyType = .next
            // Vocabulary, not prose: no automatic capital letter or correction of Japanese/Vietnamese words.
            view.autocapitalizationType = .none
            view.autocorrectionType = .no
        }
        divider.backgroundColor = Design.Color.separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true

        pictureView.isCompact = true
        pictureView.translatesAutoresizingMaskIntoConstraints = false
        pictureSpinner.translatesAutoresizingMaskIntoConstraints = false
        pictureSpinner.hidesWhenStopped = true
        pictureRow.addSubview(pictureView)
        pictureRow.addSubview(pictureSpinner)
        NSLayoutConstraint.activate([
            pictureView.topAnchor.constraint(equalTo: pictureRow.topAnchor, constant: Design.Spacing.xs),
            pictureView.bottomAnchor.constraint(equalTo: pictureRow.bottomAnchor, constant: -Design.Spacing.xs),
            pictureView.leadingAnchor.constraint(equalTo: pictureRow.leadingAnchor),
            pictureView.widthAnchor.constraint(equalToConstant: 96),
            pictureView.heightAnchor.constraint(equalToConstant: 72),
            pictureSpinner.centerXAnchor.constraint(equalTo: pictureView.centerXAnchor),
            pictureSpinner.centerYAnchor.constraint(equalTo: pictureView.centerYAnchor)
        ])

        for (chip, title, symbol, field) in [(readingChip, NSLocalizedString("Reading", comment: ""), "plus", CardField.reading),
                                             (noteChip, NSLocalizedString("Note", comment: ""), "plus", CardField.note)] {
            var configuration = UIButton.Configuration.tinted()
            configuration.title = title
            configuration.image = UIImage(systemName: symbol)
            configuration.imagePadding = Design.Spacing.xs
            configuration.cornerStyle = .capsule
            configuration.buttonSize = .small
            chip.configuration = configuration
            chip.addAction(UIAction { [weak self] _ in self?.onReveal?(field) }, for: .primaryActionTriggered)
        }
        readingChip.accessibilityLabel = NSLocalizedString("Add reading", comment: "")
        noteChip.accessibilityLabel = NSLocalizedString("Add note", comment: "")
        pictureChip.showsMenuAsPrimaryAction = true
        pictureChip.accessibilityIdentifier = "card_picture"
        chips.spacing = Design.Spacing.s
        chips.alignment = .leading
        let spacer = UIView()
        spacer.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        [readingChip, noteChip, pictureChip].forEach {
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            $0.setContentHuggingPriority(.required, for: .horizontal)
        }
        [readingChip, noteChip, pictureChip, spacer].forEach(chips.addArrangedSubview)

        stack.axis = .vertical
        stack.spacing = Design.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        [header, frontView, readingView, divider, backView, noteView, pictureRow, chips, errorLabel].forEach(stack.addArrangedSubview)
        stack.setCustomSpacing(Design.Spacing.s, after: divider)
        stack.setCustomSpacing(Design.Spacing.s, after: noteView)
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)
        ])
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: CardEditorCell, _) in cell.updateAxis() }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func prepareForReuse() {
        super.prepareForReuse()
        pictureView.cancel()
        onTextChange = nil
        onBeginEditing = nil
        onHeightChange = nil
        onReveal = nil
    }

    private func updateAxis() {
        chips.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
    }

    fileprivate func textViewForAccessory(_ field: CardField) -> PlaceholderTextView { textView(for: field) }

    private func textView(for field: CardField) -> PlaceholderTextView {
        switch field {
        case .front: return frontView
        case .back: return backView
        case .reading: return readingView
        case .note: return noteView
        }
    }

    /// Fields currently shown, in typing order.
    var visibleFields: [CardField] {
        [.front, .reading, .back, .note].filter { !textView(for: $0).isHidden }
    }

    func focus(_ field: CardField) {
        textView(for: field).becomeFirstResponder()
    }

    var focusedField: CardField? {
        CardField.allCases.first { textView(for: $0).isFirstResponder }
    }

    func configure(card: CardDraft, number: Int, revealed: Set<CardField>, isBusy: Bool, problem: String?,
                   optionsMenu: UIMenu, pictureMenu: UIMenu) {
        self.revealed = revealed
        numberLabel.text = String(format: NSLocalizedString("Card %lld", comment: "Card number in the editor"), number)
        optionsButton.menu = optionsMenu
        optionsButton.accessibilityLabel = String(format: NSLocalizedString("Options for card %lld", comment: ""), number)
        for (field, text) in [(CardField.front, card.front), (.back, card.back), (.reading, card.reading), (.note, card.note)] {
            let view = textView(for: field)
            if view.text != text { view.text = text }
        }
        let showReading = !card.reading.isEmpty || revealed.contains(.reading)
        let showNote = !card.note.isEmpty || revealed.contains(.note)
        readingView.isHidden = !showReading
        noteView.isHidden = !showNote
        readingChip.isHidden = showReading
        noteChip.isHidden = showNote
        let hasPicture = !card.imageReference.isEmpty
        pictureRow.isHidden = !hasPicture
        if hasPicture { pictureView.setReference(card.imageReference) } else { pictureView.cancel() }
        pictureView.accessibilityLabel = String(format: NSLocalizedString("Picture for card %lld", comment: ""), number)
        isBusy ? pictureSpinner.startAnimating() : pictureSpinner.stopAnimating()
        var chipConfiguration = pictureChip.configuration ?? .tinted()
        // Same short title either way (three chips must fit one row); the symbol and VoiceOver label say what it does.
        chipConfiguration.title = NSLocalizedString("Picture", comment: "")
        chipConfiguration.image = UIImage(systemName: hasPicture ? "photo.fill" : "plus")
        chipConfiguration.imagePadding = Design.Spacing.xs
        chipConfiguration.cornerStyle = .capsule
        chipConfiguration.buttonSize = .small
        chipConfiguration.showsActivityIndicator = isBusy
        pictureChip.configuration = chipConfiguration
        pictureChip.menu = pictureMenu
        pictureChip.accessibilityLabel = hasPicture ? NSLocalizedString("Change picture", comment: "") : NSLocalizedString("Add picture", comment: "")
        pictureChip.isEnabled = !isBusy
        setProblem(problem)
    }

    func setProblem(_ message: String?) {
        errorLabel.show(message)
    }

    // MARK: UITextViewDelegate

    private func field(of textView: UITextView) -> CardField { CardField(rawValue: textView.tag) ?? .front }

    func textViewDidChange(_ textView: UITextView) {
        composingField = textView.markedTextRange != nil ? field(of: textView) : nil
        onTextChange?(field(of: textView), textView.text, textView.markedTextRange != nil)
        onHeightChange?()
    }

    /// Accepting a composition unchanged (kana confirmed as typed) may not report a text change; the selection still moves.
    /// Announce the committed text so the lookup for it is not left waiting for the next keystroke.
    func textViewDidChangeSelection(_ textView: UITextView) {
        guard composingField == field(of: textView), textView.markedTextRange == nil else { return }
        composingField = nil
        onTextChange?(field(of: textView), textView.text, false)
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        onBeginEditing?(field(of: textView))
    }

    /// Return moves to the next field instead of adding a line break: card text is a word or a short phrase.
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard text == "\n" else { return true }
        let fields = visibleFields
        if let index = fields.firstIndex(of: field(of: textView)), index + 1 < fields.count {
            focus(fields[index + 1])
        } else {
            textView.resignFirstResponder()
        }
        return false
    }
}

extension CardEditorCell {
    /// Puts the shared keyboard bar on every field of the card.
    func setAccessory(_ view: UIView, for field: CardField) {
        textViewForAccessory(field).inputAccessoryView = view
    }
}

/// A compact capsule whose touch area is still at least 44 × 44 pt (the hit test grows; the drawn size stays small).
final class ChipButton: UIButton {
    static let minimumTouchLength: CGFloat = 44

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let growX = max(0, (Self.minimumTouchLength - bounds.width) / 2)
        let growY = max(0, (Self.minimumTouchLength - bounds.height) / 2)
        return bounds.insetBy(dx: -growX, dy: -growY).contains(point)
    }
}
