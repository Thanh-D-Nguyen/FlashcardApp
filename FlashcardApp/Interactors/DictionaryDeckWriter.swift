//
//  DictionaryDeckWriter.swift
//  FlashcardApp
//
//  Saves a dictionary entry as a card in one of the learner's own decks. The learner always picks the deck (or asks for
//  the "Saved from dictionary" deck to be created): nothing is ever written to a deck on its own. Saving is idempotent: the
//  card has a fixed id, `dict:<deck>:<kind>:<entry id>`, and a word the deck already holds is not added again, so a double
//  tap or a repeat never duplicates it. Decks stay local; there is no deck sync with the server.
//

import Foundation

/// The text of a card made from an entry.
struct DictionaryCard: Equatable {
    let kind: DictionaryItemKind
    let entryID: String
    let front: String
    let frontExtra: String
    let back: String
    let backExtra: String

    /// `nil` when the entry has no meaning to put on the back: a card must have both sides.
    init?(_ entry: EntryDetail) {
        switch entry {
        case .vocabulary(let detail):
            let meaning = detail.meanings.map(\.text).joined(separator: "; ")
            self.init(kind: .vocabulary, entryID: detail.id, front: detail.headword, frontExtra: detail.reading ?? "", back: meaning,
                      backExtra: detail.hanViet ?? "")
        case .kanji(let detail):
            let readings = [detail.onyomi.joined(separator: " "), detail.kunyomi.joined(separator: " ")].filter { !$0.isEmpty }.joined(separator: " / ")
            self.init(kind: .kanji, entryID: detail.id, front: detail.character, frontExtra: readings, back: detail.meaning ?? "",
                      backExtra: detail.mnemonic.map(\.text).joined())
        case .grammar(let detail):
            self.init(kind: .grammar, entryID: detail.id, front: detail.pattern, frontExtra: detail.level ?? "", back: detail.meaning,
                      backExtra: detail.sections.compactMap(\.formation).first ?? "")
        case .sentence(let detail):
            self.init(kind: .sentence, entryID: detail.id, front: detail.japanese, frontExtra: detail.reading ?? "", back: detail.translation ?? "", backExtra: "")
        }
        if front.isEmpty || back.isEmpty { return nil }
    }

    private init(kind: DictionaryItemKind, entryID: String, front: String, frontExtra: String, back: String, backExtra: String) {
        self.kind = kind
        self.entryID = entryID
        self.front = front.trimmingCharacters(in: .whitespacesAndNewlines)
        self.frontExtra = frontExtra.trimmingCharacters(in: .whitespacesAndNewlines)
        self.back = back.trimmingCharacters(in: .whitespacesAndNewlines)
        self.backExtra = backExtra.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum DictionaryDeckTarget: Equatable {
    case existing(deckID: String)
    case newDictionaryDeck
}

struct DictionarySaveOutcome: Equatable {
    let deckID: String
    let deckName: String
    /// The deck already held this word, so nothing was written.
    let wasAlreadyThere: Bool
}

protocol DictionaryDeckWriterInterface: AnyObject {
    func choices() -> [TodayDeckChoice]
    func dictionaryDeckExists() -> Bool
    func save(_ card: DictionaryCard, to target: DictionaryDeckTarget) throws -> DictionarySaveOutcome
}

final class DictionaryDeckWriter: DictionaryDeckWriterInterface {
    static let dictionaryDeckID = "dictionary-saved"

    private let decks: DeskRepositoryInterface
    private let cards: CardRepositoryInterface
    private let now: () -> Date

    init(decks: DeskRepositoryInterface = DeskManagement.shared, cards: CardRepositoryInterface = CardManagement.shared,
         now: @escaping () -> Date = Date.init) {
        self.decks = decks
        self.cards = cards
        self.now = now
    }

    func choices() -> [TodayDeckChoice] {
        decks.getAll().map { TodayDeckChoice(id: $0.id, name: $0.name, cardCount: $0.cards.count) }
    }

    func dictionaryDeckExists() -> Bool { decks.desk(withId: Self.dictionaryDeckID) != nil }

    func save(_ card: DictionaryCard, to target: DictionaryDeckTarget) throws -> DictionarySaveOutcome {
        let deckID: String
        switch target {
        case .existing(let id): deckID = id
        case .newDictionaryDeck: deckID = Self.dictionaryDeckID
        }
        let existing = decks.desk(withId: deckID)
        if existing == nil, case .existing = target { throw AppError.entityNotFound(NSLocalizedString("deck", comment: "")) }

        let cardID = "dict:\(deckID):\(card.kind.rawValue):\(card.entryID)"
        // The same entry (same id), or a word the learner typed or got elsewhere. Another dictionary entry that merely shares its
        // text (the kanji 日 next to the word 日, two readings of 生) is a different card.
        if let existing, existing.cards.contains(where: { $0.id == cardID || (!$0.id.hasPrefix("dict:") && $0.frontText == card.front) }) {
            return DictionarySaveOutcome(deckID: deckID, deckName: existing.name, wasAlreadyThere: true)
        }

        let entity = CardEntity()
        entity.id = cardID
        entity.frontText = card.front
        entity.frontExtraText = card.frontExtra
        entity.backText = card.back
        entity.backExtraText = card.backExtra
        do {
            if let existing {
                try cards.add(entity, toDesk: existing)
                return DictionarySaveOutcome(deckID: deckID, deckName: existing.name, wasAlreadyThere: false)
            }
            let deck = DeskEntity()
            deck.id = deckID
            deck.name = NSLocalizedString("Saved from dictionary", comment: "Name of the deck that collects entries saved from the dictionary")
            deck.description = NSLocalizedString("Words, kanji and grammar saved from the dictionary.", comment: "Description of the dictionary deck")
            deck.cards = [entity]
            deck.date = now()
            try decks.add(deck)
            return DictionarySaveOutcome(deckID: deckID, deckName: deck.name, wasAlreadyThere: false)
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.databaseWriteFailed(error.localizedDescription)
        }
    }
}
