import UIKit

/// Add or edit one example sentence: the sentence (required), its reading and its meaning. The sentence is stored on this
/// device for the signed-in account; the note under the fields says so.
final class ExampleEditorViewController: BaseViewController, ExampleEditorViewInterface, UITextViewDelegate {
    var presenter: ExampleEditorPresenterInterface!

    private let japanese = PlaceholderTextView(role: .explanation)
    private let reading = PlaceholderTextView(role: .reading)
    private let translation = PlaceholderTextView(role: .meaning)
    private let problemLabel = ErrorMessageLabel()
    private var saveButton: UIBarButtonItem!
    private var isRendering = false
    /// What the presenter last drew; a change is reported only when the text differs from it.
    private var shown = CardExampleDraft()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }

    func subscribe() {}

    func setupUI() {
        view.backgroundColor = Design.Color.background
        navigationItem.largeTitleDisplayMode = .never
        let cancel = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in self?.presenter.cancel() })
        cancel.accessibilityIdentifier = "example_editor_cancel"
        navigationItem.leftBarButtonItem = cancel
        saveButton = UIBarButtonItem(systemItem: .save, primaryAction: UIAction { [weak self] _ in
            self?.view.endEditing(true)
            self?.presenter.save()
        })
        saveButton.accessibilityIdentifier = "example_editor_save"
        navigationItem.rightBarButtonItem = saveButton
        navigationController?.presentationController?.delegate = self

        japanese.placeholder = NSLocalizedString("Sentence", comment: "Example sentence field")
        japanese.accessibilityIdentifier = "example_editor_japanese"
        japanese.accessibilityLanguage = "ja"
        reading.placeholder = NSLocalizedString("Reading (optional)", comment: "")
        reading.accessibilityIdentifier = "example_editor_reading"
        reading.accessibilityLanguage = "ja"
        translation.placeholder = NSLocalizedString("Meaning (optional)", comment: "")
        translation.accessibilityIdentifier = "example_editor_translation"
        for field in [japanese, reading, translation] { field.delegate = self }

        let fields = UIStackView(arrangedSubviews: [row(japanese), row(reading), row(translation)])
        fields.axis = .vertical
        fields.spacing = Design.Spacing.m
        let note = UILabel()
        note.apply(.metadata)
        note.text = NSLocalizedString("Saved on this device for the account you are signed in with. It is not synced to the website.", comment: "")
        problemLabel.accessibilityIdentifier = "example_editor_problem"
        let content = UIStackView(arrangedSubviews: [fields, problemLabel, note])
        content.axis = .vertical
        content.spacing = Design.Spacing.m
        content.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: Design.Spacing.l),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -Design.Spacing.xl),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: Design.Spacing.gutter),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -Design.Spacing.gutter)
        ])
    }

    /// A field on a surface, so the three read as inputs.
    private func row(_ field: PlaceholderTextView) -> UIView {
        let container = UIView()
        container.backgroundColor = Design.Color.surface
        container.layer.cornerRadius = 12
        container.layer.cornerCurve = .continuous
        field.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(field)
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: container.topAnchor, constant: Design.Spacing.xs),
            field.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Design.Spacing.xs),
            field.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Design.Spacing.m),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Design.Spacing.m),
            field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        return container
    }

    func render(_ state: ExampleEditorState) {
        guard isViewLoaded else { return }
        isRendering = true
        defer { isRendering = false }
        shown = state.draft
        title = state.isNew ? NSLocalizedString("New example sentence", comment: "") : NSLocalizedString("Edit example sentence", comment: "")
        if japanese.text != state.draft.japanese { japanese.text = state.draft.japanese }
        if reading.text != state.draft.reading { reading.text = state.draft.reading }
        if translation.text != state.draft.translation { translation.text = state.draft.translation }
        saveButton.isEnabled = state.canSave
        problemLabel.text = state.problem
        problemLabel.isHidden = state.problem == nil
        // Typing is not thrown away by a swipe; Cancel asks first.
        isModalInPresentation = state.isDirty
        if state.problem != nil { UIAccessibility.post(notification: .announcement, argument: state.problem) }
    }

    func textViewDidChange(_ textView: UITextView) {
        guard !isRendering else { return }
        // Wait for an IME composition to commit before the draft changes.
        guard textView.markedTextRange == nil else { return }
        let text = textView.text ?? ""
        switch textView {
        case japanese where text != shown.japanese: presenter.setJapanese(text)
        case reading where text != shown.reading: presenter.setReading(text)
        case translation where text != shown.translation: presenter.setTranslation(text)
        default: break
        }
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        // A composition that just committed changes the marked range without a text change.
        textViewDidChange(textView)
    }
}

extension ExampleEditorViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        presenter.cancel()
    }
}
