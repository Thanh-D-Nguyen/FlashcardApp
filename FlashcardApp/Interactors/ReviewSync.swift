import CryptoKit
import Foundation
import RxSwift

/// Which self-ratings made on this device for an account deck can be sent to the account, and as what. Only "remembered" /
/// "needs review" are sent: a quiz pick or a typed answer is recognition, not the learner's own judgement of recall, and is never
/// turned into a server rating. The local schedule is never changed by the server, and the server keeps the newer of the two
/// (an older device rating is "superseded"): the two schedulers stay independent, only ratings travel, at most once each.
enum ReviewSyncPlanner {
    static func rating(for attempt: ReviewAttempt) -> String? {
        switch attempt.result {
        case .needsReview: return "again"
        case .remembered: return attempt.hints.isEmpty ? "good" : "hard"
        case .correct, .incorrect, .typedCorrect, .typedIncorrect: return nil
        }
    }

    /// Oldest first, so two ratings of one card arrive in the order they were made.
    static func items(attempts: [ReviewAttempt], deckCardIds: Set<String>, done: Set<String>, now: Date, maxAgeDays: Int) -> [BJTReviewSyncItem] {
        let oldest = now.addingTimeInterval(-Double(maxAgeDays) * 86_400)
        return attempts
            .filter { deckCardIds.contains($0.cardID) && !done.contains($0.id) && $0.answeredAt >= oldest && $0.answeredAt <= now.addingTimeInterval(300) }
            .sorted { ($0.answeredAt, $0.id) < ($1.answeredAt, $1.id) }
            .compactMap { attempt in
                rating(for: attempt).map {
                    BJTReviewSyncItem(clientMutationId: attempt.id, deckCardId: attempt.cardID, rating: $0,
                                      reviewedAt: BJTReviewSyncItem.timestamp(attempt.answeredAt))
                }
            }
    }
}

/// The ratings already handled by the account (applied, already there, superseded or refused), per account, in one small file.
protocol ReviewSyncLedgerInterface: AnyObject {
    func done(account: String) -> Set<String>
    func markDone(_ ids: [String], account: String) throws
}

final class FileReviewSyncLedger: ReviewSyncLedgerInterface {
    static let shared = FileReviewSyncLedger()
    private let directory: URL

    init(directory: URL? = nil) {
        let base = directory ?? (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
        self.directory = base.appendingPathComponent("ReviewSync", isDirectory: true)
    }

    /// The account id is hashed so the file name says nothing about who it is.
    private func url(_ account: String) -> URL {
        let digest = SHA256.hash(data: Data(account.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest + ".json")
    }

    func done(account: String) -> Set<String> {
        guard let data = try? Data(contentsOf: url(account)), let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(ids)
    }

    func markDone(_ ids: [String], account: String) throws {
        guard !ids.isEmpty else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let all = done(account: account).union(ids).sorted()
        try JSONEncoder().encode(all).write(to: url(account), options: [.atomic])
    }
}

struct ReviewSyncReport: Equatable {
    var applied = 0
    var alreadyThere = 0
    /// The account has a newer review of the card: the device rating is not applied, the account's schedule is kept.
    var superseded = 0
    var refused = 0
}

protocol ReviewSyncInteractorInterface: AnyObject {
    /// Self-ratings of this account deck's device copy that are not on the account yet (local only, no network).
    func pendingCount(deckId: String) -> Int
    /// Emits whether the server can take them safely (an idempotent batch); `false` for servers without it.
    func isSupported() -> Single<Bool>
    /// Sends the pending ratings (in batches the server allows) and records what the server did with each.
    func send(deckId: String) -> Single<ReviewSyncReport>
}

final class ReviewSyncInteractor: ReviewSyncInteractorInterface {
    private let api: BJTReviewSyncAPIInterface
    private let history: ReviewHistoryStoreInterface
    private let ledger: ReviewSyncLedgerInterface
    private let deckCardIds: (String) -> Set<String>
    private let accountId: () -> String?
    private let now: () -> Date
    private var capabilities: BJTReviewSyncCapabilitiesDTO?

    init(api: BJTReviewSyncAPIInterface = BJTLearnerAPI.shared,
         history: ReviewHistoryStoreInterface = RealmReviewHistoryStore(),
         ledger: ReviewSyncLedgerInterface = FileReviewSyncLedger.shared,
         deckCardIds: @escaping (String) -> Set<String> = { id in Set(DeskManagement.shared.desk(withId: id)?.cards.map(\.id) ?? []) },
         accountId: @escaping () -> String? = { AuthSession.shared.bearerToken == nil ? nil : AuthSession.shared.currentUser?.id },
         now: @escaping () -> Date = Date.init) {
        self.api = api
        self.history = history
        self.ledger = ledger
        self.deckCardIds = deckCardIds
        self.accountId = accountId
        self.now = now
    }

    private func items(deckId: String, maxAgeDays: Int) -> [BJTReviewSyncItem] {
        guard let account = accountId(), !account.isEmpty else { return [] }
        let cards = deckCardIds(deckId)
        guard !cards.isEmpty else { return [] }
        return ReviewSyncPlanner.items(attempts: history.attempts(ownerKey: account, cardId: nil), deckCardIds: cards,
                                       done: ledger.done(account: account), now: now(), maxAgeDays: maxAgeDays)
    }

    func pendingCount(deckId: String) -> Int { items(deckId: deckId, maxAgeDays: capabilities?.maxAgeDays ?? 30).count }

    func isSupported() -> Single<Bool> {
        if let capabilities { return .just(capabilities.idempotentBatch && capabilities.deckCardIdentity) }
        return api.reviewSyncCapabilities()
            .do(onSuccess: { [weak self] in self?.capabilities = $0 })
            .map { $0.idempotentBatch && $0.deckCardIdentity && $0.maxItems > 0 }
            .catch { error in
                if case LearnerAPIError.notFound = error { return .just(false) }
                return .error(error)
            }
    }

    func send(deckId: String) -> Single<ReviewSyncReport> {
        isSupported().flatMap { [weak self] supported -> Single<ReviewSyncReport> in
            guard let self, supported, let capabilities = self.capabilities, let account = self.accountId() else {
                return .error(LearnerAPIError.serviceUnavailable(nil))
            }
            let all = self.items(deckId: deckId, maxAgeDays: capabilities.maxAgeDays)
            let size = max(1, min(capabilities.maxItems, 100))
            let batches = stride(from: 0, to: all.count, by: size).map { Array(all[$0..<min($0 + size, all.count)]) }
            // One batch after another; a failure stops there. Every item is idempotent on this server, so a later tap may send again.
            return Observable.from(batches)
                .concatMap { batch in self.api.syncReviews(batch).asObservable() }
                .reduce(ReviewSyncReport()) { report, results in
                    var report = report
                    var done: [String] = []
                    for result in results {
                        switch result.status {
                        case "applied"?: report.applied += 1
                        case "duplicate"?: report.alreadyThere += 1
                        case "superseded"?: report.superseded += 1
                        default:
                            if result.ok { report.applied += 1 } else { report.refused += 1 }
                        }
                        // A server error ("internal") is not final: everything else is.
                        if result.ok || result.status != nil { done.append(result.clientMutationId) }
                    }
                    try self.ledger.markDone(done, account: account)
                    return report
                }
                .asSingle()
        }
    }
}
