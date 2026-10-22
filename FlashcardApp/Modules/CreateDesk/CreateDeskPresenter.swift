//
//  CreateDeskPresenter.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//  
//

import Foundation
import RxRelay
import RxSwift

/// The text fields of one card in the editor.
enum CardField: Int, CaseIterable {
    case front, back, reading, note
}

/// A dictionary suggestion offered above the keyboard while typing a card.
struct CardSuggestion: Equatable {
    let japanese: String
    let reading: String
    let vietnamese: String
    /// The learner was typing Japanese (so the Japanese side is theirs) or Vietnamese.
    let typedJapanese: Bool

    /// Text of the chip: the headword with its meaning.
    var title: String { "\(japanese) · \(vietnamese)" }
}

protocol CreateDeskViewInterface: AnyObject {
    /// Everything changed (first load, restored draft, import).
    func reload()
    func insertCard(at index: Int)
    func deleteCard(at index: Int)
    func moveCard(from: Int, to: Int)
    func reloadCard(at index: Int)
    func reloadDetails()
    /// `reveal` scrolls to the first problem (a failed save); otherwise the messages only update in place.
    func showIssues(_ issues: [DeckValidationIssue], reveal: Bool)
    func setSaving(_ saving: Bool)
    func setDirty(_ dirty: Bool)
    func showSuggestions(_ suggestions: [CardSuggestion])
    /// Moves the keyboard to a field of a card (after inserting a card or choosing "Next").
    func focus(cardIndex: Int, field: CardField)
}

protocol CreateDeskPresenterInterface: AnyObject {
    var draft: DeckDraft { get }
    var issues: [DeckValidationIssue] { get }
    var busyCardIds: Set<String> { get }
    var isEditingExistingDeck: Bool { get }

    func viewDidLoad()
    func viewDidAppear()
    func updateName(_ text: String)
    func updateDetails(_ text: String)
    func setDirection(_ direction: LanguageSortingType)
    func updateField(_ field: CardField, ofCardAt index: Int, text: String)
    func insertCard(after index: Int?)
    func deleteCard(at index: Int)
    func requestDeleteCard(at index: Int)
    func duplicateCard(at index: Int)
    func moveCard(from: Int, to: Int)
    func moveCard(at index: Int, by offset: Int)
    func focusNext(after index: Int, field: CardField)

    func setPicture(fromData data: Data, forCardAt index: Int)
    func setPicture(fromAddress text: String, forCardAt index: Int)
    func removePicture(fromCardAt index: Int)

    func suggestionsNeeded(cardIndex: Int, field: CardField)
    func apply(_ suggestion: CardSuggestion, toCardAt index: Int)

    func importCards(from text: String) -> Result<Int, BulkDeckImport.Failure>
    func persistDraftNow()
    func save()
    func close()
    /// Only for a stored deck: asks first, then deletes it and closes the editor.
    func deleteDeck()
}

class CreateDeskPresenter {
    private let interactor: CreateDeskInteractorInterface
    private let searchWordInteractor: SearchWordsInteractorInterface
    private let wireframe: CreateDeskWireframeInterface
    private let onFinish: (() -> Void)?
    private let draftSaveDelay: RxTimeInterval
    private let suggestionDelay: RxTimeInterval
    private var disposeBag = DisposeBag()
    private var pictureBag = [String: Disposable]()

    weak var view: CreateDeskViewInterface?

    private(set) var draft: DeckDraft
    private(set) var issues: [DeckValidationIssue] = []
    private(set) var busyCardIds = Set<String>()
    private let deckId: String?
    private let baseline: DeckDraft
    private var isSaving = false
    private var isFinished = false
    private var showsIssues = false
    private var didOfferRestore = false
    private let draftChanged = PublishRelay<Void>()
    private let suggestionRequest = PublishRelay<(cardId: String, field: CardField, text: String)>()

    var isEditingExistingDeck: Bool { baseline.isEditing }
    private var isDirty: Bool { draft != baseline }

    init(interactor: CreateDeskInteractorInterface,
         wireframe: CreateDeskWireframeInterface,
         deckId: String? = nil,
         onFinish: (() -> Void)? = nil,
         searchWordInteractor: SearchWordsInteractorInterface = SearchWordsInteractor(),
         draftSaveDelay: RxTimeInterval = .milliseconds(800),
         suggestionDelay: RxTimeInterval = .milliseconds(300)) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.onFinish = onFinish
        self.searchWordInteractor = searchWordInteractor
        self.draftSaveDelay = draftSaveDelay
        self.suggestionDelay = suggestionDelay
        let loaded = deckId.flatMap { interactor.deck(withId: $0) }
        // An id that no longer resolves (the deck was deleted meanwhile) opens an empty new deck rather than failing.
        self.deckId = loaded?.id
        self.baseline = loaded.map(DeckDraft.init(entity:)) ?? DeckDraft()
        self.draft = baseline
    }

    deinit {
        pictureBag.values.forEach { $0.dispose() }
    }

    // MARK: Draft bookkeeping

    private func didEdit() {
        view?.setDirty(isDirty)
        if showsIssues {
            // After a failed save the problems stay visible and clear as the learner fixes them.
            issues = draft.issues
            showsIssues = !issues.isEmpty
            view?.showIssues(issues, reveal: false)
        }
        draftChanged.accept(())
    }

    /// Writes (or clears, when nothing differs from the stored deck) the recovery draft. A finished editor never writes again.
    func persistDraftNow() {
        guard !isFinished else { return }
        if isDirty { interactor.saveDraft(draft) } else { interactor.discardDraft(forDeckId: deckId) }
    }

    private func bind() {
        draftChanged
            .debounce(draftSaveDelay, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in self?.persistDraftNow() })
            .disposed(by: disposeBag)
        suggestionRequest
            .debounce(suggestionDelay, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] request in self?.search(request) })
            .disposed(by: disposeBag)
    }

    private func search(_ request: (cardId: String, field: CardField, text: String)) {
        let japanese = isJapanese(request.field)
        // The offline dictionary answers per language: Japanese words (with readings) or Vietnamese words.
        let result = searchWordInteractor.searchText(request.text, cardFace: japanese ? .front : .back)
        let suggestions = result.cards.prefix(12).compactMap { card -> CardSuggestion? in
            let japaneseText = japanese ? card.frontText : card.backText
            let vietnameseText = japanese ? card.backText : card.frontText
            guard !japaneseText.isEmpty, !vietnameseText.isEmpty else { return nil }
            let reading = japanese ? card.frontExtraText : ""
            return CardSuggestion(japanese: japaneseText, reading: reading, vietnamese: vietnameseText, typedJapanese: japanese)
        }
        view?.showSuggestions(Array(suggestions))
    }

    /// Whether a field holds Japanese: front for a Japanese–Vietnamese deck, back for Vietnamese–Japanese.
    private func isJapanese(_ field: CardField) -> Bool {
        let japaneseOnFront = draft.sortingLanguage == .normal
        switch field {
        case .front, .reading: return japaneseOnFront
        case .back, .note: return !japaneseOnFront
        }
    }

    private func isValid(_ index: Int) -> Bool { draft.cards.indices.contains(index) }
}

extension CreateDeskPresenter: CreateDeskPresenterInterface {
    func viewDidLoad() {
        bind()
        view?.reload()
        view?.setDirty(false)
    }

    /// Offered once the editor is on screen (an alert cannot be presented from `viewDidLoad`).
    func viewDidAppear() {
        guard !didOfferRestore else { return }
        didOfferRestore = true
        guard let stored = interactor.savedDraft(forDeckId: deckId), stored != baseline else { return }
        wireframe.offerDraftRestore(restore: { [weak self] in
            guard let self else { return }
            self.draft = stored
            self.view?.reload()
            self.view?.setDirty(self.isDirty)
        }, discard: { [weak self] in
            self?.interactor.discardDraft(forDeckId: self?.deckId)
            self?.interactor.collectUnusedPictures()
        })
    }

    func updateName(_ text: String) {
        draft.name = text
        didEdit()
    }

    func updateDetails(_ text: String) {
        draft.details = text
        didEdit()
    }

    func setDirection(_ direction: LanguageSortingType) {
        guard draft.sortingLanguage != direction else { return }
        draft.sortingLanguage = direction
        view?.reloadDetails()
        didEdit()
    }

    func updateField(_ field: CardField, ofCardAt index: Int, text: String) {
        guard isValid(index) else { return }
        switch field {
        case .front: draft.cards[index].front = text
        case .back: draft.cards[index].back = text
        case .reading: draft.cards[index].reading = text
        case .note: draft.cards[index].note = text
        }
        didEdit()
        if field == .front || field == .back { suggestionsNeeded(cardIndex: index, field: field) }
    }

    func insertCard(after index: Int?) {
        guard draft.cards.count < DeckDraft.maximumCards else {
            return wireframe.showAlert(with: NSLocalizedString("Error", comment: ""), message: DeckValidationIssue.tooManyCards.appError.errorDescription)
        }
        let position = index.map { min($0 + 1, draft.cards.count) } ?? draft.cards.count
        draft.cards.insert(CardDraft(), at: position)
        view?.insertCard(at: position)
        view?.focus(cardIndex: position, field: .front)
        didEdit()
    }

    func requestDeleteCard(at index: Int) {
        guard isValid(index) else { return }
        if draft.cards[index].isEmpty { return deleteCard(at: index) }
        wireframe.confirmDeleteCard(number: index + 1) { [weak self] in self?.deleteCard(at: index) }
    }

    func deleteCard(at index: Int) {
        guard isValid(index) else { return }
        let removed = draft.cards.remove(at: index)
        pictureBag.removeValue(forKey: removed.id)?.dispose()
        busyCardIds.remove(removed.id)
        view?.deleteCard(at: index)
        didEdit()
    }

    func duplicateCard(at index: Int) {
        guard isValid(index), draft.cards.count < DeckDraft.maximumCards else { return }
        var copy = draft.cards[index]
        copy.id = UUID().uuidString
        draft.cards.insert(copy, at: index + 1)
        view?.insertCard(at: index + 1)
        didEdit()
    }

    func moveCard(from: Int, to: Int) {
        guard isValid(from), isValid(to), from != to else { return }
        draft.cards.insert(draft.cards.remove(at: from), at: to)
        didEdit()
    }

    /// Move by one position with the menu or a VoiceOver action; the table animates the row.
    func moveCard(at index: Int, by offset: Int) {
        let target = index + offset
        guard isValid(index), isValid(target) else { return }
        moveCard(from: index, to: target)
        view?.moveCard(from: index, to: target)
    }

    func focusNext(after index: Int, field: CardField) {
        switch field {
        case .front: view?.focus(cardIndex: index, field: .back)
        case .reading: view?.focus(cardIndex: index, field: .back)
        case .back, .note:
            if isValid(index + 1) { view?.focus(cardIndex: index + 1, field: .front) } else { insertCard(after: index) }
        }
    }

    // MARK: Pictures

    func setPicture(fromData data: Data, forCardAt index: Int) {
        run(interactor.storePicture(data: data), forCardAt: index)
    }

    func setPicture(fromAddress text: String, forCardAt index: Int) {
        do {
            let url = try RemoteImageLoader.validatedURL(text)
            run(interactor.downloadPicture(from: url), forCardAt: index)
        } catch {
            wireframe.showAlert(with: NSLocalizedString("Couldn't add the picture", comment: ""), message: (error as? LocalizedError)?.errorDescription)
        }
    }

    private func run(_ source: Single<String>, forCardAt index: Int) {
        guard isValid(index) else { return }
        let cardId = draft.cards[index].id
        pictureBag.removeValue(forKey: cardId)?.dispose()
        busyCardIds.insert(cardId)
        view?.reloadCard(at: index)
        pictureBag[cardId] = source
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] reference in
                guard let self else { return }
                self.pictureBag[cardId] = nil
                self.busyCardIds.remove(cardId)
                // The card may have moved or been deleted while the picture loaded: find it again by id.
                guard let current = self.draft.cards.firstIndex(where: { $0.id == cardId }) else { return }
                self.draft.cards[current].imageReference = reference
                self.view?.reloadCard(at: current)
                self.didEdit()
            }, onFailure: { [weak self] error in
                guard let self else { return }
                self.pictureBag[cardId] = nil
                self.busyCardIds.remove(cardId)
                if let current = self.draft.cards.firstIndex(where: { $0.id == cardId }) { self.view?.reloadCard(at: current) }
                self.wireframe.showAlert(with: NSLocalizedString("Couldn't add the picture", comment: ""),
                                         message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            })
    }

    func removePicture(fromCardAt index: Int) {
        guard isValid(index) else { return }
        pictureBag.removeValue(forKey: draft.cards[index].id)?.dispose()
        busyCardIds.remove(draft.cards[index].id)
        draft.cards[index].imageReference = ""
        view?.reloadCard(at: index)
        didEdit()
    }

    // MARK: Suggestions

    func suggestionsNeeded(cardIndex: Int, field: CardField) {
        guard isValid(cardIndex), field == .front || field == .back else { return }
        let card = draft.cards[cardIndex]
        suggestionRequest.accept((card.id, field, field == .front ? card.front : card.back))
    }

    /// Fills the card with the suggestion. The side the learner was typing in is replaced; the other side, and the
    /// reading, are only filled when empty, so nothing already written is overwritten.
    func apply(_ suggestion: CardSuggestion, toCardAt index: Int) {
        guard isValid(index) else { return }
        let japaneseOnFront = draft.sortingLanguage == .normal
        var card = draft.cards[index]
        func fill(japanese: Bool, with text: String, overwrite: Bool) {
            let onFront = japanese == japaneseOnFront
            let current = onFront ? card.front : card.back
            guard overwrite || current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            if onFront { card.front = text } else { card.back = text }
        }
        fill(japanese: true, with: suggestion.japanese, overwrite: suggestion.typedJapanese)
        fill(japanese: false, with: suggestion.vietnamese, overwrite: !suggestion.typedJapanese)
        if japaneseOnFront, !suggestion.reading.isEmpty, card.reading.isEmpty { card.reading = suggestion.reading }
        draft.cards[index] = card
        view?.reloadCard(at: index)
        didEdit()
    }

    // MARK: Import

    func importCards(from text: String) -> Result<Int, BulkDeckImport.Failure> {
        switch BulkDeckImport.parse(text) {
        case .failure(let failure):
            return .failure(failure)
        case .success(let rows):
            let kept = draft.cards.filter { !$0.isEmpty }
            guard kept.count + rows.count <= DeckDraft.maximumCards else { return .failure(.tooManyRows) }
            // Untouched blank cards (a new deck starts with two) make way for the imported ones.
            draft.cards = kept + rows.map { CardDraft(front: $0.front, back: $0.back, imageReference: $0.imageUrl ?? "") }
            while draft.cards.count < DeckDraft.minimumCards { draft.cards.append(CardDraft()) }
            view?.reload()
            didEdit()
            return .success(rows.count)
        }
    }

    // MARK: Saving and leaving

    func save() {
        guard !isSaving else { return }
        // A picture still being stored or downloaded would be lost by closing the editor now.
        guard busyCardIds.isEmpty else {
            wireframe.showAlert(with: NSLocalizedString("Please wait", comment: ""),
                                message: NSLocalizedString("A picture is still being added. Save again in a moment.", comment: ""))
            return
        }
        issues = draft.issues
        guard issues.isEmpty else {
            showsIssues = true
            view?.showIssues(issues, reveal: true)
            return
        }
        isSaving = true
        view?.setSaving(true)
        do {
            try interactor.save(draft)
            isFinished = true
            onFinish?()
            wireframe.close()
        } catch {
            isSaving = false
            view?.setSaving(false)
            wireframe.showAlert(with: NSLocalizedString("Error", comment: ""),
                                message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func close() {
        guard isDirty else { return finish(discardingDraft: true) }
        wireframe.confirmDiscard(onDiscard: { [weak self] in self?.finish(discardingDraft: true) })
    }

    func deleteDeck() {
        guard let id = deckId, !isFinished else { return }
        wireframe.confirmDeleteDeck(named: baseline.name) { [weak self] in
            guard let self, !self.isFinished else { return }
            do {
                try self.interactor.deleteDeck(withId: id)
            } catch {
                self.wireframe.showAlert(with: NSLocalizedString("Error", comment: ""),
                                         message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
                return
            }
            self.pictureBag.values.forEach { $0.dispose() }
            self.isFinished = true
            self.onFinish?()
            self.wireframe.close()
        }
    }

    private func finish(discardingDraft: Bool) {
        isFinished = true
        if discardingDraft {
            interactor.discardDraft(forDeckId: deckId)
            interactor.collectUnusedPictures()
        }
        wireframe.close()
    }
}
