import UIKit

/// Circular progress ring showing Today's Quest completion (`completed/total`), adapting colors to Light/Dark and respecting Reduce Motion.
final class TodayQuestProgressRingView: UIView {
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let countLabel = UILabel()
    private let doneCheck = UIImageView(image: UIImage(systemName: "checkmark"))
    private var fraction: CGFloat = 0
    private var isComplete = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.lineWidth = 5
        trackLayer.lineCap = .round
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineWidth = 5
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        layer.addSublayer(trackLayer)
        layer.addSublayer(progressLayer)

        countLabel.apply(.figure)
        countLabel.textAlignment = .center
        countLabel.adjustsFontSizeToFitWidth = true
        countLabel.minimumScaleFactor = 0.7
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(countLabel)

        doneCheck.tintColor = Design.Color.success
        doneCheck.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        doneCheck.isHidden = true
        doneCheck.translatesAutoresizingMaskIntoConstraints = false
        addSubview(doneCheck)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 48),
            heightAnchor.constraint(equalToConstant: 48),
            countLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            countLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 6),
            countLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
            doneCheck.centerXAnchor.constraint(equalTo: centerXAnchor),
            doneCheck.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        isAccessibilityElement = false
        applyColors()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: TodayQuestProgressRingView, _) in
            view.applyColors()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = max(1, min(bounds.width, bounds.height) / 2 - 4)
        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true).cgPath
        trackLayer.path = path
        progressLayer.path = path
    }

    private func applyColors() {
        trackLayer.strokeColor = Design.Color.surfaceTint.resolvedColor(with: traitCollection).cgColor
        let activeColor = isComplete ? Design.Color.success : Design.Color.accent
        progressLayer.strokeColor = activeColor.resolvedColor(with: traitCollection).cgColor
        doneCheck.tintColor = Design.Color.success
    }

    func configure(completed: Int, total: Int, fraction: Double, animated: Bool) {
        let clamped = CGFloat(min(max(fraction, 0), 1))
        let newlyCompleted = !isComplete && total > 0 && completed == total
        isComplete = total > 0 && completed == total
        self.fraction = clamped
        countLabel.text = "\(completed)/\(total)"
        countLabel.isHidden = isComplete
        doneCheck.isHidden = !isComplete
        applyColors()

        let shouldAnimate = animated && !UIAccessibility.isReduceMotionEnabled && window != nil
        if shouldAnimate {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = progressLayer.presentation()?.strokeEnd ?? progressLayer.strokeEnd
            animation.toValue = clamped
            animation.duration = 0.35
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            progressLayer.strokeEnd = clamped
            progressLayer.add(animation, forKey: "stroke")
            if newlyCompleted {
                doneCheck.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                UIView.animate(withDuration: 0.4, delay: 0.05, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.5) {
                    self.doneCheck.transform = .identity
                }
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            progressLayer.strokeEnd = clamped
            CATransaction.commit()
            doneCheck.transform = .identity
        }
    }
}

/// "Nhiệm vụ hôm nay" (Today's Quest) card with circular progress ring, checklist (max 3 items), and "Xong hôm nay" state.
final class TodayQuestCardView: UIView {
    var onSelectItem: ((TodayQuestAction) -> Void)?

    private let headerRow = UIStackView()
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let doneBadge = UIView()
    private let doneBadgeIcon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    private let doneBadgeLabel = UILabel()
    private let ringView = TodayQuestProgressRingView()
    private let listStack = UIStackView()
    private let feedback = UINotificationFeedbackGenerator()
    private var wasAllDone = false
    private var hasRenderedOnce = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyCardSurface(radius: Design.Radius.card)
        accessibilityIdentifier = "today_quest_card"

        titleLabel.apply(.eyebrow)
        titleLabel.textColor = Design.Color.accent
        titleLabel.accessibilityTraits = .header
        summaryLabel.apply(.title)

        doneBadge.layer.cornerRadius = Design.Radius.badge
        doneBadge.layer.cornerCurve = .continuous
        doneBadge.backgroundColor = Design.Color.statusFill(Design.Color.success)
        doneBadge.isHidden = true
        doneBadgeIcon.tintColor = Design.Color.success
        doneBadgeIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote)
        doneBadgeIcon.setContentHuggingPriority(.required, for: .horizontal)
        doneBadgeLabel.apply(.eyebrow)
        doneBadgeLabel.textColor = Design.Color.success
        let badgeRow = UIStackView(arrangedSubviews: [doneBadgeIcon, doneBadgeLabel])
        badgeRow.alignment = .center
        badgeRow.spacing = Design.Spacing.xs
        badgeRow.translatesAutoresizingMaskIntoConstraints = false
        doneBadge.addSubview(badgeRow)
        NSLayoutConstraint.activate([
            badgeRow.topAnchor.constraint(equalTo: doneBadge.topAnchor, constant: Design.Spacing.xs),
            badgeRow.bottomAnchor.constraint(equalTo: doneBadge.bottomAnchor, constant: -Design.Spacing.xs),
            badgeRow.leadingAnchor.constraint(equalTo: doneBadge.leadingAnchor, constant: Design.Spacing.s),
            badgeRow.trailingAnchor.constraint(equalTo: doneBadge.trailingAnchor, constant: -Design.Spacing.s)
        ])

        let badgeHolder = UIStackView(arrangedSubviews: [doneBadge, UIView()])
        badgeHolder.axis = .horizontal
        let titleColumn = UIStackView(arrangedSubviews: [titleLabel, summaryLabel, badgeHolder])
        titleColumn.axis = .vertical
        titleColumn.spacing = Design.Spacing.xs

        headerRow.spacing = Design.Spacing.m
        [titleColumn, ringView].forEach(headerRow.addArrangedSubview)

        listStack.axis = .vertical
        listStack.spacing = 0

        let container = UIStackView(arrangedSubviews: [headerRow, listStack])
        container.axis = .vertical
        container.spacing = Design.Spacing.m
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.l),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.s),
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.l),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.l)
        ])

        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: TodayQuestCardView, _) in
            view.updateAxis()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func updateAxis() {
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        headerRow.axis = isAX ? .vertical : .horizontal
        headerRow.alignment = isAX ? .leading : .center
    }

    func configure(_ state: TodayQuestState) {
        let justFinishedAll = hasRenderedOnce && !wasAllDone && state.isAllDone
        hasRenderedOnce = true
        wasAllDone = state.isAllDone

        titleLabel.text = state.title.uppercased()
        summaryLabel.text = state.summary
        summaryLabel.textColor = state.isAllDone ? Design.Color.success : Design.Color.textPrimary
        doneBadge.isHidden = !state.isAllDone
        doneBadgeLabel.text = state.completionTitle
        ringView.configure(completed: state.completedCount, total: state.totalCount, fraction: state.progressFraction, animated: true)

        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, item) in state.items.enumerated() {
            let row = TodayQuestRowControl()
            row.configure(item, showsSeparator: index < state.items.count - 1)
            row.addAction(UIAction { [weak self] _ in self?.onSelectItem?(item.action) }, for: .touchUpInside)
            listStack.addArrangedSubview(row)
        }

        if justFinishedAll {
            feedback.notificationOccurred(.success)
            if !UIAccessibility.isReduceMotionEnabled {
                doneBadge.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
                UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.4) {
                    self.doneBadge.transform = .identity
                }
            }
            UIAccessibility.post(notification: .announcement, argument: state.completionTitle)
        }
    }
}

private final class TodayQuestRowControl: UIControl {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let separator = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.isAccessibilityElement = false

        titleLabel.apply(.meaning)
        detailLabel.apply(.metadata)

        chevron.tintColor = Design.Color.textSecondary
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.isAccessibilityElement = false

        separator.backgroundColor = Design.Color.separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.isUserInteractionEnabled = false

        let row = UIStackView(arrangedSubviews: [iconView, textStack, chevron])
        row.alignment = .center
        row.spacing = Design.Spacing.m
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false

        addSubview(row)
        addSubview(separator)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum),
            row.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.s + 2),
            row.bottomAnchor.constraint(equalTo: separator.topAnchor, constant: -(Design.Spacing.s + 2)),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.leadingAnchor.constraint(equalTo: textStack.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? Design.Color.highlight : .clear }
    }

    func configure(_ item: TodayQuestItem, showsSeparator: Bool) {
        accessibilityIdentifier = "today_quest_item_\(item.id)"
        iconView.image = UIImage(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
        iconView.tintColor = item.isDone ? Design.Color.success : Design.Color.textSecondary
        titleLabel.text = item.title
        titleLabel.textColor = item.isDone ? Design.Color.textSecondary : Design.Color.textPrimary
        detailLabel.text = item.detail
        detailLabel.isHidden = item.detail == nil
        chevron.isHidden = item.isDone
        separator.isHidden = !showsSeparator
        let status = item.isDone ? NSLocalizedString("Completed", comment: "") : nil
        accessibilityLabel = [item.title, item.detail, status].compactMap { $0 }.joined(separator: ", ")
    }
}
