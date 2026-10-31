import UIKit

/// The entrance to the everyday-situation lessons, set directly under the life hub. The life hub teaches from what is happening today
/// (the date, the weather, the place); this teaches from moments that can happen any day, such as a haircut, a clinic visit or the ward
/// office, so it says so and shows a few of the groups instead of promising a number it has not loaded.
final class TodayScenarioBannerView: UIControl {
    /// The groups named on the card: the ones a learner in Japan meets first.
    private static let shownGroups: [ScenarioCategory] = [.beauty, .health, .admin, .banking, .shopping, .dining, .transport, .housing, .delivery, .emergency]

    private let gradient = CAGradientLayer()
    private let badge = UIImageView(image: UIImage(systemName: "text.bubble.fill"))
    private let eyebrow = UILabel()
    private let titleLabel = UILabel()
    private let japanese = UILabel()
    private let detail = UILabel()
    private let chipScroll = UIScrollView()
    private let chipStack = UIStackView()
    private let cta = UIButton(configuration: .filled())

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = Design.Radius.panel
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.masksToBounds = true
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradient, at: 0)

        let badgeBox = UIView()
        badgeBox.backgroundColor = Design.Color.accent
        badgeBox.layer.cornerRadius = 22
        badgeBox.layer.cornerCurve = .continuous
        badgeBox.isUserInteractionEnabled = false
        badge.tintColor = Design.Color.onAccent
        badge.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        badge.translatesAutoresizingMaskIntoConstraints = false
        badgeBox.addSubview(badge)
        badgeBox.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badgeBox.widthAnchor.constraint(equalToConstant: 44),
            badgeBox.heightAnchor.constraint(equalToConstant: 44),
            badge.centerXAnchor.constraint(equalTo: badgeBox.centerXAnchor),
            badge.centerYAnchor.constraint(equalTo: badgeBox.centerYAnchor)
        ])

        eyebrow.apply(.eyebrow)
        eyebrow.textColor = Design.Color.accent
        eyebrow.text = NSLocalizedString("EVERY MOMENT IN JAPAN", comment: "Eyebrow of the situation lessons card on Today")
        titleLabel.apply(.headword)
        titleLabel.font = Design.TextRole.headword.font.withWeight(.semibold)
        titleLabel.text = NSLocalizedString("Daily-life situations", comment: "Name of the situation lessons")
        japanese.apply(.reading)
        japanese.text = "暮らしの場面"
        japanese.accessibilityLabel = nil
        let titleBlock = UIStackView(arrangedSubviews: [eyebrow, titleLabel, japanese])
        titleBlock.axis = .vertical
        titleBlock.spacing = 2
        let header = UIStackView(arrangedSubviews: [badgeBox, titleBlock])
        header.spacing = Design.Spacing.m
        header.alignment = .center

        detail.apply(.meaning)
        detail.text = NSLocalizedString("A haircut, a clinic visit, the ward office, the bank… Choose what you would say and hear whether it sounds natural.",
                                        comment: "Description of the situation lessons card on Today")

        chipStack.axis = .horizontal
        chipStack.spacing = Design.Spacing.s
        chipStack.translatesAutoresizingMaskIntoConstraints = false
        chipScroll.showsHorizontalScrollIndicator = false
        chipScroll.alwaysBounceHorizontal = true
        chipScroll.translatesAutoresizingMaskIntoConstraints = false
        chipScroll.addSubview(chipStack)
        NSLayoutConstraint.activate([
            chipStack.topAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.topAnchor),
            chipStack.bottomAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.bottomAnchor),
            chipStack.leadingAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.leadingAnchor),
            chipStack.trailingAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.trailingAnchor),
            chipStack.heightAnchor.constraint(equalTo: chipScroll.frameLayoutGuide.heightAnchor)
        ])
        for group in Self.shownGroups { chipStack.addArrangedSubview(chip(group)) }

        var configuration = Design.Button.primary(title: NSLocalizedString("Practise situations", comment: "Opens the situation lessons"))
        configuration.image = UIImage(systemName: "arrow.right")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = Design.Spacing.s
        cta.configuration = configuration
        cta.isUserInteractionEnabled = false
        cta.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true

        let column = UIStackView(arrangedSubviews: [header, detail, chipScroll, cta])
        column.axis = .vertical
        column.spacing = Design.Spacing.m
        column.isUserInteractionEnabled = false
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

        updateColors()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: TodayScenarioBannerView, _) in view.updateColors() }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.85 : 1 }
    }

    private func updateColors() {
        gradient.colors = [Design.Color.accent.withAlphaComponent(0.20).resolvedColor(with: traitCollection).cgColor,
                           Design.Color.surface.resolvedColor(with: traitCollection).cgColor]
        layer.borderColor = Design.Color.accent.withAlphaComponent(0.35).resolvedColor(with: traitCollection).cgColor
    }

    private func chip(_ group: ScenarioCategory) -> UIView {
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        configuration.imagePadding = Design.Spacing.xs
        configuration.image = UIImage(systemName: group.symbol)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .small)
        configuration.baseBackgroundColor = Design.Color.surface
        configuration.baseForegroundColor = Design.Color.textPrimary
        var title = AttributedString(group.title)
        title.font = UIFont.preferredFont(forTextStyle: .footnote)
        configuration.attributedTitle = title
        let pill = UIButton(configuration: configuration)
        pill.isUserInteractionEnabled = false
        pill.setContentHuggingPriority(.required, for: .horizontal)
        pill.setContentCompressionResistancePriority(.required, for: .horizontal)
        return pill
    }
}
