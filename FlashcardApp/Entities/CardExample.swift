//
//  CardExample.swift
//  FlashcardApp
//
//  Example sentences for the card being studied. They come from the public `GET /api/search?scope=example`
//  (Japanese sentence in `title`, hiragana in `reading`, Vietnamese in `description`); the Go deck endpoints
//  carry no examples. Nothing is stored on the card: they are looked up for the card's Japanese word.
//

import Foundation

struct CardExample: Equatable, Identifiable {
    let id: String
    let japanese: String
    let reading: String
    let translation: String

    /// Text copied to the pasteboard: the sentence, its reading and its meaning, one per line.
    var copyText: String { [japanese, reading, translation].filter { !$0.isEmpty }.joined(separator: "\n") }
}

enum ExamplesState: Equatable {
    /// Nothing to show: the answer is not revealed yet, or the card has no Japanese word to look up.
    case hidden
    case loading
    case results([CardExample])
    case empty
    case unavailable
}

enum CardExampleLookup {
    static let maximumTermLength = 20
    static let maximumExamples = 5
    /// Candidates asked from the server; the typo-tolerant index returns noise that is filtered out locally.
    static let candidateLimit = 30

    /// The Japanese word of a card, to look sentences up by. `nil` when no side is Japanese or the Japanese side
    /// is itself a sentence (a long text is not a headword).
    static func term(front: String, back: String, deckHasJapaneseOnFront: Bool) -> String? {
        let japaneseOnFront = JapaneseText.japaneseIsOnFront(front: front, back: back, deckHasJapaneseOnFront: deckHasJapaneseOnFront)
        let text = (japaneseOnFront ? front : back).trimmingCharacters(in: .whitespacesAndNewlines)
        guard JapaneseText.containsJapanese(text), text.count <= maximumTermLength else { return nil }
        return text
    }

    /// Sentences that really use the word. The index also matches by meaning and by near spellings, which would put
    /// unrelated sentences under a card. Whole sentences come before phrases; shorter (easier) first; at most five.
    static func examples(from results: [BJTSearchResultDTO], term: String, cardReading: String) -> [CardExample] {
        let reading = cardReading.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        let relevant = results.compactMap { result -> CardExample? in
            let sentence = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let kana = (result.reading ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard result.kind == "example", !sentence.isEmpty,
                  sentence.contains(term) || (!reading.isEmpty && kana.contains(reading)),
                  seen.insert(sentence).inserted else { return nil }
            let translation = (result.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return CardExample(id: result.id, japanese: sentence, reading: kana == sentence ? "" : kana, translation: translation)
        }
        func isSentence(_ example: CardExample) -> Bool { "。！？!?".contains(example.japanese.last ?? " ") }
        return relevant.enumerated()
            .sorted { lhs, rhs in
                (isSentence(lhs.element) ? 0 : 1, lhs.element.japanese.count, lhs.offset)
                    < (isSentence(rhs.element) ? 0 : 1, rhs.element.japanese.count, rhs.offset)
            }
            .prefix(maximumExamples).map(\.element)
    }
}
