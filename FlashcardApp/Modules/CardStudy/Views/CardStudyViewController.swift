import UIKit

/// Tactile feedback for flipping a card and answering a quiz question. Follows the Settings switch for sound and
/// haptics, which was stored but unused until now.
private struct StudyHaptics {
    let isEnabled: () -> Bool

    func flip() {
        guard isEnabled() else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// A self-rating was saved.
    func rated() {
        guard isEnabled() else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// An answer could not be saved; fires once when that happens, not on every redraw.
    func saveFailed() {
        guard isEnabled() else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    func answered(correct: Bool) {
        guard isEnabled() else { return }
        UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
    }
}

/// Studying one deck: a single large card (tap to flip, swipe or use the buttons to move), or a multiple-choice
/// quiz. Chrome is minimal: the progress line, one primary control and a menu for everything optional.
final class CardStudyViewController: BaseViewController, CardStudyViewInterface {
    var presenter: CardStudyPresenterInterface!

    private let progressLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let cardView = StudyCardView()
    private let examplesView = StudyExamplesView()
    private let optionsStack = UIStackView()
    /// Typing mode (K-09): the learner types the reading in kana, then the app checks it.
    private let typingStack = UIStackView()
    private let typingField = UITextField()
    private let typingFeedback = UILabel()
    private let summaryView = StudySummaryView()
    private let controls = UIStackView()
    private let navButtonsRow = UIStackView()
    private let navSpacer = UIView()
    private let bottomStack = UIStackView()
    private let ratingView = StudyRatingView()
    private let failureView = StudySaveFailureView()
    private let savedLabel = UILabel()
    private let hintLabel = UILabel()
    private let statusLabel = UILabel()
    private lazy var leaveButton: UIBarButtonItem = {
        let item = UIBarButtonItem(title: NSLocalizedString("Leave session", comment: ""), primaryAction: UIAction { [weak self] _ in self?.presenter.leaveSession() })
        item.accessibilityIdentifier = "study_leave"
        return item
    }()
    private let previousButton = UIButton(configuration: .glass())
    private let nextButton = UIButton(configuration: .glass())
    // The one primary action is a solid accent capsule (readable in both appearances); only the secondary controls are glass.
    private let primaryButton = UIButton(configuration: Design.Button.primary(title: ""))
    private var cardMinHeight: NSLayoutConstraint!
    private var state: CardStudyState?
    private let haptics = StudyHaptics(isEnabled: { UserDefaultsPreferences.shared.isSoundEnabled })

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        subscribe()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        presenter.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter.viewWillDisappear()
        // The gesture belongs to the navigation controller, which other screens share: hand it back.
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    func subscribe() {}

    func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu())
        navigationItem.rightBarButtonItem?.accessibilityLabel = NSLocalizedString("Study options", comment: "")
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "study_options"

        progressLabel.apply(.figure)
        progressLabel.font = Design.TextRole.figure.font
        progressLabel.textColor = Design.Color.textSecondary
        progressLabel.numberOfLines = 1
        progressLabel.accessibilityIdentifier = "study_progress"
        progressView.progressTintColor = Design.Color.accent
        progressView.trackTintColor = Design.Color.highlight
        progressView.isAccessibilityElement = false
        savedLabel.apply(.figure)
        savedLabel.font = Design.TextRole.figure.font
        savedLabel.textColor = Design.Color.accent
        savedLabel.textAlignment = .right
        savedLabel.accessibilityIdentifier = "study_saved"
        let counts = UIStackView(arrangedSubviews: [progressLabel, savedLabel])
        counts.alignment = .firstBaseline
        counts.spacing = Design.Spacing.m
        savedLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let header = UIStackView(arrangedSubviews: [counts, progressView])
        header.axis = .vertical
        header.spacing = Design.Spacing.s
        header.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        contentStack.axis = .vertical
        contentStack.spacing = Design.Spacing.l
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        optionsStack.axis = .vertical
        optionsStack.spacing = Design.Spacing.m
        for label in [hintLabel, statusLabel] {
            label.apply(.metadata)
            label.textAlignment = .center
            label.isHidden = true
        }
        hintLabel.textColor = Design.Color.warning
        hintLabel.accessibilityIdentifier = "study_hint"
        statusLabel.accessibilityIdentifier = "study_save_status"
        configureTyping()
        [cardView, hintLabel, statusLabel, typingStack, examplesView, optionsStack, summaryView].forEach(contentStack.addArrangedSubview)
        scrollView.addSubview(contentStack)

        configureControls()
        bottomStack.axis = .vertical
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        [controls, ratingView, failureView].forEach(bottomStack.addArrangedSubview)
        [header, scrollView, bottomStack].forEach(view.addSubview)
        let margins = view.layoutMarginsGuide
        cardMinHeight = cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 320)
        cardMinHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Design.Spacing.s),
            header.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: Design.Spacing.m),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomStack.topAnchor, constant: -Design.Spacing.m),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.s),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter),
            bottomStack.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            bottomStack.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            // Follows the keyboard (and the safe area when there is none), so the Check button is never hidden by it.
            bottomStack.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -Design.Spacing.s),
            cardMinHeight
        ])
        cardView.speakButton.addAction(UIAction { [weak self] _ in self?.presenter.speakCurrent() }, for: .primaryActionTriggered)
        cardView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(flipTapped)))
        for direction in [UISwipeGestureRecognizer.Direction.left, .right] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
            swipe.direction = direction
            scrollView.addGestureRecognizer(swipe)
        }
        cardView.accessibilityIdentifier = "study_card"
        examplesView.isHidden = true
        examplesView.onSpeak = { [weak self] id in self?.presenter.speakExample(id: id) }
        examplesView.onToggle = { [weak self] expanded in self?.presenter.setExamplesExpanded(expanded) }
        examplesView.onRetry = { [weak self] in self?.presenter.retryExamples() }
        examplesView.onAdd = { [weak self] in self?.presenter.addExample() }
        examplesView.onEdit = { [weak self] id in self?.presenter.editExample(id: id) }
        examplesView.onRemove = { [weak self] id in self?.presenter.removeExample(id: id) }
        examplesView.onRestoreOriginal = { [weak self] id in self?.presenter.restoreOriginalExample(id: id) }
        examplesView.onRestoreRemoved = { [weak self] in self?.presenter.restoreRemovedExamples() }
        summaryView.onRestart = { [weak self] in self?.presenter.restart() }
        summaryView.onDone = { [weak self] in self?.navigationController?.popViewController(animated: true) }
        ratingView.isHidden = true
        failureView.isHidden = true
        ratingView.onRate = { [weak self] rating in self?.presenter.rate(rating) }
        ratingView.onSkip = { [weak self] in self?.presenter.next() }
        failureView.onRetry = { [weak self] in self?.presenter.retrySave() }
        failureView.onLeave = { [weak self] in self?.presenter.leaveSession() }
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: CardStudyViewController, _) in
            controller.updatePrimaryShape()
            controller.updateCardHeight()
        }
        updatePrimaryShape()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCardHeight()
    }

    /// At accessibility sizes, give the primary button the full width above the prev/next row so
    /// it never wraps into a tall narrow blob and the study card keeps comfortable room above it.
    private func updatePrimaryShape() {
        let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        primaryButton.configuration?.cornerStyle = Design.Button.cornerStyle(for: traitCollection)
        primaryButton.configuration?.titleAlignment = .center
        controls.arrangedSubviews.forEach { controls.removeArrangedSubview($0); $0.removeFromSuperview() }
        navButtonsRow.arrangedSubviews.forEach { navButtonsRow.removeArrangedSubview($0); $0.removeFromSuperview() }
        if isAX {
            controls.axis = .vertical
            controls.alignment = .fill
            controls.spacing = Design.Spacing.s
            navButtonsRow.axis = .horizontal
            navButtonsRow.alignment = .center
            navButtonsRow.spacing = Design.Spacing.m
            [previousButton, navSpacer, nextButton].forEach(navButtonsRow.addArrangedSubview)
            [primaryButton, navButtonsRow].forEach(controls.addArrangedSubview)
            navButtonsRow.isHidden = state?.mode != .flip
        } else {
            controls.axis = .horizontal
            controls.alignment = .center
            controls.spacing = Design.Spacing.m
            [previousButton, primaryButton, nextButton].forEach(controls.addArrangedSubview)
        }
    }

    private func updateCardHeight() {
        // Flip cards use most of the free height so the word reads large; quiz cards are as tall as their content.
        // With example sentences below it the card leaves their heading in view, so it is clear there is more to scroll to.
        let free = scrollView.bounds.height
        let peek = examplesView.isHidden ? Design.Spacing.s : 200
        cardMinHeight.constant = state?.mode != .flip ? 0 : max(240, free - peek)
    }

    private func configureControls() {
        controls.translatesAutoresizingMaskIntoConstraints = false
        navSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        previousButton.configuration?.image = UIImage(systemName: "chevron.left")
        nextButton.configuration?.image = UIImage(systemName: "chevron.right")
        previousButton.accessibilityLabel = NSLocalizedString("Previous card", comment: "")
        nextButton.accessibilityLabel = NSLocalizedString("Next card", comment: "")
        previousButton.accessibilityIdentifier = "study_previous"
        nextButton.accessibilityIdentifier = "study_skip"
        primaryButton.accessibilityIdentifier = "study_primary"
        for button in [previousButton, nextButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 56).isActive = true
            button.heightAnchor.constraint(equalToConstant: 56).isActive = true
            button.setContentHuggingPriority(.required, for: .horizontal)
        }
        primaryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        previousButton.addAction(UIAction { [weak self] _ in self?.presenter.previous() }, for: .primaryActionTriggered)
        nextButton.addAction(UIAction { [weak self] _ in self?.presenter.next() }, for: .primaryActionTriggered)
        primaryButton.addAction(UIAction { [weak self] _ in self?.primaryTapped() }, for: .primaryActionTriggered)
    }

    // MARK: Typing

    private func configureTyping() {
        typingField.borderStyle = .roundedRect
        typingField.font = Design.TextRole.meaning.font
        typingField.adjustsFontForContentSizeCategory = true
        typingField.placeholder = NSLocalizedString("Type the reading in kana", comment: "Typing mode placeholder")
        typingField.autocorrectionType = .no
        typingField.autocapitalizationType = .none
        typingField.spellCheckingType = .no
        typingField.smartDashesType = .no
        typingField.returnKeyType = .done
        typingField.clearButtonMode = .whileEditing
        typingField.accessibilityLabel = NSLocalizedString("Reading in kana", comment: "Typing mode field label")
        typingField.accessibilityHint = NSLocalizedString("Use the Japanese keyboard", comment: "Typing mode field hint")
        typingField.accessibilityIdentifier = "study_type_field"
        typingField.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        typingField.addAction(UIAction { [weak self] _ in self?.typingChanged() }, for: .editingChanged)
        typingField.addAction(UIAction { [weak self] _ in self?.primaryTapped() }, for: .primaryActionTriggered)
        typingFeedback.apply(.title)
        typingFeedback.numberOfLines = 0
        typingFeedback.accessibilityIdentifier = "study_feedback"
        typingStack.axis = .vertical
        typingStack.spacing = Design.Spacing.m
        [typingFeedback, typingField].forEach(typingStack.addArrangedSubview)
        typingStack.isHidden = true
    }

    /// The state `apply` drew last, to tell a new question from a redraw of the same one.
    private var lastApplied: CardStudyState?
    private var isTypingQuestionOpen: Bool { state?.typing != nil && state?.typing?.typed == nil }

    /// "Check answer" sends the text; once answered the same button moves on.
    private func primaryTapped() {
        if isTypingQuestionOpen {
            presenter.submit(typed: typingField.text ?? "")
        } else {
            presenter.primaryAction()
        }
    }

    private func typingChanged() {
        let hasText = !(typingField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        primaryButton.isEnabled = isTypingQuestionOpen ? hasText : (lastApplied?.isPrimaryEnabled ?? true)
    }

    private func renderTyping(_ state: CardStudyState, previous: CardStudyState?) {
        guard let typing = state.typing, state.screen == .card else {
            typingStack.isHidden = true
            typingField.resignFirstResponder()
            return
        }
        typingStack.isHidden = false
        let newQuestion = previous?.card?.front != state.card?.front || previous?.typing == nil
        if let typed = typing.typed {
            typingField.text = typed
            typingField.isUserInteractionEnabled = false
            let correct = typing.isCorrect == true
            typingFeedback.text = correct ? NSLocalizedString("Correct", comment: "")
                                          : String(format: NSLocalizedString("Not quite. The answer is %@.", comment: ""), typing.expected)
            typingFeedback.textColor = correct ? Design.Color.success : Design.Color.error
            typingFeedback.isHidden = false
            typingField.resignFirstResponder()
            if previous?.typing?.typed == nil, !newQuestion, state.review.save != .failed {
                haptics.answered(correct: correct)
                UIAccessibility.post(notification: .announcement, argument: typingFeedback.text)
            }
        } else {
            typingFeedback.isHidden = true
            typingField.isUserInteractionEnabled = true
            if newQuestion || previous?.typing?.typed != nil {
                typingField.text = ""
                // Opens the keyboard on the new question; VoiceOver users keep their own focus.
                if !UIAccessibility.isVoiceOverRunning { typingField.becomeFirstResponder() }
            }
        }
    }

    // MARK: Gestures

    @objc private func flipTapped() { presenter.flip() }

    @objc private func swiped(_ gesture: UISwipeGestureRecognizer) {
        guard state?.screen == .card else { return }
        if gesture.direction == .left { presenter.next() } else { presenter.previous() }
    }

    // MARK: CardStudyViewInterface

    func render(_ newState: CardStudyState, transition: CardStudyTransition) {
        let previous = state
        state = newState
        title = newState.deckName
        let apply = { self.apply(newState) }
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        switch transition {
        case .none:
            if let quiz = newState.quiz, let selected = quiz.selected, previous?.quiz?.selected == nil,
               previous?.card?.front == newState.card?.front, newState.review.save != .failed {
                haptics.answered(correct: selected == quiz.correct)
            }
            apply()
            announceSave(from: previous, to: newState)
        case .flip:
            haptics.flip()
            let flip: UIView.AnimationOptions = newState.style?.flip == .vertical ? .transitionFlipFromBottom : .transitionFlipFromRight
            UIView.transition(with: cardView, duration: reduceMotion ? 0.15 : 0.45,
                              options: [reduceMotion ? .transitionCrossDissolve : flip, .allowAnimatedContent],
                              animations: apply)
            announceFlip(newState)
        case .forward, .backward:
            guard previous != nil, !reduceMotion else { return apply() }
            let offset: CGFloat = transition == .forward ? 36 : -36
            apply()
            contentStack.alpha = 0
            contentStack.transform = CGAffineTransform(translationX: offset, y: 0)
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                self.contentStack.alpha = 1
                self.contentStack.transform = .identity
            }
        }
    }

    /// One signal per event, however often the screen is redrawn, posted after the screen is up to date so nothing replaces
    /// it: a failure, a saved self-rating, and a retry that worked (the quiz already announces its first result itself).
    private func announceSave(from previous: CardStudyState?, to state: CardStudyState) {
        let sameCard = previous?.card?.front == state.card?.front
        if previous?.review.save != .failed, state.review.save == .failed {
            haptics.saveFailed()
            UIAccessibility.post(notification: .announcement, argument: NSLocalizedString("Couldn't save this attempt.", comment: ""))
        } else if previous?.review.save != .saved, state.review.save == .saved, sameCard,
                  state.mode == .flip || previous?.review.save == .failed {
            haptics.rated()
            UIAccessibility.post(notification: .announcement, argument: NSLocalizedString("Saved", comment: ""))
        }
    }

    private func announceFlip(_ state: CardStudyState) {
        guard state.card != nil, let text = cardView.accessibilityLabel else { return }
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    private func apply(_ state: CardStudyState) {
        progressLabel.text = state.progressText
        progressView.setProgress(state.progress, animated: !UIAccessibility.isReduceMotionEnabled)
        navigationItem.rightBarButtonItem?.menu = makeMenu(for: state)
        let finished = state.screen == .finished
        cardView.isHidden = finished
        examplesView.configure(state: finished ? .hidden : state.examples, expanded: state.examplesExpanded)
        optionsStack.isHidden = finished || state.quiz == nil
        renderTyping(state, previous: lastApplied)
        summaryView.isHidden = !finished
        let failed = state.review.save == .failed && !finished
        controls.isHidden = finished || state.review.canRate || failed
        ratingView.isHidden = finished || !state.review.canRate
        failureView.isHidden = !failed
        progressLabel.isHidden = false
        savedLabel.text = String(format: NSLocalizedString("Saved %1$lld of %2$lld", comment: "Study header: attempts saved of cards in the session"),
                                 state.review.savedCount, state.review.total)
        applyReview(state, finished: finished)
        // While an answer is unsaved the way out is explicit, so the learner always knows what leaving costs.
        navigationItem.hidesBackButton = failed
        navigationItem.leftBarButtonItem = failed ? leaveButton : nil
        if let pop = navigationController?.interactivePopGestureRecognizer, pop.isEnabled == failed { pop.isEnabled = !failed }
        if finished {
            summaryView.configure(with: state.summary)
        } else if let card = state.card {
            let isQuiz = state.mode != .flip
            cardView.configure(card: card, direction: state.direction, showingBack: !isQuiz && card.isFlipped, isQuiz: isQuiz,
                               readingVisible: state.readingVisible, imagesVisible: state.imagesVisible, style: state.style)
            cardView.accessibilityHint = isQuiz ? nil : NSLocalizedString("Double-tap to flip the card", comment: "")
            cardView.isAccessibilityElement = true
            cardView.accessibilityCustomActions = [
                UIAccessibilityCustomAction(name: NSLocalizedString("Read aloud", comment: "")) { [weak self] _ in self?.presenter.speakCurrent(); return true },
                UIAccessibilityCustomAction(name: NSLocalizedString("Next card", comment: "")) { [weak self] _ in self?.presenter.next(); return true },
                UIAccessibilityCustomAction(name: NSLocalizedString("Previous card", comment: "")) { [weak self] _ in self?.presenter.previous(); return true }
            ]
            cardView.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }.forEach { $0.isEnabled = !isQuiz }
            renderOptions(state.quiz)
        }
        previousButton.isHidden = state.mode != .flip
        nextButton.isHidden = state.mode != .flip
        navButtonsRow.isHidden = state.mode != .flip
        previousButton.isEnabled = state.canGoBack
        primaryButton.configuration?.title = state.primaryTitle
        primaryButton.isEnabled = state.isPrimaryEnabled
        lastApplied = state
        typingChanged()
        updateCardHeight()
    }

    /// The hint notice and the save status under the card. Both state facts, in words and an icon, not only in colour.
    private func applyReview(_ state: CardStudyState, finished: Bool) {
        let answerShown = state.card?.isFlipped == true || state.quiz?.selected != nil
        // Before the answer the notice describes what is on screen, so it goes when the reading is hidden again; the hint
        // itself stays recorded and is named after the answer.
        hintLabel.isHidden = finished || !state.review.usedReadingHint || (!answerShown && !state.readingVisible)
        hintLabel.text = answerShown ? NSLocalizedString("Hint used: reading", comment: "")
                                     : NSLocalizedString("Reading shown · counts as a hint", comment: "")
        switch state.review.save {
        case .saved where !finished:
            statusLabel.attributedText = Self.statusText("checkmark", NSLocalizedString("Saved", comment: ""), Design.Color.success)
            statusLabel.isHidden = false
        case .failed where !finished:
            statusLabel.attributedText = Self.statusText("exclamationmark.triangle", NSLocalizedString("Couldn't save this attempt.", comment: ""), Design.Color.error)
            statusLabel.isHidden = false
        default:
            statusLabel.isHidden = true
        }
    }

    private static func statusText(_ symbol: String, _ text: String, _ color: UIColor) -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = UIImage(systemName: symbol)?.withTintColor(color, renderingMode: .alwaysOriginal)
        let result = NSMutableAttributedString(attachment: attachment)
        result.append(NSAttributedString(string: " " + text))
        result.addAttributes([.foregroundColor: color, .font: Design.TextRole.metadata.font.withWeight(.semibold)], range: NSRange(location: 0, length: result.length))
        return result
    }

    private func renderOptions(_ quiz: StudyQuizState?) {
        optionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let quiz else { return }
        for (index, option) in quiz.options.enumerated() {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.filled()
            configuration.title = option
            configuration.titleAlignment = .leading
            configuration.cornerStyle = .large
            configuration.background.cornerRadius = Design.Radius.control
            configuration.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.m, leading: Design.Spacing.l, bottom: Design.Spacing.m, trailing: Design.Spacing.l)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = Design.TextRole.meaning.font
                return attributes
            }
            configuration.baseForegroundColor = Design.Color.textPrimary
            configuration.baseBackgroundColor = Design.Color.surface
            configuration.background.strokeColor = Design.Color.border
            configuration.background.strokeWidth = 1
            var announcement = option
            if let selected = quiz.selected {
                if option == quiz.correct {
                    configuration.image = UIImage(systemName: "checkmark.circle.fill")
                    configuration.baseForegroundColor = Design.Color.success
                    configuration.background.strokeColor = Design.Color.success
                    configuration.background.strokeWidth = 2
                    announcement += ", " + NSLocalizedString("Correct answer", comment: "")
                } else if option == selected {
                    configuration.image = UIImage(systemName: "xmark.circle.fill")
                    configuration.baseForegroundColor = Design.Color.error
                    configuration.background.strokeColor = Design.Color.error
                    configuration.background.strokeWidth = 2
                    announcement += ", " + NSLocalizedString("Your answer, incorrect", comment: "")
                }
                configuration.imagePlacement = .trailing
                configuration.imagePadding = Design.Spacing.s
            }
            button.configuration = configuration
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
            button.contentHorizontalAlignment = .leading
            // Stays enabled after the choice (a disabled button dims its label and hides which answer was right);
            // the presenter ignores a second tap.
            button.configurationUpdateHandler = nil
            button.accessibilityLabel = announcement
            button.accessibilityIdentifier = "study_option_\(index)"
            button.addAction(UIAction { [weak self] _ in self?.presenter.select(option: option) }, for: .primaryActionTriggered)
            optionsStack.addArrangedSubview(button)
        }
        if let selected = quiz.selected {
            let correct = selected == quiz.correct
            let text = correct ? NSLocalizedString("Correct", comment: "") : String(format: NSLocalizedString("Not quite. The answer is %@.", comment: ""), quiz.correct)
            let feedback = UILabel()
            feedback.apply(.title)
            feedback.textColor = correct ? Design.Color.success : Design.Color.error
            feedback.text = text
            feedback.accessibilityIdentifier = "study_feedback"
            // Above the options so the result is visible without scrolling.
            optionsStack.insertArrangedSubview(feedback, at: 0)
            UIAccessibility.post(notification: .announcement, argument: text)
        }
    }

    // MARK: Menu

    private func makeMenu(for state: CardStudyState) -> UIMenu {
        // While an answer is unsaved these would end the run and lose it, so they are off until it is saved or left.
        let locked: UIMenuElement.Attributes = state.review.save == .failed ? .disabled : []
        let edit = UIAction(title: NSLocalizedString("Edit deck", comment: ""), image: UIImage(systemName: "pencil"), attributes: locked) { [weak self] _ in self?.presenter.edit() }
        let modes = UIMenu(title: NSLocalizedString("Mode", comment: ""), options: [.displayInline, .singleSelection], children: [
            UIAction(title: NSLocalizedString("Flip cards", comment: ""), image: UIImage(systemName: "rectangle.on.rectangle"),
                     attributes: locked, state: state.mode == .flip ? .on : .off) { [weak self] _ in self?.presenter.setMode(.flip) },
            UIAction(title: NSLocalizedString("Quiz", comment: ""), image: UIImage(systemName: "list.bullet.rectangle"),
                     attributes: state.canQuiz ? locked : .disabled, state: state.mode == .quiz ? .on : .off) { [weak self] _ in self?.presenter.setMode(.quiz) },
            UIAction(title: NSLocalizedString("Type the reading", comment: "Study mode: type the kana reading"), image: UIImage(systemName: "keyboard"),
                     attributes: state.canType ? locked : .disabled, state: state.mode == .type ? .on : .off) { [weak self] _ in self?.presenter.setMode(.type) }
        ])
        let options = UIMenu(options: .displayInline, children: [
            UIAction(title: NSLocalizedString("Shuffle", comment: ""), image: UIImage(systemName: "shuffle"), attributes: locked,
                     state: state.isShuffled ? .on : .off) { [weak self] _ in self?.presenter.setShuffled(!state.isShuffled) },
            UIAction(title: NSLocalizedString("Show reading", comment: ""), image: UIImage(systemName: "character.textbox"), state: state.readingVisible ? .on : .off) { [weak self] _ in self?.presenter.setReadingVisible(!state.readingVisible) },
            UIAction(title: NSLocalizedString("Show pictures", comment: ""), image: UIImage(systemName: "photo"),
                     attributes: state.deckHasImages ? [] : .disabled, state: state.imagesVisible ? .on : .off) { [weak self] _ in self?.presenter.setImagesVisible(!state.imagesVisible) },
            UIAction(title: NSLocalizedString("Read aloud automatically", comment: ""), image: UIImage(systemName: "speaker.wave.2"), state: state.autoSpeak ? .on : .off) { [weak self] _ in self?.presenter.setAutoSpeak(!state.autoSpeak) }
        ])
        let writing = UIAction(title: NSLocalizedString("Write the kanji", comment: "Kanji writing practice"), image: UIImage(systemName: "pencil.and.scribble")) { [weak self] _ in
            self?.presenter.writeKanji()
        }
        let appearance = UIAction(title: NSLocalizedString("Card style…", comment: ""), image: UIImage(systemName: "paintpalette")) { [weak self] _ in self?.presenter.chooseStyle() }
        appearance.accessibilityIdentifier = "study_card_style"
        let restart = UIAction(title: NSLocalizedString("Start over", comment: ""), image: UIImage(systemName: "arrow.counterclockwise"), attributes: locked) { [weak self] _ in self?.presenter.restart() }
        writing.accessibilityIdentifier = "study_write_kanji"
        return UIMenu(children: [edit, modes, options, UIMenu(options: .displayInline, children: [writing, appearance]), restart])
    }
}
