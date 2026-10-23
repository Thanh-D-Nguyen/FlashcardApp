//
//  DeskManagement.swift
//  FlashcardApp
//
//  Created by タイン・グエン on 2023/02/23.
//

import Foundation
import RealmSwift

/// Realm-backed deck repository. All access happens on the thread that owns `RealmService.shared.realm`
/// (the main thread); callers receive value copies (`DeskEntity`), never live Realm objects.
class DeskManagement: DeskRepositoryInterface {
    static let shared = DeskManagement()

    private var realm: Realm { RealmService.shared.realm }

    func getAll() -> [DeskEntity] {
        let desks = realm.objects(RDesk.self)
        return Array(desks).map({ $0.toEntity() }).sorted(by: { $0.date > $1.date })
    }

    func deskFromId(_ id: String) -> RDesk? {
        return realm.object(ofType: RDesk.self, forPrimaryKey: id)
    }

    func desk(withId id: String) -> DeskEntity? {
        deskFromId(id)?.toEntity()
    }

    /// Realm raises an uncatchable exception on a duplicate primary key, so ids are checked first. A card id must also
    /// not be in use by another deck: saving would otherwise silently move that card out of its deck.
    private func validateIdentity(of desk: DeskEntity, allowedOwner ownerId: String?) throws {
        for card in desk.cards {
            if let existing = realm.object(ofType: RCard.self, forPrimaryKey: card.id),
               !existing.assignee.contains(where: { $0.id == ownerId }) {
                throw AppError.invalidInput(NSLocalizedString("A card in this deck already belongs to another deck.", comment: ""))
            }
        }
    }

    func add(_ desk: DeskEntity) throws {
        guard deskFromId(desk.id) == nil else {
            throw AppError.invalidInput(NSLocalizedString("This deck already exists.", comment: ""))
        }
        try validateIdentity(of: desk, allowedOwner: nil)
        try realm.write {
            realm.add(desk.toRealm())
        }
    }

    /// Replaces the deck's fields and card list in one transaction. The creation date and identity are kept;
    /// cards that were dropped from the deck are deleted so they cannot remain as orphans.
    func update(_ desk: DeskEntity) throws {
        guard let managed = deskFromId(desk.id) else {
            throw AppError.entityNotFound(NSLocalizedString("deck", comment: ""))
        }
        try validateIdentity(of: desk, allowedOwner: desk.id)
        try realm.write {
            let previous = Array(managed.cards)
            managed.name = desk.name
            managed.desc = desk.description
            managed.imageNamed = desk.imageNamed
            managed.sortingLanguage = desk.sortingLanguage.rawValue
            let cards = desk.cards.map { card -> RCard in
                let object = card.toRealm()
                realm.add(object, update: .modified)
                return object
            }
            managed.cards.removeAll()
            managed.cards.append(objectsIn: cards)
            let dropped = previous.filter { !$0.isInvalidated && $0.assignee.isEmpty }
            realm.deleteExamples(forCards: dropped.map(\.id))
            realm.deleteReviewHistory(forCards: dropped.map(\.id))
            realm.delete(dropped)
        }
    }

    func delete(_ desk: DeskEntity) throws {
        guard let managed = deskFromId(desk.id) else {
            throw AppError.entityNotFound(NSLocalizedString("deck", comment: ""))
        }
        try realm.write {
            let cards = Array(managed.cards)
            realm.delete(managed)
            let dropped = cards.filter { !$0.isInvalidated && $0.assignee.isEmpty }
            realm.deleteExamples(forCards: dropped.map(\.id))
            realm.deleteReviewHistory(forCards: dropped.map(\.id))
            realm.delete(dropped)
        }
    }
}
