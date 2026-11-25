import UIKit

/// Full-area loading / empty / error presentation shared by list screens.
/// Color is never the only signal: every state has an icon (or spinner) and words.
/// Scrollable so accessibility text sizes never clip or collide with navigation chrome.
final class StateView: UIView {
    enum State: Equatable {
        case loading(String)
        case empty(title: String, message: String?)
        /// An empty screen with one clear next step (e.g. "Create your first deck").
        case call(symbol: String, title: String, message: String?, actionTitle: String)
        case error(message: String, retryTitle: String)
    }

    /// Extra top inset when displayed as a table/collection `backgroundView` beneath a section header or search bar.
    var topContentInset: CGFloat = 0 {
        didSet {
            scrollTopConstraint?.constant = topContentInset
            setNeedsLayout()
        }
    }

    private let scrollView = UIScrollView()
    private let contentGuideView = UIView()
    private let stack = UIStackView()
    private let iconView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private var onRetry: (() -> Void)?
    private var shownState: State?
    private var scrollTopConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentGuideView.translatesAutoresizingMaskIntoConstraints = false

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
        retryButton.enableAdaptiveCornerStyle()

        [spinner, iconView, titleLabel, messageLabel, retryButton].forEach(stack.addArrangedSubview)
        stack.setCustomSpacing(Design.Spacing.xl, after: messageLabel)

        addSubview(scrollView)
        scrollView.addSubview(contentGuideView)
        contentGuideView.addSubview(stack)

        let top = scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor)
        scrollTopConstraint = top

        let centerY = stack.centerYAnchor.constraint(equalTo: contentGuideView.centerYAnchor, constant: -Design.Spacing.l)
        centerY.priority = .defaultHigh

        let minHeight = contentGuideView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor)
        minHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            top,
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),

            contentGuideView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentGuideView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentGuideView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentGuideView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentGuideView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            minHeight,

            centerY,
            stack.leadingAnchor.constraint(equalTo: contentGuideView.leadingAnchor, constant: Design.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: contentGuideView.trailingAnchor, constant: -Design.Spacing.xl),
            stack.topAnchor.constraint(greaterThanOrEqualTo: contentGuideView.topAnchor, constant: Design.Spacing.l),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentGuideView.bottomAnchor, constant: -Design.Spacing.l)
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
        case .call(let symbol, let title, let message, let actionTitle):
            show(symbol: symbol, tint: Design.Color.accent)
            titleLabel.text = title
            titleLabel.textColor = Design.Color.textPrimary
            messageLabel.text = message
            messageLabel.isHidden = message == nil
            retryButton.configuration = Design.Button.primary(title: actionTitle, traits: traitCollection)
            retryButton.isHidden = false
        case .error(let message, let retryTitle):
            show(symbol: "exclamationmark.triangle", tint: Design.Color.error)
            titleLabel.text = message
            titleLabel.textColor = Design.Color.error
            retryButton.configuration = Design.Button.primary(title: retryTitle, traits: traitCollection)
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
