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
    private let headerRow = UIStackView()
    private let stack = UIStackView()
    private var imageHeight: NSLayoutConstraint!

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

        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Design.Spacing.l
        stack.translatesAutoresizingMaskIntoConstraints = false
        [imageView, termLabel, readingLabel, noteLabel].forEach(stack.addArrangedSubview)
        stack.setCustomSpacing(Design.Spacing.xs, after: termLabel)
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerRow)
        addSubview(stack)
        imageHeight = imageView.heightAnchor.constraint(equalToConstant: 200)
        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.m),
            headerRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.xl),
            headerRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.m),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.xl),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: headerRow.bottomAnchor, constant: Design.Spacing.m),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -Design.Spacing.xl),
            speakButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            speakButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            imageHeight
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
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
        // A quiz leaves room for the options below; a flip card gives the picture more room on the front.
        imageHeight.constant = isQuiz ? 110 : (showingBack ? 140 : 200)
        if hasImage {
            imageView.setReference(card.imageReference)
            imageView.accessibilityLabel = String(format: NSLocalizedString("Picture for %@", comment: ""), card.front)
        } else {
            imageView.cancel()
        }
        var spoken = [text]
        if !reading.isEmpty, readingVisible { spoken.append(String(format: NSLocalizedString("Reading: %@", comment: ""), reading)) }
        if !note.isEmpty { spoken.append(String(format: NSLocalizedString("Note: %@", comment: ""), note)) }
        accessibilityLabel = ([languageName(japanese: japaneseVisible)] + spoken).joined(separator: ", ")
    }
}
