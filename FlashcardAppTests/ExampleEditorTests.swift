import XCTest
@testable import FlashcardApp

final class ExampleEditorTests: XCTestCase {
    private var wireframe: EditorWireframe!
    private var view: EditorView!
    private var saved: [CardExampleDraft] = []
    private var failure: Error?

    override func setUp() {
        super.setUp()
        wireframe = EditorWireframe()
        view = EditorView()
        saved = []
        failure = nil
    }

    private func makePresenter(isNew: Bool = true, draft: CardExampleDraft = CardExampleDraft()) -> ExampleEditorPresenter {
        let presenter = ExampleEditorPresenter(isNew: isNew, draft: draft, wireframe: wireframe) { [unowned self] draft in
            if let failure { throw failure }
            saved.append(draft)
        }
        presenter.view = view
        presenter.viewDidLoad()
        return presenter
    }

    private var state: ExampleEditorState { view.states.last! }

    func test_anEmptyFormCannotBeSavedUntilTheSentenceIsTyped() {
        let presenter = makePresenter()
        XCTAssertFalse(state.canSave)
        presenter.setReading("いぬ")
        XCTAssertFalse(state.canSave, "A reading alone is not a sentence")
        presenter.setJapanese("  ")
        XCTAssertFalse(state.canSave)
        presenter.setJapanese("犬")
        XCTAssertTrue(state.canSave)
    }

    func test_savingHandsTheDraftOverAndClosesTheForm() {
        let presenter = makePresenter()
        presenter.setJapanese("犬が好き。")
        presenter.setTranslation("Tôi thích chó.")
        presenter.save()
        XCTAssertEqual(saved, [CardExampleDraft(japanese: "犬が好き。", translation: "Tôi thích chó.")])
        XCTAssertEqual(wireframe.finishCount, 1)
    }

    func test_aRefusedSaveKeepsTheFormOpenWithTheReason() {
        failure = CardExampleError.duplicate
        let presenter = makePresenter()
        presenter.setJapanese("犬が好き。")
        presenter.save()
        XCTAssertEqual(wireframe.finishCount, 0)
        XCTAssertEqual(state.problem, CardExampleError.duplicate.errorDescription)
        XCTAssertEqual(state.draft.japanese, "犬が好き。", "Nothing typed is lost")
        presenter.setJapanese("犬が好きだ。")
        XCTAssertNil(state.problem, "Typing again clears the message")
        failure = nil
        presenter.save()
        XCTAssertEqual(wireframe.finishCount, 1)
    }

    func test_savingTwiceStoresOnce() {
        let presenter = makePresenter()
        presenter.setJapanese("犬")
        presenter.save()
        presenter.save()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(wireframe.finishCount, 1)
    }

    func test_editingStartsFromTheSentenceAndIsDirtyOnlyOnceItChanges() {
        let presenter = makePresenter(isNew: false, draft: CardExampleDraft(japanese: "犬", reading: "いぬ", translation: "chó"))
        XCTAssertFalse(state.isNew)
        XCTAssertTrue(state.canSave)
        XCTAssertFalse(state.isDirty)
        presenter.setTranslation("con chó")
        XCTAssertTrue(state.isDirty)
        presenter.setTranslation("chó")
        XCTAssertFalse(state.isDirty, "Typing back to the original is not a change")
    }

    func test_cancellingAnUntouchedFormClosesItAtOnce() {
        makePresenter().cancel()
        XCTAssertEqual(wireframe.finishCount, 1)
        XCTAssertEqual(wireframe.discardPrompts, 0)
    }

    func test_cancellingTypingAsksFirstAndKeepsTheFormUnlessTheLearnerAgrees() {
        let presenter = makePresenter()
        presenter.setJapanese("書きかけ")
        presenter.cancel()
        XCTAssertEqual(wireframe.discardPrompts, 1)
        XCTAssertEqual(wireframe.finishCount, 0)
        wireframe.discard?()
        XCTAssertEqual(wireframe.finishCount, 1)
        XCTAssertTrue(saved.isEmpty)
    }
}

private final class EditorView: ExampleEditorViewInterface {
    var states: [ExampleEditorState] = []
    func render(_ state: ExampleEditorState) { states.append(state) }
}

private final class EditorWireframe: ExampleEditorWireframeInterface {
    var finishCount = 0
    var discardPrompts = 0
    var discard: (() -> Void)?
    func finish() { finishCount += 1 }
    func confirmDiscard(onDiscard: @escaping () -> Void) {
        discardPrompts += 1
        discard = onDiscard
    }
}
