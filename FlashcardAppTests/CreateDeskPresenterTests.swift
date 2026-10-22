import RxSwift
import XCTest
@testable import FlashcardApp

final class CreateDeskPresenterTests: XCTestCase {
    private var interactor: FakeEditorInteractor!
    private var wireframe: FakeEditorWireframe!
    private var view: SpyEditorView!
    private var finished = 0

    override func setUp() {
        super.setUp()
        interactor = FakeEditorInteractor()
        wireframe = FakeEditorWireframe()
        view = SpyEditorView()
        suggestions = FakeSuggestions()
        finished = 0
    }

    private var suggestions: FakeSuggestions!

    private func makePresenter(deckId: String? = nil, suggestionDelay: DispatchTimeInterval = .milliseconds(40)) -> CreateDeskPresenter {
        let presenter = CreateDeskPresenter(interactor: interactor, wireframe: wireframe, deckId: deckId, onFinish: { [unowned self] in finished += 1 },
                                            suggestionInteractor: suggestions, draftSaveDelay: .milliseconds(0), suggestionDelay: suggestionDelay)
        presenter.view = view
        presenter.viewDidLoad()
        return presenter
    }

    private func fill(_ presenter: CreateDeskPresenter, name: String = "Deck") {
        presenter.updateName(name)
        for index in 0..<2 {
            presenter.updateField(.front, ofCardAt: index, text: "F\(index)")
            presenter.updateField(.back, ofCardAt: index, text: "B\(index)")
        }
    }

    private func savedDeck(id: String = "d1") -> DeskEntity {
        let first = CardEntity(); first.id = "c1"; first.frontText = "会議"; first.frontExtraText = "かいぎ"; first.backText = "họp"; first.backExtraText = "formal"
        first.imageUrl = "local-image:a.jpg"
        let second = CardEntity(); second.id = "c2"; second.frontText = "資料"; second.backText = "tài liệu"
        let desk = DeskEntity(); desk.id = id; desk.name = "Work"; desk.cards = [first, second]; desk.sortingLanguage = .opposite
        return desk
    }

    // MARK: Loading

    func test_aNewDeckStartsWithTwoEmptyCardsAndIsClean() {
        let presenter = makePresenter()
        XCTAssertEqual(presenter.draft.cards.count, 2)
        XCTAssertFalse(presenter.isEditingExistingDeck)
        XCTAssertEqual(view.dirty.last, false)
    }

    func test_editingLoadsTheStoredDeckKeepingIdsAndExtras() {
        interactor.decks["d1"] = savedDeck()
        let presenter = makePresenter(deckId: "d1")
        XCTAssertTrue(presenter.isEditingExistingDeck)
        XCTAssertEqual(presenter.draft.deckId, "d1")
        XCTAssertEqual(presenter.draft.cards.map(\.id), ["c1", "c2"])
        XCTAssertEqual(presenter.draft.cards[0].reading, "かいぎ")
        XCTAssertEqual(presenter.draft.cards[0].note, "formal")
        XCTAssertEqual(presenter.draft.cards[0].imageReference, "local-image:a.jpg")
        XCTAssertEqual(presenter.draft.sortingLanguage, .opposite)
    }

    func test_anUnknownDeckIdOpensANewDeckInstead() {
        let presenter = makePresenter(deckId: "missing")
        XCTAssertFalse(presenter.isEditingExistingDeck)
    }

    // MARK: Saving

    func test_savingAnIncompleteDeckShowsTheProblemsAndDoesNotSave() {
        let presenter = makePresenter()
        presenter.save()
        XCTAssertTrue(interactor.saved.isEmpty)
        XCTAssertEqual(view.issues.last?.issues, [.nameEmpty, .tooFewCards])
        XCTAssertEqual(view.issues.last?.reveal, true)
        XCTAssertEqual(finished, 0)
    }

    func test_problemsClearAsTheyAreFixedWithoutScrollingAgain() {
        let presenter = makePresenter()
        presenter.save()
        fill(presenter)
        XCTAssertEqual(view.issues.last?.issues, [])
        XCTAssertEqual(view.issues.last?.reveal, false)
    }

    func test_aHalfFilledCardBlocksSavingInsteadOfBeingDropped() {
        let presenter = makePresenter()
        fill(presenter)
        presenter.insertCard(after: 1)
        presenter.updateField(.front, ofCardAt: 2, text: "only front")
        presenter.save()
        XCTAssertTrue(interactor.saved.isEmpty)
        XCTAssertEqual(view.issues.last?.issues, [.incompleteCard(index: 2, missingFront: false)])
    }

    func test_aValidDeckIsSavedOnceThenTheEditorClosesAndTheLibraryRefreshes() {
        let presenter = makePresenter()
        fill(presenter)
        presenter.save()
        presenter.save()
        XCTAssertEqual(interactor.saved.count, 1)
        XCTAssertEqual(finished, 1)
        XCTAssertEqual(wireframe.closeCount, 1)
    }

    func test_aFailedSaveKeepsTheEditorOpenAndReportsTheError() {
        interactor.saveError = AppError.databaseWriteFailed("disk full")
        let presenter = makePresenter()
        fill(presenter)
        presenter.save()
        XCTAssertEqual(wireframe.closeCount, 0)
        XCTAssertEqual(wireframe.alerts.count, 1)
        XCTAssertEqual(view.saving, [true, false])
        interactor.saveError = nil
        presenter.save()
        XCTAssertEqual(interactor.saved.count, 1, "The learner can retry after a failure")
    }

    func test_aFinishedEditorNeverWritesADraftAgain() {
        let presenter = makePresenter()
        fill(presenter)
        presenter.save()
        interactor.savedDrafts.removeAll()
        presenter.persistDraftNow()
        XCTAssertTrue(interactor.savedDrafts.isEmpty)
    }

    // MARK: Deleting

    func test_deletingAStoredDeckAsksFirstThenDeletesAndClosesTheEditor() {
        interactor.decks["d1"] = savedDeck()
        let presenter = makePresenter(deckId: "d1")
        presenter.deleteDeck()
        XCTAssertTrue(interactor.deleted.isEmpty, "Nothing is deleted before the confirmation")
        XCTAssertEqual(wireframe.deleteDeckPrompts, ["Work"])
        wireframe.confirmDeleteDeck?()
        XCTAssertEqual(interactor.deleted, ["d1"])
        XCTAssertEqual(finished, 1, "The library (and a study screen behind the editor) are told to refresh")
        XCTAssertEqual(wireframe.closeCount, 1)
    }

    func test_aNewDeckHasNothingToDelete() {
        let presenter = makePresenter()
        presenter.deleteDeck()
        XCTAssertTrue(wireframe.deleteDeckPrompts.isEmpty)
    }

    func test_aFailedDeleteKeepsTheEditorOpen() {
        interactor.decks["d1"] = savedDeck()
        interactor.deleteError = AppError.databaseWriteFailed("disk full")
        let presenter = makePresenter(deckId: "d1")
        presenter.deleteDeck()
        wireframe.confirmDeleteDeck?()
        XCTAssertEqual(wireframe.alerts.count, 1)
        XCTAssertEqual(wireframe.closeCount, 0)
        XCTAssertEqual(finished, 0)
    }

    // MARK: Drafts

    func test_editsAreWrittenToTheRecoveryDraftAndCleanStateClearsIt() {
        let presenter = makePresenter()
        presenter.updateName("Work in progress")
        presenter.persistDraftNow()
        XCTAssertEqual(interactor.savedDrafts.last?.name, "Work in progress")
        presenter.updateName("")
        presenter.persistDraftNow()
        XCTAssertEqual(interactor.discardedDrafts.count, 1, "A draft equal to the stored deck is removed")
    }

    func test_aStoredDraftIsOfferedOnceAndRestoredOnRequest() {
        interactor.draft = DeckDraft(name: "Recovered", cards: [CardDraft(front: "a", back: "b"), CardDraft(front: "c", back: "d")])
        let presenter = makePresenter()
        presenter.viewDidAppear()
        presenter.viewDidAppear()
        XCTAssertEqual(wireframe.restoreOffers, 1)
        wireframe.restore?()
        XCTAssertEqual(presenter.draft.name, "Recovered")
        XCTAssertEqual(view.dirty.last, true)
    }

    func test_decliningTheDraftDiscardsItAndCollectsItsPictures() {
        interactor.draft = DeckDraft(name: "Recovered")
        let presenter = makePresenter()
        presenter.viewDidAppear()
        wireframe.declineRestore?()
        XCTAssertEqual(interactor.discardedDrafts.count, 1)
        XCTAssertEqual(interactor.collectCount, 1)
        XCTAssertEqual(presenter.draft.name, "")
    }

    // MARK: Leaving

    func test_closingACleanEditorLeavesImmediately() {
        let presenter = makePresenter()
        presenter.close()
        XCTAssertEqual(wireframe.closeCount, 1)
        XCTAssertEqual(wireframe.discardPrompts, 0)
    }

    func test_closingADirtyEditorAsksAndDiscardsOnlyAfterConfirmation() {
        let presenter = makePresenter()
        presenter.updateName("Typing")
        presenter.close()
        XCTAssertEqual(wireframe.closeCount, 0)
        XCTAssertEqual(wireframe.discardPrompts, 1)
        wireframe.confirmDiscard?()
        XCTAssertEqual(wireframe.closeCount, 1)
        XCTAssertEqual(interactor.collectCount, 1)
        XCTAssertEqual(interactor.discardedDrafts.count, 1)
    }

    // MARK: Cards

    func test_insertDuplicateMoveAndDelete() {
        let presenter = makePresenter()
        fill(presenter)
        presenter.insertCard(after: 0)
        XCTAssertEqual(view.inserted.last, 1)
        XCTAssertEqual(view.focused.last?.index, 1)
        presenter.updateField(.front, ofCardAt: 1, text: "mid")
        presenter.updateField(.back, ofCardAt: 1, text: "mid")
        presenter.duplicateCard(at: 1)
        XCTAssertEqual(presenter.draft.cards.map(\.front), ["F0", "mid", "mid", "F1"])
        XCTAssertNotEqual(presenter.draft.cards[1].id, presenter.draft.cards[2].id, "A duplicate is a new card")
        presenter.moveCard(at: 3, by: -3)
        XCTAssertEqual(presenter.draft.cards.map(\.front), ["F1", "F0", "mid", "mid"])
        XCTAssertEqual(view.moved.last?.1, 0)
        presenter.deleteCard(at: 0)
        XCTAssertEqual(presenter.draft.cards.map(\.front), ["F0", "mid", "mid"])
    }

    func test_deletingACardWithContentAsksFirstButAnEmptyOneDoesNot() {
        let presenter = makePresenter()
        presenter.updateField(.front, ofCardAt: 0, text: "keep me")
        presenter.requestDeleteCard(at: 0)
        XCTAssertEqual(presenter.draft.cards.count, 2)
        XCTAssertEqual(wireframe.deleteCardPrompts, [1])
        wireframe.confirmDeleteCard?()
        XCTAssertEqual(presenter.draft.cards.count, 1)
        presenter.requestDeleteCard(at: 0)
        XCTAssertEqual(presenter.draft.cards.count, 0, "An untouched card is removed without a prompt")
    }

    func test_reorderFromTheTableOnlyChangesTheDraft() {
        let presenter = makePresenter()
        fill(presenter)
        presenter.moveCard(from: 0, to: 1)
        XCTAssertEqual(presenter.draft.cards.map(\.front), ["F1", "F0"])
        XCTAssertTrue(view.moved.isEmpty, "The table already moved the row itself")
    }

    func test_theDeckCannotGrowBeyondTheLimit() throws {
        let presenter = makePresenter()
        _ = try presenter.importCards(from: (0..<DeckDraft.maximumCards).map { "f\($0)|b\($0)" }.joined(separator: "\n")).get()
        presenter.insertCard(after: nil)
        XCTAssertEqual(presenter.draft.cards.count, DeckDraft.maximumCards)
        XCTAssertEqual(wireframe.alerts.count, 1)
    }

    func test_returnMovesThroughFieldsAndInsertsACardAfterTheLastOne() {
        let presenter = makePresenter()
        presenter.focusNext(after: 0, field: .front)
        XCTAssertEqual(view.focused.last?.field, .back)
        presenter.focusNext(after: 0, field: .back)
        XCTAssertEqual(view.focused.last?.index, 1)
        presenter.focusNext(after: 1, field: .back)
        XCTAssertEqual(presenter.draft.cards.count, 3)
    }

    // MARK: Import

    func test_importReplacesUntouchedBlankCardsAndKeepsWhatWasTyped() throws {
        let presenter = makePresenter()
        presenter.updateField(.front, ofCardAt: 0, text: "typed")
        presenter.updateField(.back, ofCardAt: 0, text: "typed back")
        let count = try presenter.importCards(from: "犬|chó\n猫|mèo|https://example.com/cat.jpg").get()
        XCTAssertEqual(count, 2)
        XCTAssertEqual(presenter.draft.cards.map(\.front), ["typed", "犬", "猫"])
        XCTAssertEqual(presenter.draft.cards.last?.imageReference, "https://example.com/cat.jpg")
        XCTAssertTrue(view.reloads > 0)
    }

    func test_aBadImportChangesNothing() {
        let presenter = makePresenter()
        let result = presenter.importCards(from: "ok|fine\nbroken")
        guard case .failure(let failure) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(failure, .invalidLine(2))
        XCTAssertTrue(presenter.draft.cards.allSatisfy(\.isEmpty))
    }

    func test_anImportThatWouldExceedTheLimitIsRejected() {
        let presenter = makePresenter()
        _ = presenter.importCards(from: (0..<150).map { "f\($0)|b\($0)" }.joined(separator: "\n"))
        let result = presenter.importCards(from: (0..<51).map { "g\($0)|c\($0)" }.joined(separator: "\n"))
        guard case .failure(let failure) = result else { return XCTFail("expected failure") }
        XCTAssertEqual(failure, .tooManyRows)
        XCTAssertEqual(presenter.draft.cards.count, 150)
    }

    // MARK: Pictures

    func test_aStoredPictureIsAttachedToItsCard() {
        interactor.storeResult = .just("local-image:new.jpg")
        let presenter = makePresenter()
        presenter.setPicture(fromData: Data([1]), forCardAt: 1)
        XCTAssertEqual(presenter.draft.cards[1].imageReference, "local-image:new.jpg")
        XCTAssertTrue(presenter.busyCardIds.isEmpty)
    }

    func test_aPictureFailureIsReportedAndLeavesTheCardUnchanged() {
        interactor.storeResult = .error(CardImageError.unreadable)
        let presenter = makePresenter()
        presenter.setPicture(fromData: Data(), forCardAt: 0)
        XCTAssertEqual(presenter.draft.cards[0].imageReference, "")
        XCTAssertEqual(wireframe.alerts.count, 1)
        XCTAssertTrue(presenter.busyCardIds.isEmpty)
    }

    func test_aPictureThatArrivesAfterTheCardMovedStillGoesToTheRightCard() {
        let pending = PublishSubjectBox()
        interactor.storeResult = pending.single
        let presenter = makePresenter()
        fill(presenter)
        presenter.setPicture(fromData: Data([1]), forCardAt: 0)
        XCTAssertEqual(presenter.busyCardIds.count, 1)
        presenter.moveCard(from: 0, to: 1)
        pending.succeed("local-image:late.jpg")
        XCTAssertEqual(presenter.draft.cards.first { $0.front == "F0" }?.imageReference, "local-image:late.jpg")
    }

    func test_savingWhileAPictureIsStillLoadingIsRefusedSoThePictureIsNotLost() {
        let pending = PublishSubjectBox()
        interactor.storeResult = pending.single
        let presenter = makePresenter()
        fill(presenter)
        presenter.setPicture(fromData: Data([1]), forCardAt: 0)
        presenter.save()
        XCTAssertTrue(interactor.saved.isEmpty)
        XCTAssertEqual(wireframe.alerts.count, 1)
        XCTAssertEqual(wireframe.closeCount, 0)
        pending.succeed("local-image:done.jpg")
        presenter.save()
        XCTAssertEqual(interactor.saved.first?.cards.first?.imageReference, "local-image:done.jpg")
    }

    func test_aPictureForADeletedCardIsIgnored() {
        let pending = PublishSubjectBox()
        interactor.storeResult = pending.single
        let presenter = makePresenter()
        presenter.setPicture(fromData: Data([1]), forCardAt: 0)
        presenter.deleteCard(at: 0)
        pending.succeed("local-image:late.jpg")
        XCTAssertFalse(presenter.draft.cards.contains { $0.imageReference == "local-image:late.jpg" })
    }

    func test_webAddressesMustBeHTTPSAndAreDownloadedThroughTheInteractor() {
        let presenter = makePresenter()
        presenter.setPicture(fromAddress: "http://example.com/a.jpg", forCardAt: 0)
        XCTAssertEqual(wireframe.alerts.count, 1)
        XCTAssertTrue(interactor.downloaded.isEmpty)
        interactor.downloadResult = .just("local-image:dl.jpg")
        presenter.setPicture(fromAddress: "https://example.com/a.jpg", forCardAt: 0)
        XCTAssertEqual(interactor.downloaded, [URL(string: "https://example.com/a.jpg")!])
        XCTAssertEqual(presenter.draft.cards[0].imageReference, "local-image:dl.jpg")
    }

    func test_removingAPictureClearsTheReference() {
        interactor.decks["d1"] = savedDeck()
        let presenter = makePresenter(deckId: "d1")
        presenter.removePicture(fromCardAt: 0)
        XCTAssertEqual(presenter.draft.cards[0].imageReference, "")
    }

    // MARK: Suggestions

    /// Lets the debounce (40 ms) fire and the asynchronous pipeline deliver.
    private func settle(_ seconds: TimeInterval = 0.2) {
        let done = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
        wait(for: [done], timeout: seconds + 2)
    }

    private func entry(_ japanese: String = "犬", reading: String = "いぬ", _ vietnamese: String = "chó", typedJapanese: Bool = true) -> CardSuggestion {
        CardSuggestion(japanese: japanese, reading: reading, vietnamese: vietnamese, typedJapanese: typedJapanese)
    }

    func test_aBurstOfKeystrokesLooksUpOnlyTheFinalText() {
        let presenter = makePresenter()
        for text in ["食", "食べ", "食べる"] { presenter.updateField(.front, ofCardAt: 0, text: text) }
        settle()
        XCTAssertEqual(suggestions.queries.map(\.text), ["食べる"], "Debounced: one lookup, for what the learner ended up typing")
        XCTAssertEqual(suggestions.queries.first?.isJapanese, true)
    }

    func test_aNewKeystrokeCancelsTheLookupStillRunning() {
        let presenter = makePresenter()
        presenter.updateField(.front, ofCardAt: 0, text: "犬")
        settle()
        XCTAssertEqual(suggestions.disposed, [])
        presenter.updateField(.front, ofCardAt: 0, text: "犬小屋")
        settle()
        XCTAssertEqual(suggestions.queries.map(\.text), ["犬", "犬小屋"])
        XCTAssertEqual(suggestions.disposed, [0], "The older lookup is disposed, which cancels its network request")
    }

    func test_aLateAnswerForOlderTextNeverOverwritesTheLatest() {
        let presenter = makePresenter()
        presenter.updateField(.front, ofCardAt: 0, text: "犬")
        settle()
        presenter.updateField(.front, ofCardAt: 0, text: "猫")
        settle()
        suggestions.subjects[1].onNext(.results([entry("猫", reading: "ねこ", "mèo")]))
        suggestions.subjects[0].onNext(.results([entry()]))
        settle(0.05)
        XCTAssertEqual(view.suggestions.last, .results([entry("猫", reading: "ねこ", "mèo")]))
    }

    func test_anAnswerThatArrivesAfterTheTextWasClearedIsDropped() {
        let presenter = makePresenter()
        presenter.updateField(.front, ofCardAt: 0, text: "犬")
        settle()
        presenter.updateField(.front, ofCardAt: 0, text: "")
        suggestions.subjects[0].onNext(.results([entry()]))
        XCTAssertEqual(view.suggestions.last, .hidden)
        XCTAssertFalse(view.suggestions.contains(.results([entry()])))
    }

    func test_nothingIsLookedUpWhileAJapaneseCompositionIsOpen() {
        let presenter = makePresenter()
        presenter.updateField(.front, ofCardAt: 0, text: "た", isComposing: true)
        presenter.updateField(.front, ofCardAt: 0, text: "たべ", isComposing: true)
        settle()
        XCTAssertTrue(suggestions.queries.isEmpty, "Marked (uncommitted) text is not a word yet")
        XCTAssertEqual(view.suggestions.last, .hidden)
        presenter.updateField(.front, ofCardAt: 0, text: "食べ", isComposing: false)
        settle()
        XCTAssertEqual(suggestions.queries.map(\.text), ["食べ"])
    }

    func test_aCompositionStartedAfterATypedWordWithdrawsItsPendingLookup() {
        let presenter = makePresenter()
        presenter.updateField(.front, ofCardAt: 0, text: "食", isComposing: false)
        presenter.updateField(.front, ofCardAt: 0, text: "食べ", isComposing: true)
        settle()
        XCTAssertTrue(suggestions.queries.isEmpty)
    }

    func test_oneLatinLetterAndWholeSentencesAreNotLookedUp() {
        let presenter = makePresenter()
        presenter.updateField(.back, ofCardAt: 0, text: "a")
        settle()
        presenter.updateField(.back, ofCardAt: 0, text: String(repeating: "đi học ", count: 10))
        settle()
        XCTAssertTrue(suggestions.queries.isEmpty)
        XCTAssertNotNil(SuggestionQuery("犬"), "One Japanese character is already a word")
    }

    func test_theScriptTypedDecidesTheLookupNotTheDeckDirection() {
        let presenter = makePresenter()
        presenter.updateField(.front, ofCardAt: 0, text: "ăn cơm")
        settle()
        XCTAssertEqual(suggestions.queries.last?.isJapanese, false, "Vietnamese typed on the front of a Japanese–Vietnamese deck")
    }

    func test_choosingAnOfflineEntryWhileTheOnlineLookupRunsKeepsItsLateAnswerOut() {
        let presenter = makePresenter()
        presenter.updateField(.front, ofCardAt: 0, text: "犬")
        settle()
        suggestions.subjects[0].onNext(.searching(partial: [entry()]))
        settle(0.05)
        presenter.apply(entry(), toCardAt: 0)
        suggestions.subjects[0].onNext(.results([entry("犬小屋", reading: "いぬごや", "cũi chó")]))
        settle(0.05)
        XCTAssertEqual(view.suggestions.last, .hidden, "The bar stays closed after a choice")
    }

    func test_focusMovingToAnotherFieldWithdrawsTheSuggestions() {
        let presenter = makePresenter()
        presenter.updateField(.front, ofCardAt: 0, text: "犬")
        settle()
        presenter.suggestionsNotNeeded()
        suggestions.subjects[0].onNext(.results([entry()]))
        XCTAssertEqual(view.suggestions.last, .hidden)
    }

    func test_applyingAJapaneseEntryFillsExpressionReadingAndMeaning() {
        let presenter = makePresenter()
        presenter.updateField(.front, ofCardAt: 0, text: "犬")
        presenter.apply(entry(), toCardAt: 0)
        XCTAssertEqual(presenter.draft.cards[0].front, "犬")
        XCTAssertEqual(presenter.draft.cards[0].reading, "いぬ")
        XCTAssertEqual(presenter.draft.cards[0].back, "chó")
        XCTAssertTrue(wireframe.replacements.isEmpty, "Filling empty fields never asks")
    }

    func test_japaneseTypedOnTheBackPutsTheReadingWithTheAnswer() {
        let presenter = makePresenter()
        presenter.updateField(.back, ofCardAt: 0, text: "犬")
        presenter.apply(entry(), toCardAt: 0)
        XCTAssertEqual(presenter.draft.cards[0].back, "犬")
        XCTAssertEqual(presenter.draft.cards[0].front, "chó")
        XCTAssertEqual(presenter.draft.cards[0].note, "いぬ", "The front is Vietnamese here, so the reading belongs with the Japanese answer")
        XCTAssertEqual(presenter.draft.cards[0].reading, "")
    }

    func test_vietnameseTypedOnTheFrontCompletesItAndFillsTheJapaneseSide() {
        let presenter = makePresenter()
        presenter.updateField(.front, ofCardAt: 0, text: "chó")
        presenter.apply(entry(typedJapanese: false), toCardAt: 0)
        XCTAssertEqual(presenter.draft.cards[0].front, "chó")
        XCTAssertEqual(presenter.draft.cards[0].back, "犬")
        XCTAssertEqual(presenter.draft.cards[0].note, "いぬ")
    }

    func test_aSuggestionNeverReplacesAnEditedFieldWithoutConfirmation() {
        let presenter = makePresenter()
        presenter.updateField(.back, ofCardAt: 0, text: "my own meaning")
        presenter.updateField(.front, ofCardAt: 0, text: "犬")
        presenter.apply(entry(), toCardAt: 0)
        XCTAssertEqual(presenter.draft.cards[0].front, "犬")
        XCTAssertEqual(presenter.draft.cards[0].reading, "いぬ", "Empty fields are still filled")
        XCTAssertEqual(presenter.draft.cards[0].back, "my own meaning", "The learner's own text stays until they confirm")
        XCTAssertEqual(wireframe.replacements.first, [ReplacementProposal(field: .back, current: "my own meaning", proposed: "chó")])
        wireframe.confirmReplacement?()
        XCTAssertEqual(presenter.draft.cards[0].back, "chó")
    }

    func test_keepingMyTextLeavesTheCardAsItWas() {
        let presenter = makePresenter()
        presenter.updateField(.back, ofCardAt: 0, text: "my own meaning")
        presenter.updateField(.front, ofCardAt: 0, text: "犬")
        presenter.apply(entry(), toCardAt: 0)
        // The alert's "Keep mine" does nothing: no callback runs.
        XCTAssertEqual(presenter.draft.cards[0].back, "my own meaning")
    }

    func test_textThatAlreadyMatchesTheEntryIsNotAConflict() {
        let presenter = makePresenter()
        presenter.updateField(.back, ofCardAt: 0, text: " chó ")
        presenter.updateField(.front, ofCardAt: 0, text: "犬")
        presenter.apply(entry(), toCardAt: 0)
        XCTAssertTrue(wireframe.replacements.isEmpty)
    }

    func test_aConfirmationForACardThatWasDeletedMeanwhileDoesNothing() {
        let presenter = makePresenter()
        presenter.updateField(.back, ofCardAt: 0, text: "mine")
        presenter.updateField(.front, ofCardAt: 0, text: "犬")
        presenter.apply(entry(), toCardAt: 0)
        presenter.deleteCard(at: 0)
        wireframe.confirmReplacement?()
        XCTAssertEqual(presenter.draft.cards.count, 1)
        XCTAssertNotEqual(presenter.draft.cards[0].back, "chó")
    }

    func test_withoutATypedFieldTheDeckDirectionDecidesWhichSideIsJapanese() {
        let presenter = makePresenter()
        presenter.setDirection(.opposite)
        presenter.apply(entry(typedJapanese: false), toCardAt: 0)
        XCTAssertEqual(presenter.draft.cards[0].front, "chó")
        XCTAssertEqual(presenter.draft.cards[0].back, "犬")
        XCTAssertEqual(presenter.draft.cards[0].reading, "", "The front is Vietnamese in this deck")
    }

    // MARK: Picture search

    func test_theSearchTermIsTheDictionaryMeaningOfAFilledCard() {
        let presenter = makePresenter()
        presenter.updateField(.front, ofCardAt: 0, text: "食べる")
        presenter.apply(entry("食べる", reading: "たべる", "ăn; dùng bữa"), toCardAt: 0)
        presenter.findPictures(forCardAt: 0)
        XCTAssertEqual(wireframe.pictureTerms, ["ăn"])
    }

    func test_withoutADictionaryEntryTheNonJapaneseSideIsTheTermThenTheJapanese() {
        XCTAssertEqual(PictureSearchTerm.make(front: "犬", back: "chó, con chó", applied: nil), "chó")
        XCTAssertEqual(PictureSearchTerm.make(front: "犬", back: "", applied: nil), "犬")
        XCTAssertEqual(PictureSearchTerm.make(front: "", back: "", applied: nil), "")
        let edited = entry("犬", reading: "いぬ", "chó")
        XCTAssertEqual(PictureSearchTerm.make(front: "犬", back: "my own words", applied: edited), "my own words",
                       "A meaning the learner replaced is no longer the dictionary's")
    }

    func test_aChosenPictureIsDownloadedWithItsSourceAndAttachedToTheCard() {
        let presenter = makePresenter()
        presenter.updateField(.front, ofCardAt: 0, text: "犬")
        presenter.findPictures(forCardAt: 0)
        let picture = PictureSuggestion(BJTImageResultDTO(id: "p1", thumbUrl: "https://img.test/t.jpg", fullUrl: "https://img.test/f.jpg", source: "unsplash"))!
        wireframe.pickPicture?(picture)
        XCTAssertEqual(interactor.downloaded, [URL(string: "https://img.test/f.jpg")!])
        XCTAssertEqual(interactor.attributions, [ImageAttribution(source: "unsplash", sourceID: "p1", imageURL: "https://img.test/f.jpg")])
        XCTAssertEqual(presenter.draft.cards[0].imageReference, "local-image:x.jpg")
    }

    func test_pictureSuggestionsOnlyAcceptSecureAddresses() {
        XCTAssertNil(PictureSuggestion(BJTImageResultDTO(id: "p", thumbUrl: "http://img.test/t.jpg", fullUrl: "https://img.test/f.jpg", source: "x")))
        XCTAssertNil(PictureSuggestion(BJTImageResultDTO(id: "p", thumbUrl: "https://img.test/t.jpg", fullUrl: "file:///etc/passwd", source: "x")))
        XCTAssertNil(PictureSuggestion(BJTImageResultDTO(id: "", thumbUrl: "https://img.test/t.jpg", fullUrl: "https://img.test/f.jpg", source: "x")))
    }

}

// MARK: - Doubles

private final class PublishSubjectBox {
    private let subject = PublishSubject<String>()
    var single: Single<String> { subject.asSingle() }
    func succeed(_ value: String) { subject.onNext(value); subject.onCompleted() }
}

private final class FakeSuggestions: DictionarySuggestionInteractorInterface {
    var queries: [SuggestionQuery] = []
    var subjects: [PublishSubject<SuggestionsState>] = []
    var disposed: [Int] = []

    func suggestions(for query: SuggestionQuery) -> Observable<SuggestionsState> {
        queries.append(query)
        let index = queries.count - 1
        let subject = PublishSubject<SuggestionsState>()
        subjects.append(subject)
        return subject.do(onDispose: { [weak self] in self?.disposed.append(index) })
    }
}

private final class FakeEditorInteractor: CreateDeskInteractorInterface {
    var decks: [String: DeskEntity] = [:]
    var draft: DeckDraft?
    var saved: [DeckDraft] = []
    var deleted: [String] = []
    var deleteError: Error?
    var saveError: Error?
    var savedDrafts: [DeckDraft] = []
    var discardedDrafts: [String?] = []
    var collectCount = 0
    var storeResult: Single<String> = .just("local-image:x.jpg")
    var downloadResult: Single<String> = .just("local-image:x.jpg")
    var downloaded: [URL] = []
    var attributions: [ImageAttribution] = []

    func deck(withId id: String) -> DeskEntity? { decks[id] }
    func savedDraft(forDeckId deckId: String?) -> DeckDraft? { draft }
    func saveDraft(_ draft: DeckDraft) { savedDrafts.append(draft) }
    func discardDraft(forDeckId deckId: String?) { discardedDrafts.append(deckId) }
    func save(_ draft: DeckDraft) throws {
        if let saveError { throw saveError }
        saved.append(draft)
    }
    func collectUnusedPictures() { collectCount += 1 }
    func deleteDeck(withId id: String) throws {
        if let deleteError { throw deleteError }
        deleted.append(id)
    }
    func storePicture(data: Data) -> Single<String> { storeResult }
    func downloadPicture(from url: URL, attribution: ImageAttribution?) -> Single<String> {
        downloaded.append(url)
        if let attribution { attributions.append(attribution) }
        return downloadResult
    }
}

private final class FakeEditorWireframe: CreateDeskWireframeInterface {
    var closeCount = 0
    var alerts: [String?] = []
    var discardPrompts = 0
    var confirmDiscard: (() -> Void)?
    var deleteCardPrompts: [Int] = []
    var confirmDeleteCard: (() -> Void)?
    var restoreOffers = 0
    var restore: (() -> Void)?
    var declineRestore: (() -> Void)?
    var deleteDeckPrompts: [String] = []
    var confirmDeleteDeck: (() -> Void)?
    var replacements: [[ReplacementProposal]] = []
    var confirmReplacement: (() -> Void)?
    var pictureTerms: [String] = []
    var pickPicture: ((PictureSuggestion) -> Void)?

    func showAlert(with title: String?, message: String?) { alerts.append(message) }
    func close() { closeCount += 1 }
    func confirmDiscard(onDiscard: @escaping () -> Void) { discardPrompts += 1; confirmDiscard = onDiscard }
    func confirmDeleteCard(number: Int, onDelete: @escaping () -> Void) { deleteCardPrompts.append(number); confirmDeleteCard = onDelete }
    func confirmDeleteDeck(named name: String, onDelete: @escaping () -> Void) { deleteDeckPrompts.append(name); confirmDeleteDeck = onDelete }
    func confirmReplace(_ proposals: [ReplacementProposal], onReplace: @escaping () -> Void) {
        replacements.append(proposals)
        confirmReplacement = onReplace
    }
    func showPictureSearch(term: String, onPick: @escaping (PictureSuggestion) -> Void) {
        pictureTerms.append(term)
        pickPicture = onPick
    }
    func offerDraftRestore(restore: @escaping () -> Void, discard: @escaping () -> Void) {
        restoreOffers += 1
        self.restore = restore
        declineRestore = discard
    }
}

private final class SpyEditorView: CreateDeskViewInterface {
    var reloads = 0
    var inserted: [Int] = []
    var deleted: [Int] = []
    var moved: [(Int, Int)] = []
    var issues: [(issues: [DeckValidationIssue], reveal: Bool)] = []
    var saving: [Bool] = []
    var dirty: [Bool] = []
    var suggestions: [SuggestionsState] = []
    var focused: [(index: Int, field: CardField)] = []

    func reload() { reloads += 1 }
    func insertCard(at index: Int) { inserted.append(index) }
    func deleteCard(at index: Int) { deleted.append(index) }
    func moveCard(from: Int, to: Int) { moved.append((from, to)) }
    func reloadCard(at index: Int) {}
    func reloadDetails() {}
    func showIssues(_ issues: [DeckValidationIssue], reveal: Bool) { self.issues.append((issues, reveal)) }
    func setSaving(_ saving: Bool) { self.saving.append(saving) }
    func setDirty(_ dirty: Bool) { self.dirty.append(dirty) }
    func showSuggestions(_ state: SuggestionsState) { suggestions.append(state) }
    func focus(cardIndex: Int, field: CardField) { focused.append((cardIndex, field)) }
}
