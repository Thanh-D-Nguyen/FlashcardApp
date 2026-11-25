import UIKit

/// Builds the practice for a deck: only kanji the stroke templates can check are asked.
enum KanjiWritingWireframe {
    static func make(cards: [StudyCard]) -> KanjiWritingViewController {
        let known = Set((try? HandwritingTemplateStore.load())?.templates.compactMap(\.character) ?? [])
        let presenter = KanjiWritingPresenter(questions: KanjiWritingQuestions.make(from: cards, canCheck: known.contains),
                                              recognizer: StrokeTemplateRecognizer())
        let controller = KanjiWritingViewController()
        controller.presenter = presenter
        presenter.view = controller
        controller.hidesBottomBarWhenPushed = true
        return controller
    }
}

/// Write the hidden kanji of the word from its reading and meaning, with a finger or Apple Pencil.
final class KanjiWritingViewController: BaseViewController, KanjiWritingViewInterface {
    var presenter: KanjiWritingPresenterInterface!

    private let scrollView = UIScrollView()
    private let stateView = StateView()
    private let progressLabel = UILabel()
    private let wordLabel = UILabel()
    private let cueLabel = UILabel()
    private let canvas = HandwritingCanvasView()
    private let resultLabel = UILabel()
    private let primaryButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let buttons = UIStackView()
    private var phase: KanjiWritingState.Phase = .writing

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }

    /// iOS 26 goes back with a swipe from anywhere in the content, which would take every left-to-right stroke drawn on the canvas.
    /// It is off on this screen; the edge swipe and the back button still go back.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = true
    }

    func subscribe() {}

    func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        title = NSLocalizedString("Write the kanji", comment: "Kanji writing practice")

        progressLabel.apply(.metadata)
        wordLabel.apply(.headword)
        wordLabel.textAlignment = .center
        wordLabel.accessibilityIdentifier = "kanji_writing_word"
        cueLabel.apply(.meaning)
        cueLabel.textAlignment = .center
        cueLabel.numberOfLines = 0
        resultLabel.apply(.meaning)
        resultLabel.textAlignment = .center
        resultLabel.numberOfLines = 0
        resultLabel.accessibilityIdentifier = "kanji_writing_result"

        canvas.accessibilityIdentifier = "kanji_writing_canvas"
        canvas.isAccessibilityElement = true
        canvas.accessibilityLabel = NSLocalizedString("Writing area", comment: "Kanji writing practice canvas")
        canvas.onInkChange = { [weak self] ink in self?.presenter.inkChanged(ink) }

        primaryButton.configuration = Design.Button.primary(title: NSLocalizedString("Check", comment: "Kanji writing practice"), traits: traitCollection)
        primaryButton.enableAdaptiveCornerStyle()
        primaryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        primaryButton.accessibilityIdentifier = "kanji_writing_primary"
        primaryButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if case .answered = self.phase { self.presenter.next() } else { self.presenter.check() }
        }, for: .touchUpInside)

        clearButton.configuration = Design.Button.secondary(title: NSLocalizedString("Clear", comment: ""), traits: traitCollection)
        clearButton.enableAdaptiveCornerStyle()
        clearButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Design.HitTarget.minimum).isActive = true
        clearButton.addAction(UIAction { [weak self] _ in self?.presenter.clear() }, for: .touchUpInside)

        [clearButton, primaryButton].forEach(buttons.addArrangedSubview)
        buttons.spacing = Design.Spacing.m
        buttons.distribution = .fillEqually
        updateButtonsAxis()

        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView(arrangedSubviews: [progressLabel, wordLabel, cueLabel, canvas, resultLabel, buttons])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        stateView.translatesAutoresizingMaskIntoConstraints = false
        stateView.isHidden = true
        view.addSubview(scrollView)
        view.addSubview(stateView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Design.Spacing.m),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter),
            canvas.heightAnchor.constraint(equalTo: canvas.widthAnchor),
            stateView.topAnchor.constraint(equalTo: view.topAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: KanjiWritingViewController, _) in
            controller.updateButtonsAxis()
        }
    }

    private func updateButtonsAxis() {
        buttons.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
    }

    func clearCanvas() { canvas.clear() }

    func render(_ state: KanjiWritingState) {
        phase = state.phase
        progressLabel.text = state.total > 0 ? String(format: NSLocalizedString("%1$lld of %2$lld", comment: "Study progress: position of total"),
                                                       min(state.position + 1, state.total), state.total) : nil
        wordLabel.text = state.question?.maskedWord
        cueLabel.text = state.question.map { [$0.reading, $0.meaning].filter { !$0.isEmpty }.joined(separator: " · ") }
        canvas.isUserInteractionEnabled = state.phase == .writing
        clearButton.isEnabled = state.phase == .writing && state.hasInk
        stateView.isHidden = true
        scrollView.isHidden = false
        switch state.phase {
        case .empty:
            let message = NSLocalizedString("This deck has no kanji the app can check yet.", comment: "Kanji writing practice")
            resultLabel.text = message
            stateView.configure(.empty(title: message, message: nil))
            stateView.isHidden = false
            scrollView.isHidden = true
        case .writing, .checking:
            resultLabel.textColor = Design.Color.textSecondary
            resultLabel.text = state.notice
            primaryButton.configuration = Design.Button.primary(title: NSLocalizedString("Check", comment: "Kanji writing practice"), traits: traitCollection)
            primaryButton.isEnabled = state.phase == .writing && state.hasInk
        case .answered(let correct):
            let target = state.question?.target ?? ""
            resultLabel.textColor = correct ? Design.Color.success : Design.Color.error
            resultLabel.text = correct ? String(format: NSLocalizedString("Right: %@", comment: "Kanji writing practice"), target)
                                       : String(format: NSLocalizedString("Not recognised as %@. Compare and try the next one.", comment: "Kanji writing practice"), target)
            wordLabel.text = state.question.map { $0.maskedWord.replacingOccurrences(of: "□", with: $0.target) }
            primaryButton.configuration = Design.Button.primary(title: NSLocalizedString("Next", comment: ""), traits: traitCollection)
            primaryButton.isEnabled = true
        case .finished:
            let message = String(format: NSLocalizedString("Done: %1$lld of %2$lld recognised.", comment: "Kanji writing practice"), state.correct, state.total)
            resultLabel.text = message
            stateView.configure(.empty(title: message, message: nil))
            stateView.isHidden = false
            scrollView.isHidden = true
        }
    }
}
