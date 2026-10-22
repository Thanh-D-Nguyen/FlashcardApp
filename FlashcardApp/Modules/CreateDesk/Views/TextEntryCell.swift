import UIKit

/// One growing text field in the deck's details (name or description) with an optional inline problem message.
final class TextEntryCell: UITableViewCell, UITextViewDelegate {
    static let reuseIdentifier = "text_entry_cell"

    let textView = PlaceholderTextView(role: .meaning)
    private let errorLabel = ErrorMessageLabel()
    var onChange: ((String) -> Void)?
    var onHeightChange: (() -> Void)?
    var onBeginEditing: (() -> Void)?
    /// Whether Return inserts a line break (description) or finishes the field (name).
    var allowsLineBreaks = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Design.Color.surface
        textView.delegate = self
        let stack = UIStackView(arrangedSubviews: [textView, errorLabel])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(text: String, placeholder: String, role: Design.TextRole, problem: String?, allowsLineBreaks: Bool, identifier: String) {
        textView.font = role.font
        textView.placeholder = placeholder
        if textView.text != text { textView.text = text }
        self.allowsLineBreaks = allowsLineBreaks
        textView.returnKeyType = allowsLineBreaks ? .default : .next
        textView.accessibilityIdentifier = identifier
        setProblem(problem)
    }

    func setProblem(_ message: String?) {
        errorLabel.show(message)
        accessibilityElements = errorLabel.isHidden ? [textView] : [textView, errorLabel]
    }

    func textViewDidChange(_ textView: UITextView) {
        onChange?(textView.text)
        onHeightChange?()
    }

    func textViewDidBeginEditing(_ textView: UITextView) { onBeginEditing?() }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard text == "\n", !allowsLineBreaks else { return true }
        textView.resignFirstResponder()
        return false
    }
}

/// Inline validation text: icon and words together, so the problem is never conveyed by color alone.
/// One label (icon as a text attachment) so it is a single, simple accessibility element.
final class ErrorMessageLabel: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        apply(.metadata)
        textColor = Design.Color.error
        isHidden = true
        accessibilityTraits = .staticText
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show(_ message: String?) {
        guard let message else {
            text = nil
            isHidden = true
            return
        }
        let attachment = NSTextAttachment()
        attachment.image = UIImage(systemName: "exclamationmark.circle.fill")?.withTintColor(Design.Color.error, renderingMode: .alwaysOriginal)
        let size = font.pointSize
        attachment.bounds = CGRect(x: 0, y: -2, width: size, height: size)
        let result = NSMutableAttributedString(attachment: attachment)
        result.append(NSAttributedString(string: "  " + message))
        attributedText = result
        accessibilityLabel = message
        isHidden = false
    }
}
