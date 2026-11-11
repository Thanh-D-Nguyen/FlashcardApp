//
//  CardLibraryServerInteractor.swift
//  FlashcardApp
//
//  Use cases of the Cards tab that live on the learner's account: the website's deck library, the cards due for
//  review and rating them. Decks the learner studies are still stored on the device; "saving" a server deck copies
//  it there with the server's own ids (the same mapping the deck generator uses), so saving twice finds the first copy.
//
//  Nothing synchronises afterwards, and a rating is never sent twice by this layer.
//

import Foundation
import RxSwift

protocol CardLibraryServerInteractorInterface: AnyObject {
    var isSignedIn: Bool { get }
    /// Who is signed in; cached server data is only valid for this account.
    var accountId: String? { get }
    /// The learner's own decks and all public decks, newest changes first.
    func decks() -> Single<[ServerDeck]>
    func detail(deckId: String) -> Single<ServerDeckDetail>
    /// Up to `limit` cards due now, oldest first; a card whose content is unusable is skipped.
    func dueCards(limit: Int) -> Single<[DueCard]>
    /// Sends one rating. Never call it twice for one learner action.
    func submit(_ rating: ReviewRating, for card: DueCard, elapsed: TimeInterval) -> Single<Void>
    /// Wrong answers for a multiple-choice question about `card`. Read-only; an empty list means "no question, just flip".
    func distractors(for card: DueCard, count: Int) -> Single<[String]>
    func archive(deckId: String) -> Single<Void>
    func report(deckId: String, reason: String) -> Single<Void>
    func blockAuthor(deckId: String) -> Single<Void>
    /// The id of the device deck saved from this server deck, when there is one.
    func hasDeviceCopy(deckId: String) -> Bool
    func saveToDevice(_ detail: ServerDeckDetail) throws -> DeckImportOutcome
    /// Stores the pictures of a just-saved device copy next to it and links them to its cards. Best effort: a picture that
    /// cannot be fetched is skipped (the card stays without one) and never fails the copy. Emits how many were stored.
    func copyPictures(of detail: ServerDeckDetail) -> Single<Int>
}

final class CardLibraryServerInteractor: CardLibraryServerInteractorInterface {
    static let decksLimit = 200

    private let api: BJTFlashcardLibraryAPIInterface
    private let repository: DeskRepositoryInterface
    private let auth: AuthSession
    private let language: () -> AppLanguage
    private let remote: RemoteImageLoader
    private let images: CardImageStore
    private let links: DeckAccountLinks

    init(api: BJTFlashcardLibraryAPIInterface = BJTLearnerAPI.shared,
         repository: DeskRepositoryInterface = DeskManagement.shared,
         auth: AuthSession = .shared,
         language: @escaping () -> AppLanguage = { .current },
         remote: RemoteImageLoader = .shared,
         images: CardImageStore = .shared,
         links: DeckAccountLinks = .shared) {
        self.api = api
        self.repository = repository
        self.auth = auth
        self.language = language
        self.remote = remote
        self.images = images
        self.links = links
    }

    var isSignedIn: Bool { auth.bearerToken != nil }
    var accountId: String? { auth.bearerToken == nil ? nil : auth.currentUser?.id }

    func decks() -> Single<[ServerDeck]> {
        api.libraryDecks(limit: Self.decksLimit)
            .map { [language] rows in
                let language = language()
                return rows.filter { $0.status != "archived" && UUID(uuidString: $0.id) != nil }.map { ServerDeckMapper.deck(from: $0, language: language) }
            }
            .do(onError: signOutIfRejected)
    }

    func detail(deckId: String) -> Single<ServerDeckDetail> {
        api.deck(id: deckId)
            .map { [language] dto in
                guard UUID(uuidString: dto.id) != nil else { throw LearnerAPIError.invalidResponse }
                return ServerDeckMapper.detail(from: dto, language: language())
            }
            .do(onError: signOutIfRejected)
    }

    func dueCards(limit: Int) -> Single<[DueCard]> {
        api.dueCards(limit: limit)
            .map { $0.compactMap(ServerDeckMapper.dueCard(from:)) }
            .do(onError: signOutIfRejected)
    }

    func submit(_ rating: ReviewRating, for card: DueCard, elapsed: TimeInterval) -> Single<Void> {
        let milliseconds = Int((max(elapsed, 0) * 1000).rounded())
        return api.submitReview(userFlashcardId: card.id, rating: rating, elapsedMs: milliseconds)
            .do(onError: signOutIfRejected)
    }

    func distractors(for card: DueCard, count: Int) -> Single<[String]> {
        api.distractors(userFlashcardId: card.id, count: count).do(onError: signOutIfRejected)
    }

    func archive(deckId: String) -> Single<Void> {
        api.archiveDeck(id: deckId).do(onError: signOutIfRejected)
    }

    func report(deckId: String, reason: String) -> Single<Void> {
        api.reportDeck(id: deckId, reason: reason).do(onError: signOutIfRejected)
    }

    func blockAuthor(deckId: String) -> Single<Void> {
        api.blockDeckAuthor(id: deckId).do(onError: signOutIfRejected)
    }

    func hasDeviceCopy(deckId: String) -> Bool {
        if repository.desk(withId: deckId) != nil { return true }
        // A deck saved to the account from this device has its own id there: it is the same deck, not one to download again.
        return links.deviceDeckId(forAccount: deckId).map { repository.desk(withId: $0) != nil } ?? false
    }

    func saveToDevice(_ detail: ServerDeckDetail) throws -> DeckImportOutcome {
        if repository.desk(withId: detail.deck.id) != nil { return .alreadyPresent(deckId: detail.deck.id) }
        let deck = GeneratedDeck(id: detail.deck.id, name: detail.deck.title, direction: Self.direction(of: detail.cards),
                                 cards: detail.cards.map { GeneratedDeck.Card(id: $0.id, front: $0.front, back: $0.back, reading: $0.reading) })
        do {
            try repository.add(DeckGeneratorInteractor.entity(from: deck))
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.databaseWriteFailed(error.localizedDescription)
        }
        return .imported(deckId: detail.deck.id)
    }

    func copyPictures(of detail: ServerDeckDetail) -> Single<Int> {
        let pictures = detail.cards.compactMap { card in card.picture.map { (cardId: card.id, picture: $0) } }
        guard !pictures.isEmpty else { return .just(0) }
        // One at a time: a deck can hold 200 cards and each picture is up to 10 MB.
        return Observable.from(pictures)
            .concatMap { [weak self] item -> Observable<(String, String)> in
                guard let self else { return .empty() }
                return self.store(item.picture).asObservable().map { (item.cardId, $0) }.catch { _ in .empty() }
            }
            .toArray()
            // Realm is confined to the thread that opened it: the device deck is only touched on the main thread.
            .observe(on: MainScheduler.instance)
            .map { [weak self] stored -> Int in
                guard let self, !stored.isEmpty, let desk = self.repository.desk(withId: detail.deck.id) else { return 0 }
                let references = Dictionary(stored, uniquingKeysWith: { first, _ in first })
                for card in desk.cards { if let reference = references[card.id], card.imageUrl.isEmpty { card.imageUrl = reference } }
                do { try self.repository.update(desk) } catch { return 0 }
                return stored.count
            }
    }

    /// Fetches one picture (with the session only when it is the API's own copy), stores it and keeps its credit.
    private func store(_ picture: CardPicture) -> Single<String> {
        let authorization = APIImageAuthorization.header(for: picture.url, token: auth.bearerToken)
        return remote.fetch(picture.url, authorization: authorization)
            .observe(on: ConcurrentDispatchQueueScheduler(qos: .userInitiated))
            .map { [images] data in
                let reference = try images.save(imageData: data)
                if let attribution = picture.attribution { try? images.saveAttribution(attribution, for: reference) }
                return reference
            }
    }

    /// A deck has no stored direction on the server: read it from the first card (Vietnamese front, Japanese back reverses it).
    static func direction(of cards: [ServerDeckCard]) -> GenerationDirection {
        guard let first = cards.first else { return .japaneseToVietnamese }
        let japaneseFront = JapaneseText.containsJapanese(first.front)
        let japaneseBack = JapaneseText.containsJapanese(first.back)
        return !japaneseFront && japaneseBack ? .vietnameseToJapanese : .japaneseToVietnamese
    }

    /// The server no longer accepts the stored session: let the app notice and sign out locally.
    private func signOutIfRejected(_ error: Error) {
        if case LearnerAPIError.signInRequired = error, auth.bearerToken != nil { _ = auth.refresh().subscribe() }
    }
}
