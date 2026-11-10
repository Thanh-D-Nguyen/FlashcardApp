//
//  DictionaryEntryInteractor.swift
//  FlashcardApp
//
//  Use cases of the entry screens (vocabulary, kanji, grammar, sentence): load the detail, the kanji of a word, example
//  sentences and the verified stroke drawing; resolve a word or a character the learner tapped to an entry; keep the
//  account's favourite flag; save an entry as a card. Every network call is a cold `Single`: disposing it cancels the request.
//

import Foundation
import RxSwift

enum DictionaryEntryError: Error, Equatable, LocalizedError {
    /// The stroke drawing did not match the hash the API published for it.
    case strokeIntegrity
    /// The stroke drawing could not be read as a plain set of strokes.
    case strokeUnreadable

    var errorDescription: String? {
        switch self {
        case .strokeIntegrity: return NSLocalizedString("The stroke data did not pass the integrity check, so it is not shown.", comment: "")
        case .strokeUnreadable: return NSLocalizedString("The stroke data could not be read.", comment: "")
        }
    }
}

protocol DictionaryEntryInteractorInterface: AnyObject {
    var isSignedIn: Bool { get }
    func detail(for item: DictionaryItem) -> Single<EntryDetail>
    func kanjiInWord(id: String) -> Single<[KanjiReference]>
    /// The kanji that appear in a text (a sentence), in order of appearance, for those the dictionary has an entry for.
    func kanjiInText(_ text: String) -> Single<[KanjiReference]>
    func examples(term: String, reading: String) -> Single<[CardExample]>
    func strokes(kanjiID: String, expectedHash: String?) -> Single<KanjiStrokeDrawing>
    func resolveWord(_ text: String, reading: String?) -> Single<DictionaryItem?>
    func resolveKanji(_ character: String) -> Single<DictionaryItem?>
    func isFavorite(_ item: DictionaryItem) -> Single<Bool>
    func toggleFavorite(_ item: DictionaryItem) -> Single<Bool>
    func recordViewed(_ item: DictionaryItem)
    func deckChoices() -> [TodayDeckChoice]
    func dictionaryDeckExists() -> Bool
    func save(_ card: DictionaryCard, to target: DictionaryDeckTarget) throws -> DictionarySaveOutcome
}

final class DictionaryEntryInteractor: DictionaryEntryInteractorInterface {
    static let maximumKanjiLookups = 12

    private let api: BJTDictionaryAPIInterface
    private let search: BJTSearchAPI
    private let examplesProvider: CardExamplesInteractorInterface
    private let bookmarks: BJTBookmarkAPIInterface
    private let history: DictionaryHistoryStoreInterface
    private let decks: DictionaryDeckWriterInterface
    private let signedIn: () -> Bool

    init(api: BJTDictionaryAPIInterface = BJTDictionaryAPI.shared,
         search: BJTSearchAPI = .shared,
         examples: CardExamplesInteractorInterface = CardExamplesInteractor(),
         bookmarks: BJTBookmarkAPIInterface = BJTBookmarkAPI.shared,
         history: DictionaryHistoryStoreInterface = UserDefaultsDictionaryHistoryStore.shared,
         decks: DictionaryDeckWriterInterface = DictionaryDeckWriter(),
         signedIn: @escaping () -> Bool = { AuthSession.shared.bearerToken != nil }) {
        self.api = api
        self.search = search
        self.examplesProvider = examples
        self.bookmarks = bookmarks
        self.history = history
        self.decks = decks
        self.signedIn = signedIn
    }

    var isSignedIn: Bool { signedIn() }

    // MARK: Detail

    func detail(for item: DictionaryItem) -> Single<EntryDetail> {
        switch item.kind {
        case .vocabulary: return api.lexeme(id: item.id).map { .vocabulary(DictionaryEntryMapper.vocabulary($0)) }
        case .kanji: return api.kanji(id: item.id).map { .kanji(DictionaryEntryMapper.kanji($0)) }
        case .grammar: return api.grammar(id: item.id).map { .grammar(DictionaryEntryMapper.grammar($0)) }
        case .sentence: return .just(.sentence(DictionaryEntryMapper.sentence(item)))
        }
    }

    func kanjiInWord(id: String) -> Single<[KanjiReference]> {
        api.kanjiForWord(lexemeID: id).map(DictionaryEntryMapper.kanjiReferences)
    }

    func kanjiInText(_ text: String) -> Single<[KanjiReference]> {
        var seen = Set<String>()
        let characters: [String] = text.compactMap { character -> String? in
            let string = String(character)
            guard string.unicodeScalars.allSatisfy({ $0.properties.isIdeographic }), seen.insert(string).inserted else { return nil }
            return string
        }
        let limited = Array(characters.prefix(Self.maximumKanjiLookups))
        guard !limited.isEmpty else { return .just([]) }
        let lookups: [Observable<(Int, BJTKanjiSummaryDTO?)>] = limited.enumerated().map { index, character in
            // One kanji without an entry (or one failed lookup) must not hide the others.
            api.kanji(character: character).asObservable()
                .catchAndReturn(nil)
                .map { (index, $0) as (Int, BJTKanjiSummaryDTO?) }
        }
        return Observable.from(lookups)
            .merge(maxConcurrent: 4)
            .toArray()
            .map { (rows: [(Int, BJTKanjiSummaryDTO?)]) -> [KanjiReference] in
                rows.sorted { $0.0 < $1.0 }.compactMap { $0.1 }
                    .map { KanjiReference(id: $0.id, character: $0.character, meaning: $0.meaningVi) }
            }
    }

    func examples(term: String, reading: String) -> Single<[CardExample]> {
        examplesProvider.examples(for: term, cardReading: reading)
    }

    func strokes(kanjiID: String, expectedHash: String?) -> Single<KanjiStrokeDrawing> {
        api.strokeSVG(kanjiID: kanjiID).map { svg in
            guard KanjiStrokeDrawing.matches(svg, expectedHash: expectedHash) else { throw DictionaryEntryError.strokeIntegrity }
            do { return try KanjiStrokeDrawing(svg: svg) } catch { throw DictionaryEntryError.strokeUnreadable }
        }
    }

    // MARK: Resolving what the learner tapped

    func resolveWord(_ text: String, reading: String?) -> Single<DictionaryItem?> {
        search.search(q: text, scope: .vocabulary, limit: 20).map { rows in
            let exact = rows.filter { $0.kind == "lexeme" && $0.title == text }
            let preferred = reading.flatMap { reading in exact.first { ($0.reading ?? "").split(separator: " ").contains(Substring(reading)) } }
            return (preferred ?? exact.first).flatMap(DictionaryItem.init)
        }
    }

    func resolveKanji(_ character: String) -> Single<DictionaryItem?> {
        api.kanji(character: character).map { row in
            row.map { DictionaryItem(kind: .kanji, id: $0.id, title: $0.character, reading: nil, meaning: $0.meaningVi, level: $0.level.map { "N\($0)" }) }
        }
    }

    // MARK: Favourites, history and cards

    func isFavorite(_ item: DictionaryItem) -> Single<Bool> { bookmarks.check(item.kind, id: item.id) }
    func toggleFavorite(_ item: DictionaryItem) -> Single<Bool> { bookmarks.toggle(item.kind, id: item.id) }
    func recordViewed(_ item: DictionaryItem) { history.recordItem(item) }
    func deckChoices() -> [TodayDeckChoice] { decks.choices() }
    func dictionaryDeckExists() -> Bool { decks.dictionaryDeckExists() }
    func save(_ card: DictionaryCard, to target: DictionaryDeckTarget) throws -> DictionarySaveOutcome { try decks.save(card, to: target) }
}
