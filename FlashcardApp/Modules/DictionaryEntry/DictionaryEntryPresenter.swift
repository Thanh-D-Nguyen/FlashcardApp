import AVFoundation
import Foundation
import RxRelay
import RxSwift
import UIKit

enum FavoriteState: Equatable {
    /// Sentences cannot be favourited on the server.
    case unavailable
    /// Not signed in: the button asks the learner to sign in.
    case signedOut
    case checking
    /// The server could not be asked (offline, error): neither "saved" nor "not saved" may be claimed.
    case unknown
    case off
    case on
    /// A toggle is in flight, heading to this state.
    case updating(Bool)

    var isOn: Bool {
        switch self {
        case .on, .updating(true): return true
        default: return false
        }
    }
}

struct DictionaryEntryState: Equatable {
    var item: DictionaryItem
    var detail: Loadable<EntryDetail> = .loading
    var kanji: Loadable<[KanjiReference]> = .idle
    var examples: Loadable<[CardExample]> = .idle
    var stroke: Loadable<KanjiStrokeDrawing> = .idle
    var favorite: FavoriteState = .checking
    var showReadings = true
}

/// Short feedback after an action. Shown as a transient message and announced to VoiceOver.
enum EntryNotice: Equatable {
    case copied(what: String)
    case savedToDeck(name: String)
    case alreadyInDeck(name: String)
    case nothingToSave
    case favoriteAdded
    case favoriteRemoved
    case voiceUnavailable
    case notFound(text: String)
    case failure(String)
}

protocol DictionaryEntryPresenterInterface: AnyObject {
    var state: BehaviorRelay<DictionaryEntryState> { get }
    var notices: PublishRelay<EntryNotice> { get }
    func viewDidLoad()
    /// The account may have changed while another tab was open: the saved state is read again then.
    func viewWillAppear()
    func retry()
    func retryExamples()
    func retryStroke()
    func toggleFavorite()
    func speak(_ text: String)
    func copy(_ text: String, what: String)
    func share(_ text: String)
    func addToDeck()
    func openKanji(_ reference: KanjiReference)
    /// A kanji that came as plain text (a component, a character in a sentence): its entry is looked up first.
    func openKanji(character: String)
    func openWord(_ word: String, reading: String?)
    func open(example: CardExample)
    func lookUp(_ text: String)
    func setShowReadings(_ on: Bool)
    func openVoiceSettings()
}

final class DictionaryEntryPresenter: DictionaryEntryPresenterInterface {
    let state: BehaviorRelay<DictionaryEntryState>
    let notices = PublishRelay<EntryNotice>()

    private let interactor: DictionaryEntryInteractorInterface
    private let wireframe: DictionaryEntryWireframeInterface
    private let speech: SpeechServiceInterface
    private let preferences: DictionaryPreferencesInterface
    private let japaneseVoiceAvailable: () -> Bool
    private let pasteboard: (String) -> Void
    private let item: DictionaryItem

    private var loadBag = DisposeBag()
    private var favoriteBag = DisposeBag()
    private let actionBag = DisposeBag()
    private var resolving = DisposeBag()
    private var signedInWhenFavoriteWasRead: Bool?

    init(item: DictionaryItem,
         interactor: DictionaryEntryInteractorInterface,
         wireframe: DictionaryEntryWireframeInterface,
         speech: SpeechServiceInterface = SystemSpeechService.shared,
         preferences: DictionaryPreferencesInterface = UserDefaultsDictionaryPreferences.shared,
         japaneseVoiceAvailable: @escaping () -> Bool = { AVSpeechSynthesisVoice(language: "ja-JP") != nil },
         pasteboard: @escaping (String) -> Void = { UIPasteboard.general.string = $0 }) {
        self.item = item
        self.interactor = interactor
        self.wireframe = wireframe
        self.speech = speech
        self.preferences = preferences
        self.japaneseVoiceAvailable = japaneseVoiceAvailable
        self.pasteboard = pasteboard
        var initial = DictionaryEntryState(item: item)
        initial.showReadings = preferences.showReadings
        initial.favorite = item.kind.bookmarkType == nil ? .unavailable : .checking
        state = BehaviorRelay(value: initial)
    }

    deinit { speech.stop() }

    // MARK: Loading

    func viewDidLoad() {
        interactor.recordViewed(item)
        load()
        refreshFavorite()
    }

    func viewWillAppear() {
        guard let known = signedInWhenFavoriteWasRead, known != interactor.isSignedIn else { return }
        refreshFavorite()
    }

    func retry() { load() }

    private func load() {
        loadBag = DisposeBag()
        update { $0.detail = .loading; $0.kanji = .idle; $0.examples = .idle; $0.stroke = .idle }
        interactor.detail(for: item)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] detail in
                self?.update { $0.detail = .loaded(detail) }
                self?.loadRelated(for: detail)
            }, onFailure: { [weak self] error in
                self?.update { $0.detail = .failed(Self.message(for: error)) }
            })
            .disposed(by: loadBag)
    }

    private func loadRelated(for detail: EntryDetail) {
        switch detail {
        case .vocabulary(let vocabulary):
            loadKanji(interactor.kanjiInWord(id: vocabulary.id))
            loadExamples(term: vocabulary.headword, reading: vocabulary.reading ?? "")
        case .kanji(let kanji):
            loadStroke(kanji)
        case .grammar(let grammar):
            if let term = grammar.exampleTerm { loadExamples(term: term, reading: "") }
        case .sentence(let sentence):
            loadKanji(interactor.kanjiInText(sentence.japanese))
        }
    }

    private func loadKanji(_ request: Single<[KanjiReference]>) {
        update { $0.kanji = .loading }
        request.observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] value in self?.update { state in state.kanji = .loaded(value) } },
                       onFailure: { [weak self] error in self?.update { state in state.kanji = .failed(Self.message(for: error)) } })
            .disposed(by: loadBag)
    }

    private func loadExamples(term: String, reading: String) {
        guard term.count <= CardExampleLookup.maximumTermLength, JapaneseText.containsJapanese(term) else { return }
        update { $0.examples = .loading }
        interactor.examples(term: term, reading: reading)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] value in self?.update { state in state.examples = .loaded(value) } },
                       onFailure: { [weak self] error in self?.update { state in state.examples = .failed(Self.message(for: error)) } })
            .disposed(by: loadBag)
    }

    func retryExamples() {
        guard case .loaded(let detail) = state.value.detail else { return }
        switch detail {
        case .vocabulary(let vocabulary): loadExamples(term: vocabulary.headword, reading: vocabulary.reading ?? "")
        case .grammar(let grammar): if let term = grammar.exampleTerm { loadExamples(term: term, reading: "") }
        default: break
        }
    }

    private func loadStroke(_ kanji: KanjiDetail) {
        update { $0.stroke = .loading }
        interactor.strokes(kanjiID: kanji.id, expectedHash: kanji.strokeHash)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] value in self?.update { state in state.stroke = .loaded(value) } },
                       onFailure: { [weak self] error in self?.update { state in state.stroke = .failed(Self.message(for: error)) } })
            .disposed(by: loadBag)
    }

    func retryStroke() {
        guard case .loaded(.kanji(let kanji)) = state.value.detail else { return }
        loadStroke(kanji)
    }

    // MARK: Favourite

    private func refreshFavorite() {
        favoriteBag = DisposeBag()
        signedInWhenFavoriteWasRead = interactor.isSignedIn
        guard item.kind.bookmarkType != nil else { return update { $0.favorite = .unavailable } }
        guard interactor.isSignedIn else { return update { $0.favorite = .signedOut } }
        update { $0.favorite = .checking }
        interactor.isFavorite(item)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] isOn in self?.update { state in state.favorite = isOn ? .on : .off } },
                       onFailure: { [weak self] error in
                           if case LearnerAPIError.signInRequired = error { self?.update { $0.favorite = .signedOut } }
                           else { self?.update { $0.favorite = .unknown } }
                       })
            .disposed(by: favoriteBag)
    }

    func toggleFavorite() {
        switch state.value.favorite {
        case .unavailable, .checking, .updating: return
        case .unknown:
            // Not a toggle: ask the server again first, so the tap can never add what is already saved or remove what is not.
            refreshFavorite()
        case .signedOut:
            wireframe.showSignIn { [weak self] in self?.refreshFavorite() }
        case .off, .on:
            let wanted = !state.value.favorite.isOn
            update { $0.favorite = .updating(wanted) }
            // A toggle is never retried: a second call would undo the first.
            interactor.toggleFavorite(item)
                .observe(on: MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] now in
                    self?.update { $0.favorite = now ? .on : .off }
                    self?.notices.accept(now ? .favoriteAdded : .favoriteRemoved)
                }, onFailure: { [weak self] error in self?.favoriteFailed(error, wanted: wanted) })
                .disposed(by: favoriteBag)
        }
    }

    private func favoriteFailed(_ error: Error, wanted: Bool) {
        switch error {
        case LearnerAPIError.signInRequired:
            update { $0.favorite = .signedOut }
            wireframe.showSignIn { [weak self] in self?.refreshFavorite() }
        case LearnerAPIError.interrupted:
            // The request may have reached the server: read the state instead of guessing.
            notices.accept(.failure(Self.message(for: error)))
            refreshFavorite()
        default:
            update { $0.favorite = wanted ? .off : .on }
            notices.accept(.failure(Self.message(for: error)))
        }
    }

    // MARK: Actions on the text

    func speak(_ text: String) {
        guard japaneseVoiceAvailable() else { return notices.accept(.voiceUnavailable) }
        speech.speak(text, languageCode: "ja-JP")
    }

    func copy(_ text: String, what: String) {
        pasteboard(text)
        notices.accept(.copied(what: what))
    }

    func share(_ text: String) { wireframe.share(text) }

    func openVoiceSettings() { wireframe.openSystemSettings() }

    func setShowReadings(_ on: Bool) {
        preferences.showReadings = on
        update { $0.showReadings = on }
    }

    // MARK: Deck

    func addToDeck() {
        guard case .loaded(let detail) = state.value.detail, let card = DictionaryCard(detail) else {
            return notices.accept(.nothingToSave)
        }
        wireframe.showDeckChooser(interactor.deckChoices(), dictionaryDeckExists: interactor.dictionaryDeckExists()) { [weak self] target in
            guard let self else { return }
            do {
                let outcome = try self.interactor.save(card, to: target)
                self.notices.accept(outcome.wasAlreadyThere ? .alreadyInDeck(name: outcome.deckName) : .savedToDeck(name: outcome.deckName))
            } catch {
                self.notices.accept(.failure(error.localizedDescription))
            }
        }
    }

    // MARK: Navigation

    func openKanji(_ reference: KanjiReference) {
        wireframe.showEntry(DictionaryItem(kind: .kanji, id: reference.id, title: reference.character, meaning: reference.meaning))
    }

    func openKanji(character: String) {
        resolving = DisposeBag()
        interactor.resolveKanji(character)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                if let found = $0 { self?.wireframe.showEntry(found) } else { self?.notices.accept(.notFound(text: character)) }
            }, onFailure: { [weak self] in self?.notices.accept(.failure(Self.message(for: $0))) })
            .disposed(by: resolving)
    }

    func openWord(_ word: String, reading: String?) {
        resolving = DisposeBag()
        interactor.resolveWord(word, reading: reading)
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] in
                if let found = $0 { self?.wireframe.showEntry(found) } else { self?.notices.accept(.notFound(text: word)) }
            }, onFailure: { [weak self] in self?.notices.accept(.failure(Self.message(for: $0))) })
            .disposed(by: resolving)
    }

    func open(example: CardExample) {
        wireframe.showEntry(DictionaryItem(kind: .sentence, id: example.id, title: example.japanese,
                                           reading: example.reading.isEmpty ? nil : example.reading,
                                           meaning: example.translation.isEmpty ? nil : example.translation))
    }

    func lookUp(_ text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        wireframe.showSearch(for: query)
    }

    // MARK: Helpers

    private func update(_ change: (inout DictionaryEntryState) -> Void) {
        var next = state.value
        change(&next)
        if next != state.value { state.accept(next) }
    }

    static func message(for error: Error) -> String {
        if let known = error as? LocalizedError, let text = known.errorDescription { return text }
        return error.localizedDescription
    }
}
