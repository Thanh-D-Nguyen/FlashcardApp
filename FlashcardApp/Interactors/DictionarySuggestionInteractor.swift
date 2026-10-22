//
//  DictionarySuggestionInteractor.swift
//  FlashcardApp
//
//  Dictionary suggestions for the card editor. Two sources answer one query:
//  - the offline dictionary bundled in Realm (instant, works without a connection), and
//  - the public `GET /api/search?scope=lexeme` (headword, reading, Vietnamese meaning, JLPT level; no login).
//  `POST /api/flashcards/cards/suggest` is not used: it needs a session, orders results at random and only
//  matches substrings, which makes it a deck-building tool rather than autocomplete.
//

import Foundation
import RxSwift

/// A dictionary entry offered above the keyboard while typing a card.
struct CardSuggestion: Equatable {
    enum Source: Equatable { case offline, online }

    let japanese: String
    let reading: String
    let vietnamese: String
    /// The learner was typing Japanese (so the Japanese side is theirs) or Vietnamese.
    let typedJapanese: Bool
    var jlptLevel: String? = nil
    var source: Source = .offline

    /// Text of the chip: the headword with its meaning.
    var title: String { "\(japanese) · \(vietnamese)" }

    /// Entries that describe the same word collapse into one chip.
    var identity: String { "\(japanese)|\(reading)" }
}

struct SuggestionQuery: Equatable {
    let text: String
    let isJapanese: Bool

    static let maximumLength = 40

    /// `nil` when the text is not worth a lookup: empty, a single Latin letter, or a whole sentence.
    init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let japanese = JapaneseText.containsJapanese(trimmed)
        guard !trimmed.isEmpty, trimmed.count <= Self.maximumLength, japanese || trimmed.count >= 2 else { return nil }
        text = trimmed
        isJapanese = japanese
    }
}

enum SuggestionsState: Equatable {
    case hidden
    /// The online lookup is running; `partial` is what the offline dictionary already found.
    case searching(partial: [CardSuggestion])
    case results([CardSuggestion])
    case empty
    /// Nothing offline matched and the online dictionary could not be reached.
    case unavailable
}

protocol DictionarySuggestionInteractorInterface: AnyObject {
    /// Emits `.searching` right away, then one final state. Disposing the subscription cancels the online request.
    func suggestions(for query: SuggestionQuery) -> Observable<SuggestionsState>
}

protocol OfflineDictionaryInterface: AnyObject {
    func entries(for query: SuggestionQuery, limit: Int) -> [CardSuggestion]
}

protocol OnlineDictionaryInterface: AnyObject {
    func lookup(_ text: String, limit: Int) -> Single<[BJTSearchResultDTO]>
}

extension BJTSearchAPI: OnlineDictionaryInterface {
    func lookup(_ text: String, limit: Int) -> Single<[BJTSearchResultDTO]> {
        search(q: text, scope: .vocabulary, limit: limit)
    }
}

/// The bundled Realm dictionary. Realm objects are read on the calling (main) thread and copied into values.
final class RealmOfflineDictionary: OfflineDictionaryInterface {
    func entries(for query: SuggestionQuery, limit: Int) -> [CardSuggestion] {
        if query.isJapanese {
            return JaViManagement.shared.search(query.text, limit: limit).compactMap { entity in
                guard let meaning = entity.means?.first?.mean, !meaning.isEmpty, !entity.word.isEmpty else { return nil }
                return CardSuggestion(japanese: entity.word, reading: entity.phonetic, vietnamese: meaning, typedJapanese: true)
            }
        }
        return ViJaManagement.shared.search(query.text, limit: limit).compactMap { entity in
            guard let japanese = entity.means?.first?.mean, !japanese.isEmpty, !entity.word.isEmpty else { return nil }
            return CardSuggestion(japanese: japanese, reading: "", vietnamese: entity.word, typedJapanese: false)
        }
    }
}

final class DictionarySuggestionInteractor: DictionarySuggestionInteractorInterface {
    static let limit = 10

    private let offline: OfflineDictionaryInterface
    private let online: OnlineDictionaryInterface

    init(offline: OfflineDictionaryInterface = RealmOfflineDictionary(), online: OnlineDictionaryInterface = BJTSearchAPI.shared) {
        self.offline = offline
        self.online = online
    }

    func suggestions(for query: SuggestionQuery) -> Observable<SuggestionsState> {
        let local = offline.entries(for: query, limit: Self.limit)
        let remote = online.lookup(query.text, limit: 20)
            .map { Self.suggestions(from: $0, for: query) }
            .asObservable()
            .map { remote -> SuggestionsState in
                let merged = Self.merge(remote: remote, local: local, query: query)
                return merged.isEmpty ? .empty : .results(merged)
            }
            .catch { _ in
                // The offline answer stands on its own; only an empty one makes the failure worth reporting.
                .just(local.isEmpty ? .unavailable : .results(Self.merge(remote: [], local: local, query: query)))
            }
        return Observable.concat(.just(.searching(partial: Self.merge(remote: [], local: local, query: query))), remote)
    }

    // MARK: Mapping and ranking

    /// Search results that really answer the typed text. The search index is typo-tolerant ("食べ" also returns
    /// "イベント駆動"), which is fine for a results page but noise in a one-line suggestion bar.
    static func suggestions(from results: [BJTSearchResultDTO], for query: SuggestionQuery) -> [CardSuggestion] {
        let folded = JapaneseText.folded(query.text)
        return results.compactMap { result in
            guard result.kind == "lexeme", !result.title.isEmpty,
                  let meaning = result.description?.trimmingCharacters(in: .whitespacesAndNewlines), !meaning.isEmpty else { return nil }
            let reading = result.reading ?? ""
            let relevant = query.isJapanese
                ? result.title.contains(query.text) || reading.contains(query.text)
                : JapaneseText.folded(meaning).contains(folded) || JapaneseText.folded(result.title).contains(folded)
            guard relevant else { return nil }
            return CardSuggestion(japanese: result.title, reading: reading, vietnamese: meaning, typedJapanese: query.isJapanese,
                                  jlptLevel: result.jlptLevel, source: .online)
        }
    }

    /// Online entries first (the server's content is the current one), then offline ones for words not already
    /// listed; exact and prefix matches float to the top. Stable, so equal ranks keep the source order.
    static func merge(remote: [CardSuggestion], local: [CardSuggestion], query: SuggestionQuery) -> [CardSuggestion] {
        var seen = Set<String>()
        let unique = (remote + local).filter { seen.insert($0.identity).inserted }
        let folded = JapaneseText.folded(query.text)
        func rank(_ suggestion: CardSuggestion) -> Int {
            let typed = query.isJapanese ? [suggestion.japanese, suggestion.reading] : [suggestion.vietnamese]
            let candidates = typed.map(JapaneseText.folded).filter { !$0.isEmpty }
            if candidates.contains(folded) { return 0 }
            if candidates.contains(where: { $0.hasPrefix(folded) }) { return 1 }
            return 2
        }
        return unique.enumerated().sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .prefix(limit).map(\.element)
    }
}
