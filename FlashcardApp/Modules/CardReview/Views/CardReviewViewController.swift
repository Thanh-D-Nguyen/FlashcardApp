import UIKit

/// Reviewing the cards that are due: one large card (tap to flip), then four ratings. The only primary control is "Show answer";
/// the ratings appear once there is something to judge. Colour is never the only signal: every rating has an icon and a word.
final class CardReviewViewController: BaseViewController, CardReviewViewInterface {
    var presenter: CardReviewPresenterInterface!

    private let progressLabel = UILabel()
    private let stateLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let cardView = StudyCardView()
    private let stateView = StateView()
    private let summaryView = ReviewSummaryView()
    private let showAnswerButton = PressableButton(configuration: Design.Button.primary(title: NSLocalizedString("Show answer", comment: "")))
    private let ratingGrid = UIStackView()
    /// The multiple-choice answers (K-07); shown only while the server supplied a question and the learner has not answered it.
    private let choiceStack = UIStackView()
    private let choiceFeedbackLabel = UILabel()
    private let failureView = ReviewFailureView()
    private let bottomStack = UIStackView()
    private var cardMinHeight: NSLayoutConstraint!
    private var state = CardReviewState()
    private lazy var closeItem = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), primaryAction: UIAction { [weak self] _ in self?.presenter.close() })
    private var isSoundEnabled: Bool { UserDefaultsPreferences.shared.isSoundEnabled }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter.viewWillDisappear()
        // The gesture belongs to the navigation controller, which other screens share: hand it back.
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cardMinHeight.constant = max(240, scrollView.bounds.height - Design.Spacing.xs)
    }

    func subscribe() {}

    // MARK: Layout

    func setupUI() {
        view.backgroundColor = Design.Color.background
        title = NSLocalizedString("Review", comment: "Spaced-repetition review screen title")
        navigationItem.largeTitleDisplayMode = .never
        // "Done" is the one way out (the back arrow would be a second, identical one).
        navigationItem.hidesBackButton = true
        closeItem.accessibilityIdentifier = "review_close"
        navigationItem.rightBarButtonItem = closeItem

        progressLabel.apply(.figure)
        progressLabel.textColor = Design.Color.textSecondary
        progressLabel.accessibilityIdentifier = "review_progress"
        stateLabel.apply(.figure)
        stateLabel.textAlignment = .right
        stateLabel.accessibilityIdentifier = "review_state"
        stateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        progressView.progressTintColor = Design.Color.accent
        progressView.trackTintColor = Design.Color.highlight
        progressView.isAccessibilityElement = false
        let counts = UIStackView(arrangedSubviews: [progressLabel, stateLabel])
        counts.alignment = .firstBaseline
        counts.spacing = Design.Spacing.m
        let header = UIStackView(arrangedSubviews: [counts, progressView])
        header.axis = .vertical
        header.spacing = Design.Spacing.s
        header.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.contentInsetAdjustmentBehavior = .never
        contentStack.axis = .vertical
        contentStack.spacing = Design.Spacing.l
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        [cardView, summaryView].forEach(contentStack.addArrangedSubview)
        scrollView.addSubview(contentStack)

        showAnswerButton.accessibilityIdentifier = "review_show_answer"
        showAnswerButton.enableAdaptiveCornerStyle()
        showAnswerButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        showAnswerButton.addAction(UIAction { [weak self] _ in self?.presenter.flip() }, for: .primaryActionTriggered)
        configureRatings()
        failureView.onRetry = { [weak self] in self?.presenter.retryRating() }
        failureView.onSkip = { [weak self] in self?.presenter.skipCard() }
        bottomStack.axis = .vertical
        bottomStack.spacing = Design.Spacing.m
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        choiceStack.axis = .vertical
        choiceStack.spacing = Design.Spacing.s
        choiceStack.isHidden = true
        choiceStack.accessibilityLabel = NSLocalizedString("Pick the meaning", comment: "Accessibility label of the group of multiple-choice answers in review")
        choiceStack.accessibilityContainerType = .semanticGroup
        choiceFeedbackLabel.apply(.reading)
        choiceFeedbackLabel.textAlignment = .center
        choiceFeedbackLabel.numberOfLines = 0
        choiceFeedbackLabel.isHidden = true
        choiceFeedbackLabel.accessibilityIdentifier = "review_choice_feedback"
        [failureView, choiceStack, showAnswerButton, choiceFeedbackLabel, ratingGrid].forEach(bottomStack.addArrangedSubview)

        stateView.translatesAutoresizingMaskIntoConstraints = false
        [header, scrollView, bottomStack, stateView].forEach(view.addSubview)
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
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter),
            bottomStack.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            bottomStack.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            bottomStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Design.Spacing.s),
            stateView.topAnchor.constraint(equalTo: view.topAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cardMinHeight
        ])
        cardView.speakButton.addAction(UIAction { [weak self] _ in self?.presenter.speakCurrent() }, for: .primaryActionTriggered)
        cardView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(flipTapped)))
        cardView.accessibilityIdentifier = "review_card"
        summaryView.onContinue = { [weak self] in self?.presenter.reloadBatch() }
        summaryView.onDone = { [weak self] in self?.presenter.close() }
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: CardReviewViewController, _) in
            controller.updateRatingAxis()
        }
        updateRatingAxis()
    }

    private let ratingRows = [UIStackView(), UIStackView()]

    private func configureRatings() {
        ratingGrid.axis = .vertical
        ratingGrid.spacing = Design.Spacing.s
        // The four choices carry the same weight and one accent: they differ by word and icon, the way the Study screen's own rating does,
        // so the rating is not nudged by a traffic-light colour.
        let items: [(ReviewRating, String, String)] = [
            (.again, NSLocalizedString("Again", comment: "Review rating: forgot the card"), "arrow.counterclockwise"),
            (.hard, NSLocalizedString("Hard", comment: "Review rating"), "tortoise"),
            (.good, NSLocalizedString("Good", comment: "Review rating"), "checkmark"),
            (.easy, NSLocalizedString("Easy", comment: "Review rating"), "hare")
        ]
        for (index, row) in ratingRows.enumerated() {
            row.spacing = Design.Spacing.s
            row.distribution = .fillEqually
            for (rating, title, symbol) in items[(index * 2)..<(index * 2 + 2)] {
                let button = Self.makeRatingButton(title: title, symbol: symbol, identifier: "review_rate_\(rating.rawValue)")
                button.addAction(UIAction { [weak self] _ in self?.presenter.rate(rating) }, for: .primaryActionTriggered)
                row.addArrangedSubview(button)
            }
            ratingGrid.addArrangedSubview(row)
        }
    }

    /// Two by two normally; one column at accessibility sizes so each word keeps its full width.
    private func updateRatingAxis() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        ratingRows.forEach { $0.axis = large ? .vertical : .horizontal }
    }

    private static func makeRatingButton(title: String, symbol: String, identifier: String) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.buttonSize = .large
        configuration.baseBackgroundColor = Design.Color.surface
        configuration.baseForegroundColor = Design.Color.textPrimary
        configuration.background.strokeColor = Design.Color.accent.withAlphaComponent(0.38)
        configuration.background.strokeWidth = 1.5
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = Design.Spacing.s
        configuration.imageColorTransformer = UIConfigurationColorTransformer { _ in Design.Color.accent }
        var text = AttributedString(title)
        text.font = UIFont.preferredFont(forTextStyle: .headline)
        configuration.attributedTitle = text
        let button = PressableButton(configuration: configuration)
        button.enableAdaptiveCornerStyle()
        button.accessibilityIdentifier = identifier
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        return button
    }

    // MARK: Rendering

    @objc private func flipTapped() { presenter.flip() }

    /// Options are offered before the answer; once one is picked the card is up and only the feedback line and the four ratings remain.
    private func renderChoice(_ newState: CardReviewState, previous: CardReviewState) {
        let isCard = newState.screen == .card
        let flipped = newState.card?.isFlipped ?? false
        let choice = newState.choice
        let asking = isCard && !flipped && newState.failure == nil && choice != nil && choice?.selectedIndex == nil
        if choice?.options != previous.choice?.options || choiceStack.arrangedSubviews.count != (choice?.options.count ?? 0) {
            choiceStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for (index, option) in (choice?.options ?? []).enumerated() {
                let button = Self.makeChoiceButton(title: option, identifier: "review_choice_\(index)")
                button.addAction(UIAction { [weak self] _ in self?.presenter.choose(optionAt: index) }, for: .primaryActionTriggered)
                choiceStack.addArrangedSubview(button)
            }
        }
        choiceStack.isHidden = !asking
        choiceStack.isUserInteractionEnabled = !newState.isSubmitting
        if asking, previous.choice == nil || !(previous.card.map { $0.front == newState.card?.front } ?? false) {
            UIAccessibility.post(notification: .layoutChanged, argument: choiceStack.arrangedSubviews.first)
        }
        let feedback: String?
        switch choice?.isCorrect {
        case .some(true): feedback = NSLocalizedString("Correct. Now rate how well you remembered it.", comment: "Shown after a right multiple-choice pick in review; the learner still chooses the rating")
        case .some(false): feedback = NSLocalizedString("Not quite. Now rate how well you remembered it.", comment: "Shown after a wrong multiple-choice pick in review; the learner still chooses the rating")
        case .none: feedback = nil
        }
        choiceFeedbackLabel.text = feedback
        choiceFeedbackLabel.isHidden = !(isCard && flipped && newState.failure == nil && feedback != nil)
        if previous.choice?.selectedIndex == nil, let feedback, choice?.selectedIndex != nil {
            UIAccessibility.post(notification: .announcement, argument: feedback)
        }
    }

    private static func makeChoiceButton(title: String, identifier: String) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .large
        configuration.buttonSize = .large
        configuration.baseBackgroundColor = Design.Color.surface
        configuration.baseForegroundColor = Design.Color.textPrimary
        configuration.background.strokeColor = Design.Color.accent.withAlphaComponent(0.38)
        configuration.background.strokeWidth = 1.5
        var text = AttributedString(title)
        text.font = UIFont.preferredFont(forTextStyle: .body)
        configuration.attributedTitle = text
        let button = PressableButton(configuration: configuration)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.lineBreakMode = .byWordWrapping
        button.accessibilityIdentifier = identifier
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        return button
    }

    func render(_ newState: CardReviewState) {
        let previous = state
        state = newState
        let isCard = newState.screen == .card
        var showsState = false
        switch newState.screen {
        case .loading:
            stateView.configure(.loading(NSLocalizedString("Loading your cards…", comment: "")))
            showsState = true
        case .failed(let message, let canRetry):
            if canRetry {
                stateView.configure(.error(message: message, retryTitle: NSLocalizedString("Try again", comment: "")),
                                    onRetry: { [weak self] in self?.presenter.reloadBatch() })
            } else {
                stateView.configure(.empty(title: message, message: nil))
            }
            showsState = true
        case .card, .finished:
            break
        }
        stateView.isHidden = !showsState
        let finished = newState.screen == .finished
        cardView.isHidden = !isCard
        summaryView.isHidden = !finished
        navigationItem.rightBarButtonItem = finished ? nil : closeItem
        // The swipe-back gesture is the same exit: not while a rating is on its way to the server.
        navigationController?.interactivePopGestureRecognizer?.isEnabled = !newState.isSubmitting
        navigationItem.rightBarButtonItem?.isEnabled = !newState.isSubmitting
        if finished { summaryView.configure(with: newState.summary) }

        let flipped = newState.card?.isFlipped ?? false
        failureView.isHidden = newState.failure == nil
        showAnswerButton.isHidden = !isCard || flipped || newState.failure != nil
        ratingGrid.isHidden = !isCard || !flipped || newState.failure != nil
        ratingGrid.isUserInteractionEnabled = !newState.isSubmitting
        ratingGrid.alpha = newState.isSubmitting ? 0.5 : 1
        if let failure = newState.failure { failureView.configure(failure) }
        renderChoice(newState, previous: previous)

        progressLabel.text = isCard ? newState.progressText : nil
        progressView.isHidden = !isCard
        progressView.setProgress(newState.progress, animated: !UIAccessibility.isReduceMotionEnabled && previous.screen == newState.screen)
        if let card = newState.card, isCard {
            stateLabel.text = newState.card?.isLeech == true
                ? card.stateLabel + " · " + NSLocalizedString("Leech", comment: "A card the learner keeps forgetting")
                : card.stateLabel
            stateLabel.textColor = card.isLeech ? Design.Color.warning : Design.Color.textSecondary
            let apply = {
                // Once the answer is up, the word that was asked stays in view beneath it: the rating judges that word.
                let asked = card.reading.isEmpty ? card.front : "\(card.front) (\(card.reading))"
                self.cardView.configure(card: StudyCardState(front: card.front, back: card.back, reading: card.reading, note: asked,
                                                              imageReference: card.picture?.reference ?? "", isFlipped: card.isFlipped,
                                                              imageCredit: card.picture?.credit ?? ""),
                                        direction: .normal, showingBack: card.isFlipped, readingVisible: true,
                                        imagesVisible: UserDefaultsStudyPreferences.shared.areImagesVisible,
                                        style: CardStyle.style(forSlug: UserDefaultsStudyPreferences.shared.cardStyleSlug))
                self.cardView.accessibilityHint = NSLocalizedString("Double-tap to flip the card", comment: "")
            }
            let isSameCard = previous.card?.front == card.front && previous.card?.back == card.back
            if isSameCard, previous.card?.isFlipped != card.isFlipped {
                if isSoundEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                let reduceMotion = UIAccessibility.isReduceMotionEnabled
                UIView.transition(with: cardView, duration: reduceMotion ? 0.15 : 0.45,
                                  options: [reduceMotion ? .transitionCrossDissolve : .transitionFlipFromRight, .allowAnimatedContent],
                                  animations: apply)
                if let text = cardView.accessibilityLabel { UIAccessibility.post(notification: .announcement, argument: text) }
            } else {
                apply()
                if !isSameCard, previous.screen == .card, previous.card != nil, !UIAccessibility.isReduceMotionEnabled {
                    contentStack.alpha = 0
                    contentStack.transform = CGAffineTransform(translationX: 36, y: 0)
                    UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                        self.contentStack.alpha = 1
                        self.contentStack.transform = .identity
                    }
                }
            }
        } else {
            stateLabel.text = nil
        }
        if previous.failure == nil, newState.failure != nil {
            if isSoundEnabled { UINotificationFeedbackGenerator().notificationOccurred(.error) }
            UIAccessibility.post(notification: .announcement, argument: newState.failure?.message)
        } else if previous.summary.total < newState.summary.total, newState.screen == .card, isSoundEnabled {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        if previous.screen != .finished, finished {
            UIAccessibility.post(notification: .screenChanged, argument: summaryView)
        }
    }
}

/// A rating the server did not confirm. The learner chooses: try again, or leave the card (it stays due).
final class ReviewFailureView: UIStackView {
    var onRetry: (() -> Void)?
    var onSkip: (() -> Void)?

    private let messageLabel = UILabel()
    private let warningLabel = UILabel()
    private let retryButton = UIButton(configuration: Design.Button.primary(title: NSLocalizedString("Try again", comment: "")))
    private let skipButton = UIButton(configuration: .plain())

    override init(frame: CGRect) {
        super.init(frame: frame)
        axis = .vertical
        spacing = Design.Spacing.s
        messageLabel.apply(.reading)
        messageLabel.textColor = Design.Color.error
        messageLabel.textAlignment = .center
        messageLabel.accessibilityIdentifier = "review_failure_message"
        warningLabel.apply(.metadata)
        warningLabel.textAlignment = .center
        warningLabel.text = NSLocalizedString("The connection broke while sending. This rating may already have been saved.", comment: "")
        retryButton.accessibilityIdentifier = "review_retry"
        retryButton.enableAdaptiveCornerStyle()
        retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        retryButton.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .primaryActionTriggered)
        skipButton.configuration?.title = NSLocalizedString("Skip this card", comment: "Leave a card that could not be rated; it stays due")
        skipButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        skipButton.accessibilityIdentifier = "review_skip"
        skipButton.addAction(UIAction { [weak self] _ in self?.onSkip?() }, for: .primaryActionTriggered)
        [messageLabel, warningLabel, retryButton, skipButton].forEach(addArrangedSubview)
    }

    @available(*, unavailable) required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(_ failure: CardReviewState.Failure) {
        messageLabel.text = failure.message
        warningLabel.isHidden = !failure.outcomeUnknown
    }
}

/// End of a batch: how it went at a glance (one figure, the four ratings in a row, two facts) and the next step. No table: the numbers
/// are few enough to read without a rule under each.
final class ReviewSummaryView: UIView {
    var onContinue: (() -> Void)?
    var onDone: (() -> Void)?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let figureLabel = UILabel()
    private let figureCaption = UILabel()
    private let ratings = UIStackView()
    private let facts = UIStackView()
    private let continueButton = PressableButton(configuration: Design.Button.primary(title: NSLocalizedString("Review more", comment: "")))
    private let doneButton = PressableButton(configuration: .plain())

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.apply(.headword)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header
        subtitleLabel.apply(.reading)
        subtitleLabel.textAlignment = .center
        figureLabel.apply(.heroFigure)
        figureLabel.textColor = Design.Color.accent
        figureLabel.textAlignment = .center
        figureLabel.adjustsFontSizeToFitWidth = true
        figureLabel.minimumScaleFactor = 0.5
        figureCaption.apply(.metadata)
        figureCaption.textAlignment = .center
        ratings.distribution = .fillEqually
        ratings.spacing = Design.Spacing.s
        facts.axis = .vertical
        facts.spacing = Design.Spacing.m
        continueButton.accessibilityIdentifier = "review_continue"
        continueButton.enableAdaptiveCornerStyle()
        continueButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        continueButton.addAction(UIAction { [weak self] _ in self?.onContinue?() }, for: .primaryActionTriggered)
        doneButton.accessibilityIdentifier = "review_done"
        doneButton.enableAdaptiveCornerStyle()
        doneButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        doneButton.addAction(UIAction { [weak self] _ in self?.onDone?() }, for: .primaryActionTriggered)

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, figureLabel, figureCaption, ratings, facts, continueButton, doneButton])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.setCustomSpacing(Design.Spacing.s, after: titleLabel)
        stack.setCustomSpacing(Design.Spacing.xl, after: subtitleLabel)
        stack.setCustomSpacing(Design.Spacing.xl, after: figureCaption)
        stack.setCustomSpacing(Design.Spacing.xl, after: ratings)
        stack.setCustomSpacing(Design.Spacing.xl, after: facts)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.xl),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.l),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        accessibilityIdentifier = "review_summary"
        updateAxis()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: ReviewSummaryView, _) in view.updateAxis() }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Side by side normally; stacked at accessibility sizes so each word keeps its full width.
    private func updateAxis() {
        ratings.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
    }

    func configure(with summary: ReviewSummary) {
        let empty = summary.total == 0 && summary.skipped == 0
        titleLabel.text = empty ? NSLocalizedString("All caught up", comment: "") : NSLocalizedString("Session complete", comment: "")
        subtitleLabel.text = empty
            ? NSLocalizedString("No cards are due right now. Come back later.", comment: "")
            : String.localizedStringWithFormat(NSLocalizedString("You reviewed %lld cards.", comment: ""), summary.total)
        let rated = summary.total > 0
        figureLabel.isHidden = !rated
        figureCaption.isHidden = !rated
        ratings.isHidden = !rated
        figureLabel.text = summary.accuracy.formatted(.percent.precision(.fractionLength(0)).locale(AppLanguage.current.locale))
        figureCaption.text = NSLocalizedString("remembered", comment: "Caption under the share of cards remembered")

        ratings.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (title, count) in [(NSLocalizedString("Again", comment: ""), summary.again), (NSLocalizedString("Hard", comment: ""), summary.hard),
                               (NSLocalizedString("Good", comment: ""), summary.good), (NSLocalizedString("Easy", comment: ""), summary.easy)] {
            ratings.addArrangedSubview(Self.makeCount(title: title, count: count))
        }

        facts.arrangedSubviews.forEach { $0.removeFromSuperview() }
        var entries: [(String, String)] = []
        if rated {
            entries.append((NSLocalizedString("Longest streak", comment: ""), "\(summary.longestStreak)"))
            entries.append((NSLocalizedString("Time", comment: ""), Self.format(summary.duration)))
        }
        if summary.skipped > 0 { entries.append((NSLocalizedString("Skipped", comment: ""), "\(summary.skipped)")) }
        entries.forEach { facts.addArrangedSubview(Self.makeFact(title: $0.0, value: $0.1)) }
        facts.isHidden = entries.isEmpty

        continueButton.isHidden = !summary.mayHaveMore
        // With nothing more to review, finishing is the one action: make it the solid button.
        let title = NSLocalizedString("Done", comment: "")
        doneButton.configuration = summary.mayHaveMore ? .plain() : Design.Button.primary(title: title)
        doneButton.configuration?.title = title
        isAccessibilityElement = false
    }

    private static func format(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.calendar = {
            var calendar = Calendar.current
            calendar.locale = AppLanguage.current.locale
            return calendar
        }()
        return formatter.string(from: max(duration, 1)) ?? ""
    }

    /// One of the four ratings: its count large, its word small beneath.
    private static func makeCount(title: String, count: Int) -> UIView {
        let number = UILabel()
        number.apply(.headword)
        number.text = count.formatted(.number.locale(AppLanguage.current.locale))
        number.textAlignment = .center
        number.isAccessibilityElement = false
        let label = UILabel()
        label.apply(.metadata)
        label.text = title
        label.textAlignment = .center
        label.isAccessibilityElement = false
        let stack = UIStackView(arrangedSubviews: [number, label])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.xs
        stack.isAccessibilityElement = true
        stack.accessibilityLabel = "\(title), \(count)"
        return stack
    }

    private static func makeFact(title: String, value: String) -> UIView {
        let titleLabel = UILabel()
        titleLabel.apply(.reading)
        titleLabel.text = title
        titleLabel.numberOfLines = 0
        let valueLabel = UILabel()
        valueLabel.apply(.figure)
        valueLabel.text = value
        valueLabel.textAlignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        row.spacing = Design.Spacing.m
        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(title), \(value)"
        return row
    }
}
