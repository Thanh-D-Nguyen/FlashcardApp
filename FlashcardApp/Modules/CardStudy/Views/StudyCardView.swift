import UIKit

/// The study card: a single panel showing one side at a time, drawn in the chosen card style. Tapping it is handled by
/// the controller; this view only lays out the visible side and is one accessibility element.
final class StudyCardView: UIView {
    let imageView = CardImageView()
    private let surface = CardSurfaceView()
    let speakButton = UIButton(configuration: .plain())

    private let eyebrowLabel = UILabel()
    private let termLabel = UILabel()
    private let readingLabel = UILabel()
    private let noteLabel = UILabel()
    private let creditButton = SmallTargetButton(type: .system)
    private var credit = ""
    private let headerRow = UIStackView()
    private let stack = UIStackView()
    private var imageHeight: NSLayoutConstraint!
    private var stackBottom: NSLayoutConstraint!
    private var lastIsQuiz = false
    private var lastShowingBack = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        surface.translatesAutoresizingMaskIntoConstraints = false
        addSubview(surface)
        NSLayoutConstraint.activate([
            surface.topAnchor.constraint(equalTo: topAnchor), surface.bottomAnchor.constraint(equalTo: bottomAnchor),
            surface.leadingAnchor.constraint(equalTo: leadingAnchor), surface.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        eyebrowLabel.apply(.eyebrow)
        // A caption, not content: it must not push the speaker button out at accessibility sizes.
        eyebrowLabel.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: Design.TextRole.eyebrow.font.withSize(12), maximumPointSize: 22)
        eyebrowLabel.numberOfLines = 1
        eyebrowLabel.adjustsFontSizeToFitWidth = true
        eyebrowLabel.minimumScaleFactor = 0.6
        eyebrowLabel.isAccessibilityElement = false
        speakButton.configuration = {
            var configuration = UIButton.Configuration.plain()
            configuration.image = UIImage(systemName: "speaker.wave.2")
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
            configuration.baseForegroundColor = Design.Color.accent
            return configuration
        }()
        speakButton.accessibilityLabel = NSLocalizedString("Read aloud", comment: "")
        speakButton.accessibilityIdentifier = "study_speak"
        speakButton.setContentHuggingPriority(.required, for: .horizontal)
        speakButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        headerRow.addArrangedSubview(eyebrowLabel)
        headerRow.addArrangedSubview(UIView())
        headerRow.addArrangedSubview(speakButton)
        headerRow.alignment = .center

        imageView.accessibilityTraits = .image
        termLabel.apply(.term)
        termLabel.textAlignment = .center
        termLabel.isAccessibilityElement = false
        readingLabel.apply(.reading)
        readingLabel.textAlignment = .center
        readingLabel.isAccessibilityElement = false
        noteLabel.apply(.metadata)
        noteLabel.textAlignment = .center
        noteLabel.isAccessibilityElement = false
        // The credit is a footnote, not part of what is being learned: one tap on the picture's corner shows it.
        var info = UIButton.Configuration.filled()
        info.image = UIImage(systemName: "info.circle")
        info.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 9, weight: .regular)
        info.cornerStyle = .capsule
        info.baseBackgroundColor = UIColor.black.withAlphaComponent(0.22)
        info.baseForegroundColor = UIColor.white.withAlphaComponent(0.85)
        info.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 3, bottom: 3, trailing: 3)
        creditButton.configuration = info
        creditButton.accessibilityLabel = NSLocalizedString("Picture credit", comment: "Info button on a study card picture that shows who made it")
        creditButton.accessibilityIdentifier = "study_credit"
        creditButton.translatesAutoresizingMaskIntoConstraints = false
        creditButton.addTarget(self, action: #selector(showCredit), for: .primaryActionTriggered)

        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Design.Spacing.l
        stack.translatesAutoresizingMaskIntoConstraints = false
        [imageView, termLabel, readingLabel, noteLabel].forEach(stack.addArrangedSubview)
        stack.setCustomSpacing(Design.Spacing.xs, after: termLabel)
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerRow)
        addSubview(stack)
        addSubview(creditButton)
        imageHeight = imageView.heightAnchor.constraint(equalToConstant: 200)
        stackBottom = stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -Design.Spacing.xl)
        let stackCenterY = stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        stackCenterY.priority = .defaultHigh
        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.m),
            headerRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.xl),
            headerRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.m),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.xl),
            stackCenterY,
            stack.topAnchor.constraint(greaterThanOrEqualTo: headerRow.bottomAnchor, constant: Design.Spacing.s),
            stackBottom,
            speakButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            speakButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            creditButton.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -6),
            creditButton.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -6),
            imageHeight
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
        updateCardDensity()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: StudyCardView, _) in
            view.updateCardDensity()
        }
    }

    private func updateCardDensity() {
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        if lastIsQuiz {
            imageHeight.constant = isAX ? 88 : 110
        } else if lastShowingBack {
            imageHeight.constant = isAX ? 96 : 140
        } else {
            imageHeight.constant = isAX ? 96 : 200
        }
        stack.spacing = isAX ? Design.Spacing.s : Design.Spacing.l
        stackBottom.constant = isAX ? -Design.Spacing.m : -Design.Spacing.xl
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var termFont = Design.TextRole.term.font
    private var answerFont = Design.TextRole.answer.font

    /// Colours and faces of the chosen style; the app's own roles when there is none.
    private func applyStyle(_ style: CardStyle?) {
        surface.apply(style: style)
        termFont = style?.font(textStyle: .largeTitle, weight: .semibold, size: 52, maximum: 96) ?? Design.TextRole.term.font
        answerFont = style?.font(textStyle: .title2) ?? Design.TextRole.answer.font
        readingLabel.font = style?.font(textStyle: .subheadline) ?? Design.TextRole.reading.font
        noteLabel.font = style?.font(textStyle: .footnote) ?? Design.TextRole.metadata.font
        termLabel.textColor = style?.foregroundColor ?? Design.TextRole.term.color
        readingLabel.textColor = style?.mutedColor ?? Design.TextRole.reading.color
        noteLabel.textColor = style?.mutedColor ?? Design.TextRole.metadata.color
        eyebrowLabel.textColor = style?.mutedColor ?? Design.TextRole.eyebrow.color
        speakButton.configuration?.baseForegroundColor = style?.accentColor ?? Design.Color.accent
    }

    @objc private func showCredit() {
        guard !credit.isEmpty else { return }
        var responder: UIResponder? = self
        while let next = responder?.next, !(next is UIViewController) { responder = next }
        guard let presenter = responder?.next as? UIViewController else { return }
        let label = UILabel()
        label.apply(.meaning)
        label.numberOfLines = 0
        label.text = credit
        let controller = UIViewController()
        controller.view.backgroundColor = Design.Color.surface
        label.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: controller.view.topAnchor, constant: Design.Spacing.m),
            label.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor, constant: -Design.Spacing.m),
            label.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor, constant: Design.Spacing.m),
            label.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor, constant: -Design.Spacing.m)
        ])
        controller.modalPresentationStyle = .popover
        controller.preferredContentSize = controller.view.systemLayoutSizeFitting(CGSize(width: 260, height: UIView.layoutFittingCompressedSize.height),
                                                                                  withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        controller.popoverPresentationController?.sourceView = creditButton
        controller.popoverPresentationController?.permittedArrowDirections = [.up, .down]
        controller.popoverPresentationController?.delegate = CreditPopoverStyle.shared
        presenter.present(controller, animated: true)
    }

    private func languageName(japanese: Bool) -> String {
        japanese ? NSLocalizedString("Japanese", comment: "Language name") : NSLocalizedString("Vietnamese", comment: "Language name")
    }

    /// Lays out the visible side. `isFlip` cards show front or back; quiz cards show only the prompt (front).
    func configure(card: StudyCardState, direction: LanguageSortingType, showingBack: Bool, isQuiz: Bool = false,
                   readingVisible: Bool, imagesVisible: Bool, style: CardStyle? = nil) {
        applyStyle(style)
        let japaneseOnFront = JapaneseText.japaneseIsOnFront(front: card.front, back: card.back, deckHasJapaneseOnFront: direction != .opposite)
        let japaneseVisible = showingBack ? !japaneseOnFront : japaneseOnFront
        eyebrowLabel.text = languageName(japanese: japaneseVisible).uppercased(with: AppLanguage.current.locale)
        let text = showingBack ? card.back : card.front
        termLabel.text = text
        // The headword is the big mark; a meaning in the learner's language is set a size down.
        let big = japaneseVisible || !showingBack
        termLabel.font = big ? termFont : answerFont
        let reading = showingBack ? "" : card.reading
        readingLabel.text = reading
        readingLabel.isHidden = reading.isEmpty || !readingVisible
        let note = showingBack ? card.note : ""
        noteLabel.text = note
        noteLabel.isHidden = note.isEmpty
        let hasImage = imagesVisible && !card.imageReference.isEmpty
        imageView.isHidden = !hasImage
        lastIsQuiz = isQuiz
        lastShowingBack = showingBack
        updateCardDensity()
        credit = card.imageCredit
        creditButton.isHidden = !hasImage || credit.isEmpty
        if hasImage {
            imageView.setReference(card.imageReference)
            imageView.accessibilityLabel = String(format: NSLocalizedString("Picture for %@", comment: ""), card.front)
        } else {
            imageView.cancel()
        }
        var spoken = [text]
        if hasImage, !card.imageCredit.isEmpty { spoken.append(card.imageCredit) }
        if !reading.isEmpty, readingVisible { spoken.append(String(format: NSLocalizedString("Reading: %@", comment: ""), reading)) }
        if !note.isEmpty { spoken.append(String(format: NSLocalizedString("Note: %@", comment: ""), note)) }
        accessibilityLabel = ([languageName(japanese: japaneseVisible)] + spoken).joined(separator: ", ")
    }
}

/// Keeps the credit a popover on iPhone instead of a sheet.
private final class CreditPopoverStyle: NSObject, UIPopoverPresentationControllerDelegate {
    static let shared = CreditPopoverStyle()
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle { .none }
}

/// A small button that still has a 44 pt touch target.
private final class SmallTargetButton: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: min(0, (bounds.width - 44) / 2), dy: min(0, (bounds.height - 44) / 2)).contains(point)
    }
}
