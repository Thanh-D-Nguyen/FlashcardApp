import Foundation

struct ExampleEditorState: Equatable {
    let isNew: Bool
    let draft: CardExampleDraft
    /// Saving needs the sentence; the other fields are optional.
    let canSave: Bool
    /// Unsaved typing: closing the form then asks first.
    let isDirty: Bool
    /// Why the last save was refused (empty sentence, too long, already on the card, a storage error).
    let problem: String?
}

protocol ExampleEditorViewInterface: AnyObject {
    func render(_ state: ExampleEditorState)
}

protocol ExampleEditorPresenterInterface: AnyObject {
    func viewDidLoad()
    func setJapanese(_ text: String)
    func setReading(_ text: String)
    func setTranslation(_ text: String)
    func save()
    func cancel()
}

protocol ExampleEditorWireframeInterface: AnyObject {
    func finish()
    /// Asks whether to throw the typing away; `onDiscard` runs when the learner agrees.
    func confirmDiscard(onDiscard: @escaping () -> Void)
}

/// The form for one example sentence. It does not know where the sentence is stored: `save` is given by the study screen,
/// validates and stores it, and throws a readable error that the form shows without closing.
final class ExampleEditorPresenter: ExampleEditorPresenterInterface {
    private let isNew: Bool
    private let initial: CardExampleDraft
    private var draft: CardExampleDraft
    private let saveHandler: (CardExampleDraft) throws -> Void
    private let wireframe: ExampleEditorWireframeInterface
    private var problem: String?
    private var finished = false
    weak var view: ExampleEditorViewInterface?

    init(isNew: Bool, draft: CardExampleDraft, wireframe: ExampleEditorWireframeInterface, save: @escaping (CardExampleDraft) throws -> Void) {
        self.isNew = isNew
        self.initial = draft
        self.draft = draft
        self.wireframe = wireframe
        self.saveHandler = save
    }

    func viewDidLoad() { publish() }

    func setJapanese(_ text: String) { draft.japanese = text; edited() }
    func setReading(_ text: String) { draft.reading = text; edited() }
    func setTranslation(_ text: String) { draft.translation = text; edited() }

    func save() {
        guard !finished, canSave else { return }
        do {
            try saveHandler(draft)
            finished = true
            wireframe.finish()
        } catch {
            problem = error.localizedDescription
            publish()
        }
    }

    func cancel() {
        guard draft != initial else { return wireframe.finish() }
        wireframe.confirmDiscard { [weak self] in self?.wireframe.finish() }
    }

    private var canSave: Bool { !draft.japanese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func edited() {
        problem = nil
        publish()
    }

    private func publish() {
        view?.render(ExampleEditorState(isNew: isNew, draft: draft, canSave: canSave, isDirty: draft != initial, problem: problem))
    }
}
