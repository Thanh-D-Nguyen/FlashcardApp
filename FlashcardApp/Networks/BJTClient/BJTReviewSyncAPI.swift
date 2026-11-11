import Alamofire
import Foundation
import RxSwift

/// `GET /api/flashcards/reviews/sync-capabilities` (backend branch `ios/kiokoto-k10-k18`, task IOSK-18). A server without it (404,
/// e.g. production on 2026-11-11) has no idempotent batch, so nothing is sent to it.
struct BJTReviewSyncCapabilitiesDTO: Decodable, Equatable {
    let idempotentBatch: Bool
    let deckCardIdentity: Bool
    let maxItems: Int
    let maxAgeDays: Int
}

/// One self-rating made on this device for a card of an account deck, keyed by the deck card id the local copy keeps.
struct BJTReviewSyncItem: Encodable, Equatable {
    let clientMutationId: String
    let deckCardId: String
    let rating: String
    /// RFC 3339 with milliseconds, which the Go handler decodes.
    let reviewedAt: String

    static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

/// What the server did with one item. `ok` means "nothing more to do" (applied, already applied, or older than the account's own
/// review, which is kept). `status` is absent on servers before IOSK-18.
struct BJTReviewSyncResultDTO: Decodable, Equatable {
    let clientMutationId: String
    let ok: Bool
    let status: String?
    let error: String?
}

protocol BJTReviewSyncAPIInterface: AnyObject {
    func reviewSyncCapabilities() -> Single<BJTReviewSyncCapabilitiesDTO>
    /// Idempotent on servers that advertise `idempotentBatch`: the same `clientMutationId` is applied at most once.
    func syncReviews(_ items: [BJTReviewSyncItem]) -> Single<[BJTReviewSyncResultDTO]>
}

extension BJTLearnerAPI: BJTReviewSyncAPIInterface {
    private struct NoBody: Encodable {}
    private struct Batch: Encodable { let items: [BJTReviewSyncItem] }
    private struct Results: Decodable { let results: [BJTReviewSyncResultDTO] }

    func reviewSyncCapabilities() -> Single<BJTReviewSyncCapabilitiesDTO> {
        perform(["flashcards", "reviews", "sync-capabilities"], method: .get, body: Optional<NoBody>.none)
    }

    func syncReviews(_ items: [BJTReviewSyncItem]) -> Single<[BJTReviewSyncResultDTO]> {
        guard (1...100).contains(items.count) else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return performData(["flashcards", "reviews", "batch"], method: .post, body: Batch(items: items))
            .map { data in
                do { return try JSONDecoder().decode(Results.self, from: data).results } catch { throw LearnerAPIError.invalidResponse }
            }
    }
}
