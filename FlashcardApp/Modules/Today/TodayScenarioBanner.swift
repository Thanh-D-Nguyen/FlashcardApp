import UIKit

/// The entrance to the everyday-situation lessons, set directly under the life hub. The life hub teaches from what is happening today
/// (the date, the weather, the place); this teaches from moments that can happen any day, such as a haircut, a clinic visit or the ward
/// office, so it says so and shows a few of the groups instead of promising a number it has not loaded.
final class TodayScenarioBannerView: UIControl {
    /// The groups named on the card: the ones a learner in Japan meets first.
    private static let shownGroups: [ScenarioCategory] = [.beauty, .health, .admin, .banking, .shopping, .dining, .transport, .housing, .delivery, .emergency]

    private let badgeBox = UIView()
    private let badge = UIImageView(image: UIImage(systemName: "text.bubble.fill"))
    private let eyebrow = UILabel()
    private let titleLabel = UILabel()
    private let japanese = UILabel()
    private let detail = UILabel()
    private let chipScroll = UIScrollView()
    private let chipStack = UIStackView()
    private let cta = UIButton(type: .system)
    private let header = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyCardSurface(radius: Design.Radius.card)
        layer.masksToBounds = true

        badgeBox.backgroundColor = Design.Color.highlight
        badgeBox.layer.cornerRadius = Design.Radius.control
        badgeBox.layer.cornerCurve = .continuous
        badgeBox.isUserInteractionEnabled = false
        badge.tintColor = Design.Color.accent
        badge.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        badge.translatesAutoresizingMaskIntoConstraints = false
        badgeBox.addSubview(badge)
        badgeBox.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badgeBox.widthAnchor.constraint(equalToConstant: Design.HitTarget.minimum),
            badgeBox.heightAnchor.constraint(equalToConstant: Design.HitTarget.minimum),
            badge.centerXAnchor.constraint(equalTo: badgeBox.centerXAnchor),
            badge.centerYAnchor.constraint(equalTo: badgeBox.centerYAnchor)
        ])

        eyebrow.apply(.eyebrow)
        eyebrow.textColor = Design.Color.accent
        eyebrow.text = NSLocalizedString("EVERY MOMENT IN JAPAN", comment: "Eyebrow of the situation lessons card on Today")
        titleLabel.apply(.headword)
        titleLabel.font = Design.TextRole.weighted(.title2, weight: .semibold)
        titleLabel.text = NSLocalizedString("Daily-life situations", comment: "Name of the situation lessons")
        japanese.apply(.reading)
        japanese.text = "暮らしの場面"
        japanese.accessibilityLabel = nil
        let titleBlock = UIStackView(arrangedSubviews: [eyebrow, titleLabel, japanese])
        titleBlock.axis = .vertical
        titleBlock.spacing = 2

        [badgeBox, titleBlock].forEach(header.addArrangedSubview)
        header.spacing = Design.Spacing.m
        header.alignment = .center
        header.isUserInteractionEnabled = false

        detail.apply(.meaning)
        detail.isUserInteractionEnabled = false
        detail.text = NSLocalizedString("A haircut, a clinic visit, the ward office, the bank… Choose what you would say and hear whether it sounds natural.",
                                        comment: "Description of the situation lessons card on Today")

        chipStack.axis = .horizontal
        chipStack.spacing = Design.Spacing.s
        chipStack.translatesAutoresizingMaskIntoConstraints = false
        chipScroll.showsHorizontalScrollIndicator = false
        chipScroll.alwaysBounceHorizontal = true
        chipScroll.translatesAutoresizingMaskIntoConstraints = false
        chipScroll.addSubview(chipStack)
        let chipTap = UITapGestureRecognizer(target: self, action: #selector(handleChipAreaTap))
        chipTap.cancelsTouchesInView = false
        chipScroll.addGestureRecognizer(chipTap)
        NSLayoutConstraint.activate([
            chipStack.topAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.topAnchor),
            chipStack.bottomAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.bottomAnchor),
            chipStack.leadingAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.leadingAnchor),
            chipStack.trailingAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.trailingAnchor),
            chipStack.heightAnchor.constraint(equalTo: chipScroll.frameLayoutGuide.heightAnchor)
        ])
        for group in Self.shownGroups { chipStack.addArrangedSubview(chip(group)) }

        cta.isUserInteractionEnabled = false
        cta.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        updateCTA()

        let column = UIStackView(arrangedSubviews: [header, detail, chipScroll, cta])
        column.axis = .vertical
        column.spacing = Design.Spacing.m
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.l),
            column.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.l),
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.l),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.l)
        ])

        // One element for VoiceOver: the card is a single button.
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "today_scenarios"
        accessibilityLabel = [titleLabel.text, detail.text].compactMap { $0 }.joined(separator: ". ")
        accessibilityHint = NSLocalizedString("Practise situations", comment: "Opens the situation lessons")

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: TodayScenarioBannerView, _) in
            view.updateCTA()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.85 : 1 }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, isUserInteractionEnabled, alpha > 0.01, self.point(inside: point, with: event) else { return nil }
        let chipPoint = convert(point, to: chipScroll)
        if chipScroll.point(inside: chipPoint, with: event) {
            return chipScroll
        }
        return self
    }

    @objc private func handleChipAreaTap() {
        sendActions(for: .touchUpInside)
    }

    private func updateCTA() {
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        var configuration = Design.Button.secondary(
            title: NSLocalizedString("Practise situations", comment: "Opens the situation lessons"),
            systemImage: isAX ? nil : "arrow.right",
            traits: traitCollection
        )
        configuration.imagePlacement = .trailing
        cta.configuration = configuration
        header.axis = isAX ? .vertical : .horizontal
        header.alignment = isAX ? .leading : .center
    }

    private func chip(_ group: ScenarioCategory) -> UIView {
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        configuration.imagePadding = Design.Spacing.xs
        configuration.image = UIImage(systemName: group.symbol)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .small)
        configuration.baseBackgroundColor = Design.Color.surfaceTint
        configuration.baseForegroundColor = Design.Color.textPrimary
        configuration.title = group.title
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.preferredFont(forTextStyle: .footnote)
            return outgoing
        }
        let pill = UIButton(configuration: configuration)
        pill.isUserInteractionEnabled = false
        pill.setContentHuggingPriority(.required, for: .horizontal)
        pill.setContentCompressionResistancePriority(.required, for: .horizontal)
        return pill
    }
}
