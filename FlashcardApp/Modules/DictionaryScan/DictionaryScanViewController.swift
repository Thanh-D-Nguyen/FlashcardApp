import PhotosUI
import RxSwift
import UIKit

/// Camera / photo text lookup. A photo is read on the device; the recognized text is shown for the learner to correct, and
/// they choose the word or phrase to look up. Nothing is searched automatically and no photo leaves the phone.
final class DictionaryScanViewController: BaseVC, UIImagePickerControllerDelegate, UINavigationControllerDelegate,
                                          PHPickerViewControllerDelegate, UITextViewDelegate {
    var presenter: DictionaryScanPresenterInterface!

    private let content = UIStackView()
    private let stateView = StateView()
    private let textView = UITextView()
    private let lookUpButton = UIButton(type: .system)
    private let hint = UILabel()
    private var anotherItem: UIBarButtonItem!
    private lazy var textViewHeight = textView.heightAnchor.constraint(equalToConstant: 140)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Design.Color.background
        title = NSLocalizedString("Scan text", comment: "")
        navigationItem.largeTitleDisplayMode = .never
        let close = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.presenter.close() })
        close.accessibilityIdentifier = "scan_close"
        navigationItem.leftBarButtonItem = close
        anotherItem = UIBarButtonItem(image: UIImage(systemName: "arrow.counterclockwise"), primaryAction: UIAction { [weak self] _ in self?.presenter.scanAnother() })
        anotherItem.accessibilityLabel = NSLocalizedString("Scan another photo", comment: "")
        anotherItem.accessibilityIdentifier = "scan_another"

        content.axis = .vertical
        content.spacing = Design.Spacing.m
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)
        stateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stateView)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Design.Spacing.l),
            content.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -Design.Spacing.m),
            stateView.topAnchor.constraint(equalTo: view.topAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        textView.font = Design.TextRole.sentence.font
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = Design.Color.surface
        textView.layer.cornerRadius = 12
        textView.layer.cornerCurve = .continuous
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.autocorrectionType = .no
        textView.delegate = self
        textViewHeight.isActive = true
        textView.accessibilityIdentifier = "scan_text"
        textView.accessibilityLabel = NSLocalizedString("Recognized text", comment: "")

        hint.apply(.metadata)
        hint.text = NSLocalizedString("Check the text, select a word or phrase, then look it up. You can edit what was read.", comment: "")

        var configuration = Design.Button.primary(title: NSLocalizedString("Look up", comment: ""))
        configuration.titleLineBreakMode = .byWordWrapping
        lookUpButton.configuration = configuration
        lookUpButton.addAction(UIAction { [weak self] _ in self?.lookUp() }, for: .touchUpInside)
        lookUpButton.accessibilityIdentifier = "scan_lookup"

        presenter.state.observe(on: MainScheduler.instance).subscribe(onNext: { [weak self] in self?.render($0) }).disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter.viewWillAppear()
    }

    #if DEBUG
    /// `-ScanFixtureText <text>`: instead of a photo, a picture of this text is drawn and recognized, so the whole
    /// recognize → correct → look up path can be exercised in the Simulator, which has no camera.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-ScanFixtureText"), index + 1 < arguments.count, case .choosing = presenter.state.value else { return }
        let text = arguments[index + 1]
        let size = CGSize(width: 1000, height: 320)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            (text as NSString).draw(in: CGRect(x: 40, y: 90, width: 920, height: 160), withAttributes: [
                .font: UIFont(name: "HiraginoSans-W6", size: 76) ?? UIFont.systemFont(ofSize: 96, weight: .semibold), .foregroundColor: UIColor.black])
        }
        presenter.imagePicked(image)
    }
    #endif

    // MARK: Rendering

    private func render(_ state: ScanState) {
        content.arrangedSubviews.forEach { $0.removeFromSuperview() }
        navigationItem.rightBarButtonItem = nil
        content.isHidden = true
        stateView.isHidden = false
        switch state {
        case .choosing(let camera):
            stateView.isHidden = true
            content.isHidden = false
            content.addArrangedSubview(chooser(camera: camera))
        case .recognizing:
            stateView.configure(.loading(NSLocalizedString("Reading text…", comment: "")))
        case .noText:
            navigationItem.rightBarButtonItem = anotherItem
            stateView.configure(.call(symbol: "text.magnifyingglass", title: NSLocalizedString("No text found", comment: ""),
                                      message: NSLocalizedString("Try a sharper, well-lit photo with the text filling more of the picture.", comment: ""),
                                      actionTitle: NSLocalizedString("Try another photo", comment: ""))) { [weak self] in self?.presenter.scanAnother() }
        case .failed(let message):
            navigationItem.rightBarButtonItem = anotherItem
            stateView.configure(.error(message: message, retryTitle: NSLocalizedString("Try another photo", comment: ""))) { [weak self] in self?.presenter.scanAnother() }
        case .recognized(let text):
            stateView.isHidden = true
            content.isHidden = false
            navigationItem.rightBarButtonItem = anotherItem
            if textView.text != text { textView.text = text }
            content.addArrangedSubview(hint)
            content.addArrangedSubview(textView)
            content.addArrangedSubview(lookUpButton)
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
            content.addArrangedSubview(spacer)
            updateLookUpButton()
            updateTextHeight()
        }
    }

    private func chooser(camera: CameraAccess) -> UIView {
        let box = UIStackView()
        box.axis = .vertical
        box.spacing = Design.Spacing.m
        box.alignment = .fill
        let icon = UIImageView(image: UIImage(systemName: "text.viewfinder"))
        icon.tintColor = Design.Color.accent
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 48, weight: .light)
        icon.contentMode = .scaleAspectFit
        let title = UILabel()
        title.apply(.title)
        title.text = NSLocalizedString("Scan Japanese text", comment: "")
        title.textAlignment = .center
        let message = UILabel()
        message.apply(.reading)
        message.textAlignment = .center
        message.text = NSLocalizedString("Take a photo or choose one, then pick a word to look up. Text is read on your device; the photo is not uploaded or saved.", comment: "")
        [icon, title, message].forEach(box.addArrangedSubview)
        box.setCustomSpacing(Design.Spacing.xl, after: message)

        switch camera {
        case .available, .notDetermined:
            box.addArrangedSubview(sourceButton(NSLocalizedString("Take photo", comment: ""), symbol: "camera", prominent: true, identifier: "scan_camera") { [weak self] in self?.presenter.takePhoto() })
        case .denied:
            let note = UILabel()
            note.apply(.metadata)
            note.textColor = Design.Color.error
            note.textAlignment = .center
            note.text = NSLocalizedString("Camera access is off for this app. You can turn it on in Settings, or choose a photo instead.", comment: "")
            box.addArrangedSubview(note)
            box.addArrangedSubview(sourceButton(NSLocalizedString("Open Settings", comment: ""), symbol: "gearshape", prominent: false, identifier: "scan_settings") { [weak self] in self?.presenter.openSettings() })
        case .unavailable:
            let note = UILabel()
            note.apply(.metadata)
            note.textAlignment = .center
            note.text = NSLocalizedString("This device has no camera. You can still choose a photo.", comment: "")
            box.addArrangedSubview(note)
        }
        box.addArrangedSubview(sourceButton(NSLocalizedString("Choose photo", comment: ""), symbol: "photo", prominent: camera == .unavailable, identifier: "scan_photos") { [weak self] in self?.presenter.choosePhoto() })
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        let wrapper = UIStackView(arrangedSubviews: [box, spacer])
        wrapper.axis = .vertical
        return wrapper
    }

    private func sourceButton(_ title: String, symbol: String, prominent: Bool, identifier: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = prominent ? Design.Button.primary(title: title) : UIButton.Configuration.gray()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = Design.Spacing.s
        if !prominent { configuration.cornerStyle = .capsule; configuration.buttonSize = .large; configuration.baseForegroundColor = Design.Color.accent }
        button.configuration = configuration
        button.accessibilityIdentifier = identifier
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    // MARK: Look up

    /// The selected words when something is selected, otherwise the whole text.
    private var target: String {
        if let range = textView.selectedTextRange, !range.isEmpty, let selected = textView.text(in: range) { return selected }
        return textView.text ?? ""
    }

    private func updateLookUpButton() {
        let selection = (textView.selectedTextRange.map { !$0.isEmpty } ?? false)
        let valid: Bool
        if case .valid = DictionaryQuery.validate(target) { valid = true } else { valid = false }
        var configuration = lookUpButton.configuration
        configuration?.title = selection ? NSLocalizedString("Look up selection", comment: "") : NSLocalizedString("Look up all text", comment: "")
        lookUpButton.configuration = configuration
        lookUpButton.isEnabled = valid
        lookUpButton.accessibilityHint = valid ? nil : NSLocalizedString("Select a word or phrase first.", comment: "")
    }

    func textViewDidChangeSelection(_ textView: UITextView) { updateLookUpButton() }
    func textViewDidChange(_ textView: UITextView) {
        updateLookUpButton()
        updateTextHeight()
    }

    /// The text box fits its text (at least a few lines) and scrolls once it would take more than half the screen.
    private func updateTextHeight() {
        let width = max(textView.bounds.width, view.bounds.width - 2 * Design.Spacing.l)
        let needed = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        textViewHeight.constant = min(max(needed, 140), view.bounds.height * 0.5)
    }

    private func lookUp() {
        textView.resignFirstResponder()
        presenter.lookUp(target)
    }

    // MARK: Pickers

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage { presenter.imagePicked(image) } else { presenter.pickerCancelled() }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        presenter.pickerCancelled()
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return presenter.pickerCancelled() }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            DispatchQueue.main.async {
                if let image = object as? UIImage { self?.presenter.imagePicked(image) } else { self?.presenter.pickerCancelled() }
            }
        }
    }
}
