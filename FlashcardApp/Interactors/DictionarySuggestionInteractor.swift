//
//  DictionarySuggestionInteractor.swift
//  FlashcardApp
//
//  Dictionary suggestions for the card editor, from the public `GET /api/search?scope=lexeme` (headword,
//  reading, Vietnamese meaning, JLPT level; no login). The app bundles no dictionary: without a connection
//  there are no suggestions, and typing a card by hand keeps working.
//  `POST /api/flashcards/cards/suggest` is not used: it needs a session, orders results at random and only
//  matches substrings, which makes it a deck-building tool rather than autocomplete.
//

import Foundation
import RxSwift

/// A dictionary entry offered above the keyboard while typing a card.
struct CardSuggestion: Equatable {
    let japanese: String
    let reading: String
    let vietnamese: String
    /// The learner was typing Japanese (so the Japanese side is theirs) or Vietnamese.
    let typedJapanese: Bool
    var jlptLevel: String? = nil

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
    case searching
    case results([CardSuggestion])
    case empty
    /// The dictionary could not be reached.
    case unavailable
}

protocol DictionarySuggestionInteractorInterface: AnyObject {
    /// Emits `.searching` right away, then one final state. Disposing the subscription cancels the request.
    func suggestions(for query: SuggestionQuery) -> Observable<SuggestionsState>
}

protocol OnlineDictionaryInterface: AnyObject {
    func lookup(_ text: String, limit: Int) -> Single<[BJTSearchResultDTO]>
}

extension BJTSearchAPI: OnlineDictionaryInterface {
    func lookup(_ text: String, limit: Int) -> Single<[BJTSearchResultDTO]> {
        search(q: text, scope: .vocabulary, limit: limit)
    }
}

final class DictionarySuggestionInteractor: DictionarySuggestionInteractorInterface {
    static let limit = 10

    private let online: OnlineDictionaryInterface

    init(online: OnlineDictionaryInterface = BJTSearchAPI.shared) {
        self.online = online
    }

    func suggestions(for query: SuggestionQuery) -> Observable<SuggestionsState> {
        let answer = online.lookup(query.text, limit: 20)
            .map { Self.suggestions(from: $0, for: query) }
            .asObservable()
            .map { found -> SuggestionsState in
                let ranked = Self.rank(found, query: query)
                return ranked.isEmpty ? .empty : .results(ranked)
            }
            .catch { _ in .just(.unavailable) }
        return Observable.concat(.just(.searching), answer)
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
                                  jlptLevel: result.jlptLevel)
        }
    }

    /// Same word listed once; exact and prefix matches float to the top. Stable, so equal ranks keep the server's order.
    static func rank(_ suggestions: [CardSuggestion], query: SuggestionQuery) -> [CardSuggestion] {
        var seen = Set<String>()
        let unique = suggestions.filter { seen.insert($0.identity).inserted }
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
