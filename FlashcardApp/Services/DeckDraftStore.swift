//
//  DeckDraftStore.swift
//  FlashcardApp
//
//  Persists the deck editor's unsaved work so a crash, a force-quit or the system reclaiming memory
//  does not lose it. One draft per deck (`new` for a deck that does not exist yet). Drafts hold text
//  and picture references only, never image bytes: pictures already live in `CardImageStore`.
//

import Foundation

protocol DeckDraftStoreInterface: AnyObject {
    func draft(forDeckId deckId: String?) -> DeckDraft?
    func save(_ draft: DeckDraft)
    func discard(forDeckId deckId: String?)
    /// Picture references used by any stored draft; they must survive garbage collection.
    func referencedImages() -> Set<String>
}

final class DeckDraftStore: DeckDraftStoreInterface {
    static let shared = DeckDraftStore()

    private let defaults: UserDefaults
    private let keyPrefix = "com.flashcardapp.cards.draft."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(_ deckId: String?) -> String { keyPrefix + (deckId ?? "new") }

    func draft(forDeckId deckId: String?) -> DeckDraft? {
        guard let data = defaults.data(forKey: key(deckId)) else { return nil }
        // An undecodable draft is dropped rather than blocking the editor on every launch.
        guard let draft = try? JSONDecoder().decode(DeckDraft.self, from: data) else {
            defaults.removeObject(forKey: key(deckId))
            return nil
        }
        return draft
    }

    func save(_ draft: DeckDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        defaults.set(data, forKey: key(draft.deckId))
    }

    func discard(forDeckId deckId: String?) {
        defaults.removeObject(forKey: key(deckId))
    }

    func referencedImages() -> Set<String> {
        var result = Set<String>()
        for storedKey in defaults.dictionaryRepresentation().keys where storedKey.hasPrefix(keyPrefix) {
            guard let data = defaults.data(forKey: storedKey),
                  let draft = try? JSONDecoder().decode(DeckDraft.self, from: data) else { continue }
            draft.cards.forEach { if !$0.imageReference.isEmpty { result.insert($0.imageReference) } }
        }
        return result
    }
}
