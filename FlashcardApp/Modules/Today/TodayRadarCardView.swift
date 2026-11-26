import UIKit

/// Interactive Daily Radar card on Today: rich `LifeSceneView` illustration matched to the card's module type,
/// Japanese expression and meaning, plus real actions: Listen (Nghe), Save to deck (Lưu vào deck), and Study now / Read card.
final class TodayRadarCardView: UIView {
    var onOpenCard: (() -> Void)?
    var onSpeak: (() -> Void)?
    var onSaveToDeck: (() -> Void)?
    var onStudyNow: (() -> Void)?

    private let sceneView = LifeSceneView()
    private let badgeBox = UIView()
    private let badgeLabel = UILabel()
    private let inlineBadgeBox = UIView()
    private let inlineBadgeLabel = UILabel()
    private let inlineBadgeRow = UIStackView()
    private let expressionLabel = UILabel()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let listenButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let studyButton = UIButton(type: .system)
    private let secondaryActionsRow = UIStackView()
    private let actionsColumn = UIStackView()
    private var studyButtonTitle = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyCardSurface(radius: Design.Radius.card)
        clipsToBounds = true
        accessibilityIdentifier = "today_radar_card"

        sceneView.translatesAutoresizingMaskIntoConstraints = false

        for (label, box) in [(badgeLabel, badgeBox), (inlineBadgeLabel, inlineBadgeBox)] {
            label.apply(.eyebrow)
            label.textColor = Design.Color.accent
            label.translatesAutoresizingMaskIntoConstraints = false
            box.layer.cornerRadius = Design.Radius.badge
            box.layer.cornerCurve = .continuous
            box.translatesAutoresizingMaskIntoConstraints = false
            box.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: box.topAnchor, constant: 4),
                label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -4),
                label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: Design.Spacing.s),
                label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -Design.Spacing.s)
            ])
        }
        badgeBox.backgroundColor = Design.Color.surface.withAlphaComponent(0.92)
        inlineBadgeBox.backgroundColor = Design.Color.statusFill(Design.Color.accent)
        inlineBadgeRow.axis = .horizontal
        inlineBadgeRow.addArrangedSubview(inlineBadgeBox)
        inlineBadgeRow.addArrangedSubview(UIView())
        inlineBadgeRow.isHidden = true

        expressionLabel.apply(.headword)
        expressionLabel.font = Design.TextRole.weighted(.title2, weight: .semibold)
        titleLabel.apply(.meaning)
        detailLabel.apply(.metadata)

        listenButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        listenButton.enableAdaptiveCornerStyle()
        listenButton.accessibilityIdentifier = "today_radar_listen"
        listenButton.addAction(UIAction { [weak self] _ in self?.onSpeak?() }, for: .primaryActionTriggered)

        saveButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        saveButton.enableAdaptiveCornerStyle()
        saveButton.accessibilityIdentifier = "today_radar_save"
        saveButton.addAction(UIAction { [weak self] _ in self?.onSaveToDeck?() }, for: .primaryActionTriggered)

        studyButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        studyButton.enableAdaptiveCornerStyle()
        studyButton.accessibilityIdentifier = "today_radar_study"
        studyButton.addAction(UIAction { [weak self] _ in self?.onStudyNow?() }, for: .primaryActionTriggered)

        secondaryActionsRow.spacing = Design.Spacing.s
        secondaryActionsRow.distribution = .fillEqually
        [listenButton, saveButton].forEach(secondaryActionsRow.addArrangedSubview)

        actionsColumn.axis = .vertical
        actionsColumn.spacing = Design.Spacing.s
        [secondaryActionsRow, studyButton].forEach(actionsColumn.addArrangedSubview)

        let body = UIStackView(arrangedSubviews: [inlineBadgeRow, expressionLabel, titleLabel, detailLabel, actionsColumn])
        body.axis = .vertical
        body.spacing = Design.Spacing.xs
        body.setCustomSpacing(Design.Spacing.m, after: detailLabel)
        body.isLayoutMarginsRelativeArrangement = true
        body.layoutMargins = UIEdgeInsets(top: Design.Spacing.m, left: Design.Spacing.l, bottom: Design.Spacing.l, right: Design.Spacing.l)

        let tap = UITapGestureRecognizer(target: self, action: #selector(bodyTapped))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)

        let column = UIStackView(arrangedSubviews: [sceneView, body])
        column.axis = .vertical
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        addSubview(badgeBox)

        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            sceneView.heightAnchor.constraint(equalToConstant: 108),
            badgeBox.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.m),
            badgeBox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.m),
            badgeBox.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Design.Spacing.m)
        ])

        updateButtonConfigs()
        updateLayoutForTextSize()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: TodayRadarCardView, _) in
            view.updateButtonConfigs()
            view.updateLayoutForTextSize()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func bodyTapped(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self)
        for button in [listenButton, saveButton, studyButton] where !button.isHidden {
            if button.convert(button.bounds, to: self).contains(point) { return }
        }
        onOpenCard?()
    }

    private func updateButtonConfigs() {
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        listenButton.configuration = Design.Button.surfaceChip(
            title: NSLocalizedString("Listen", comment: "Speaks the Japanese expression aloud"),
            systemImage: "speaker.wave.2.fill",
            traits: traitCollection
        )
        saveButton.configuration = Design.Button.surfaceChip(
            title: NSLocalizedString("Save to deck", comment: "Saves the card's expression to a flashcard deck"),
            systemImage: "plus.rectangle.on.folder",
            traits: traitCollection
        )
        var studyConfig = Design.Button.primary(
            title: studyButtonTitle,
            systemImage: isAX ? nil : "arrow.right",
            traits: traitCollection
        )
        studyConfig.imagePlacement = .trailing
        studyButton.configuration = studyConfig
    }

    private func updateLayoutForTextSize() {
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        badgeBox.isHidden = isAX
        inlineBadgeRow.isHidden = !isAX
        secondaryActionsRow.axis = isAX ? .vertical : .horizontal
        secondaryActionsRow.distribution = isAX ? .fill : .fillEqually
    }

    func configure(_ card: TodayRadarCard) {
        sceneView.configure(scene: card.scene, topic: card.topic)
        let eyebrowText = card.eyebrow.isEmpty
            ? NSLocalizedString("DAILY RADAR", comment: "Today: eyebrow of the Daily Radar card")
            : card.eyebrow.uppercased()
        badgeLabel.text = eyebrowText
        inlineBadgeLabel.text = eyebrowText
        expressionLabel.text = card.expression
        titleLabel.text = card.title
        detailLabel.text = card.detail
        detailLabel.isHidden = card.detail == nil
        saveButton.isHidden = !card.canSave
        studyButtonTitle = card.hasDeepLink
            ? NSLocalizedString("Study now", comment: "Opens the mapped study screen from a Daily Radar card")
            : NSLocalizedString("Read the card", comment: "Today: opens the Daily Radar card")
        updateButtonConfigs()
        updateLayoutForTextSize()
        expressionLabel.accessibilityLabel = [eyebrowText, card.expression, card.title, card.detail].compactMap { $0 }.joined(separator: ". ")
    }
}
