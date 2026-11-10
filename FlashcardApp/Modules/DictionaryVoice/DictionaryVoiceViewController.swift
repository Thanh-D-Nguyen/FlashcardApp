import RxSwift
import UIKit

/// Voice search: speak Japanese, see the recognized text, correct it, then look it up. Nothing is searched until the learner asks.
final class DictionaryVoiceViewController: BaseVC, UITextViewDelegate {
    var presenter: DictionaryVoicePresenterInterface!

    private let stack = UIStackView()
    private let micButton = UIButton(type: .system)
    private let status = UILabel()
    private let detail = UILabel()
    private let transcript = UITextView()
    private let lookUpButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private var wasListening = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Design.Color.background
        title = NSLocalizedString("Voice search", comment: "")
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.presenter.close() })
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "voice_close"

        status.apply(.title)
        status.textAlignment = .center
        detail.apply(.reading)
        detail.textAlignment = .center
        transcript.font = Design.TextRole.sentence.font
        transcript.adjustsFontForContentSizeCategory = true
        transcript.backgroundColor = Design.Color.surface
        transcript.layer.cornerRadius = 12
        transcript.layer.cornerCurve = .continuous
        transcript.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        transcript.autocorrectionType = .no
        transcript.delegate = self
        transcript.accessibilityIdentifier = "voice_text"
        transcript.heightAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true

        var mic = UIButton.Configuration.filled()
        mic.cornerStyle = .capsule
        mic.buttonSize = .large
        mic.baseBackgroundColor = Design.Color.accent
        mic.baseForegroundColor = Design.Color.onAccent
        mic.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 34, weight: .regular)
        micButton.configuration = mic
        micButton.accessibilityIdentifier = "voice_mic"
        micButton.addAction(UIAction { [weak self] _ in self?.presenter.toggleListening() }, for: .touchUpInside)
        micButton.heightAnchor.constraint(equalToConstant: 88).isActive = true
        micButton.widthAnchor.constraint(equalToConstant: 88).isActive = true

        lookUpButton.configuration = Design.Button.primary(title: NSLocalizedString("Look up", comment: ""))
        lookUpButton.accessibilityIdentifier = "voice_lookup"
        lookUpButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.transcript.resignFirstResponder()
            self.presenter.lookUp(self.transcript.text)
        }, for: .touchUpInside)

        var settings = UIButton.Configuration.gray()
        settings.title = NSLocalizedString("Open Settings", comment: "")
        settings.cornerStyle = .capsule
        settings.baseForegroundColor = Design.Color.accent
        settingsButton.configuration = settings
        settingsButton.accessibilityIdentifier = "voice_settings"
        settingsButton.addAction(UIAction { [weak self] _ in self?.presenter.openSettings() }, for: .touchUpInside)

        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Design.Spacing.l
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])
        presenter.state.observe(on: MainScheduler.instance).subscribe(onNext: { [weak self] in self?.render($0) }).disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter.viewWillDisappear()
    }

    private func render(_ state: VoiceState) {
        defer { if case .listening = state { wasListening = true } else { wasListening = false } }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let micHolder = UIStackView(arrangedSubviews: [micButton])
        micHolder.alignment = .center
        micHolder.axis = .vertical
        func setMic(symbol: String, label: String, enabled: Bool = true) {
            micButton.configuration?.image = UIImage(systemName: symbol)
            micButton.accessibilityLabel = label
            micButton.isEnabled = enabled
        }
        switch state {
        case .ready(let access):
            switch access {
            case .authorized, .notDetermined:
                setMic(symbol: "mic.fill", label: NSLocalizedString("Start listening", comment: ""))
                status.text = NSLocalizedString("Say a Japanese word or phrase", comment: "")
                detail.text = NSLocalizedString("Tap the microphone and speak. Recognition uses Apple’s speech service and runs on the device when this iPhone supports it.", comment: "")
                stack.addArrangedSubview(micHolder)
                stack.addArrangedSubview(status)
                stack.addArrangedSubview(detail)
            case .denied:
                setMic(symbol: "mic.slash.fill", label: NSLocalizedString("Microphone unavailable", comment: ""), enabled: false)
                status.text = NSLocalizedString("Microphone or speech access is off", comment: "")
                detail.text = NSLocalizedString("Turn on Microphone and Speech Recognition for this app in Settings, then try again.", comment: "")
                [micHolder, status, detail, settingsButton].forEach(stack.addArrangedSubview)
            case .unavailable:
                setMic(symbol: "mic.slash.fill", label: NSLocalizedString("Microphone unavailable", comment: ""), enabled: false)
                status.text = NSLocalizedString("Japanese speech recognition isn’t available right now.", comment: "")
                detail.text = NSLocalizedString("It may need an internet connection, or this device doesn’t support it. You can type the word instead.", comment: "")
                [micHolder, status, detail].forEach(stack.addArrangedSubview)
            }
        case .listening(let partial):
            setMic(symbol: "stop.fill", label: NSLocalizedString("Stop listening", comment: ""))
            status.text = NSLocalizedString("Listening…", comment: "")
            detail.text = partial.isEmpty ? NSLocalizedString("Speak now.", comment: "") : partial
            detail.font = partial.isEmpty ? Design.TextRole.reading.font : Design.TextRole.sentence.font
            detail.textColor = partial.isEmpty ? Design.TextRole.reading.color : Design.Color.textPrimary
            [micHolder, status, detail].forEach(stack.addArrangedSubview)
            // Announced once when listening starts, not with every partial transcript.
            if !wasListening { UIAccessibility.post(notification: .announcement, argument: NSLocalizedString("Listening", comment: "")) }
        case .result(let text):
            detail.font = Design.TextRole.reading.font
            detail.textColor = Design.TextRole.reading.color
            setMic(symbol: "mic.fill", label: NSLocalizedString("Listen again", comment: ""))
            status.text = NSLocalizedString("Check what was heard", comment: "")
            detail.text = NSLocalizedString("Edit the text if needed, then look it up.", comment: "")
            if transcript.text != text { transcript.text = text }
            [status, detail, transcript, lookUpButton, micHolder].forEach(stack.addArrangedSubview)
            updateLookUp()
        case .failed(let message):
            detail.font = Design.TextRole.reading.font
            detail.textColor = Design.TextRole.reading.color
            setMic(symbol: "mic.fill", label: NSLocalizedString("Try again", comment: ""))
            status.text = NSLocalizedString("Couldn’t hear that", comment: "")
            detail.text = message
            [micHolder, status, detail].forEach(stack.addArrangedSubview)
        }
    }

    private func updateLookUp() {
        if case .valid = DictionaryQuery.validate(transcript.text ?? "") { lookUpButton.isEnabled = true } else { lookUpButton.isEnabled = false }
    }

    func textViewDidChange(_ textView: UITextView) { updateLookUp() }
}
