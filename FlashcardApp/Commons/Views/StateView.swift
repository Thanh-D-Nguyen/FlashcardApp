import UIKit

/// Full-area loading / empty / error presentation shared by list screens.
/// Color is never the only signal: every state has an icon (or spinner) and words.
final class StateView: UIView {
    enum State: Equatable {
        case loading(String)
        case empty(title: String, message: String?)
        case error(message: String, retryTitle: String)
    }

    private let stack = UIStackView()
    private let iconView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private var onRetry: (() -> Void)?
    private var shownState: State?

    override init(frame: CGRect) {
        super.init(frame: frame)
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Design.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .largeTitle)
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.apply(.title)
        titleLabel.textAlignment = .center
        messageLabel.apply(.reading)
        messageLabel.textAlignment = .center
        retryButton.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .touchUpInside)
        [spinner, iconView, titleLabel, messageLabel, retryButton].forEach(stack.addArrangedSubview)
        stack.setCustomSpacing(Design.Spacing.xl, after: messageLabel)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor, constant: -Design.Spacing.xxl),
            stack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: Design.Spacing.l),
            stack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -Design.Spacing.l),
            stack.topAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.topAnchor, constant: Design.Spacing.l),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.bottomAnchor, constant: -Design.Spacing.l)
        ])
        isAccessibilityElement = false
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(_ state: State, onRetry: (() -> Void)? = nil) {
        self.onRetry = onRetry
        spinner.stopAnimating()
        iconView.isHidden = true
        messageLabel.isHidden = true
        retryButton.isHidden = true
        switch state {
        case .loading(let text):
            spinner.startAnimating()
            titleLabel.text = text
            titleLabel.textColor = Design.Color.textSecondary
        case .empty(let title, let message):
            show(symbol: "tray", tint: Design.Color.textSecondary)
            titleLabel.text = title
            titleLabel.textColor = Design.Color.textPrimary
            messageLabel.text = message
            messageLabel.isHidden = message == nil
        case .error(let message, let retryTitle):
            show(symbol: "exclamationmark.triangle", tint: Design.Color.error)
            titleLabel.text = message
            titleLabel.textColor = Design.Color.error
            retryButton.configuration = Design.Button.primary(title: retryTitle)
            retryButton.isHidden = false
        }
        spinner.isHidden = !spinner.isAnimating
        accessibilityElements = state.isLoading ? [titleLabel] : [titleLabel, messageLabel, retryButton]
        accessibilityViewIsModal = false
        // Tell VoiceOver when loading ends in an empty or error result.
        if shownState != state, !state.isLoading, !isHidden {
            UIAccessibility.post(notification: .layoutChanged, argument: titleLabel)
        }
        shownState = state
    }

    private func show(symbol: String, tint: UIColor) {
        iconView.image = UIImage(systemName: symbol)
        iconView.tintColor = tint
        iconView.isHidden = false
    }
}

private extension StateView.State {
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
