//
//  DeckGeneration.swift
//  FlashcardApp
//
//  Value types for generating a deck from the server's dictionary content. The options are exactly the
//  ones `POST /api/flashcards/decks/generate` honours (levels, source types, direction, limit, name);
//  the website's "topic" and "weak area" modes have no backend support and are deliberately absent.
//

import Foundation

/// JLPT levels the backend filters on. The server accepts `J1`…`J5` (and `N1`…`N5`); `J1+` is the same set as `J1`.
enum GenerationLevel: String, CaseIterable, Equatable, Codable {
    case n5 = "J5", n4 = "J4", n3 = "J3", n2 = "J2", n1 = "J1"

    var title: String { "N" + rawValue.dropFirst() }
}

/// `flashcard_variant.source_type` values the generator can draw from.
enum GenerationContentType: String, CaseIterable, Equatable, Codable {
    case vocabulary = "lexeme", kanji, grammar

    var title: String {
        switch self {
        case .vocabulary: return NSLocalizedString("Vocabulary", comment: "")
        case .kanji: return NSLocalizedString("Kanji", comment: "")
        case .grammar: return NSLocalizedString("Grammar", comment: "")
        }
    }
}

/// The server's `direction` values. `both` alternates the direction card by card (it does not add the
/// reverse of every card), so the learner is told so.
enum GenerationDirection: String, CaseIterable, Equatable, Codable {
    case japaneseToVietnamese = "jp_to_vn", vietnameseToJapanese = "vn_to_jp", both

    var title: String {
        switch self {
        case .japaneseToVietnamese: return NSLocalizedString("Japanese – Vietnamese", comment: "")
        case .vietnameseToJapanese: return NSLocalizedString("Vietnamese – Japanese", comment: "")
        case .both: return NSLocalizedString("Mixed directions", comment: "Generated deck direction")
        }
    }

    /// Direction stored on the local deck. A mixed deck keeps each card as the server wrote it.
    var localDirection: LanguageSortingType {
        self == .vietnameseToJapanese ? .opposite : .normal
    }
}

enum DeckGenerationIssue: Equatable {
    case nameEmpty
    case nameTooLong
    case noLevel
    case noContentType
    case countOutOfRange
}

struct DeckGenerationRequest: Equatable {
    static let countRange = 5...100
    static let countStep = 5
    static let maximumNameLength = 120

    var name: String
    var level: GenerationLevel
    var contentTypes: Set<GenerationContentType>
    var direction: GenerationDirection
    var count: Int

    init(name: String = "", level: GenerationLevel = .n5, contentTypes: Set<GenerationContentType> = [.vocabulary],
         direction: GenerationDirection = .japaneseToVietnamese, count: Int = 20) {
        self.name = name
        self.level = level
        self.contentTypes = contentTypes
        self.direction = direction
        self.count = count
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Server-side filter values, in a stable order so identical choices encode identically.
    var sourceTypes: [String] { GenerationContentType.allCases.filter(contentTypes.contains).map(\.rawValue) }

    var issues: [DeckGenerationIssue] {
        var result: [DeckGenerationIssue] = []
        if trimmedName.isEmpty { result.append(.nameEmpty) }
        if trimmedName.count > Self.maximumNameLength { result.append(.nameTooLong) }
        if contentTypes.isEmpty { result.append(.noContentType) }
        if !Self.countRange.contains(count) { result.append(.countOutOfRange) }
        return result
    }

    /// Name suggested from the choices, so most learners only press Generate.
    static func suggestedName(level: GenerationLevel, contentTypes: Set<GenerationContentType>) -> String {
        let kinds = GenerationContentType.allCases.filter(contentTypes.contains).map(\.title)
        return ([level.title] + [kinds.joined(separator: ", ")]).joined(separator: " · ")
    }
}

/// A server deck downloaded for local use. Identity is the backend's: the deck id and each `deck_card` id.
struct GeneratedDeck: Equatable {
    struct Card: Equatable {
        let id: String
        let front: String
        let back: String
        let reading: String
    }

    let id: String
    let name: String
    let direction: GenerationDirection
    let cards: [Card]
}
