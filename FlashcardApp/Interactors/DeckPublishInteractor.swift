//
//  DeckPublishInteractor.swift
//  FlashcardApp
//
//  Saves a deck from this device to the learner's account, as the website's deck composer does: each card picture is
//  uploaded (or, for a picture found through the picture search, its asset from `image-selections` is reused), then the
//  deck is created with `primaryImageAssetId` per card. This is a one-way copy: later edits are not synchronised, and a deck
//  already saved is not saved again (the link below remembers which account deck came from which device deck).
//
//  Server load is bounded: pictures go one at a time, each at most `maximumPictureBytes` (a few hundred KB, the picture is
//  re-encoded smaller until it fits), at most `maximumTotalBytes` per deck. A picture that does not fit is left out (the card is still saved); the deck is created once and never retried.
//

import Foundation
import RxSwift

/// Which account deck was created from which device deck, per account. Not a sync state, only a guard against saving twice.
final class DeckAccountLinks {
    static let shared = DeckAccountLinks()

    private let defaults: UserDefaults
    private let accountId: () -> String?
    private let keyPrefix = "com.flashcardapp.cards.accountLinks."

    init(defaults: UserDefaults = .standard, accountId: @escaping () -> String? = { AuthSession.shared.currentUser?.id }) {
        self.defaults = defaults
        self.accountId = accountId
    }

    private var key: String? { accountId().map { keyPrefix + $0 } }
    private var links: [String: String] {
        get { key.flatMap { defaults.dictionary(forKey: $0) as? [String: String] } ?? [:] }
        set { if let key { defaults.set(newValue, forKey: key) } }
    }

    func accountDeckId(forDevice deckId: String) -> String? { links[deckId] }
    func deviceDeckId(forAccount deckId: String) -> String? { links.first { $0.value == deckId }?.key }
    func link(device deckId: String, account accountDeckId: String) { links[deckId] = accountDeckId }
}

struct DeckPublishReport: Equatable {
    let accountDeckId: String
    let cardCount: Int
    /// Pictures uploaded now, reused from the picture search, and left out because they were missing or too large.
    let uploaded: Int
    let reused: Int
    let skipped: Int
}

enum DeckPublishUpdate: Equatable {
    /// `done` of `total` pictures handled.
    case uploading(done: Int, total: Int)
    /// The deck is being created; from here on the work cannot be cancelled without an unknown outcome.
    case creating
    case finished(DeckPublishReport)
}

enum DeckPublishError: Error, Equatable, LocalizedError {
    case notFound
    case alreadySaved
    case tooManyCards(Int)
    case noCards

    var errorDescription: String? {
        switch self {
        case .notFound: return NSLocalizedString("That deck could not be found on this device.", comment: "")
        case .alreadySaved: return NSLocalizedString("This deck is already on your account.", comment: "")
        case .tooManyCards(let limit): return String.localizedStringWithFormat(NSLocalizedString("A deck can hold up to %lld cards.", comment: ""), limit)
        case .noCards: return NSLocalizedString("Add at least one card with a front and a back first.", comment: "")
        }
    }
}

protocol DeckPublishInteractorInterface: AnyObject {
    var isSignedIn: Bool { get }
    /// The account deck made from this device deck, if any.
    func accountDeckId(forDevice deckId: String) -> String?
    /// How many cards carry a picture; shown before the learner confirms.
    func pictureCount(ofDeck deckId: String) -> Int
    /// Emits progress, then `.finished`. Disposing stops the uploads; the create call is not started after that.
    func publish(deckId: String) -> Observable<DeckPublishUpdate>
}

final class DeckPublishInteractor: DeckPublishInteractorInterface {
    static let maximumPictureBytes = 300_000
    static let maximumTotalBytes = 20_000_000

    private let api: BJTAccountDeckAPIInterface
    private let repository: DeskRepositoryInterface
    private let images: CardImageStore
    private let links: DeckAccountLinks
    private let auth: AuthSession

    init(api: BJTAccountDeckAPIInterface = BJTLearnerAPI.shared,
         repository: DeskRepositoryInterface = DeskManagement.shared,
         images: CardImageStore = .shared,
         links: DeckAccountLinks = .shared,
         auth: AuthSession = .shared) {
        self.api = api
        self.repository = repository
        self.images = images
        self.links = links
        self.auth = auth
    }

    var isSignedIn: Bool { auth.bearerToken != nil }

    func accountDeckId(forDevice deckId: String) -> String? { links.accountDeckId(forDevice: deckId) }

    func pictureCount(ofDeck deckId: String) -> Int {
        repository.desk(withId: deckId)?.cards.filter { !$0.imageUrl.isEmpty }.count ?? 0
    }

    /// What one card needs from the picture step; mutated only by the serial pipeline below.
    private final class Run {
        var assetIds: [String: String] = [:]
        var uploaded = 0, reused = 0, skipped = 0
        var bytes = 0
    }

    func publish(deckId: String) -> Observable<DeckPublishUpdate> {
        guard let desk = repository.desk(withId: deckId) else { return .error(DeckPublishError.notFound) }
        guard links.accountDeckId(forDevice: deckId) == nil else { return .error(DeckPublishError.alreadySaved) }
        let cards = desk.cards.filter { !$0.frontText.trimmed.isEmpty && !$0.backText.trimmed.isEmpty }
        guard !cards.isEmpty else { return .error(DeckPublishError.noCards) }
        guard cards.count <= DeckDraft.maximumCards else { return .error(DeckPublishError.tooManyCards(DeckDraft.maximumCards)) }

        let run = Run()
        let withPictures = cards.filter { !$0.imageUrl.isEmpty }
        let uploads = Observable.from(Array(withPictures.enumerated())).concatMap { [self] item -> Observable<DeckPublishUpdate> in
            picture(of: item.element, run: run).asObservable().map { _ in .uploading(done: item.offset + 1, total: withPictures.count) }
        }
        let create = Observable<DeckPublishUpdate>.deferred { [self] in
            let input = AccountDeckInput(titleVi: desk.name.trimmed, visibility: "private", cards: cards.map {
                AccountDeckCardInput(frontText: $0.frontText.trimmed, backText: $0.backText.trimmed, reading: Self.reading(of: $0),
                                     primaryImageAssetId: run.assetIds[$0.id])
            })
            return api.createDeck(input).asObservable().map { [links] created in
                guard UUID(uuidString: created.id) != nil else { throw LearnerAPIError.invalidResponse }
                links.link(device: deckId, account: created.id)
                return .finished(DeckPublishReport(accountDeckId: created.id, cardCount: cards.count, uploaded: run.uploaded,
                                                   reused: run.reused, skipped: run.skipped))
            }.startWith(.creating)
        }
        return uploads.concat(create).do(onError: { [auth] error in
            if case LearnerAPIError.signInRequired = error, auth.bearerToken != nil { _ = auth.refresh().subscribe() }
        })
    }

    /// Resolves the asset of one card's picture into `run`. A picture that cannot be sent is skipped; a failure that would
    /// repeat for every picture (signed out, rate limited, offline) ends the whole save instead.
    private func picture(of card: CardEntity, run: Run) -> Single<Void> {
        let reference = CardImageReference(card.imageUrl)
        guard case .local = reference else {
            run.skipped += 1
            return .just(())
        }
        if let assetId = images.attribution(for: card.imageUrl)?.assetId {
            run.assetIds[card.id] = assetId
            run.reused += 1
            return .just(())
        }
        return Single.deferred { [self] in
            guard let data = images.uploadData(for: reference, maximumBytes: Self.maximumPictureBytes),
                  run.bytes + data.count <= Self.maximumTotalBytes else {
                run.skipped += 1
                return .just(())
            }
            return api.uploadPicture(data: data, fileName: "card-\(card.id.prefix(8)).jpg", mimeType: "image/jpeg")
                .map { assetId in
                    run.assetIds[card.id] = assetId
                    run.uploaded += 1
                    run.bytes += data.count
                }
                .catch { error in
                    switch error {
                    case LearnerAPIError.invalidRequest, LearnerAPIError.notFound, LearnerAPIError.invalidResponse, LearnerAPIError.server:
                        run.skipped += 1
                        return .just(())
                    default:
                        return .error(error)
                    }
                }
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .userInitiated))
    }

    /// The reading is stored under whichever side is Japanese (see `DeckGeneratorInteractor.entity`).
    static func reading(of card: CardEntity) -> String? {
        let value: String
        if JapaneseText.containsJapanese(card.frontText) {
            value = card.frontExtraText
        } else if JapaneseText.containsJapanese(card.backText) {
            value = card.backExtraText
        } else {
            return nil
        }
        return value.trimmed.isEmpty ? nil : value.trimmed
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
