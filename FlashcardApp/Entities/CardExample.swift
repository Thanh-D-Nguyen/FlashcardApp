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

/// Where a sentence on screen comes from. Only `server` sentences can come back from the server on their own.
enum ExampleOrigin: Equatable {
    /// Offered by the dictionary API, shown as it is.
    case server
    /// A server sentence the learner changed; their text is shown instead.
    case edited
    /// Written by the learner.
    case custom
}

struct ExampleItem: Equatable, Identifiable {
    let example: CardExample
    let origin: ExampleOrigin
    var id: String { example.id }
    /// Identity of the server sentence this one stands for (it is the sentence's own id for `server` and `edited`).
    var serverId: String? { origin == .custom ? nil : example.id }
}

/// What the learner did to a card's sentences. Server sentences are not stored; only the learner's changes are.
struct ExampleOverlay: Equatable {
    var edited: [String: CardExample] = [:]
    var hidden: Set<String> = []
    var custom: [CardExample] = []

    static let empty = ExampleOverlay()
}

enum ExampleMerge {
    /// The sentences to show: the server's in their order with the learner's edits in place and removed ones left out,
    /// then the learner's own. Edited sentences are the learner's text, so they stay even when the server is out of reach.
    static func items(server: [CardExample], overlay: ExampleOverlay) -> [ExampleItem] {
        var shown = Set<String>()
        var items: [ExampleItem] = []
        for example in server where !overlay.hidden.contains(example.id) {
            shown.insert(example.id)
            if let edited = overlay.edited[example.id] {
                items.append(ExampleItem(example: edited, origin: .edited))
            } else {
                items.append(ExampleItem(example: example, origin: .server))
            }
        }
        // Without the server's answer (offline, or the sentence no longer matches) the learner's edits are still theirs.
        let orphanedEdits = overlay.edited.filter { !shown.contains($0.key) && !overlay.hidden.contains($0.key) }
            .sorted { $0.key < $1.key }.map { ExampleItem(example: $0.value, origin: .edited) }
        return items + orphanedEdits + overlay.custom.map { ExampleItem(example: $0, origin: .custom) }
    }

    /// How many of the server's current sentences the learner removed (what "Restore" would bring back).
    static func removedCount(server: [CardExample], overlay: ExampleOverlay) -> Int {
        server.filter { overlay.hidden.contains($0.id) }.count
    }
}

/// What the sentences panel shows. The learner's own sentences are shown at once; the server's part has its own status.
struct ExamplesPanelState: Equatable {
    enum Server: Equatable {
        /// The card has no Japanese word to look sentences up by.
        case notApplicable
        case loading
        case loaded
        case unavailable
    }

    /// The panel appears with the answer.
    var isVisible: Bool
    var items: [ExampleItem]
    var server: Server
    var removedCount: Int

    static let hidden = ExamplesPanelState(isVisible: false, items: [], server: .notApplicable, removedCount: 0)
}

/// Text the learner typed for a sentence, before it is saved.
struct CardExampleDraft: Equatable {
    static let maximumJapaneseLength = 500
    static let maximumReadingLength = 500
    static let maximumTranslationLength = 1000
    static let maximumCustomPerCard = 20

    var japanese = ""
    var reading = ""
    var translation = ""

    init(japanese: String = "", reading: String = "", translation: String = "") {
        self.japanese = japanese
        self.reading = reading
        self.translation = translation
    }

    init(_ example: CardExample) {
        self.init(japanese: example.japanese, reading: example.reading, translation: example.translation)
    }

    /// The trimmed draft, or the first problem with it.
    func validated() throws -> CardExampleDraft {
        let draft = CardExampleDraft(japanese: japanese.trimmingCharacters(in: .whitespacesAndNewlines),
                                     reading: reading.trimmingCharacters(in: .whitespacesAndNewlines),
                                     translation: translation.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !draft.japanese.isEmpty else { throw CardExampleError.sentenceMissing }
        guard draft.japanese.count <= Self.maximumJapaneseLength else { throw CardExampleError.tooLong(Self.maximumJapaneseLength) }
        guard draft.reading.count <= Self.maximumReadingLength else { throw CardExampleError.tooLong(Self.maximumReadingLength) }
        guard draft.translation.count <= Self.maximumTranslationLength else { throw CardExampleError.tooLong(Self.maximumTranslationLength) }
        return draft
    }
}

enum CardExampleError: LocalizedError, Equatable {
    case sentenceMissing
    case tooLong(Int)
    case duplicate
    case limitReached(Int)
    case notFound

    var errorDescription: String? {
        switch self {
        case .sentenceMissing: return NSLocalizedString("Enter the example sentence.", comment: "")
        case .tooLong(let limit):
            return String(format: NSLocalizedString("This text is too long (up to %lld characters).", comment: ""), limit)
        case .duplicate: return NSLocalizedString("This sentence is already in the list.", comment: "")
        case .limitReached(let limit):
            return String(format: NSLocalizedString("You can add up to %lld example sentences per card.", comment: ""), limit)
        case .notFound: return NSLocalizedString("This example sentence no longer exists.", comment: "")
        }
    }
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
