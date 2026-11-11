import Foundation

/// A word of a lesson as the server wrote it. The lesson carries no dictionary entry id, so the card is made from this text alone.
struct LessonWord: Equatable {
    let japanese: String
    let reading: String
    let meaning: String

    init(_ word: BJTLessonVocabularyDTO) {
        japanese = word.japanese
        reading = word.reading ?? ""
        meaning = word.meaningVi
    }

    init(japanese: String, reading: String, meaning: String) {
        self.japanese = japanese
        self.reading = reading
        self.meaning = meaning
    }
}

struct LessonWordSaveOutcome: Equatable {
    let deckID: String
    let deckName: String
    let added: Int
    /// Words the deck already held, so nothing was written for them.
    let alreadyThere: Int
    /// Words without a Japanese side or a meaning: a card must have both sides, so none was made.
    let skipped: Int
}

protocol LessonWordSaverInterface: AnyObject {
    func choices() -> [TodayDeckChoice]
    func save(_ words: [LessonWord], fromLesson slug: String, to target: DictionaryDeckTarget) throws -> LessonWordSaveOutcome
}

/// Saves lesson words as cards in a deck the learner picks (or asks to be created); nothing is written on its own.
/// A card has a fixed id, `lesson:<deck>:<lesson slug>:<Japanese text>`, so a repeat never adds it twice. The lesson has no
/// dictionary entry id, so none is invented. A word the deck already holds (same Japanese text, typed by the learner or
/// saved from the dictionary as a word) is left as it is. Decks stay local.
final class LessonWordSaver: LessonWordSaverInterface {
    static let lessonDeckID = "lesson-words"

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

    func save(_ words: [LessonWord], fromLesson slug: String, to target: DictionaryDeckTarget) throws -> LessonWordSaveOutcome {
        let deckID: String
        switch target {
        case .existing(let id): deckID = id
        case .newDictionaryDeck: deckID = Self.lessonDeckID
        }
        let existing = decks.desk(withId: deckID)
        if existing == nil, case .existing = target { throw AppError.entityNotFound(NSLocalizedString("deck", comment: "")) }

        var heldIDs = Set(existing?.cards.map(\.id) ?? [])
        // Cards that are the same word whatever their id: typed by the learner, or a dictionary *word* (a kanji or a grammar
        // point that merely shares its text is a different card).
        var heldFronts = Set((existing?.cards ?? []).filter { !$0.id.hasPrefix("dict:") || $0.id.contains(":vocabulary:") }
            .map { $0.frontText.trimmingCharacters(in: .whitespacesAndNewlines) })
        var added: [CardEntity] = []
        var alreadyThere = 0, skipped = 0
        for word in words {
            let front = word.japanese.trimmingCharacters(in: .whitespacesAndNewlines)
            let back = word.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !front.isEmpty, !back.isEmpty else { skipped += 1; continue }
            let id = "lesson:\(deckID):\(slug):\(front)"
            if heldIDs.contains(id) || heldFronts.contains(front) { alreadyThere += 1; continue }
            heldIDs.insert(id)
            heldFronts.insert(front)
            let card = CardEntity()
            card.id = id
            card.frontText = front
            card.frontExtraText = word.reading.trimmingCharacters(in: .whitespacesAndNewlines)
            card.backText = back
            added.append(card)
        }

        do {
            if let existing {
                if !added.isEmpty { try cards.add(added, toDesk: existing) }
                return LessonWordSaveOutcome(deckID: deckID, deckName: existing.name, added: added.count, alreadyThere: alreadyThere, skipped: skipped)
            }
            guard !added.isEmpty else {
                // Nothing to save: the learner's request does not create an empty deck.
                return LessonWordSaveOutcome(deckID: deckID, deckName: Self.newDeckName, added: 0, alreadyThere: alreadyThere, skipped: skipped)
            }
            let deck = DeskEntity()
            deck.id = deckID
            deck.name = Self.newDeckName
            deck.description = NSLocalizedString("Words saved from lessons.", comment: "Description of the deck that collects lesson words")
            deck.cards = added
            deck.date = now()
            try decks.add(deck)
            return LessonWordSaveOutcome(deckID: deckID, deckName: deck.name, added: added.count, alreadyThere: alreadyThere, skipped: skipped)
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.databaseWriteFailed(error.localizedDescription)
        }
    }

    private static var newDeckName: String { NSLocalizedString("Saved from lessons", comment: "Name of the deck that collects words saved from lessons") }
}
