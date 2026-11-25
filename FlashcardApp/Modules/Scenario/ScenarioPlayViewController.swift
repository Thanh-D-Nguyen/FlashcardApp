import UIKit

/// One situation: what is happening, the phrases to choose from, and the verdict. Content is solid surfaces on the paper background;
/// glass belongs to the system bars only.
final class ScenarioPlayViewController: BaseVC, ScenarioPlayViewInterface {
    var presenter: ScenarioPlayPresenterInterface!

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let stateView = StateView()
    private var lastKey = ""

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
    }

    private func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "scenario_play_screen"
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)
        stateView.translatesAutoresizingMaskIntoConstraints = false
        stateView.isHidden = true
        view.addSubview(stateView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
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

    // MARK: ScenarioPlayViewInterface

    func render(_ state: ScenarioPlayState) {
        loadViewIfNeeded()
        title = state.title
        let key: String
        let content: [UIView]?
        switch state.screen {
        case .loading:
            stateView.configure(.loading(NSLocalizedString("Loading the situation…", comment: "")))
            (key, content) = ("loading", nil)
        case .failed(let message, let canRetry):
            if canRetry {
                stateView.configure(.error(message: message, retryTitle: NSLocalizedString("Try again", comment: ""))) { [weak self] in self?.presenter.retryLoad() }
            } else {
                stateView.configure(.empty(title: message, message: nil))
            }
            (key, content) = ("failed", nil)
        case .step:
            (key, content) = ("step-\(state.progressText)-\(state.feedback == nil ? "ask" : "answered")", stepViews(state))
        case .summary:
            (key, content) = ("summary", summaryViews(state))
        }
        let changed = key != lastKey
        lastKey = key
        guard let content else {
            scrollView.isHidden = true
            stateView.isHidden = false
            return
        }
        stateView.isHidden = true
        scrollView.isHidden = false
        let apply = {
            self.stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            content.forEach(self.stack.addArrangedSubview)
            self.view.layoutIfNeeded()
        }
        if changed, !UIAccessibility.isReduceMotionEnabled {
            UIView.transition(with: stack, duration: 0.2, options: .transitionCrossDissolve, animations: apply)
        } else {
            apply()
        }
        if changed {
            if key.hasSuffix("ask") || key == "summary" { scrollView.setContentOffset(CGPoint(x: 0, y: -scrollView.adjustedContentInset.top), animated: false) }
            UIAccessibility.post(notification: .screenChanged, argument: content.first)
        }
    }

    // MARK: Building blocks

    private func label(_ text: String, role: Design.TextRole, color: UIColor? = nil) -> UILabel {
        let label = UILabel()
        label.apply(role)
        label.text = text
        if let color { label.textColor = color }
        return label
    }

    private func card(_ views: [UIView], spacing: CGFloat = Design.Spacing.xs, tint: UIColor? = nil) -> UIView {
        let container = UIView()
        if let tint {
            container.applyCardSurface(radius: Design.Radius.card,
                                       background: Design.Color.statusFill(tint),
                                       borderColor: tint.withAlphaComponent(0.35))
        } else {
            container.applyCardSurface(radius: Design.Radius.card)
        }
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

    private func button(_ title: String, id: String, prominent: Bool, symbol: String? = nil, action: @escaping () -> Void) -> UIButton {
        let configuration = prominent
            ? Design.Button.primary(title: title, systemImage: symbol, traits: traitCollection)
            : Design.Button.secondary(title: title, systemImage: symbol, traits: traitCollection)
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = id
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        button.enableAdaptiveCornerStyle()
        button.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        return button
    }

    private func listenButton(_ text: String, id: String) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "speaker.wave.2.fill")
        configuration.title = NSLocalizedString("Listen", comment: "Plays a Japanese phrase aloud")
        configuration.imagePadding = Design.Spacing.xs
        configuration.contentInsets = .zero
        let listen = UIButton(configuration: configuration)
        listen.contentHorizontalAlignment = .leading
        listen.accessibilityIdentifier = id
        listen.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        listen.addAction(UIAction { [weak self] _ in self?.presenter.speak(text) }, for: .primaryActionTriggered)
        return listen
    }

    // MARK: Step

    private func stepViews(_ state: ScenarioPlayState) -> [UIView] {
        var views: [UIView] = []
        let progress = UIProgressView(progressViewStyle: .bar)
        progress.progress = state.progress
        progress.progressTintColor = Design.Color.accent
        progress.trackTintColor = Design.Color.separator
        progress.isAccessibilityElement = false
        let progressLabel = label(state.progressText, role: .metadata)
        progressLabel.accessibilityIdentifier = "scenario_progress"
        views += [progressLabel, progress]

        var situation: [UIView] = []
        if let speaker = state.speaker { situation.append(label(speaker, role: .eyebrow)) }
        let main = label(state.situation, role: .sentence)
        main.accessibilityIdentifier = "scenario_situation"
        situation.append(main)
        if let gloss = state.situationGloss { situation.append(label(gloss, role: .reading)) }
        views.append(card(situation, spacing: Design.Spacing.s))

        views.append(label(NSLocalizedString("Which would you say?", comment: "Prompt above the phrases to choose from"), role: .sectionTitle))
        for choice in state.choices {
            let control = ScenarioChoiceControl()
            control.configure(choice, busy: state.isBusy)
            control.addAction(UIAction { [weak self] _ in self?.presenter.choose(key: choice.key) }, for: .touchUpInside)
            views.append(control)
        }
        if let error = state.error {
            views.append(label(error, role: .metadata, color: Design.Color.error))
        }
        if let feedback = state.feedback {
            let tint = feedback.isNatural ? Design.Color.success : Design.Color.warning
            let icon = UIImageView(image: UIImage(systemName: feedback.isNatural ? "checkmark.circle.fill" : "lightbulb.fill"))
            icon.tintColor = tint
            icon.setContentHuggingPriority(.required, for: .horizontal)
            icon.isAccessibilityElement = false
            let title = label(feedback.title, role: .title, color: tint)
            let head = UIStackView(arrangedSubviews: [icon, title])
            head.spacing = Design.Spacing.s
            head.alignment = .firstBaseline
            var rows: [UIView] = [head]
            if let detail = feedback.detail { rows.append(label(detail, role: .reading)) }
            if let spoken = feedback.spokenText { rows.append(listenButton(spoken, id: "scenario_listen")) }
            let box = card(rows, spacing: Design.Spacing.s, tint: tint)
            box.accessibilityIdentifier = "scenario_feedback"
            views.append(box)
            views.append(button(state.continueTitle, id: "scenario_continue", prominent: true) { [weak self] in self?.presenter.advance() })
            if state.canChooseAgain {
                views.append(button(NSLocalizedString("Choose again", comment: "Lets the learner pick another phrase"), id: "scenario_choose_again", prominent: false) { [weak self] in
                    self?.presenter.chooseAgain()
                })
            }
        }
        return views
    }

    // MARK: Summary

    private func summaryViews(_ state: ScenarioPlayState) -> [UIView] {
        guard let summary = state.summary else { return [] }
        var views: [UIView] = []
        let headline = label(summary.headline, role: .headword)
        headline.font = Design.TextRole.weighted(.title3, weight: .semibold)
        headline.accessibilityTraits = .header
        headline.accessibilityIdentifier = "scenario_summary_headline"
        views.append(card([label(NSLocalizedString("Result", comment: "Heading of the summary of a situation"), role: .eyebrow), headline], spacing: Design.Spacing.xs))

        views.append(label(NSLocalizedString("Phrases you chose", comment: "Recap of the phrases chosen in a situation"), role: .sectionTitle))
        for (index, row) in summary.rows.enumerated() {
            let tint = row.isNatural ? Design.Color.success : Design.Color.warning
            let mark = UIImageView(image: UIImage(systemName: row.isNatural ? "checkmark.circle.fill" : "lightbulb.fill"))
            mark.tintColor = tint
            mark.setContentHuggingPriority(.required, for: .horizontal)
            mark.isAccessibilityElement = false
            let phrase = label(row.phrase, role: .headword)
            let top = UIStackView(arrangedSubviews: [mark, phrase])
            top.spacing = Design.Spacing.s
            top.alignment = .firstBaseline
            var lines: [UIView] = [label(row.step, role: .metadata), top]
            if let meaning = row.meaning { lines.append(label(meaning, role: .reading)) }
            lines.append(label(row.isNatural ? NSLocalizedString("Natural", comment: "") : NSLocalizedString("Another phrase fits better", comment: ""),
                               role: .metadata, color: tint))
            if let spoken = row.spokenText { lines.append(listenButton(spoken, id: "scenario_recap_listen_\(index)")) }
            views.append(card(lines))
        }

        views.append(saveRow(summary.save))
        if let next = summary.nextTitle {
            views.append(button(String(format: NSLocalizedString("Next: %@", comment: "Opens the next situation, with its title"), next), id: "scenario_next",
                                prominent: true, symbol: "arrow.right") { [weak self] in self?.presenter.openNext() })
        }
        views.append(button(NSLocalizedString("Practise again", comment: ""), id: "scenario_replay", prominent: summary.nextTitle == nil, symbol: "arrow.counterclockwise") {
            [weak self] in self?.presenter.replay()
        })
        views.append(button(NSLocalizedString("Back to situations", comment: ""), id: "scenario_done", prominent: false) { [weak self] in self?.presenter.close() })
        return views
    }

    private func saveRow(_ save: ScenarioSummaryState.Save) -> UIView {
        switch save {
        case .saving:
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            let row = UIStackView(arrangedSubviews: [spinner, label(NSLocalizedString("Saving to your account…", comment: ""), role: .metadata)])
            row.spacing = Design.Spacing.s
            row.alignment = .center
            row.accessibilityIdentifier = "scenario_save_status"
            return row
        case .saved:
            let icon = UIImageView(image: UIImage(systemName: "checkmark.icloud"))
            icon.tintColor = Design.Color.success
            icon.setContentHuggingPriority(.required, for: .horizontal)
            icon.isAccessibilityElement = false
            let row = UIStackView(arrangedSubviews: [icon, label(NSLocalizedString("Saved to your account", comment: ""), role: .metadata)])
            row.spacing = Design.Spacing.s
            row.alignment = .center
            row.accessibilityIdentifier = "scenario_save_status"
            return row
        case .failed(let message):
            let retry = button(NSLocalizedString("Try saving again", comment: ""), id: "scenario_retry_save", prominent: false) { [weak self] in self?.presenter.retrySave() }
            let box = card([label(NSLocalizedString("Couldn't save this result", comment: ""), role: .title, color: Design.Color.error),
                            label(message, role: .metadata), retry], spacing: Design.Spacing.s, tint: Design.Color.error)
            box.accessibilityIdentifier = "scenario_save_status"
            return box
        }
    }
}

/// A phrase the learner can choose: the Japanese in reading type, its meaning below, and a mark once it has been checked.
final class ScenarioChoiceControl: UIControl {
    private let phrase = UILabel()
    private let meaning = UILabel()
    private let mark = UIImageView()
    private var currentBorderColor: UIColor = Design.Color.border

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Design.Color.surface
        layer.cornerRadius = Design.Radius.control
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.5
        observeAdaptiveBorder { [weak self] in self?.currentBorderColor ?? Design.Color.border }
        phrase.apply(.headword)
        meaning.apply(.reading)
        mark.setContentHuggingPriority(.required, for: .horizontal)
        mark.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        mark.isAccessibilityElement = false
        let text = UIStackView(arrangedSubviews: [phrase, meaning])
        text.axis = .vertical
        text.spacing = Design.Spacing.xs
        let row = UIStackView(arrangedSubviews: [text, mark])
        row.spacing = Design.Spacing.m
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: Design.Spacing.m),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Design.Spacing.m),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Design.Spacing.l),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Design.Spacing.l),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 64)
        ])
        isAccessibilityElement = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }

    func configure(_ choice: ScenarioChoiceState, busy: Bool) {
        phrase.text = choice.title
        meaning.text = choice.subtitle
        meaning.isHidden = choice.subtitle == nil
        isEnabled = choice.isEnabled && !busy
        accessibilityIdentifier = "scenario_choice_\(choice.key)"
        accessibilityLabel = [choice.title, choice.subtitle].compactMap { $0 }.joined(separator: ". ")
        accessibilityTraits = choice.isEnabled ? .button : [.button, .notEnabled]
        switch choice.mark {
        case .none:
            mark.isHidden = true
            backgroundColor = Design.Color.surface
            currentBorderColor = Design.Color.border
            alpha = choice.isEnabled ? 1 : 0.55
        case .natural:
            mark.image = UIImage(systemName: "checkmark.circle.fill")
            mark.tintColor = Design.Color.success
            mark.isHidden = false
            backgroundColor = Design.Color.statusFill(Design.Color.success)
            currentBorderColor = Design.Color.success
            accessibilityValue = NSLocalizedString("Natural", comment: "")
            accessibilityTraits.insert(.selected)
        case .other:
            mark.image = UIImage(systemName: "lightbulb.fill")
            mark.tintColor = Design.Color.warning
            mark.isHidden = false
            backgroundColor = Design.Color.statusFill(Design.Color.warning)
            currentBorderColor = Design.Color.warning
            accessibilityValue = NSLocalizedString("Another phrase fits better", comment: "")
            accessibilityTraits.insert(.selected)
        }
        layer.borderColor = currentBorderColor.resolvedColor(with: traitCollection).cgColor
    }
}
