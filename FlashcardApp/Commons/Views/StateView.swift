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

    /// Extra top inset beneath a pinned section header, filter bar or table header.
    var topContentInset: CGFloat = 0 {
        didSet {
            guard oldValue != topContentInset else { return }
            setNeedsLayout()
        }
    }

    /// Extra bottom inset above custom chrome when needed.
    var bottomContentInset: CGFloat = 0 {
        didSet {
            guard oldValue != bottomContentInset else { return }
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
    private var scrollBottomConstraint: NSLayoutConstraint?
    private var centerYConstraint: NSLayoutConstraint?

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

        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .vertical)

        titleLabel.apply(.title)
        titleLabel.textAlignment = .center
        messageLabel.apply(.reading)
        messageLabel.textAlignment = .center

        retryButton.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .touchUpInside)
        retryButton.enableAdaptiveCornerStyle()

        [spinner, iconView, titleLabel, messageLabel, retryButton].forEach(stack.addArrangedSubview)

        addSubview(scrollView)
        scrollView.addSubview(contentGuideView)
        contentGuideView.addSubview(stack)

        let top = scrollView.topAnchor.constraint(equalTo: topAnchor)
        let bottom = scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        scrollTopConstraint = top
        scrollBottomConstraint = bottom

        let centerY = stack.centerYAnchor.constraint(equalTo: contentGuideView.centerYAnchor, constant: -Design.Spacing.l)
        centerY.priority = .defaultHigh
        centerYConstraint = centerY

        let minHeight = contentGuideView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor)
        minHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            top,
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottom,

            contentGuideView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentGuideView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentGuideView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentGuideView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentGuideView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            minHeight,

            centerY,
            stack.leadingAnchor.constraint(equalTo: contentGuideView.leadingAnchor, constant: Design.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: contentGuideView.trailingAnchor, constant: -Design.Spacing.xl),
            stack.topAnchor.constraint(greaterThanOrEqualTo: contentGuideView.topAnchor, constant: Design.Spacing.m),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentGuideView.bottomAnchor, constant: -Design.Spacing.l)
        ])
        isAccessibilityElement = false
        updateMetrics()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: StateView, _) in
            view.updateMetrics()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var enclosingScrollView: UIScrollView? {
        var current = superview
        while let candidate = current {
            if let scroll = candidate as? UIScrollView { return scroll }
            current = candidate.superview
        }
        return nil
    }

    private func updateMetrics() {
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        iconView.preferredSymbolConfiguration = isAX
            ? UIImage.SymbolConfiguration(pointSize: 38, weight: .regular)
            : UIImage.SymbolConfiguration(textStyle: .largeTitle)
        stack.spacing = isAX ? Design.Spacing.s : Design.Spacing.m
        stack.setCustomSpacing(isAX ? Design.Spacing.m : Design.Spacing.xl, after: messageLabel)
        centerYConstraint?.constant = isAX ? 0 : -Design.Spacing.l
        setNeedsLayout()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        // When hosted as `UITableView.backgroundView`, UIKit absorbs safe area insets into the table's
        // `adjustedContentInset` and passes `.zero` to `backgroundView.safeAreaInsets`. Reading the
        // enclosing scroll view's adjusted insets keeps content clear of both nav/search bars and tab bars.
        let parentTop = enclosingScrollView?.adjustedContentInset.top ?? 0
        let parentBottom = enclosingScrollView?.adjustedContentInset.bottom ?? 0
        let effectiveTop = max(safeAreaInsets.top, parentTop) + topContentInset
        let effectiveBottom = max(safeAreaInsets.bottom, parentBottom) + bottomContentInset
        if scrollTopConstraint?.constant != effectiveTop {
            scrollTopConstraint?.constant = effectiveTop
        }
        if scrollBottomConstraint?.constant != -effectiveBottom {
            scrollBottomConstraint?.constant = -effectiveBottom
        }
        super.layoutSubviews()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, isUserInteractionEnabled, alpha > 0.01 else { return nil }
        // Never intercept touches in the inset bands reserved for filter bars, search/scope bars or tab bars.
        guard scrollView.frame.contains(point) else { return nil }
        let hit = super.hitTest(point, with: event)
        if let hit, hit.isDescendant(of: retryButton), !retryButton.isHidden {
            return hit
        }
        let canScroll = scrollView.contentSize.height > scrollView.bounds.height + 1
        return canScroll ? hit : nil
    }

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
