//
//  CreateDeskInteractor.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/26.
//  
//

import Foundation
import RxSwift

protocol CreateDeskInteractorInterface: AnyObject {
    func deck(withId id: String) -> DeskEntity?
    func savedDraft(forDeckId deckId: String?) -> DeckDraft?
    func saveDraft(_ draft: DeckDraft)
    func discardDraft(forDeckId deckId: String?)
    /// Adds or updates the deck (by `draft.deckId`), clears its draft and removes pictures nothing uses any more.
    func save(_ draft: DeckDraft) throws
    /// Releases pictures that only an abandoned editing session referenced.
    func collectUnusedPictures()
    /// Deletes the stored deck with its cards, its recovery draft and the pictures only it used.
    func deleteDeck(withId id: String) throws
    /// Validates, downsamples and stores picked picture bytes off the main thread; emits the stored reference.
    func storePicture(data: Data) -> Single<String>
    /// Downloads a picture from an https address and stores it locally; emits the stored reference.
    func downloadPicture(from url: URL) -> Single<String>
}

class CreateDeskInteractor {
    private let repository: DeskRepositoryInterface
    private let drafts: DeckDraftStoreInterface
    private let images: CardImageStore
    private let remote: RemoteImageLoader
    private let maintenance: CardMediaMaintenance

    init(repository: DeskRepositoryInterface = DeskManagement.shared,
         drafts: DeckDraftStoreInterface = DeckDraftStore.shared,
         images: CardImageStore = .shared,
         remote: RemoteImageLoader = .shared) {
        self.repository = repository
        self.drafts = drafts
        self.images = images
        self.remote = remote
        self.maintenance = CardMediaMaintenance(repository: repository, drafts: drafts, store: images)
    }
}

extension CreateDeskInteractor: CreateDeskInteractorInterface {
    func deck(withId id: String) -> DeskEntity? {
        repository.desk(withId: id)
    }

    func savedDraft(forDeckId deckId: String?) -> DeckDraft? {
        drafts.draft(forDeckId: deckId)
    }

    func saveDraft(_ draft: DeckDraft) {
        drafts.save(draft)
    }

    func discardDraft(forDeckId deckId: String?) {
        drafts.discard(forDeckId: deckId)
    }

    func save(_ draft: DeckDraft) throws {
        if let issue = draft.issues.first {
            throw issue.appError
        }
        let entity = draft.toEntity()
        do {
            if draft.isEditing {
                try repository.update(entity)
            } else {
                try repository.add(entity)
            }
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.databaseWriteFailed(error.localizedDescription)
        }
        drafts.discard(forDeckId: draft.deckId)
        maintenance.collectGarbage()
    }

    func collectUnusedPictures() {
        maintenance.collectGarbage()
    }

    func deleteDeck(withId id: String) throws {
        guard let deck = repository.desk(withId: id) else {
            throw AppError.entityNotFound(NSLocalizedString("deck", comment: ""))
        }
        do {
            try repository.delete(deck)
        } catch {
            throw AppError.databaseWriteFailed(error.localizedDescription)
        }
        drafts.discard(forDeckId: id)
        maintenance.collectGarbage()
    }

    func storePicture(data: Data) -> Single<String> {
        Single.create { [images] observer in
            DispatchQueue.global(qos: .userInitiated).async {
                do { observer(.success(try images.save(imageData: data))) } catch { observer(.failure(error)) }
            }
            return Disposables.create()
        }
    }

    func downloadPicture(from url: URL) -> Single<String> {
        remote.fetch(url).flatMap { [weak self] data in
            guard let self else { return .error(CardImageError.unreadable) }
            return self.storePicture(data: data)
        }
    }
}

extension DeckValidationIssue {
    /// The error shown when a caller tries to save a draft that still has this problem.
    var appError: AppError {
        switch self {
        case .nameEmpty: return .deskNameEmpty
        case .tooFewCards: return .flashCardMinimum
        case .tooManyCards:
            return .invalidInput(String.localizedStringWithFormat(NSLocalizedString("A deck can hold up to %lld cards.", comment: ""), DeckDraft.maximumCards))
        case .incompleteCard(let index, let missingFront):
            return .invalidInput(String(format: missingFront
                ? NSLocalizedString("Card %lld needs a front.", comment: "") : NSLocalizedString("Card %lld needs a back.", comment: ""), index + 1))
        }
    }
}
