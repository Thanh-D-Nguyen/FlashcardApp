//
//  DeckDraft.swift
//  FlashcardApp
//
//  Value-type editing model for the deck editor. Replaces the former relay-based
//  `DeskDataModel`: identity of existing decks and cards is carried through the edit, so saving
//  an edited deck updates the same Realm rows instead of creating look-alikes.
//

import Foundation

struct CardDraft: Equatable, Codable {
    var id: String
    var front: String
    var back: String
    /// Pronunciation of the front side (stored in `CardEntity.frontExtraText`).
    var reading: String
    /// Extra note shown with the answer (stored in `CardEntity.backExtraText`).
    var note: String
    /// `CardImageReference` string: empty, `local-image:<file>` or an https URL.
    var imageReference: String

    init(id: String = UUID().uuidString, front: String = "", back: String = "", reading: String = "",
         note: String = "", imageReference: String = "") {
        self.id = id
        self.front = front
        self.back = back
        self.reading = reading
        self.note = note
        self.imageReference = imageReference
    }

    init(entity: CardEntity) {
        self.init(id: entity.id, front: entity.frontText, back: entity.backText, reading: entity.frontExtraText,
                  note: entity.backExtraText, imageReference: entity.imageUrl)
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasFront: Bool { !Self.isBlank(front) }
    var hasBack: Bool { !Self.isBlank(back) }
    /// A card the user has not typed anything into; it is ignored on save instead of being an error.
    var isEmpty: Bool { !hasFront && !hasBack && Self.isBlank(reading) && Self.isBlank(note) && imageReference.isEmpty }
    var isComplete: Bool { hasFront && hasBack }

    func toEntity() -> CardEntity {
        let entity = CardEntity()
        entity.id = id
        entity.frontText = front.trimmingCharacters(in: .whitespacesAndNewlines)
        entity.backText = back.trimmingCharacters(in: .whitespacesAndNewlines)
        entity.frontExtraText = reading.trimmingCharacters(in: .whitespacesAndNewlines)
        entity.backExtraText = note.trimmingCharacters(in: .whitespacesAndNewlines)
        entity.imageUrl = imageReference
        entity.videoUrl = ""
        return entity
    }
}

enum DeckValidationIssue: Equatable {
    case nameEmpty
    case tooFewCards
    case tooManyCards
    case incompleteCard(index: Int, missingFront: Bool)
}

struct DeckDraft: Equatable, Codable {
    static let minimumCards = 2
    /// Same ceiling as the website composer.
    static let maximumCards = 200

    /// `nil` while creating; the id of the stored deck while editing.
    var deckId: String?
    var name: String
    var details: String
    var direction: Int
    var cards: [CardDraft]
    /// Creation date of the stored deck, kept so an edit does not reorder the library.
    var createdAt: Date?

    init(deckId: String? = nil, name: String = "", details: String = "", direction: LanguageSortingType = .normal,
         cards: [CardDraft] = [CardDraft(), CardDraft()], createdAt: Date? = nil) {
        self.deckId = deckId
        self.name = name
        self.details = details
        self.direction = direction.rawValue
        self.cards = cards
        self.createdAt = createdAt
    }

    init(entity: DeskEntity) {
        self.init(deckId: entity.id, name: entity.name, details: entity.description,
                  direction: entity.sortingLanguage, cards: entity.cards.map(CardDraft.init(entity:)),
                  createdAt: entity.date)
    }

    var sortingLanguage: LanguageSortingType {
        get { LanguageSortingType(rawValue: direction) ?? .normal }
        set { direction = newValue.rawValue }
    }

    var isEditing: Bool { deckId != nil }
    var savableCards: [CardDraft] { cards.filter { !$0.isEmpty } }

    /// Everything that blocks saving. A half-filled card is reported rather than silently dropped.
    var issues: [DeckValidationIssue] {
        var result: [DeckValidationIssue] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(.nameEmpty) }
        for (index, card) in cards.enumerated() where !card.isEmpty && !card.isComplete {
            result.append(.incompleteCard(index: index, missingFront: !card.hasFront))
        }
        let complete = cards.filter(\.isComplete).count
        if complete < Self.minimumCards { result.append(.tooFewCards) }
        if cards.filter({ !$0.isEmpty }).count > Self.maximumCards { result.append(.tooManyCards) }
        return result
    }

    func toEntity(newId: @autoclosure () -> String = UUID().uuidString) -> DeskEntity {
        let entity = DeskEntity()
        entity.id = deckId ?? newId()
        entity.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        entity.description = details.trimmingCharacters(in: .whitespacesAndNewlines)
        entity.imageNamed = ""
        entity.sortingLanguage = sortingLanguage
        entity.cards = savableCards.map { $0.toEntity() }
        entity.date = createdAt ?? Date()
        return entity
    }
}
