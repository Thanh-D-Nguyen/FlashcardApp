import UIKit

/// A growing multi-line field with a placeholder. Self-sizing inside table cells (scrolling is off), Dynamic Type aware.
final class PlaceholderTextView: UITextView {
    private let placeholderLabel = UILabel()

    var placeholder: String? {
        didSet {
            placeholderLabel.text = placeholder
            // VoiceOver reads the placeholder as the field's name, then the typed value.
            accessibilityLabel = placeholder
        }
    }

    override var text: String! {
        didSet { updatePlaceholder() }
    }

    override var font: UIFont? {
        didSet { placeholderLabel.font = font }
    }

    override var attributedText: NSAttributedString! {
        didSet { updatePlaceholder() }
    }

    init(role: Design.TextRole) {
        super.init(frame: .zero, textContainer: nil)
        isScrollEnabled = false
        backgroundColor = .clear
        textContainerInset = UIEdgeInsets(top: Design.Spacing.s, left: 0, bottom: Design.Spacing.s, right: 0)
        textContainer.lineFragmentPadding = 0
        font = role.font
        textColor = role.color
        adjustsFontForContentSizeCategory = true
        placeholderLabel.font = role.font
        placeholderLabel.textColor = .placeholderText
        // One line: the field is only as tall as its (empty) text, so a wrapped placeholder would spill into the next row.
        // VoiceOver reads the full text through `accessibilityLabel`.
        placeholderLabel.numberOfLines = 1
        placeholderLabel.lineBreakMode = .byTruncatingTail
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.isAccessibilityElement = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            // A text view is a scroll view: pin the label to its content, but size it to the visible frame so it wraps.
            placeholderLabel.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor, constant: textContainerInset.top),
            placeholderLabel.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            placeholderLabel.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor)
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(updatePlaceholder), name: UITextView.textDidChangeNotification, object: self)
        updatePlaceholder()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func updatePlaceholder() {
        placeholderLabel.isHidden = !text.isEmpty
    }
}
