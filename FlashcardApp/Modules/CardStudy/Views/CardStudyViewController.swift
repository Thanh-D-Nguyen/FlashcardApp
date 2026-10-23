import UIKit

/// Tactile feedback for flipping a card and answering a quiz question. Follows the Settings switch for sound and
/// haptics, which was stored but unused until now.
private struct StudyHaptics {
    let isEnabled: () -> Bool

    func flip() {
        guard isEnabled() else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
    private let summaryView = StudySummaryView()
    private let controls = UIStackView()
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
        let header = UIStackView(arrangedSubviews: [progressLabel, progressView])
        header.axis = .vertical
        header.spacing = Design.Spacing.s
        header.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.contentInsetAdjustmentBehavior = .never
        contentStack.axis = .vertical
        contentStack.spacing = Design.Spacing.l
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        optionsStack.axis = .vertical
        optionsStack.spacing = Design.Spacing.m
        [cardView, examplesView, optionsStack, summaryView].forEach(contentStack.addArrangedSubview)
        scrollView.addSubview(contentStack)

        configureControls()
        [header, scrollView, controls].forEach(view.addSubview)
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
            scrollView.bottomAnchor.constraint(equalTo: controls.topAnchor, constant: -Design.Spacing.m),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter),
            controls.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            controls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Design.Spacing.s),
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

    /// A capsule turns into a blob when its title wraps at accessibility sizes; use a rounded rectangle there.
    private func updatePrimaryShape() {
        primaryButton.configuration?.cornerStyle = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .large : .capsule
    }

    private func updateCardHeight() {
        // Flip cards use most of the free height so the word reads large; quiz cards are as tall as their content.
        // With example sentences below it the card leaves their heading in view, so it is clear there is more to scroll to.
        let free = scrollView.bounds.height
        let peek = examplesView.isHidden ? Design.Spacing.xs : 200
        cardMinHeight.constant = state?.mode == .quiz ? 0 : max(240, free - peek)
    }

    private func configureControls() {
        controls.axis = .horizontal
        controls.spacing = Design.Spacing.m
        controls.alignment = .center
        controls.translatesAutoresizingMaskIntoConstraints = false
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
        primaryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        [previousButton, primaryButton, nextButton].forEach(controls.addArrangedSubview)
        previousButton.addAction(UIAction { [weak self] _ in self?.presenter.previous() }, for: .primaryActionTriggered)
        nextButton.addAction(UIAction { [weak self] _ in self?.presenter.next() }, for: .primaryActionTriggered)
        primaryButton.addAction(UIAction { [weak self] _ in self?.presenter.primaryAction() }, for: .primaryActionTriggered)
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
               previous?.card?.front == newState.card?.front {
                haptics.answered(correct: selected == quiz.correct)
            }
            apply()
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
        summaryView.isHidden = !finished
        controls.isHidden = finished
        progressLabel.isHidden = false
        if finished {
            summaryView.configure(with: state.summary)
        } else if let card = state.card {
            let isQuiz = state.mode == .quiz
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
        previousButton.isHidden = state.mode == .quiz
        nextButton.isHidden = state.mode == .quiz
        previousButton.isEnabled = state.canGoBack
        primaryButton.configuration?.title = state.primaryTitle
        primaryButton.isEnabled = state.isPrimaryEnabled
        updateCardHeight()
    }

    private func renderOptions(_ quiz: StudyQuizState?) {
        optionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let quiz else { return }
        for (index, option) in quiz.options.enumerated() {
            let button = UIButton(configuration: .gray())
            var configuration = UIButton.Configuration.gray()
            configuration.title = option
            configuration.titleAlignment = .leading
            configuration.cornerStyle = .large
            configuration.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.m, leading: Design.Spacing.l, bottom: Design.Spacing.m, trailing: Design.Spacing.l)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = Design.TextRole.meaning.font
                return attributes
            }
            configuration.baseForegroundColor = Design.Color.textPrimary
            configuration.background.backgroundColor = Design.Color.surface
            configuration.background.strokeColor = Design.Color.separator
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
        let edit = UIAction(title: NSLocalizedString("Edit deck", comment: ""), image: UIImage(systemName: "pencil")) { [weak self] _ in self?.presenter.edit() }
        let modes = UIMenu(title: NSLocalizedString("Mode", comment: ""), options: [.displayInline, .singleSelection], children: [
            UIAction(title: NSLocalizedString("Flip cards", comment: ""), image: UIImage(systemName: "rectangle.on.rectangle"), state: state.mode == .flip ? .on : .off) { [weak self] _ in self?.presenter.setMode(.flip) },
            UIAction(title: NSLocalizedString("Quiz", comment: ""), image: UIImage(systemName: "list.bullet.rectangle"),
                     attributes: state.canQuiz ? [] : .disabled, state: state.mode == .quiz ? .on : .off) { [weak self] _ in self?.presenter.setMode(.quiz) }
        ])
        let options = UIMenu(options: .displayInline, children: [
            UIAction(title: NSLocalizedString("Shuffle", comment: ""), image: UIImage(systemName: "shuffle"), state: state.isShuffled ? .on : .off) { [weak self] _ in self?.presenter.setShuffled(!state.isShuffled) },
            UIAction(title: NSLocalizedString("Show reading", comment: ""), image: UIImage(systemName: "character.textbox"), state: state.readingVisible ? .on : .off) { [weak self] _ in self?.presenter.setReadingVisible(!state.readingVisible) },
            UIAction(title: NSLocalizedString("Show pictures", comment: ""), image: UIImage(systemName: "photo"),
                     attributes: state.deckHasImages ? [] : .disabled, state: state.imagesVisible ? .on : .off) { [weak self] _ in self?.presenter.setImagesVisible(!state.imagesVisible) },
            UIAction(title: NSLocalizedString("Read aloud automatically", comment: ""), image: UIImage(systemName: "speaker.wave.2"), state: state.autoSpeak ? .on : .off) { [weak self] _ in self?.presenter.setAutoSpeak(!state.autoSpeak) }
        ])
        let appearance = UIAction(title: NSLocalizedString("Card style…", comment: ""), image: UIImage(systemName: "paintpalette")) { [weak self] _ in self?.presenter.chooseStyle() }
        appearance.accessibilityIdentifier = "study_card_style"
        let restart = UIAction(title: NSLocalizedString("Start over", comment: ""), image: UIImage(systemName: "arrow.counterclockwise")) { [weak self] _ in self?.presenter.restart() }
        return UIMenu(children: [edit, modes, options, UIMenu(options: .displayInline, children: [appearance]), restart])
    }
}

/// End of a session: what was covered (and the quiz score when there was one), with the two sensible next steps.
final class StudySummaryView: UIView {
    var onRestart: (() -> Void)?
    var onDone: (() -> Void)?

    private let icon = UIImageView(image: UIImage(systemName: "checkmark.circle"))
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let restartButton = UIButton(configuration: Design.Button.primary(title: NSLocalizedString("Study again", comment: "")))
    private let doneButton = UIButton(configuration: .plain())

    override init(frame: CGRect) {
        super.init(frame: frame)
        icon.tintColor = Design.Color.success
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .largeTitle)
        icon.isAccessibilityElement = false
        titleLabel.apply(.title)
        titleLabel.textAlignment = .center
        titleLabel.accessibilityTraits = .header
        detailLabel.apply(.meaning)
        detailLabel.textAlignment = .center
        doneButton.configuration?.title = NSLocalizedString("Done", comment: "")
        doneButton.accessibilityIdentifier = "study_done"
        restartButton.accessibilityIdentifier = "study_restart"
        restartButton.addAction(UIAction { [weak self] _ in self?.onRestart?() }, for: .primaryActionTriggered)
        doneButton.addAction(UIAction { [weak self] _ in self?.onDone?() }, for: .primaryActionTriggered)
        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, detailLabel, restartButton, doneButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Design.Spacing.m
        stack.setCustomSpacing(Design.Spacing.xl, after: detailLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.xxl),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        accessibilityIdentifier = "study_summary"
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(with summary: StudySummary) {
        titleLabel.text = NSLocalizedString("Deck complete", comment: "")
        if summary.mode == .quiz, summary.answered > 0 {
            let percent = Double(summary.correct) / Double(summary.answered)
            detailLabel.text = String(format: NSLocalizedString("%1$lld of %2$lld correct (%3$@)", comment: "Quiz result"),
                                      summary.correct, summary.answered, percent.formatted(.percent.precision(.fractionLength(0)).locale(AppLanguage.current.locale)))
        } else {
            let cards = String.localizedStringWithFormat(NSLocalizedString("%lld cards", comment: ""), summary.total)
            detailLabel.text = String(format: NSLocalizedString("You went through %@.", comment: "Flip session result; %@ is a card count"), cards)
        }
    }
}
