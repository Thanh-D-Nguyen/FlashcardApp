//
//  DeckGeneratorInteractor.swift
//  FlashcardApp
//
//  Generates a deck on the server and brings it onto the device.
//
//  Identity: the server creates the deck and answers with its id but no cards, so the cards are fetched with a
//  read-only GET. The local deck then uses the server's own ids unchanged — the deck's id for the deck and each
//  `deck_card` id for its cards (unique per deck, unlike the shared flashcard variant ids). Importing the same
//  server deck twice therefore finds the existing local deck instead of duplicating it.
//
//  Nothing synchronises afterwards: edits stay on the device, and deleting the local deck does not touch the
//  server's copy. Generation itself is never retried automatically (it has no idempotency key).
//

import Foundation
import RxSwift

/// What the server reported after creating the deck.
struct GeneratedDeckReceipt: Equatable {
    let id: String
    let name: String
    let cardCount: Int
    let direction: GenerationDirection
}

enum DeckImportOutcome: Equatable {
    case imported(deckId: String)
    /// A deck with this server id is already on the device; nothing was written.
    case alreadyPresent(deckId: String)

    var deckId: String {
        switch self {
        case .imported(let id), .alreadyPresent(let id): return id
        }
    }
}

protocol DeckGeneratorInteractorInterface: AnyObject {
    var isSignedIn: Bool { get }
    func preview(level: GenerationLevel, contentTypes: [GenerationContentType]) -> Single<Int>
    /// Creates a deck on the server. Never call it twice for one learner action.
    func generate(_ request: DeckGenerationRequest) -> Single<GeneratedDeckReceipt>
    /// Read-only: fetches the cards of a created deck. Safe to repeat.
    func download(_ receipt: GeneratedDeckReceipt) -> Single<GeneratedDeck>
    func importDeck(_ deck: GeneratedDeck) throws -> DeckImportOutcome
}

final class DeckGeneratorInteractor: DeckGeneratorInteractorInterface {
    private let api: BJTLearnerAPIInterface
    private let repository: DeskRepositoryInterface
    private let auth: AuthSession

    init(api: BJTLearnerAPIInterface = BJTLearnerAPI.shared,
         repository: DeskRepositoryInterface = DeskManagement.shared,
         auth: AuthSession = .shared) {
        self.api = api
        self.repository = repository
        self.auth = auth
    }

    var isSignedIn: Bool { auth.bearerToken != nil }

    func preview(level: GenerationLevel, contentTypes: [GenerationContentType]) -> Single<Int> {
        api.previewGeneration(level: level, contentTypes: contentTypes).do(onError: signOutIfRejected)
    }

    func generate(_ request: DeckGenerationRequest) -> Single<GeneratedDeckReceipt> {
        api.generateDeck(request)
            .map { dto in
                guard UUID(uuidString: dto.id) != nil else { throw LearnerAPIError.invalidResponse }
                return GeneratedDeckReceipt(id: dto.id, name: dto.titleVi, cardCount: dto.cardCount, direction: request.direction)
            }
            .do(onError: signOutIfRejected)
    }

    func download(_ receipt: GeneratedDeckReceipt) -> Single<GeneratedDeck> {
        api.deck(id: receipt.id)
            .map { try Self.deck(from: $0, direction: receipt.direction) }
            .do(onError: signOutIfRejected)
    }

    func importDeck(_ deck: GeneratedDeck) throws -> DeckImportOutcome {
        if repository.desk(withId: deck.id) != nil { return .alreadyPresent(deckId: deck.id) }
        do {
            try repository.add(Self.entity(from: deck))
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.databaseWriteFailed(error.localizedDescription)
        }
        return .imported(deckId: deck.id)
    }

    // MARK: Mapping

    static func deck(from dto: BJTRemoteDeckDTO, direction: GenerationDirection) throws -> GeneratedDeck {
        guard UUID(uuidString: dto.id) != nil else { throw LearnerAPIError.invalidResponse }
        let cards = try dto.cards.sorted { ($0.position, $0.id) < ($1.position, $1.id) }.compactMap { entry -> GeneratedDeck.Card? in
            guard UUID(uuidString: entry.id) != nil else { throw LearnerAPIError.invalidResponse }
            let front = entry.card.frontText.trimmingCharacters(in: .whitespacesAndNewlines)
            let back = entry.card.backText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !front.isEmpty, !back.isEmpty else { return nil }
            return GeneratedDeck.Card(id: entry.id, front: front, back: back,
                                      reading: entry.card.reading?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        }
        return GeneratedDeck(id: dto.id, name: dto.titleVi, direction: direction, cards: cards)
    }

    /// The reading belongs to the Japanese side: under the front when that is Japanese, with the answer otherwise.
    static func entity(from deck: GeneratedDeck, now: Date = Date()) -> DeskEntity {
        let entity = DeskEntity()
        entity.id = deck.id
        entity.name = deck.name
        entity.sortingLanguage = deck.direction.localDirection
        entity.date = now
        entity.cards = deck.cards.map { card in
            let entry = CardEntity()
            entry.id = card.id
            entry.frontText = card.front
            entry.backText = card.back
            if JapaneseText.containsJapanese(card.front) {
                entry.frontExtraText = card.reading
            } else if JapaneseText.containsJapanese(card.back) {
                entry.backExtraText = card.reading
            }
            return entry
        }
        return entity
    }

    /// The server no longer accepts the stored session: let the app notice and sign out locally.
    private func signOutIfRejected(_ error: Error) {
        if case LearnerAPIError.signInRequired = error, auth.bearerToken != nil { _ = auth.refresh().subscribe() }
    }
}
