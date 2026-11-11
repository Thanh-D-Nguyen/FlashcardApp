import UIKit

/// Listen, say it, hear yourself: one example sentence of the lesson at a time.
final class ShadowingViewController: BaseViewController, ShadowingViewInterface {
    var presenter: ShadowingPresenterInterface!

    private let progressLabel = UILabel()
    private let sentenceLabel = UILabel()
    private let translationLabel = UILabel()
    private let noticeLabel = UILabel()
    private let listenButton = UIButton(configuration: .bordered())
    private let recordButton = UIButton(configuration: .borderedProminent())
    private let playButton = UIButton(configuration: .bordered())
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

    private func configure(_ button: UIButton, _ title: String, _ symbol: String, _ id: String, _ action: @escaping () -> Void) {
        button.configuration?.title = title
        button.configuration?.image = UIImage(systemName: symbol)
        button.configuration?.imagePadding = Design.Spacing.xs
        button.accessibilityIdentifier = id
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    }

    func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        title = NSLocalizedString("Shadowing", comment: "Lesson: repeat the example sentences aloud")
        progressLabel.apply(.metadata)
        sentenceLabel.apply(.headword)
        sentenceLabel.numberOfLines = 0
        sentenceLabel.textAlignment = .center
        sentenceLabel.accessibilityIdentifier = "shadowing_sentence"
        translationLabel.apply(.meaning)
        translationLabel.numberOfLines = 0
        translationLabel.textAlignment = .center
        noticeLabel.apply(.metadata)
        noticeLabel.numberOfLines = 0
        noticeLabel.accessibilityIdentifier = "shadowing_notice"
        configure(listenButton, NSLocalizedString("Listen", comment: "Shadowing"), "speaker.wave.2", "shadowing_listen") { [weak self] in self?.presenter.listen() }
        configure(recordButton, NSLocalizedString("Record", comment: "Shadowing"), "mic", "shadowing_record") { [weak self] in self?.presenter.toggleRecording() }
        configure(playButton, NSLocalizedString("Play mine", comment: "Shadowing: play the learner's recording"), "play", "shadowing_play") { [weak self] in self?.presenter.playMine() }
        configure(previousButton, NSLocalizedString("Previous", comment: ""), "chevron.left", "shadowing_previous") { [weak self] in self?.presenter.previous() }
        configure(nextButton, NSLocalizedString("Next", comment: ""), "chevron.right", "shadowing_next") { [weak self] in self?.presenter.next() }
        let navigation = UIStackView(arrangedSubviews: [previousButton, UIView(), nextButton])
        let stack = UIStackView(arrangedSubviews: [progressLabel, sentenceLabel, translationLabel, listenButton, recordButton, playButton, noticeLabel, navigation])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Design.Spacing.l),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Design.Spacing.gutter)
        ])
    }

    func render(_ state: ShadowingState) {
        progressLabel.text = state.total > 0 ? String(format: NSLocalizedString("%1$lld of %2$lld", comment: "Study progress: position of total"),
                                                       state.position + 1, state.total) : nil
        sentenceLabel.text = state.phase == .empty ? NSLocalizedString("This lesson has no example sentences.", comment: "Shadowing") : state.sentence?.japanese
        translationLabel.text = state.sentence?.translation
        noticeLabel.text = state.notice
        noticeLabel.isHidden = state.notice == nil
        let recording = state.phase == .recording
        recordButton.configuration?.title = recording ? NSLocalizedString("Stop", comment: "Shadowing: stop recording") : NSLocalizedString("Record", comment: "Shadowing")
        recordButton.configuration?.image = UIImage(systemName: recording ? "stop.fill" : "mic")
        [listenButton, recordButton].forEach { $0.isHidden = state.phase == .empty }
        listenButton.isEnabled = !recording
        playButton.isHidden = state.phase != .recorded
        previousButton.isEnabled = state.canGoBack && !recording
        nextButton.isEnabled = state.canGoForward && !recording
    }
}
