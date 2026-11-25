import RxSwift
import UIKit

/// Handwriting search: draw a character, tap the candidate that matches, repeat, then look the text up. Nothing is
/// searched until the learner asks.
final class DictionaryHandwritingViewController: BaseVC {
    var presenter: DictionaryHandwritingPresenterInterface!

    private let textLabel = UILabel()
    private let backspaceButton = UIButton(type: .system)
    private let candidateScroll = UIScrollView()
    private let candidateStack = UIStackView()
    private let statusLabel = UILabel()
    private let canvas = HandwritingCanvasView()
    private let undoButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let lookUpButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Design.Color.background
        title = NSLocalizedString("Handwriting", comment: "Dictionary handwriting search title")
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.presenter.close() })
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "handwriting_close"

        textLabel.font = Design.TextRole.headword.font
        textLabel.adjustsFontForContentSizeCategory = true
        textLabel.numberOfLines = 1
        textLabel.lineBreakMode = .byTruncatingHead
        textLabel.accessibilityIdentifier = "handwriting_text"
        textLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        var backspace = UIButton.Configuration.plain()
        backspace.image = UIImage(systemName: "delete.left")
        backspace.baseForegroundColor = Design.Color.accent
        backspaceButton.configuration = backspace
        backspaceButton.widthAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        backspaceButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        backspaceButton.accessibilityLabel = NSLocalizedString("Delete last character", comment: "")
        backspaceButton.accessibilityIdentifier = "handwriting_backspace"
        backspaceButton.addAction(UIAction { [weak self] _ in self?.presenter.deleteLastCharacter() }, for: .touchUpInside)

        candidateScroll.showsHorizontalScrollIndicator = false
        candidateScroll.alwaysBounceHorizontal = true
        candidateScroll.accessibilityIdentifier = "handwriting_candidates"
        candidateStack.axis = .horizontal
        candidateStack.spacing = Design.Spacing.s
        candidateStack.translatesAutoresizingMaskIntoConstraints = false
        candidateScroll.addSubview(candidateStack)

        statusLabel.apply(.reading)
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.accessibilityIdentifier = "handwriting_status"

        canvas.accessibilityIdentifier = "handwriting_canvas"
        canvas.onInkChange = { [weak self] ink in
            self?.presenter.inkChanged(ink)
            self?.updateButtons()
        }

        configure(undoButton, title: NSLocalizedString("Undo", comment: "Handwriting: remove the last stroke"), symbol: "arrow.uturn.backward",
                  identifier: "handwriting_undo") { [weak self] in self?.canvas.undoLastStroke() }
        configure(clearButton, title: NSLocalizedString("Clear", comment: "Handwriting: wipe the pad"), symbol: "xmark.circle",
                  identifier: "handwriting_clear") { [weak self] in self?.canvas.clear() }
        lookUpButton.configuration = Design.Button.primary(title: NSLocalizedString("Look up", comment: ""), traits: traitCollection)
        lookUpButton.enableAdaptiveCornerStyle()
        lookUpButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        lookUpButton.accessibilityIdentifier = "handwriting_lookup"
        lookUpButton.addAction(UIAction { [weak self] _ in self?.presenter.lookUp() }, for: .touchUpInside)

        let textRow = UIStackView(arrangedSubviews: [textLabel, backspaceButton])
        textRow.alignment = .center
        textRow.spacing = Design.Spacing.s
        let canvasHolder = UIView()
        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvasHolder.addSubview(canvas)
        let preferredWidth = canvas.widthAnchor.constraint(equalTo: canvasHolder.widthAnchor)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            preferredWidth,
            canvas.widthAnchor.constraint(lessThanOrEqualTo: canvasHolder.widthAnchor),
            canvas.heightAnchor.constraint(equalTo: canvas.widthAnchor),
            canvas.heightAnchor.constraint(lessThanOrEqualTo: canvasHolder.heightAnchor),
            canvas.centerXAnchor.constraint(equalTo: canvasHolder.centerXAnchor),
            canvas.centerYAnchor.constraint(equalTo: canvasHolder.centerYAnchor)
        ])
        let buttons = UIStackView(arrangedSubviews: [undoButton, clearButton, lookUpButton])
        buttons.spacing = Design.Spacing.s
        buttons.alignment = .center
        // The two icon buttons keep their size; "Look up" takes the rest of the row.
        for button in [undoButton, clearButton] {
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        lookUpButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        lookUpButton.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [textRow, candidateScroll, statusLabel, canvasHolder, buttons])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Design.Spacing.s),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Design.Spacing.m),
            candidateScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            candidateStack.topAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.topAnchor),
            candidateStack.bottomAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.bottomAnchor),
            candidateStack.leadingAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.leadingAnchor),
            candidateStack.trailingAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.trailingAnchor),
            candidateStack.heightAnchor.constraint(equalTo: candidateScroll.frameLayoutGuide.heightAnchor)
        ])

        presenter.state.observe(on: MainScheduler.instance).subscribe(onNext: { [weak self] in self?.render($0) }).disposed(by: disposeBag)
        presenter.canvasShouldClear.observe(on: MainScheduler.instance).subscribe(onNext: { [weak self] in self?.canvas.clear() }).disposed(by: disposeBag)
        updateButtons()
    }

    private func configure(_ button: UIButton, title: String, symbol: String, identifier: String, action: @escaping () -> Void) {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: symbol)
        configuration.cornerStyle = .capsule
        configuration.buttonSize = .large
        configuration.baseBackgroundColor = Design.Color.surface
        configuration.baseForegroundColor = Design.Color.accent
        configuration.background.strokeColor = Design.Color.border
        configuration.background.strokeWidth = 1
        button.configuration = configuration
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        button.accessibilityLabel = title
        button.accessibilityIdentifier = identifier
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    }

    private func updateButtons() {
        undoButton.isEnabled = canvas.canUndo
        clearButton.isEnabled = canvas.canUndo
    }

    // MARK: Rendering

    private func render(_ state: HandwritingState) {
        textLabel.text = state.text.isEmpty ? " " : state.text
        textLabel.accessibilityLabel = state.text.isEmpty ? NSLocalizedString("Nothing chosen yet", comment: "") : state.text
        backspaceButton.isEnabled = !state.text.isEmpty
        lookUpButton.isEnabled = { if case .valid = DictionaryQuery.validate(state.text) { return true } else { return false } }()

        candidateStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for candidate in state.candidates {
            var configuration = UIButton.Configuration.filled()
            configuration.title = candidate
            configuration.cornerStyle = .capsule
            configuration.baseBackgroundColor = Design.Color.surface
            configuration.baseForegroundColor = Design.Color.textPrimary
            configuration.background.strokeColor = Design.Color.border
            configuration.background.strokeWidth = 1
            configuration.contentInsets = NSDirectionalEdgeInsets(top: Design.Spacing.s, leading: Design.Spacing.m + 2, bottom: Design.Spacing.s, trailing: Design.Spacing.m + 2)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = Design.TextRole.headword.font
                return attributes
            }
            let button = UIButton(configuration: configuration)
            button.accessibilityIdentifier = "handwriting_candidate_\(candidate)"
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
            button.addAction(UIAction { [weak self] _ in
                UISelectionFeedbackGenerator().selectionChanged()
                self?.presenter.choose(candidate)
            }, for: .touchUpInside)
            candidateStack.addArrangedSubview(button)
        }
        candidateScroll.accessibilityLabel = NSLocalizedString("Candidate characters", comment: "")
        candidateScroll.setContentOffset(.zero, animated: false)

        switch state.recognition {
        case .idle:
            statusLabel.textColor = Design.TextRole.reading.color
            statusLabel.text = state.candidates.isEmpty
                ? NSLocalizedString("Write one character below, then tap the one you meant.", comment: "Handwriting hint")
                : NSLocalizedString("Tap the character you meant.", comment: "")
        case .recognizing:
            statusLabel.textColor = Design.TextRole.reading.color
            statusLabel.text = NSLocalizedString("Reading…", comment: "")
        case .noMatch:
            statusLabel.textColor = Design.TextRole.reading.color
            statusLabel.text = NSLocalizedString("No matching character. Try writing larger, or stroke by stroke in the usual order.", comment: "")
        case .failed(let message):
            statusLabel.textColor = Design.Color.error
            statusLabel.text = message
        }
    }
}
