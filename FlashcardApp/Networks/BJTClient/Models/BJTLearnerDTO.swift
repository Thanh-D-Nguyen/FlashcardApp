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
