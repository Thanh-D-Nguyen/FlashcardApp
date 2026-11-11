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

    private let progressLabel = UILabel()
    private let wordLabel = UILabel()
    private let cueLabel = UILabel()
    private let canvas = HandwritingCanvasView()
    private let resultLabel = UILabel()
    private let primaryButton = UIButton(configuration: .borderedProminent())
    private let clearButton = UIButton(configuration: .bordered())
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
        primaryButton.accessibilityIdentifier = "kanji_writing_primary"
        primaryButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if case .answered = self.phase { self.presenter.next() } else { self.presenter.check() }
        }, for: .touchUpInside)
        clearButton.configuration?.title = NSLocalizedString("Clear", comment: "")
        clearButton.addAction(UIAction { [weak self] _ in self?.presenter.clear() }, for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [clearButton, primaryButton])
        buttons.spacing = Design.Spacing.m
        buttons.distribution = .fillEqually
        let stack = UIStackView(arrangedSubviews: [progressLabel, wordLabel, cueLabel, canvas, resultLabel, buttons])
        stack.axis = .vertical
        stack.spacing = Design.Spacing.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Design.Spacing.m),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Design.Spacing.gutter),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Design.Spacing.gutter),
            canvas.heightAnchor.constraint(equalTo: canvas.widthAnchor)
        ])
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
        switch state.phase {
        case .empty:
            resultLabel.text = NSLocalizedString("This deck has no kanji the app can check yet.", comment: "Kanji writing practice")
            canvas.isHidden = true
            primaryButton.isHidden = true
            clearButton.isHidden = true
        case .writing, .checking:
            resultLabel.text = state.notice
            primaryButton.configuration?.title = NSLocalizedString("Check", comment: "Kanji writing practice")
            primaryButton.isEnabled = state.phase == .writing && state.hasInk
        case .answered(let correct):
            let target = state.question?.target ?? ""
            resultLabel.text = correct ? String(format: NSLocalizedString("Right: %@", comment: "Kanji writing practice"), target)
                                       : String(format: NSLocalizedString("Not recognised as %@. Compare and try the next one.", comment: "Kanji writing practice"), target)
            wordLabel.text = state.question.map { $0.maskedWord.replacingOccurrences(of: "□", with: $0.target) }
            primaryButton.configuration?.title = NSLocalizedString("Next", comment: "")
            primaryButton.isEnabled = true
        case .finished:
            resultLabel.text = String(format: NSLocalizedString("Done: %1$lld of %2$lld recognised.", comment: "Kanji writing practice"), state.correct, state.total)
            canvas.isHidden = true
            primaryButton.isHidden = true
            clearButton.isHidden = true
            wordLabel.text = nil
            cueLabel.text = nil
        }
    }
}
