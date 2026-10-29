import Foundation

// Shapes verified against the Go handlers in `apps/api-go/internal/httpserver/handler_flashcard_deck.go`
// and `flashcarddeck/store.go` (JSON tags), not against the checked-in OpenAPI file, whose responses are empty.

/// `POST /api/flashcards/decks/generate/preview` → `{ "availableCount": n }`.
struct BJTGenerationPreviewDTO: Decodable, Equatable {
    let availableCount: Int
}

/// `POST /api/flashcards/decks/generate` → the created deck row. It carries no cards.
struct BJTGeneratedDeckDTO: Decodable, Equatable {
    let id: String
    let titleVi: String
    let cardCount: Int
}

/// `GET /api/flashcards/decks/{deckId}` → the deck with its cards in position order.
struct BJTRemoteDeckDTO: Decodable, Equatable {
    struct Entry: Decodable, Equatable {
        struct Card: Decodable, Equatable {
            let id: String
            let frontText: String
            let backText: String
            let reading: String?
            let sourceId: String
            let sourceType: String
        }

        /// The `deck_card` row id: unique to this deck, so it is safe as a local card key.
        let id: String
        let position: Int
        let card: Card
    }

    let id: String
    let titleVi: String
    let cards: [Entry]
    // Present in the Go response; only the library detail screen reads them. `nil` owner means the deck is not the learner's.
    var titleJa: String? = nil
    var descriptionVi: String? = nil
    var descriptionJa: String? = nil
    var visibility: String? = nil
    var ownerUserId: String? = nil
}

/// One row of `GET /api/flashcards/decks`: the learner's own decks and every public deck. The server clears
/// `ownerUserId` (and `shareToken`) on decks that are not the caller's, so a nil owner means "someone else's".
struct BJTDeckSummaryDTO: Decodable, Equatable {
    let id: String
    let ownerUserId: String?
    let titleVi: String
    let titleJa: String?
    let descriptionVi: String?
    let descriptionJa: String?
    let visibility: String
    let status: String
    let cardCount: Int
    let createdAt: String?
    let updatedAt: String?
}

/// One entry of `GET /api/flashcards/reviews/due`. `id` is the learner's scheduling row (`user_flashcard`), which the rating is posted to.
struct BJTDueCardDTO: Decodable, Equatable {
    struct Content: Decodable, Equatable {
        let id: String
        let frontText: String
        let backText: String
        let reading: String?
    }

    let id: String
    let cardId: String
    let state: String
    let intervalDays: Int
    let lapses: Int
    let leeched: Bool
    let card: Content
}

/// `POST /api/flashcards/reviews/{id}` → `{ "success": true }`.
struct BJTReviewAckDTO: Decodable, Equatable {
    let success: Bool
}

/// `POST /api/flashcards/decks/{id}/archive` → `{ "archived": true }`.
struct BJTArchiveAckDTO: Decodable, Equatable {
    let archived: Bool
}

/// `POST /api/media/search-images`. The Go handler currently always answers 503, so this shape is the one the
/// website composer reads (`data.images`) and has NOT been observed in a Go success response.
struct BJTImageSearchResponseDTO: Decodable, Equatable {
    let images: [BJTImageResultDTO]
}

struct BJTImageResultDTO: Decodable, Equatable {
    let id: String
    let thumbUrl: String
    let fullUrl: String
    let source: String
}

/// `{ "error": "message" }`, written by every Go handler and guard.
struct BJTErrorBodyDTO: Decodable {
    let error: String?
}
