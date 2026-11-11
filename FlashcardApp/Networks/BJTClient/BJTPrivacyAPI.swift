import Alamofire
import Foundation
import RxSwift

/// One row of `GET /api/learner/privacy/requests` (verified on production 2026-11-11 with a throw-away account). `status` moves
/// `pending` → `processing` (an administrator acknowledged it) → `completed` (export ready) or `failed` (rejected). For a completed
/// export `resultPayload` is a JSON *string* like `{"reason":"…","expiresAt":"…"}`; the file itself is only served by `…/export`.
struct BJTPrivacyRequestDTO: Decodable, Equatable {
    let id: String
    let kind: String
    let status: String
    let resultPayload: String?
    let createdAt: String
    let completedAt: String?
}

protocol BJTPrivacyAPIInterface: AnyObject {
    /// Read-only; the learner's own requests, newest first.
    func privacyRequests() -> Single<[BJTPrivacyRequestDTO]>
    /// Creates a new export request (201). NOT idempotent: each call creates another request for an administrator, so it is sent once
    /// per learner action and never retried by itself.
    func requestDataExport() -> Single<BJTPrivacyRequestDTO>
    /// The prepared export file (JSON) of a completed request. 404 before it is ready, 410 once it expired.
    func downloadDataExport(requestId: String) -> Single<Data>
}

extension BJTLearnerAPI: BJTPrivacyAPIInterface {
    private struct ExportBody: Encodable { let kind = "export" }
    private struct NoBody: Encodable {}

    func privacyRequests() -> Single<[BJTPrivacyRequestDTO]> {
        perform(["learner", "privacy", "requests"], method: .get, body: Optional<NoBody>.none)
    }

    func requestDataExport() -> Single<BJTPrivacyRequestDTO> {
        let response: Single<BJTPrivacyRequestDTO> = perform(["learner", "privacy", "requests"], method: .post, body: ExportBody())
        return response.map { row in
            guard row.kind == "export", UUID(uuidString: row.id) != nil else { throw LearnerAPIError.invalidResponse }
            return row
        }
    }

    func downloadDataExport(requestId: String) -> Single<Data> {
        // The id becomes a path segment: only a UUID.
        guard UUID(uuidString: requestId) != nil else { return .error(LearnerAPIError.invalidRequest(nil)) }
        return performData(["learner", "privacy", "requests", requestId, "export"], method: .get, body: Optional<NoBody>.none)
    }
}
