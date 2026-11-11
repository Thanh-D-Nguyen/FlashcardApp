import UIKit

/// The lesson slot of Today: one card, one button, from the learner's own lesson progress. It sits under the review block and
/// never competes with its primary action.
final class TodayLessonSlotView: UIControl {
    private let eyebrow = UILabel()
    private let titleLabel = UILabel()
    private let detail = UILabel()
    private let cta = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Design.Color.surface
        layer.cornerRadius = Design.Radius.panel
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = Design.Color.separator.cgColor

        eyebrow.apply(.eyebrow)
        eyebrow.textColor = Design.Color.accent
        titleLabel.apply(.headword)
        titleLabel.numberOfLines = 0
        detail.apply(.metadata)
        cta.apply(.title)
        cta.textColor = Design.Color.accent
        chevron.tintColor = Design.Color.accent
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let action = UIStackView(arrangedSubviews: [cta, UIView(), chevron])
        action.alignment = .center
        let column = UIStackView(arrangedSubviews: [eyebrow, titleLabel, detail, action])
        column.axis = .vertical
        column.spacing = Design.Spacing.xs
        column.setCustomSpacing(Design.Spacing.m, after: detail)
        column.isUserInteractionEnabled = false
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.l),
            column.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.l),
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.l),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.l)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "today_lesson_slot"
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: TodayLessonSlotView, _) in
            view.layer.borderColor = Design.Color.separator.resolvedColor(with: view.traitCollection).cgColor
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.85 : 1 }
    }

    func configure(_ card: TodayLessonCard) {
        eyebrow.text = card.eyebrow
        titleLabel.text = card.title
        detail.text = card.detail
        detail.isHidden = card.detail == nil
        cta.text = card.ctaTitle
        accessibilityLabel = [card.eyebrow, card.title, card.detail].compactMap { $0 }.joined(separator: ". ")
        accessibilityHint = card.ctaTitle
    }
}
