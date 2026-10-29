import Alamofire
import Foundation
import RxSwift

/// The calls behind the website's flashcard library: the account's decks, the cards due for review, the rating of a card
/// and archiving one's own deck. Kept apart from `BJTLearnerAPIInterface` (generation, images) so each screen depends only
/// on what it uses.
protocol BJTFlashcardLibraryAPIInterface: AnyObject {
    /// The learner's own decks and all public decks. Read-only; safe to repeat.
    func libraryDecks(limit: Int) -> Single<[BJTDeckSummaryDTO]>
    /// Read-only; safe to repeat.
    func deck(id: String) -> Single<BJTRemoteDeckDTO>
    /// Cards whose review is due, oldest first. Read-only; safe to repeat.
    func dueCards(limit: Int) -> Single<[BJTDueCardDTO]>
    /// Records one review and reschedules the card. NOT idempotent: the server applies the rating every time it is received,
    /// so a caller never repeats it by itself; only the learner may choose to try again.
    func submitReview(userFlashcardId: String, rating: ReviewRating, elapsedMs: Int?) -> Single<Void>
    /// Hides one of the learner's own decks from every list. Safe to repeat.
    func archiveDeck(id: String) -> Single<Void>
}

extension BJTLearnerAPI: BJTFlashcardLibraryAPIInterface {
    /// The server clamps a limit above this to its default, which would silently return fewer or different rows.
    private static let maximumLimit = 200

    private struct ReviewBody: Encodable { let rating: String; let elapsedMs: Int? }

    func libraryDecks(limit: Int) -> Single<[BJTDeckSummaryDTO]> {
        guard (1...Self.maximumLimit).contains(limit) else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return perform(["flashcards", "decks"], method: .get, body: Optional<ReviewBody>.none, query: ["limit": String(limit)])
    }

    func dueCards(limit: Int) -> Single<[BJTDueCardDTO]> {
        guard (1...Self.maximumLimit).contains(limit) else { return .error(LearnerAPIError.invalidRequest(nil)) }
        // The handler normalises "nothing due" to `[]`, but a `null` is tolerated: it means the same.
        let response: Single<[BJTDueCardDTO]?> = perform(["flashcards", "reviews", "due"], method: .get,
                                                         body: Optional<ReviewBody>.none, query: ["limit": String(limit)])
        return response.map { $0 ?? [] }
    }

    func submitReview(userFlashcardId: String, rating: ReviewRating, elapsedMs: Int?) -> Single<Void> {
        // The id becomes a path segment: accept only a UUID so nothing can alter the route.
        guard UUID(uuidString: userFlashcardId) != nil else { return .error(LearnerAPIError.invalidRequest(nil)) }
        let body = ReviewBody(rating: rating.rawValue, elapsedMs: elapsedMs.map { max($0, 0) })
        let response: Single<BJTReviewAckDTO> = perform(["flashcards", "reviews", userFlashcardId], method: .post, body: body)
        return response.map { ack in
            guard ack.success else { throw LearnerAPIError.invalidResponse }
        }
    }

    func archiveDeck(id: String) -> Single<Void> {
        guard UUID(uuidString: id) != nil else { return .error(LearnerAPIError.invalidRequest(nil)) }
        let response: Single<BJTArchiveAckDTO> = perform(["flashcards", "decks", id, "archive"], method: .post, body: Optional<ReviewBody>.none)
        return response.map { ack in
            guard ack.archived else { throw LearnerAPIError.invalidResponse }
        }
    }
}
