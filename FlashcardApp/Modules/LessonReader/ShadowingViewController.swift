import UIKit

/// Listen, say it, hear yourself: one example sentence of the lesson at a time.
final class ShadowingViewController: BaseViewController, ShadowingViewInterface {
    var presenter: ShadowingPresenterInterface!

    private let scrollView = UIScrollView()
    private let stateView = StateView()
    private let progressLabel = UILabel()
    private let sentenceCard = UIView()
    private let sentenceLabel = UILabel()
    private let translationLabel = UILabel()
    private let noticeLabel = UILabel()
    private let listenButton = UIButton(type: .system)
    private let recordButton = UIButton(type: .system)
    private let playButton = UIButton(type: .system)
    private let previousButton = UIButton(configuration: .plain())
    private let nextButton = UIButton(configuration: .plain())

    static func make(sentences: [ShadowingSentence]) -> ShadowingViewController {
        let controller = ShadowingViewController()
        let presenter = ShadowingPresenter(sentences: sentences, speech: SystemSpeechService.shared, recorder: ShadowingRecorder())
        presenter.view = controller
        controller.presenter = presenter
        controller.hidesBottomBarWhenPushed = true
        return controller
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent { presenter.leave() }
    }

    func subscribe() {}

    private func configure(_ button: UIButton, _ configuration: UIButton.Configuration, _ id: String, minHeight: CGFloat = Design.HitTarget.minimum, _ action: @escaping () -> Void) {
        button.configuration = configuration
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight).isActive = true
        button.enableAdaptiveCornerStyle()
        button.accessibilityIdentifier = id
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    }

    private func configurePlain(_ button: UIButton, _ title: String, _ symbol: String, _ id: String, _ action: @escaping () -> Void) {
        button.configuration?.title = title
        button.configuration?.image = UIImage(systemName: symbol)
        button.configuration?.imagePadding = Design.Spacing.xs
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        button.accessibilityIdentifier = id
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    }

    func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        title = NSLocalizedString("Shadowing", comment: "Lesson: repeat the example sentences aloud")
        progressLabel.apply(.metadata)
        progressLabel.textAlignment = .center
        sentenceLabel.apply(.headword)
        sentenceLabel.numberOfLines = 0
        sentenceLabel.textAlignment = .center
        sentenceLabel.accessibilityIdentifier = "shadowing_sentence"
        translationLabel.apply(.meaning)
        translationLabel.textColor = Design.Color.textSecondary
        translationLabel.numberOfLines = 0
        translationLabel.textAlignment = .center
        noticeLabel.apply(.metadata)
        noticeLabel.numberOfLines = 0
        noticeLabel.textAlignment = .center
        noticeLabel.accessibilityIdentifier = "shadowing_notice"

        sentenceCard.applyCardSurface(radius: Design.Radius.card)
        let cardStack = UIStackView(arrangedSubviews: [sentenceLabel, translationLabel])
        cardStack.axis = .vertical
        cardStack.spacing = Design.Spacing.s
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        sentenceCard.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: sentenceCard.topAnchor, constant: Design.Spacing.xl),
            cardStack.bottomAnchor.constraint(equalTo: sentenceCard.bottomAnchor, constant: -Design.Spacing.xl),
            cardStack.leadingAnchor.constraint(equalTo: sentenceCard.leadingAnchor, constant: Design.Spacing.l),
            cardStack.trailingAnchor.constraint(equalTo: sentenceCard.trailingAnchor, constant: -Design.Spacing.l)
        ])

        configure(listenButton, Design.Button.secondary(title: NSLocalizedString("Listen", comment: "Shadowing"), systemImage: "speaker.wave.2", traits: traitCollection), "shadowing_listen") { [weak self] in self?.presenter.listen() }
        configure(recordButton, Design.Button.primary(title: NSLocalizedString("Record", comment: "Shadowing"), systemImage: "mic", traits: traitCollection), "shadowing_record", minHeight: 52) { [weak self] in self?.presenter.toggleRecording() }
        configure(playButton, Design.Button.secondary(title: NSLocalizedString("Play mine", comment: "Shadowing: play the learner's recording"), systemImage: "play", traits: traitCollection), "shadowing_play") { [weak self] in self?.presenter.playMine() }
        configurePlain(previousButton, NSLocalizedString("Previous", comment: ""), "chevron.left", "shadowing_previous") { [weak self] in self?.presenter.previous() }
        configurePlain(nextButton, NSLocalizedString("Next", comment: ""), "chevron.right", "shadowing_next") { [weak self] in self?.presenter.next() }

        let navigation = UIStackView(arrangedSubviews: [previousButton, UIView(), nextButton])
        let stack = UIStackView(arrangedSubviews: [progressLabel, sentenceCard, listenButton, recordButton, playButton, noticeLabel, navigation])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.setCustomSpacing(Design.Spacing.l, after: sentenceCard)
        stack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.addSubview(stack)
        stateView.translatesAutoresizingMaskIntoConstraints = false
        stateView.isHidden = true
        view.addSubview(scrollView)
        view.addSubview(stateView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Design.Spacing.l),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter),
            stateView.topAnchor.constraint(equalTo: view.topAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    func render(_ state: ShadowingState) {
        let isEmpty = state.phase == .empty
        scrollView.isHidden = isEmpty
        stateView.isHidden = !isEmpty
        if isEmpty {
            stateView.configure(.empty(title: NSLocalizedString("This lesson has no example sentences.", comment: "Shadowing"), message: nil))
            return
        }
        progressLabel.text = state.total > 0 ? String(format: NSLocalizedString("%1$lld of %2$lld", comment: "Study progress: position of total"),
                                                       state.position + 1, state.total) : nil
        sentenceLabel.text = state.sentence?.japanese
        translationLabel.text = state.sentence?.translation
        translationLabel.isHidden = (state.sentence?.translation ?? "").isEmpty
        noticeLabel.text = state.notice
        noticeLabel.isHidden = state.notice == nil
        let recording = state.phase == .recording
        recordButton.configuration?.title = recording ? NSLocalizedString("Stop", comment: "Shadowing: stop recording") : NSLocalizedString("Record", comment: "Shadowing")
        recordButton.configuration?.image = UIImage(systemName: recording ? "stop.fill" : "mic")
        listenButton.isEnabled = !recording
        playButton.isHidden = state.phase != .recorded
        previousButton.isEnabled = state.canGoBack && !recording
        nextButton.isEnabled = state.canGoForward && !recording
    }
}
