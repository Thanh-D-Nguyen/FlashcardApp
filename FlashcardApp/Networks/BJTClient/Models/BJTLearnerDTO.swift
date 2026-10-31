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

/// `POST /api/media/search-images` → `{ "results": [...] }`. Each result carries a short-lived signed `handle` (valid 15 minutes,
/// bound to the account) plus the attribution the picture's licence asks for; the handle is what `image-selections` consumes.
struct BJTImageSearchResponseDTO: Decodable, Equatable {
    let results: [BJTImageResultDTO]
}

struct BJTImageResultDTO: Decodable, Equatable {
    let handle: String
    let provider: String
    let url: String
    let sourceUrl: String
    let author: String
    let authorUrl: String?
    let license: String
    let licenseUrl: String?
}

/// `POST /api/media/image-selections` → `201 { "assetId": "…", "status": "pending_review" }`.
struct BJTImageSelectionDTO: Decodable, Equatable {
    let assetId: String
    let status: String
}

/// `{ "error": "message" }`, written by every Go handler and guard.
struct BJTErrorBodyDTO: Decodable {
    let error: String?
}
