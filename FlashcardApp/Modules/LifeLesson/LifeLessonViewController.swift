import UIKit

/// One screen for the whole lesson: it draws whichever step the presenter is in. Content is solid surfaces on the paper
/// background; glass belongs to the system bars only.
final class LifeLessonViewController: BaseViewController, LifeLessonViewInterface {
    var presenter: LifeLessonPresenterInterface!

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let stateView = StateView()
    private let answerField = UITextField()
    private var lastStepKey = ""
    /// The control the learner just used. A step redraws its whole content, so with VoiceOver on the focus is put back on
    /// the same control (found by identifier) instead of being lost.
    private var focusIdentifier: String?
    private var lastPracticeProgress = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }

    func subscribe() {}

    func setupUI() {
        view.backgroundColor = Design.Color.background
        title = NSLocalizedString("Learn from Life", comment: "Screen title of a life lesson")
        navigationItem.largeTitleDisplayMode = .never

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.accessibilityIdentifier = "life_screen"
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)
        stateView.translatesAutoresizingMaskIntoConstraints = false
        stateView.isHidden = true
        view.addSubview(stateView)

        answerField.borderStyle = .none
        answerField.backgroundColor = Design.Color.surface
        answerField.layer.cornerRadius = 12
        answerField.layer.cornerCurve = .continuous
        answerField.font = .preferredFont(forTextStyle: .title3)
        answerField.adjustsFontForContentSizeCategory = true
        answerField.autocorrectionType = .no
        answerField.autocapitalizationType = .none
        answerField.spellCheckingType = .no
        answerField.returnKeyType = .done
        answerField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: Design.Spacing.m, height: 1))
        answerField.leftViewMode = .always
        answerField.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        answerField.accessibilityIdentifier = "life_answer_field"
        answerField.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.presenter.primaryTapped(answer: self.answerField.text ?? "")
        }, for: .editingDidEndOnExit)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Design.Spacing.m),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter),
            stateView.topAnchor.constraint(equalTo: view.topAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // MARK: LifeLessonViewInterface

    func announce(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    func render(_ state: LifeLessonViewState) {
        loadViewIfNeeded()
        let (key, content) = build(state)
        let changedStep = key != lastStepKey
        lastStepKey = key

        guard let content else {
            stack.isHidden = true
            scrollView.isHidden = true
            stateView.isHidden = false
            return
        }
        stateView.isHidden = true
        scrollView.isHidden = false
        stack.isHidden = false
        let apply = {
            self.stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            content.forEach(self.stack.addArrangedSubview)
            self.view.layoutIfNeeded()
        }
        if changedStep {
            scrollView.setContentOffset(CGPoint(x: 0, y: -scrollView.adjustedContentInset.top), animated: false)
            // A short cross-fade between steps; none when Reduce Motion is on.
            if UIAccessibility.isReduceMotionEnabled { apply() } else {
                UIView.transition(with: stack, duration: 0.2, options: .transitionCrossDissolve, animations: apply)
            }
            UIAccessibility.post(notification: .screenChanged, argument: content.first)
        } else {
            apply()
            restoreVoiceOverFocus()
        }
    }

    private func restoreVoiceOverFocus() {
        guard UIAccessibility.isVoiceOverRunning, let id = focusIdentifier else { return }
        focusIdentifier = nil
        UIAccessibility.post(notification: .layoutChanged, argument: view(withIdentifier: id, in: stack))
    }

    private func view(withIdentifier id: String, in root: UIView) -> UIView? {
        if root.accessibilityIdentifier == id { return root }
        for child in root.subviews { if let found = view(withIdentifier: id, in: child) { return found } }
        return nil
    }

    /// The identity of the step, so a selection or a status change does not scroll to the top or re-announce the screen.
    private func build(_ state: LifeLessonViewState) -> (String, [UIView]?) {
        switch state {
        case .loading(let message):
            stateView.configure(.loading(message))
            return ("loading", nil)
        case .failed(let title, let message):
            stateView.configure(.error(message: "\(title)\n\(message)", retryTitle: NSLocalizedString("Try again", comment: ""))) { [weak self] in
                self?.presenter.retry()
            }
            return ("failed", nil)
        case .story(let story):
            return ("story", storyViews(story))
        case .practice(let practice):
            return ("practice-\(practice.progress)", practiceViews(practice))
        case .save(let save):
            return ("save", saveViews(save))
        case .done(let done):
            return ("done", doneViews(done))
        }
    }

    // MARK: Building blocks

    private func label(_ text: String, role: Design.TextRole, color: UIColor? = nil, traits: UIAccessibilityTraits? = nil) -> UILabel {
        let label = UILabel()
        label.apply(role)
        label.text = text
        if let color { label.textColor = color }
        if let traits { label.accessibilityTraits = traits }
        return label
    }

    private func eyebrow(_ text: String) -> UILabel {
        let label = label(text, role: .eyebrow, traits: .header)
        return label
    }

    private func card(_ views: [UIView], spacing: CGFloat = Design.Spacing.xs) -> UIView {
        let container = UIView()
        container.backgroundColor = Design.Color.surface
        container.layer.cornerRadius = 20
        container.layer.cornerCurve = .continuous
        let inner = UIStackView(arrangedSubviews: views)
        inner.axis = .vertical
        inner.spacing = spacing
        inner.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: container.topAnchor, constant: Design.Spacing.l),
            inner.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Design.Spacing.l),
            inner.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Design.Spacing.l),
            inner.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Design.Spacing.l)
        ])
        return container
    }

    private func tag(_ text: String, color: UIColor = Design.Color.textSecondary) -> UIView {
        let label = label(text, role: .metadata, color: color)
        label.font = Design.TextRole.metadata.font.withWeight(.semibold)
        let box = UIView()
        box.layer.cornerRadius = 6
        box.layer.borderWidth = 1
        box.layer.borderColor = color.cgColor
        label.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -2),
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: Design.Spacing.s),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -Design.Spacing.s)
        ])
        box.isAccessibilityElement = true
        box.accessibilityLabel = text
        return box
    }

    private func wrapped(_ views: [UIView]) -> UIView {
        // Tags sit on one line when they fit; each keeps its own size.
        let row = UIStackView(arrangedSubviews: views + [UIView()])
        row.axis = .horizontal
        row.spacing = Design.Spacing.s
        row.alignment = .leading
        return row
    }

    private func primaryButton(_ title: String, id: String, enabled: Bool = true, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(configuration: Design.Button.primary(title: title))
        button.isEnabled = enabled
        button.accessibilityIdentifier = id
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        button.addAction(UIAction { [weak self] _ in self?.focusIdentifier = id; action() }, for: .primaryActionTriggered)
        return button
    }

    private func secondaryButton(_ title: String, id: String, action: @escaping () -> Void) -> UIButton {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = title
        configuration.cornerStyle = .capsule
        configuration.buttonSize = .large
        configuration.baseForegroundColor = Design.Color.accent
        configuration.baseBackgroundColor = Design.Color.accent
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = id
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        button.addAction(UIAction { [weak self] _ in self?.focusIdentifier = id; action() }, for: .primaryActionTriggered)
        return button
    }

    private func statusRow(symbol: String, title: String, detail: String?, color: UIColor) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = color
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.isAccessibilityElement = false
        let titleLabel = label(title, role: .title, color: color)
        let head = UIStackView(arrangedSubviews: [icon, titleLabel])
        head.spacing = Design.Spacing.s
        head.alignment = .firstBaseline
        var views: [UIView] = [head]
        if let detail { views.append(label(detail, role: .reading)) }
        let content = card(views)
        content.isAccessibilityElement = true
        content.accessibilityLabel = [title, detail].compactMap { $0 }.joined(separator: ". ")
        return content
    }

    // MARK: Story

    /// Where the facts come from is a footnote: one tap away, with the attribution the licence asks for and the link to the source.
    private func showSource(_ story: LifeStoryState, from button: UIView) {
        let stack = UIStackView(arrangedSubviews: [label(story.sourceLine, role: .metadata)])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.s
        let controller = UIViewController()
        if !story.attribution.isEmpty {
            stack.addArrangedSubview(label(story.attribution, role: .meaning))
            let open = UIButton(type: .system)
            var link = UIButton.Configuration.plain()
            link.title = NSLocalizedString("Open source page", comment: "Opens the data source's own page from the source popover")
            link.image = UIImage(systemName: "arrow.up.right")
            link.imagePlacement = .trailing
            link.imagePadding = Design.Spacing.xs
            link.contentInsets = .zero
            open.configuration = link
            open.contentHorizontalAlignment = .leading
            open.accessibilityTraits = .link
            open.accessibilityIdentifier = "life_source_link"
            open.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            open.addAction(UIAction { [weak self, weak controller] _ in
                controller?.dismiss(animated: true) { self?.presenter.openSource() }
            }, for: .primaryActionTriggered)
            stack.addArrangedSubview(open)
        }
        controller.view.backgroundColor = Design.Color.surface
        stack.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: controller.view.topAnchor, constant: Design.Spacing.m),
            stack.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor, constant: -Design.Spacing.s),
            stack.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor, constant: Design.Spacing.m),
            stack.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor, constant: -Design.Spacing.m)
        ])
        controller.modalPresentationStyle = .popover
        controller.preferredContentSize = controller.view.systemLayoutSizeFitting(CGSize(width: 300, height: UIView.layoutFittingCompressedSize.height),
                                                                                  withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        controller.popoverPresentationController?.sourceView = button
        controller.popoverPresentationController?.permittedArrowDirections = [.up, .down]
        controller.popoverPresentationController?.delegate = sourcePopoverStyle
        present(controller, animated: true)
    }

    private let sourcePopoverStyle = SourcePopoverStyle()

    private func storyViews(_ story: LifeStoryState) -> [UIView] {
        let sceneView = LifeSceneView()
        sceneView.layer.cornerRadius = 22
        sceneView.layer.cornerCurve = .continuous
        sceneView.heightAnchor.constraint(equalToConstant: 148).isActive = true
        sceneView.configure(scene: story.scene, topic: story.topic)
        var views: [UIView] = [sceneView, eyebrow(story.eyebrow)]
        let title = label(story.title, role: .headword, traits: .header)
        title.font = Design.TextRole.headword.font.withWeight(.semibold)
        title.accessibilityIdentifier = "life_story_title"
        let reading = label(story.titleReading, role: .reading)
        let titleBlock = UIStackView(arrangedSubviews: [title, reading])
        titleBlock.axis = .vertical
        titleBlock.spacing = 2
        views.append(titleBlock)
        if !story.tags.isEmpty {
            views.append(wrapped(story.tags.map { tag($0, color: Design.Color.warning) }))
        }

        let sourceButton = UIButton(type: .system)
        var info = UIButton.Configuration.plain()
        info.image = UIImage(systemName: "info.circle")
        info.baseForegroundColor = Design.Color.textSecondary
        info.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 0)
        sourceButton.configuration = info
        sourceButton.accessibilityLabel = NSLocalizedString("Source", comment: "Info button that shows where the facts come from")
        sourceButton.accessibilityIdentifier = "life_source_info"
        sourceButton.setContentHuggingPriority(.required, for: .horizontal)
        sourceButton.addAction(UIAction { [weak self, weak sourceButton] _ in
            guard let self, let sourceButton else { return }
            self.showSource(story, from: sourceButton)
        }, for: .primaryActionTriggered)
        let header = UIStackView(arrangedSubviews: [eyebrow(story.factsHeader), sourceButton])
        header.alignment = .center
        var factViews: [UIView] = [header]
        factViews += story.factChips.map { chip in
            let text = label(chip.text, role: .meaning)
            let image = UIImageView(image: chip.symbol.flatMap { UIImage(systemName: $0) })
            image.tintColor = Design.Color.accent
            image.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
            image.setContentHuggingPriority(.required, for: .horizontal)
            image.widthAnchor.constraint(equalToConstant: 26).isActive = true
            image.contentMode = .center
            let row = UIStackView(arrangedSubviews: [image, text])
            row.spacing = Design.Spacing.s
            row.alignment = .firstBaseline
            return row
        }
        let facts = card(factViews, spacing: Design.Spacing.xs)
        facts.accessibilityIdentifier = "life_facts"
        views.append(facts)

        views.append(eyebrow(story.sentencesHeader))
        for (index, sentence) in story.sentences.enumerated() {
            let japanese = label(sentence.japanese, role: .headword)
            japanese.accessibilityIdentifier = "life_sentence_\(index)"
            var rows: [UIView] = []
            if sentence.isAdvice { rows.append(wrapped([tag(NSLocalizedString("Tip", comment: "Label on a suggestion that is not a source fact"))])) }
            rows.append(japanese)
            if !sentence.reading.isEmpty { rows.append(label(sentence.reading, role: .reading)) }
            rows += [label(sentence.translation, role: .meaning), label(sentence.explanation, role: .metadata)]
            views.append(card(rows))
        }
        views.append(primaryButton(story.ctaTitle, id: "life_story_start") { [weak self] in self?.presenter.startPractice() })
        return views
    }

    // MARK: Practice

    private func practiceViews(_ practice: LifePracticeState) -> [UIView] {
        if practice.progress != lastPracticeProgress {
            lastPracticeProgress = practice.progress
            answerField.text = nil
        }
        var views: [UIView] = [eyebrow(practice.progress), wrapped([tag(practice.skill)])]
        let prompt = label(practice.promptJapanese, role: .headword)
        prompt.font = Design.TextRole.headword.font.withWeight(.semibold)
        prompt.accessibilityIdentifier = "life_prompt"
        views.append(card([prompt, label(practice.prompt, role: .meaning)]))

        switch practice.input {
        case .typed(let placeholder):
            answerField.placeholder = placeholder
            answerField.isEnabled = practice.feedback == nil
            answerField.accessibilityLabel = placeholder
            views.append(answerField)
        case .choices(let texts, let selected):
            for (index, text) in texts.enumerated() {
                views.append(choiceButton(text, index: index, selected: selected == index, feedback: practice.feedback))
            }
        }

        if let feedback = practice.feedback {
            let result = statusRow(symbol: feedback.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill", title: feedback.title,
                                   detail: feedback.detail, color: feedback.isCorrect ? Design.Color.success : Design.Color.error)
            result.accessibilityIdentifier = "life_feedback"
            views.append(result)
        }
        views.append(primaryButton(practice.primaryTitle, id: "life_primary", enabled: practice.primaryEnabled) { [weak self] in
            guard let self else { return }
            self.answerField.resignFirstResponder()
            self.presenter.primaryTapped(answer: self.answerField.text ?? "")
        })
        return views
    }

    private func choiceButton(_ text: String, index: Int, selected: Bool, feedback: LifeFeedback?) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = text
        configuration.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.m, leading: Design.Spacing.l, bottom: Design.Spacing.m, trailing: Design.Spacing.l)
        configuration.baseForegroundColor = Design.Color.textPrimary
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .title3)
            return attributes
        }
        var color = Design.Color.surface
        var border: UIColor = Design.Color.separator
        if let feedback {
            if index == feedback.correctChoice { border = Design.Color.success; color = Design.Color.success.withAlphaComponent(0.12) }
            else if index == feedback.selectedChoice { border = Design.Color.error; color = Design.Color.error.withAlphaComponent(0.12) }
        } else if selected {
            border = Design.Color.accent
            color = Design.Color.highlight
        }
        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.backgroundColor = color
        button.layer.cornerRadius = 14
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = selected || feedback != nil ? 2 : 1
        button.layer.borderColor = border.cgColor
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        // Stays enabled after the answer so its text keeps full contrast; the presenter ignores a pick once checked.
        button.accessibilityIdentifier = "life_choice_\(index)"
        button.accessibilityTraits = selected ? [.button, .selected] : .button
        button.addAction(UIAction { [weak self] _ in
            self?.focusIdentifier = "life_choice_\(index)"
            self?.presenter.selectChoice(index)
        }, for: .primaryActionTriggered)
        return button
    }

    // MARK: Save

    private func saveViews(_ save: LifeSaveState) -> [UIView] {
        var views: [UIView] = [eyebrow(save.header)]
        let locked: Bool = { if case .saved = save.status { return true } else if save.status == .saving { return true } else { return false } }()
        let rows = save.rows.map { row -> UIView in
            let control = LifeWordRow()
            control.configure(row, enabled: !locked)
            control.accessibilityIdentifier = "life_save_word_\(row.id)"
            control.addAction(UIAction { [weak self] _ in
                self?.focusIdentifier = "life_save_word_\(row.id)"
                self?.presenter.toggleWord(id: row.id)
            }, for: .touchUpInside)
            return control
        }
        let list = UIStackView(arrangedSubviews: rows)
        list.axis = .vertical
        views.append(card([list]))

        let deckRow = TodayRowView()
        deckRow.configure(title: save.deckLabel, value: save.deckName)
        deckRow.accessibilityIdentifier = "life_deck_row"
        deckRow.isEnabled = !locked
        deckRow.addAction(UIAction { [weak self] _ in
            self?.focusIdentifier = "life_deck_row"
            self?.presenter.chooseDeck()
        }, for: .touchUpInside)
        views.append(deckRow)

        switch save.status {
        case .idle: break
        case .saving:
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            let row = UIStackView(arrangedSubviews: [spinner, label(NSLocalizedString("Saving…", comment: ""), role: .reading)])
            row.spacing = Design.Spacing.s
            views.append(row)
        case .failed(let message):
            let failure = statusRow(symbol: "exclamationmark.triangle.fill", title: NSLocalizedString("Couldn't save", comment: ""), detail: message, color: Design.Color.error)
            failure.accessibilityIdentifier = "life_save_error"
            views.append(failure)
        case .saved(let message):
            let done = statusRow(symbol: "checkmark.circle.fill", title: NSLocalizedString("Saved", comment: ""), detail: message, color: Design.Color.success)
            done.accessibilityIdentifier = "life_save_done"
            views.append(done)
        }

        views.append(primaryButton(save.primaryTitle, id: "life_save_primary", enabled: save.primaryEnabled) { [weak self] in self?.presenter.saveWords() })
        if let secondary = save.secondaryTitle {
            views.append(secondaryButton(secondary, id: "life_save_skip") { [weak self] in self?.presenter.skipSaving() })
        }
        return views
    }

    // MARK: Done

    private func doneViews(_ done: LifeDoneState) -> [UIView] {
        let title = label(done.title, role: .display, traits: .header)
        title.accessibilityIdentifier = "life_done_title"
        var views: [UIView] = [title]
        let exercise = statusRow(symbol: "checkmark.circle.fill", title: done.exerciseTitle, detail: done.exerciseDetail, color: Design.Color.success)
        exercise.accessibilityIdentifier = "life_done_exercise"
        views.append(exercise)
        let saved = done.saveResult == .saved
        let save = statusRow(symbol: saved ? "checkmark.circle.fill" : "minus.circle.fill", title: done.saveTitle, detail: done.saveDetail,
                             color: saved ? Design.Color.success : Design.Color.warning)
        save.accessibilityIdentifier = "life_done_save"
        views.append(save)
        if done.canReviewCards {
            views.append(primaryButton(NSLocalizedString("Study these cards", comment: ""), id: "life_done_review") { [weak self] in self?.presenter.reviewSavedCards() })
            views.append(secondaryButton(NSLocalizedString("Back to Today", comment: ""), id: "life_done_back") { [weak self] in self?.presenter.finish() })
        } else {
            views.append(primaryButton(NSLocalizedString("Back to Today", comment: ""), id: "life_done_back") { [weak self] in self?.presenter.finish() })
        }
        return views
    }
}

/// A word the learner may save: a checkbox, the word with its reading, and its meaning.
final class LifeWordRow: UIControl {
    private let box = UIImageView()
    private let wordLabel = UILabel()
    private let meaningLabel = UILabel()
    private let separator = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        box.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title2)
        box.setContentHuggingPriority(.required, for: .horizontal)
        wordLabel.apply(.headword)
        meaningLabel.apply(.reading)
        let texts = UIStackView(arrangedSubviews: [wordLabel, meaningLabel])
        texts.axis = .vertical
        texts.spacing = 2
        let row = UIStackView(arrangedSubviews: [box, texts])
        row.alignment = .center
        row.spacing = Design.Spacing.m
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = Design.Color.separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        addSubview(separator)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.s),
            row.bottomAnchor.constraint(equalTo: separator.topAnchor, constant: -Design.Spacing.s),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        isAccessibilityElement = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(_ row: LifeSaveRow, enabled: Bool) {
        box.image = UIImage(systemName: row.isSelected ? "checkmark.square.fill" : "square")
        box.tintColor = row.isSelected ? Design.Color.accent : Design.Color.textSecondary
        wordLabel.text = row.reading.isEmpty ? row.japanese : "\(row.japanese)  \(row.reading)"
        meaningLabel.text = row.meaning
        isEnabled = enabled
        accessibilityLabel = "\(row.japanese), \(row.reading), \(row.meaning)"
        accessibilityTraits = row.isSelected ? [.button, .selected] : .button
        alpha = enabled ? 1 : 0.7
    }
}

/// Keeps the source popover a popover on iPhone instead of a sheet.
private final class SourcePopoverStyle: NSObject, UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle { .none }
}
