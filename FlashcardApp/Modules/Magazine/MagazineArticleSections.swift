import UIKit

/// The two interactive sections of an article: the vocabulary to save, and the quiz.
extension MagazineArticleViews {

    // MARK: Vocabulary

    static func vocabulary(_ vocabulary: MagazineArticleState.Vocabulary, kind: MagazineKind, actions: VocabularyActions) -> UIView {
        let rows = UIStackView()
        rows.axis = .vertical
        for (index, row) in vocabulary.rows.enumerated() {
            if index > 0 { rows.addArrangedSubview(separator()) }
            let view = VocabularyRowView(row: row)
            view.addAction(UIAction { _ in actions.toggle(row.id) }, for: .primaryActionTriggered)
            rows.addArrangedSubview(view)
        }
        let list = UIView()
        list.backgroundColor = Design.Color.surface
        list.layer.cornerRadius = 20
        list.layer.cornerCurve = .continuous
        list.clipsToBounds = true
        rows.translatesAutoresizingMaskIntoConstraints = false
        list.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: list.topAnchor), rows.bottomAnchor.constraint(equalTo: list.bottomAnchor),
            rows.leadingAnchor.constraint(equalTo: list.leadingAnchor), rows.trailingAnchor.constraint(equalTo: list.trailingAnchor)
        ])

        var deck = UIButton.Configuration.plain()
        deck.title = "\(vocabulary.deckLabel): \(vocabulary.deckName)"
        deck.image = UIImage(systemName: "chevron.up.chevron.down")
        deck.imagePlacement = .trailing
        deck.imagePadding = Design.Spacing.s
        deck.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .caption1, scale: .small)
        deck.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        let deckButton = UIButton(configuration: deck)
        deckButton.contentHorizontalAlignment = .leading
        deckButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        deckButton.addAction(UIAction { _ in actions.chooseDeck() }, for: .primaryActionTriggered)
        deckButton.accessibilityIdentifier = "magazine_deck_button"

        var primary = Design.Button.primary(title: vocabulary.primaryTitle)
        primary.image = vocabulary.canReview ? UIImage(systemName: "rectangle.stack.fill") : UIImage(systemName: "plus.rectangle.on.rectangle")
        primary.imagePadding = Design.Spacing.s
        let primaryButton = UIButton(configuration: primary)
        primaryButton.isEnabled = vocabulary.primaryEnabled
        primaryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        primaryButton.addAction(UIAction { _ in actions.primary() }, for: .primaryActionTriggered)
        primaryButton.accessibilityIdentifier = "magazine_save_words"

        var views: [UIView] = [sectionTitle(vocabulary.title, symbol: "character.book.closed.fill", tint: kind.tint), list]
        switch vocabulary.status {
        case .idle, .saving: break
        case .failed(let message): views.append(status(message, symbol: "exclamationmark.triangle.fill", color: Design.Color.error))
        case .saved(let message): views.append(status(message, symbol: "checkmark.circle.fill", color: Design.Color.success))
        }
        if !vocabulary.canReview { views.append(deckButton) }
        views.append(primaryButton)
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.accessibilityIdentifier = "magazine_vocabulary"
        return stack
    }

    struct VocabularyActions {
        let toggle: (String) -> Void
        let chooseDeck: () -> Void
        let primary: () -> Void
    }

    private static func status(_ message: String, symbol: String, color: UIColor) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = color
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)
        let text = label(message, role: .reading, color: color)
        let row = UIStackView(arrangedSubviews: [icon, text])
        row.alignment = .firstBaseline
        row.spacing = Design.Spacing.s
        row.isAccessibilityElement = true
        row.accessibilityLabel = message
        return row
    }

    // MARK: Quiz

    struct QuizActions {
        let select: (Int) -> Void
        let next: () -> Void
        let restart: () -> Void
    }

    static func quiz(title: String, _ quiz: MagazineArticleState.Quiz, kind: MagazineKind, actions: QuizActions) -> UIView {
        let heading = sectionTitle(title, symbol: "questionmark.bubble.fill", tint: kind.tint)
        let body: UIView
        switch quiz {
        case .question(let question): body = questionCard(question, actions: actions)
        case .result(let result): body = resultCard(result, actions: actions)
        }
        let stack = UIStackView(arrangedSubviews: [heading, body])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.accessibilityIdentifier = "magazine_quiz"
        return stack
    }

    private static func questionCard(_ question: MagazineArticleState.QuizQuestion, actions: QuizActions) -> UIView {
        var views: [UIView] = [label(question.progress.uppercased(), role: .eyebrow),
                               label(question.promptJapanese, role: .sentence, japanese: true)]
        if let prompt = question.prompt { views.append(label(prompt, role: .reading)) }
        let answered = question.feedbackTitle != nil
        let options = UIStackView()
        options.axis = .vertical
        options.spacing = Design.Spacing.s
        for (index, option) in question.options.enumerated() {
            let control = QuizOptionControl(option: option, enabled: !answered)
            control.addAction(UIAction { _ in actions.select(index) }, for: .primaryActionTriggered)
            control.accessibilityIdentifier = "magazine_quiz_option_\(index)"
            options.addArrangedSubview(control)
        }
        views.append(options)
        if let title = question.feedbackTitle, let correct = question.feedbackIsCorrect {
            let color = correct ? Design.Color.success : Design.Color.error
            let headline = label(title, role: .title, color: color, traits: .staticText)
            var feedback: [UIView] = [headline]
            if let detail = question.feedbackDetail { feedback.append(label(detail, role: .reading)) }
            let box = UIStackView(arrangedSubviews: feedback)
            box.axis = .vertical
            box.spacing = Design.Spacing.xs
            views.append(box)
        }
        if let primary = question.primaryTitle {
            var configuration = Design.Button.primary(title: primary)
            configuration.buttonSize = .large
            let button = UIButton(configuration: configuration)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
            button.addAction(UIAction { _ in actions.next() }, for: .primaryActionTriggered)
            button.accessibilityIdentifier = "magazine_quiz_next"
            views.append(button)
        }
        let card = card(views, spacing: Design.Spacing.m)
        card.accessibilityIdentifier = "magazine_quiz_card"
        return card
    }

    private static func resultCard(_ result: MagazineArticleState.QuizResult, actions: QuizActions) -> UIView {
        let score = label(result.score, role: .headword, traits: .header)
        score.font = Design.TextRole.headword.font.withWeight(.semibold)
        let message = label(result.message, role: .meaning)
        var configuration = UIButton.Configuration.tinted()
        configuration.cornerStyle = .capsule
        configuration.title = result.actionTitle
        configuration.image = UIImage(systemName: "arrow.counterclockwise")
        configuration.imagePadding = Design.Spacing.s
        let button = UIButton(configuration: configuration)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addAction(UIAction { _ in actions.restart() }, for: .primaryActionTriggered)
        button.accessibilityIdentifier = "magazine_quiz_restart"
        return card([score, message, button], spacing: Design.Spacing.m)
    }
}

// MARK: Controls

/// One word of the article's vocabulary. The whole row is the control: it toggles whether the word is saved.
final class VocabularyRowView: UIControl {
    init(row: MagazineArticleState.VocabularyRow) {
        super.init(frame: .zero)
        let check = UIImageView(image: UIImage(systemName: row.isSelected ? "checkmark.circle.fill" : "circle"))
        check.tintColor = row.isSelected ? Design.Color.accent : Design.Color.textSecondary
        check.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        check.setContentHuggingPriority(.required, for: .horizontal)
        check.setContentCompressionResistancePriority(.required, for: .horizontal)

        var head: [UIView] = [MagazineArticleViews.label(row.japanese, role: .headword, japanese: true)]
        if !row.reading.isEmpty { head.append(MagazineArticleViews.label(row.reading, role: .reading, japanese: true)) }
        if let level = row.level { head += [UIView(), MagazineArticleViews.tag(level)] }
        let headline = UIStackView(arrangedSubviews: head)
        headline.alignment = .firstBaseline
        headline.spacing = Design.Spacing.s
        var views: [UIView] = [headline, MagazineArticleViews.label(row.meaning, role: .meaning)]
        if let example = row.example {
            views += MagazineArticleViews.pair(japanese: example, meaning: row.exampleMeaning, japaneseRole: .reading)
        }
        let text = UIStackView(arrangedSubviews: views)
        text.axis = .vertical
        text.spacing = Design.Spacing.xs
        let content = UIStackView(arrangedSubviews: [check, text])
        content.alignment = .top
        content.spacing = Design.Spacing.m
        content.isUserInteractionEnabled = false
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.m),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.m),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.l),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.l),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        isAccessibilityElement = true
        accessibilityTraits = row.isSelected ? [.button, .selected] : .button
        accessibilityLabel = [row.japanese, row.reading, row.meaning, row.example, row.exampleMeaning].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ". ")
        accessibilityHint = NSLocalizedString("Double-tap to choose whether to save this word.", comment: "Magazine vocabulary row hint")
        accessibilityIdentifier = "magazine_word_\(row.id)"
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? Design.Color.highlight : .clear }
    }
}

/// An answer to pick. After the answer, the right one is marked with a check and the picked wrong one with a cross, so the
/// result does not rely on color.
final class QuizOptionControl: UIControl {
    init(option: MagazineArticleState.QuizOption, enabled: Bool) {
        super.init(frame: .zero)
        let symbol: String, tint: UIColor, fill: UIColor, border: UIColor
        switch option.mark {
        case .neutral:
            (symbol, tint, fill, border) = ("circle", Design.Color.textSecondary, Design.Color.background, Design.Color.separator)
        case .correct:
            (symbol, tint, fill, border) = ("checkmark.circle.fill", Design.Color.success, Design.Color.success.withAlphaComponent(0.12), Design.Color.success)
        case .wrong:
            (symbol, tint, fill, border) = ("xmark.circle.fill", Design.Color.error, Design.Color.error.withAlphaComponent(0.12), Design.Color.error)
        case .dimmed:
            (symbol, tint, fill, border) = ("circle", Design.Color.textSecondary, Design.Color.background, Design.Color.separator)
        }
        backgroundColor = fill
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = border.cgColor

        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = tint
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)
        let text = MagazineArticleViews.label(option.text, role: .meaning, color: option.mark == .dimmed ? Design.Color.textSecondary : Design.Color.textPrimary)
        let row = UIStackView(arrangedSubviews: [icon, text])
        row.alignment = .center
        row.spacing = Design.Spacing.m
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.m),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.m),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.m),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.m),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
        isEnabled = enabled
        isAccessibilityElement = true
        accessibilityLabel = option.text
        switch option.mark {
        case .correct: accessibilityValue = NSLocalizedString("Correct", comment: "")
        case .wrong: accessibilityValue = NSLocalizedString("Not quite", comment: "")
        case .neutral, .dimmed: accessibilityValue = nil
        }
        accessibilityTraits = enabled ? .button : [.button, .notEnabled]
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }
}
