//
//  BJTDeckDTO.swift
//  FlashcardApp
//
//  Created by Claude on 2026/09/06.
//

import Foundation

// MARK: - Deck Response (GET /api/decks, GET /api/flashcards/decks)

struct BJTDeckDTO: Codable {
    let id: String
    let ownerUserId: String?
    let titleVi: String
    let titleJa: String?
    let descriptionVi: String?
    let descriptionJa: String?
    let visibility: String
    let status: String
    let shareToken: String?
    let sourceDeckId: String?
    let cloneCount: Int
    let createdAt: String
    let updatedAt: String
    let _count: BJTDeckCountDTO?

    enum CodingKeys: String, CodingKey {
        case id, ownerUserId, titleVi, titleJa, descriptionVi, descriptionJa
        case visibility, status, shareToken, sourceDeckId, cloneCount
        case createdAt, updatedAt
        case _count
    }
}

struct BJTDeckCountDTO: Codable {
    let cards: Int
}

// MARK: - Create Deck Request (POST /api/decks)

struct BJTCreateDeckRequestDTO: Codable {
    let userId: String
    let titleVi: String
    let titleJa: String?
    let descriptionVi: String?
    let descriptionJa: String?
    let visibility: String?
}

// MARK: - Update Deck Request (PATCH /api/decks/{id})

struct BJTUpdateDeckRequestDTO: Codable {
    let userId: String
    let titleVi: String?
    let titleJa: String?
    let descriptionVi: String?
    let descriptionJa: String?
    let visibility: String?
}

// MARK: - Archive Deck Request (POST /api/decks/{id}/archive)

struct BJArchiveDeckRequestDTO: Codable {
    let userId: String
}

// MARK: - Card From Content Request (POST /api/decks/{deckId}/cards, POST /api/flashcards/cards/from-content)

struct BJTCreateCardFromContentRequestDTO: Codable {
    let userId: String
    let deckId: String?
    let contentType: String
    let contentId: String
    let frontText: String?
    let backText: String?
    let reading: String?
}

// MARK: - Deck Cards Response (GET /api/decks/{deckId}/cards)

struct BJTDeckCardDTO: Codable {
    let id: String
    let deckId: String
    let frontText: String
    let backText: String
    let reading: String?
    let contentType: String?
    let contentId: String?
    let createdAt: String?
    let updatedAt: String?
}

// MARK: - Generate Deck Request (POST /api/flashcards/decks/generate)

struct BJTGenerateDeckRequestDTO: Codable {
    let userId: String
    let titleVi: String
    let titleJa: String?
    let filters: BJTGenerateDeckFiltersDTO?
}

struct BJTGenerateDeckFiltersDTO: Codable {
    let levels: [String]?
    let contentTypes: [String]?
    let limit: Int?
}

// MARK: - Generate Deck Preview Response (POST /api/flashcards/decks/generate/preview)

struct BJTGenerateDeckPreviewDTO: Codable {
    let availableCards: Int
    let matchedContent: Int
    let filters: BJTGenerateDeckFiltersDTO?
}

// MARK: - Clone Deck Response (POST /api/flashcards/decks/clone/{token})

struct BJTCloneDeckResponseDTO: Codable {
    let id: String
    let titleVi: String
    let titleJa: String?
    let sourceDeckId: String?
    let cloneCount: Int?
}

// MARK: - Share Deck Response (POST /api/flashcards/decks/{deckId}/share)

struct BJTShareDeckResponseDTO: Codable {
    let shareToken: String
    let shareUrl: String?
}

// MARK: - Deck Detail Response (GET /api/decks/{id})

struct BJTDeckDetailDTO: Codable {
    let id: String
    let ownerUserId: String?
    let titleVi: String
    let titleJa: String?
    let descriptionVi: String?
    let descriptionJa: String?
    let visibility: String
    let status: String
    let shareToken: String?
    let sourceDeckId: String?
    let cloneCount: Int
    let createdAt: String
    let updatedAt: String
    let _count: BJTDeckCountDTO?
    let cards: [BJTDeckCardDTO]?

    enum CodingKeys: String, CodingKey {
        case id, ownerUserId, titleVi, titleJa, descriptionVi, descriptionJa
        case visibility, status, shareToken, sourceDeckId, cloneCount
        case createdAt, updatedAt
        case _count, cards
    }
}