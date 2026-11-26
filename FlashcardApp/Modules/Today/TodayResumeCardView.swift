import UIKit

/// Pinned "Học tiếp" card shown at the top of Today ONLY when the learner has a real in-progress lesson on this device.
struct TodayResumeCard: Equatable {
    let eyebrow: String
    let levelCode: String
    let title: String
    let detail: String
    let percent: Int
    let percentText: String
    let progressFraction: Double
    let ctaTitle: String
    let slug: String
    let lessonTitle: String
}

/// Compact pinned resume card with a real progress bar, real percentage, and direct resume action.
final class TodayResumeCardView: UIControl {
    private let eyebrowLabel = UILabel()
    private let topSpacer = UIView()
    private let levelBadge = UIView()
    private let levelLabel = UILabel()
    private let topRow = UIStackView()
    private let titleLabel = UILabel()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private var progressWidthConstraint: NSLayoutConstraint?
    private let detailLabel = UILabel()
    private let metaSpacer = UIView()
    private let percentLabel = UILabel()
    private let progressMetaRow = UIStackView()
    private let ctaLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private var currentFraction: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyCardSurface(radius: Design.Radius.card, background: Design.Color.surface, borderColor: Design.Color.accent, borderWidth: 1.5)
        accessibilityIdentifier = "today_resume_card"

        eyebrowLabel.apply(.eyebrow)
        eyebrowLabel.textColor = Design.Color.accent

        levelBadge.backgroundColor = Design.Color.statusFill(Design.Color.accent)
        levelBadge.layer.cornerRadius = Design.Radius.badge
        levelBadge.layer.cornerCurve = .continuous
        levelLabel.apply(.eyebrow)
        levelLabel.textColor = Design.Color.accent
        levelLabel.translatesAutoresizingMaskIntoConstraints = false
        levelBadge.addSubview(levelLabel)
        NSLayoutConstraint.activate([
            levelLabel.topAnchor.constraint(equalTo: levelBadge.topAnchor, constant: 2),
            levelLabel.bottomAnchor.constraint(equalTo: levelBadge.bottomAnchor, constant: -2),
            levelLabel.leadingAnchor.constraint(equalTo: levelBadge.leadingAnchor, constant: Design.Spacing.s),
            levelLabel.trailingAnchor.constraint(equalTo: levelBadge.trailingAnchor, constant: -Design.Spacing.s)
        ])
        levelBadge.setContentHuggingPriority(.required, for: .horizontal)

        topRow.spacing = Design.Spacing.s
        topRow.isUserInteractionEnabled = false
        [eyebrowLabel, topSpacer, levelBadge].forEach(topRow.addArrangedSubview)

        titleLabel.apply(.headword)
        titleLabel.font = Design.TextRole.weighted(.title3, weight: .semibold)

        progressTrack.backgroundColor = Design.Color.surfaceTint
        progressTrack.layer.cornerRadius = 4
        progressTrack.layer.cornerCurve = .continuous
        progressTrack.clipsToBounds = true
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressFill.backgroundColor = Design.Color.accent
        progressFill.layer.cornerRadius = 4
        progressFill.layer.cornerCurve = .continuous
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.addSubview(progressFill)
        NSLayoutConstraint.activate([
            progressTrack.heightAnchor.constraint(equalToConstant: 8),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor)
        ])

        detailLabel.apply(.metadata)
        percentLabel.apply(.figure)
        percentLabel.textColor = Design.Color.accent
        percentLabel.setContentHuggingPriority(.required, for: .horizontal)

        progressMetaRow.spacing = Design.Spacing.s
        progressMetaRow.isUserInteractionEnabled = false
        [detailLabel, metaSpacer, percentLabel].forEach(progressMetaRow.addArrangedSubview)

        ctaLabel.apply(.title)
        ctaLabel.textColor = Design.Color.accent
        chevron.tintColor = Design.Color.accent
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        let ctaRow = UIStackView(arrangedSubviews: [ctaLabel, UIView(), chevron])
        ctaRow.alignment = .center
        ctaRow.isUserInteractionEnabled = false

        let column = UIStackView(arrangedSubviews: [topRow, titleLabel, progressTrack, progressMetaRow, ctaRow])
        column.axis = .vertical
        column.spacing = Design.Spacing.s
        column.setCustomSpacing(Design.Spacing.xs, after: progressTrack)
        column.setCustomSpacing(Design.Spacing.m, after: progressMetaRow)
        column.isUserInteractionEnabled = false
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum),
            column.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.l),
            column.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.l),
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.l),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.l)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: TodayResumeCardView, _) in
            view.updateAxis()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.85 : 1 }
    }

    private func updateAxis() {
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        topRow.axis = isAX ? .vertical : .horizontal
        topRow.alignment = isAX ? .leading : .center
        topSpacer.isHidden = isAX
        progressMetaRow.axis = isAX ? .vertical : .horizontal
        progressMetaRow.alignment = isAX ? .leading : .center
        metaSpacer.isHidden = isAX
    }

    func configure(_ card: TodayResumeCard) {
        eyebrowLabel.text = card.eyebrow
        levelLabel.text = card.levelCode
        levelBadge.isHidden = card.levelCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        titleLabel.text = card.title
        detailLabel.text = card.detail
        percentLabel.text = card.percentText
        ctaLabel.text = card.ctaTitle

        currentFraction = CGFloat(min(max(card.progressFraction, 0), 1))
        progressWidthConstraint?.isActive = false
        let width = progressFill.widthAnchor.constraint(equalTo: progressTrack.widthAnchor, multiplier: max(currentFraction, 0.02))
        width.isActive = true
        progressWidthConstraint = width

        accessibilityLabel = [card.eyebrow, card.title, card.levelCode, card.percentText, card.detail]
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
        accessibilityHint = card.ctaTitle
    }
}
