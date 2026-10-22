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
    func showSuggestions(_ state: SuggestionsState)
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
    /// `isComposing`: the text still holds an uncommitted Japanese IME composition, so it is not looked up yet.
    func updateField(_ field: CardField, ofCardAt index: Int, text: String, isComposing: Bool)
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
    /// Opens the picture search for the card, prefilled with a search term taken from the card.
    func findPictures(forCardAt index: Int)

    func suggestionsNeeded(cardIndex: Int, field: CardField)
    func suggestionsNotNeeded()
    func apply(_ suggestion: CardSuggestion, toCardAt index: Int)

    func importCards(from text: String) -> Result<Int, BulkDeckImport.Failure>
    func persistDraftNow()
    func save()
    func close()
    /// Only for a stored deck: asks first, then deletes it and closes the editor.
    func deleteDeck()
}

extension CreateDeskPresenterInterface {
    func updateField(_ field: CardField, ofCardAt index: Int, text: String) {
        updateField(field, ofCardAt: index, text: text, isComposing: false)
    }
}

/// A field that already holds different text than the dictionary entry proposes.
struct ReplacementProposal: Equatable {
    let field: CardField
    let current: String
    let proposed: String
}

/// The search term offered for a card's picture: the dictionary meaning when the card was filled from the dictionary
/// (a verified everyday word), otherwise whichever side of the card is not Japanese, otherwise the Japanese side.
enum PictureSearchTerm {
    static func make(front: String, back: String, applied: CardSuggestion?) -> String {
        let sides = [front, back].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if let applied, sides.contains(applied.vietnamese.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return JapaneseText.firstGloss(of: applied.vietnamese)
        }
        if let meaning = sides.first(where: { !JapaneseText.containsJapanese($0) }) { return JapaneseText.firstGloss(of: meaning) }
        return sides.first ?? ""
    }
}

class CreateDeskPresenter {
    private let interactor: CreateDeskInteractorInterface
    private let suggestionInteractor: DictionarySuggestionInteractorInterface
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
    /// What the suggestion bar currently answers: a lookup for `text` typed into a field of a card.
    private struct SuggestionRequest: Equatable {
        let cardId: String
        let field: CardField
        let query: SuggestionQuery
    }
    /// `nil` withdraws the pending request (composing, focus left, text too short).
    private let suggestionInput = PublishRelay<SuggestionRequest?>()
    /// Set synchronously with every input, so a response that arrives late can tell it is no longer wanted.
    private var currentSuggestionRequest: SuggestionRequest?
    /// The field the learner last typed into, and the word picked from the dictionary for each card.
    private var suggestionSource: (cardId: String, field: CardField)?
    private var appliedEntries = [String: CardSuggestion]()
    private let scheduler: SchedulerType

    var isEditingExistingDeck: Bool { baseline.isEditing }
    private var isDirty: Bool { draft != baseline }

    init(interactor: CreateDeskInteractorInterface,
         wireframe: CreateDeskWireframeInterface,
         deckId: String? = nil,
         onFinish: (() -> Void)? = nil,
         suggestionInteractor: DictionarySuggestionInteractorInterface = DictionarySuggestionInteractor(),
         draftSaveDelay: RxTimeInterval = .milliseconds(800),
         suggestionDelay: RxTimeInterval = .milliseconds(300),
         scheduler: SchedulerType = MainScheduler.instance) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.onFinish = onFinish
        self.suggestionInteractor = suggestionInteractor
        self.scheduler = scheduler
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
        // ~300 ms after the last keystroke; a newer input replaces the pending one, and `flatMapLatest` disposes the
        // previous lookup, which cancels its network request.
        suggestionInput
            .debounce(suggestionDelay, scheduler: scheduler)
            .flatMapLatest { [weak self] request -> Observable<(SuggestionRequest, SuggestionsState)?> in
                guard let self, let request else { return .just(nil) }
                return self.suggestionInteractor.suggestions(for: request.query)
                    .observe(on: MainScheduler.instance)
                    .map { (request, $0) }
                    .catchAndReturn((request, .unavailable))
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] update in self?.deliver(update) })
            .disposed(by: disposeBag)
    }

    /// Shows a lookup result only if it still answers what is being typed.
    private func deliver(_ update: (SuggestionRequest, SuggestionsState)?) {
        guard let (request, state) = update else {
            view?.showSuggestions(.hidden)
            return
        }
        guard request == currentSuggestionRequest else { return }
        view?.showSuggestions(state)
    }

    private func requestSuggestions(cardIndex: Int, field: CardField, text: String, isComposing: Bool) {
        guard isValid(cardIndex), field == .front || field == .back else { return }
        let cardId = draft.cards[cardIndex].id
        suggestionSource = (cardId, field)
        guard !isComposing, let query = SuggestionQuery(text) else { return withdrawSuggestions() }
        let request = SuggestionRequest(cardId: cardId, field: field, query: query)
        currentSuggestionRequest = request
        suggestionInput.accept(request)
    }

    private func withdrawSuggestions() {
        currentSuggestionRequest = nil
        view?.showSuggestions(.hidden)
        suggestionInput.accept(nil)
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

    func updateField(_ field: CardField, ofCardAt index: Int, text: String, isComposing: Bool) {
        guard isValid(index) else { return }
        switch field {
        case .front: draft.cards[index].front = text
        case .back: draft.cards[index].back = text
        case .reading: draft.cards[index].reading = text
        case .note: draft.cards[index].note = text
        }
        didEdit()
        if field == .front || field == .back { requestSuggestions(cardIndex: index, field: field, text: text, isComposing: isComposing) }
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
        requestSuggestions(cardIndex: cardIndex, field: field, text: field == .front ? card.front : card.back, isComposing: false)
    }

    func suggestionsNotNeeded() {
        suggestionSource = nil
        withdrawSuggestions()
    }

    /// Fills the card from a dictionary entry. The field being typed in is completed with the entry's word in the
    /// language typed. Every other field is filled only while empty; a field that already holds different text is
    /// kept unless the learner confirms replacing it, so nothing written by hand is lost silently.
    func apply(_ suggestion: CardSuggestion, toCardAt index: Int) {
        guard isValid(index) else { return }
        // The lookup that offered this entry is done: its late online answer must not bring the bar back.
        withdrawSuggestions()
        let card = draft.cards[index]
        let (japaneseOnFront, typedField) = layout(for: suggestion, card: card)
        let japaneseField: CardField = japaneseOnFront ? .front : .back
        let vietnameseField: CardField = japaneseOnFront ? .back : .front
        // The reading describes the Japanese side: under the front when that is Japanese, else with the answer.
        let readingField: CardField = japaneseOnFront ? .reading : .note
        var proposals: [(field: CardField, value: String)] = [(japaneseField, suggestion.japanese), (vietnameseField, suggestion.vietnamese)]
        if !suggestion.reading.isEmpty { proposals.append((readingField, suggestion.reading)) }

        var fills: [(CardField, String)] = []
        var conflicts: [ReplacementProposal] = []
        for (field, value) in proposals {
            let current = text(of: field, in: card).trimmingCharacters(in: .whitespacesAndNewlines)
            if field == typedField || current.isEmpty {
                fills.append((field, value))
            } else if current != value {
                conflicts.append(ReplacementProposal(field: field, current: current, proposed: value))
            }
        }
        let cardId = card.id
        appliedEntries[cardId] = suggestion
        write(fills, toCardWithId: cardId)
        guard !conflicts.isEmpty else { return }
        wireframe.confirmReplace(conflicts, onReplace: { [weak self] in
            self?.write(conflicts.map { ($0.field, $0.proposed) }, toCardWithId: cardId)
        })
    }

    /// Which side is Japanese and which field the learner typed in. The field typed in decides when known (so mixed-direction
    /// decks work); otherwise the deck's direction does.
    private func layout(for suggestion: CardSuggestion, card: CardDraft) -> (japaneseOnFront: Bool, typedField: CardField) {
        if let source = suggestionSource, source.cardId == card.id {
            return (suggestion.typedJapanese == (source.field == .front), source.field)
        }
        let japaneseOnFront = draft.sortingLanguage == .normal
        return (japaneseOnFront, suggestion.typedJapanese == japaneseOnFront ? .front : .back)
    }

    private func text(of field: CardField, in card: CardDraft) -> String {
        switch field {
        case .front: return card.front
        case .back: return card.back
        case .reading: return card.reading
        case .note: return card.note
        }
    }

    private func write(_ values: [(CardField, String)], toCardWithId id: String) {
        // The card may have moved or been deleted while a confirmation was open: find it again by id.
        guard let index = draft.cards.firstIndex(where: { $0.id == id }), !values.isEmpty else { return }
        for (field, value) in values {
            switch field {
            case .front: draft.cards[index].front = value
            case .back: draft.cards[index].back = value
            case .reading: draft.cards[index].reading = value
            case .note: draft.cards[index].note = value
            }
        }
        view?.reloadCard(at: index)
        didEdit()
    }

    // MARK: Picture search

    func findPictures(forCardAt index: Int) {
        guard isValid(index) else { return }
        let card = draft.cards[index]
        let cardId = card.id
        let term = PictureSearchTerm.make(front: card.front, back: card.back, applied: appliedEntries[cardId])
        wireframe.showPictureSearch(term: term) { [weak self] picture in
            guard let self, let current = self.draft.cards.firstIndex(where: { $0.id == cardId }) else { return }
            self.run(self.interactor.downloadPicture(from: picture.imageURL, attribution: picture.attribution), forCardAt: current)
        }
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
