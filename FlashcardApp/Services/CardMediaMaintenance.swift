//
//  CardMediaMaintenance.swift
//  FlashcardApp
//
//  Deletes stored card pictures that nothing references any more: a card or deck was deleted, a picture
//  was replaced, or an editing session was discarded. References come from saved decks and from
//  unsaved drafts, so recoverable work never loses its pictures.
//

import Foundation

struct CardMediaMaintenance {
    private let repository: DeskRepositoryInterface
    private let drafts: DeckDraftStoreInterface
    private let store: CardImageStore

    init(repository: DeskRepositoryInterface = DeskManagement.shared,
         drafts: DeckDraftStoreInterface = DeckDraftStore.shared,
         store: CardImageStore = .shared) {
        self.repository = repository
        self.drafts = drafts
        self.store = store
    }

    /// Must run on the thread that owns the Realm (it reads every saved card).
    @discardableResult
    func collectGarbage() -> [String] {
        var referenced = drafts.referencedImages()
        for desk in repository.getAll() {
            desk.cards.forEach { if !$0.imageUrl.isEmpty { referenced.insert($0.imageUrl) } }
        }
        return store.removeUnreferenced(keeping: referenced)
    }
}
