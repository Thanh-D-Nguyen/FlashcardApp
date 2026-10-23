import UIKit

/// How a learner rates themselves once the answer of a flipped card is shown. The two choices have the same visual weight
/// on purpose: neither is the "good" button, so the rating is not nudged. "Skip" moves on without recording anything.
final class StudyRatingView: UIStackView {
    var onRate: ((SelfRating) -> Void)?
    var onSkip: (() -> Void)?

    private let prompt = UILabel()
    private let buttons = UIStackView()
    private let caption = UILabel()
    private let skipButton = UIButton(configuration: .plain())

    override init(frame: CGRect) {
        super.init(frame: frame)
        axis = .vertical
        spacing = Design.Spacing.m
        prompt.apply(.title)
        prompt.textAlignment = .center
        prompt.text = NSLocalizedString("Do you remember this word?", comment: "Prompt above the self-rating buttons")
        let needsReview = Self.makeButton(title: NSLocalizedString("Needs review", comment: ""), symbol: "arrow.counterclockwise",
                                          identifier: "study_rate_review")
        let remembered = Self.makeButton(title: NSLocalizedString("I remembered", comment: ""), symbol: "checkmark",
                                         identifier: "study_rate_remembered")
        needsReview.addAction(UIAction { [weak self] _ in self?.onRate?(.needsReview) }, for: .primaryActionTriggered)
        remembered.addAction(UIAction { [weak self] _ in self?.onRate?(.remembered) }, for: .primaryActionTriggered)
        buttons.spacing = Design.Spacing.m
        buttons.distribution = .fillEqually
        [needsReview, remembered].forEach(buttons.addArrangedSubview)

        caption.apply(.metadata)
        caption.text = NSLocalizedString("You rate yourself", comment: "")
        skipButton.configuration?.title = NSLocalizedString("Skip", comment: "")
        skipButton.accessibilityIdentifier = "study_skip_rating"
        skipButton.setContentHuggingPriority(.required, for: .horizontal)
        skipButton.addAction(UIAction { [weak self] _ in self?.onSkip?() }, for: .primaryActionTriggered)
        let footer = UIStackView(arrangedSubviews: [caption, skipButton])
        footer.alignment = .center
        footer.spacing = Design.Spacing.m
        [prompt, buttons, footer].forEach(addArrangedSubview)

        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: StudyRatingView, _) in view.updateAxis() }
    }

    @available(*, unavailable) required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Side by side normally; stacked at accessibility sizes so each label keeps its full width.
    private func updateAxis() {
        buttons.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
    }

    private static func makeButton(title: String, symbol: String, identifier: String) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.buttonSize = .large
        configuration.baseBackgroundColor = Design.Color.surface
        configuration.baseForegroundColor = Design.Color.textPrimary
        configuration.background.strokeColor = Design.Color.accent.withAlphaComponent(0.38)
        configuration.background.strokeWidth = 1.5
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = Design.Spacing.s
        configuration.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.m, leading: Design.Spacing.m, bottom: Design.Spacing.m, trailing: Design.Spacing.m)
        configuration.imageColorTransformer = UIConfigurationColorTransformer { _ in Design.Color.accent }
        var text = AttributedString(title)
        text.font = UIFont.preferredFont(forTextStyle: .headline)
        configuration.attributedTitle = text
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = identifier
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        return button
    }
}

/// An answer that could not be saved. The session waits here: the learner can try again or leave, knowing it will not count.
final class StudySaveFailureView: UIStackView {
    var onRetry: (() -> Void)?
    var onLeave: (() -> Void)?

    private let retryButton = UIButton(configuration: Design.Button.primary(title: NSLocalizedString("Try again", comment: "")))
    private let leaveButton = UIButton(configuration: .plain())

    override init(frame: CGRect) {
        super.init(frame: frame)
        axis = .vertical
        alignment = .fill
        spacing = Design.Spacing.s
        retryButton.accessibilityIdentifier = "study_retry_save"
        retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        retryButton.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .primaryActionTriggered)
        leaveButton.configuration?.title = NSLocalizedString("Leave session", comment: "")
        leaveButton.configuration?.baseForegroundColor = Design.Color.error
        leaveButton.accessibilityIdentifier = "study_leave_unsaved"
        leaveButton.addAction(UIAction { [weak self] _ in self?.onLeave?() }, for: .primaryActionTriggered)
        [retryButton, leaveButton].forEach(addArrangedSubview)
    }

    @available(*, unavailable) required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

/// End of a session: what was saved (quiz answers and self-ratings kept apart), what was skipped, the cards to look at
/// again, and the two sensible next steps. Only attempts confirmed saved are counted.
final class StudySummaryView: UIView {
    var onRestart: (() -> Void)?
    var onDone: (() -> Void)?

    private let icon = UIImageView(image: UIImage(systemName: "checkmark.circle"))
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let totalsCard = UIView()
    private let totals = UIStackView()
    private let footnote = UILabel()
    private let reviewHeader = UILabel()
    private let reviewCard = UIView()
    private let reviewList = UIStackView()
    private let doneButton = UIButton(configuration: Design.Button.primary(title: NSLocalizedString("Done", comment: "")))
    private let restartButton = UIButton(configuration: .plain())

    override init(frame: CGRect) {
        super.init(frame: frame)
        icon.tintColor = Design.Color.success
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .largeTitle)
        icon.isAccessibilityElement = false
        icon.contentMode = .scaleAspectFit   // the stack fills the width; the symbol must keep its shape
        titleLabel.apply(.display)
        titleLabel.textAlignment = .center
        titleLabel.accessibilityTraits = .header
        detailLabel.apply(.meaning)
        detailLabel.textColor = Design.Color.textSecondary
        detailLabel.textAlignment = .center
        footnote.apply(.metadata)
        reviewHeader.apply(.metadata)
        reviewHeader.font = Design.TextRole.metadata.font.withWeight(.semibold)
        reviewHeader.text = NSLocalizedString("Needs review", comment: "")
        reviewHeader.accessibilityTraits = .header
        doneButton.accessibilityIdentifier = "study_done"
        doneButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        restartButton.configuration?.title = NSLocalizedString("Study again", comment: "")
        restartButton.accessibilityIdentifier = "study_restart"
        restartButton.addAction(UIAction { [weak self] _ in self?.onRestart?() }, for: .primaryActionTriggered)
        doneButton.addAction(UIAction { [weak self] _ in self?.onDone?() }, for: .primaryActionTriggered)

        for (card, stack) in [(totalsCard, totals), (reviewCard, reviewList)] {
            card.backgroundColor = Design.Color.surface
            card.layer.cornerRadius = 20
            card.layer.cornerCurve = .continuous
            card.clipsToBounds = true
            stack.axis = .vertical
            stack.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: card.topAnchor),
                stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: card.trailingAnchor)
            ])
        }

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, detailLabel, totalsCard, footnote, reviewHeader, reviewCard, doneButton, restartButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Design.Spacing.m
        stack.setCustomSpacing(Design.Spacing.xl, after: detailLabel)
        stack.setCustomSpacing(Design.Spacing.xs, after: totalsCard)
        stack.setCustomSpacing(Design.Spacing.xl, after: footnote)
        stack.setCustomSpacing(Design.Spacing.xl, after: reviewCard)
        stack.translatesAutoresizingMaskIntoConstraints = false
        icon.setContentHuggingPriority(.required, for: .vertical)
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.xl),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        accessibilityIdentifier = "study_summary"
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(with summary: StudySummary) {
        let nothingSaved = summary.saved == 0
        icon.image = UIImage(systemName: nothingSaved ? "tray" : "checkmark.circle")
        icon.tintColor = nothingSaved ? Design.Color.textSecondary : Design.Color.success
        titleLabel.text = nothingSaved
            ? NSLocalizedString("Nothing saved this time", comment: "")
            : String.localizedStringWithFormat(NSLocalizedString("Saved %lld attempts", comment: "End of session title"), summary.saved)
        detailLabel.text = NSLocalizedString("You didn't answer any card in this session, so there is nothing to record.", comment: "")
        detailLabel.isHidden = !nothingSaved

        totals.arrangedSubviews.forEach { $0.removeFromSuperview() }
        var rows: [(String, String)] = []
        if summary.answered > 0 {
            rows.append((NSLocalizedString("Quiz", comment: ""),
                         String(format: NSLocalizedString("%1$lld correct · %2$lld incorrect", comment: "Quiz result row"), summary.correct, summary.incorrect)))
        }
        if summary.selfRated > 0 {
            rows.append((NSLocalizedString("Self-rating", comment: ""),
                         String.localizedStringWithFormat(NSLocalizedString("%lld attempts", comment: ""), summary.selfRated)))
        }
        let skipped = summary.total - summary.saved
        if !nothingSaved, skipped > 0 {
            rows.append((NSLocalizedString("Skipped", comment: ""),
                         String.localizedStringWithFormat(NSLocalizedString("%lld cards", comment: ""), skipped)))
        }
        for (index, row) in rows.enumerated() {
            totals.addArrangedSubview(Self.makeRow(title: row.0, value: row.1, separator: index < rows.count - 1))
        }
        totalsCard.isHidden = rows.isEmpty
        footnote.text = NSLocalizedString("Your own ratings aren't counted in the correct answer rate.", comment: "")
        footnote.isHidden = summary.selfRated == 0

        reviewList.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, card) in summary.toReview.enumerated() {
            reviewList.addArrangedSubview(Self.makeReviewRow(card, separator: index < summary.toReview.count - 1))
        }
        reviewHeader.isHidden = summary.toReview.isEmpty
        reviewCard.isHidden = summary.toReview.isEmpty
    }

    private static func makeRow(title: String, value: String, separator: Bool) -> UIView {
        let titleLabel = UILabel()
        titleLabel.apply(.meaning)
        titleLabel.text = title
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let valueLabel = UILabel()
        valueLabel.apply(.meaning)
        valueLabel.textColor = Design.Color.textSecondary
        valueLabel.textAlignment = .right
        valueLabel.text = value
        let row = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        row.spacing = Design.Spacing.m
        row.alignment = .firstBaseline
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(top: Design.Spacing.m, leading: Design.Spacing.l, bottom: Design.Spacing.m, trailing: Design.Spacing.l)
        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(title), \(value)"
        return separator ? withSeparator(row) : row
    }

    private static func makeReviewRow(_ card: StudyReviewedCard, separator: Bool) -> UIView {
        let front = UILabel()
        front.apply(.headword)
        front.text = card.front
        front.setContentHuggingPriority(.required, for: .horizontal)
        front.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        let back = UILabel()
        back.apply(.meaning)
        back.text = card.back
        let tag = UILabel()
        tag.apply(.metadata)
        tag.textColor = card.result == .incorrect ? Design.Color.warning : Design.Color.accent
        tag.text = card.result == .incorrect ? NSLocalizedString("Incorrect", comment: "") : NSLocalizedString("Self-rating", comment: "")
        tag.setContentHuggingPriority(.required, for: .horizontal)
        let texts = UIStackView(arrangedSubviews: [front, back, tag])
        texts.axis = .vertical
        texts.spacing = Design.Spacing.xs
        texts.isLayoutMarginsRelativeArrangement = true
        texts.directionalLayoutMargins = NSDirectionalEdgeInsets(top: Design.Spacing.m, leading: Design.Spacing.l, bottom: Design.Spacing.m, trailing: Design.Spacing.l)
        texts.isAccessibilityElement = true
        texts.accessibilityLabel = "\(card.front), \(card.back), \(tag.text ?? "")"
        return separator ? withSeparator(texts) : texts
    }

    private static func withSeparator(_ view: UIView) -> UIView {
        let line = UIView()
        line.backgroundColor = Design.Color.separator
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        let container = UIStackView(arrangedSubviews: [view, line])
        container.axis = .vertical
        return container
    }
}
