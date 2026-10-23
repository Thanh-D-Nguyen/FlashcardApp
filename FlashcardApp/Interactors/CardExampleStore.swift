//
//  CardExampleStore.swift
//  FlashcardApp
//
//  The learner's own changes to a card's example sentences, in Realm on this device, per account (`ownerKey` is the
//  signed-in account id, or "" with nobody signed in). The server's sentences are never stored or changed: removing one
//  hides it for this account only, editing one stores the learner's text in its place, and both can be undone.
//  Nothing here is synced to the website; the backend has no per-learner examples.
//  Main thread only, like the other Realm repositories.
//

import Foundation
import RealmSwift

protocol CardExampleStoreInterface: AnyObject {
    func overlay(cardId: String, ownerKey: String) -> ExampleOverlay
    func addCustom(_ draft: CardExampleDraft, cardId: String, ownerKey: String) throws
    /// Saves the learner's text for a sentence: the sentence itself when it is theirs, otherwise their version of a server sentence.
    func update(_ item: ExampleItem, with draft: CardExampleDraft, cardId: String, ownerKey: String) throws
    /// Deletes a sentence the learner wrote, or hides a server sentence for this account.
    func remove(_ item: ExampleItem, cardId: String, ownerKey: String) throws
    /// Brings back the server's text for a sentence the learner edited.
    func restoreOriginal(of item: ExampleItem, cardId: String, ownerKey: String) throws
    /// Brings back every server sentence the learner removed from this card.
    func restoreRemoved(cardId: String, ownerKey: String) throws
}

final class RealmCardExampleStore: CardExampleStoreInterface {
    private var realm: Realm { RealmService.shared.realm }

    /// One record per (account, card, server sentence), so editing or removing the same sentence twice updates one row.
    private func serverRecordId(ownerKey: String, cardId: String, serverId: String) -> String { "\(ownerKey)|\(cardId)|\(serverId)" }

    private func records(cardId: String, ownerKey: String) -> Results<RCardExample> {
        realm.objects(RCardExample.self).filter("cardId == %@ AND ownerKey == %@", cardId, ownerKey)
    }

    func overlay(cardId: String, ownerKey: String) -> ExampleOverlay {
        var overlay = ExampleOverlay()
        for record in records(cardId: cardId, ownerKey: ownerKey).sorted(byKeyPath: "createdAt") {
            switch RCardExample.Kind(rawValue: record.kind) {
            case .custom:
                overlay.custom.append(CardExample(id: record.id, japanese: record.japanese, reading: record.reading, translation: record.translation))
            case .edited:
                overlay.edited[record.serverExampleId] = CardExample(id: record.serverExampleId, japanese: record.japanese,
                                                                     reading: record.reading, translation: record.translation)
            case .hidden:
                overlay.hidden.insert(record.serverExampleId)
            case nil:
                continue
            }
        }
        return overlay
    }

    func addCustom(_ draft: CardExampleDraft, cardId: String, ownerKey: String) throws {
        let draft = try draft.validated()
        let existing = records(cardId: cardId, ownerKey: ownerKey).filter("kind == %@", RCardExample.Kind.custom.rawValue).count
        guard existing < CardExampleDraft.maximumCustomPerCard else { throw CardExampleError.limitReached(CardExampleDraft.maximumCustomPerCard) }
        try realm.write {
            let record = RCardExample()
            record.id = UUID().uuidString
            fill(record, cardId: cardId, ownerKey: ownerKey, kind: .custom, serverId: "", draft: draft)
            realm.add(record)
        }
    }

    func update(_ item: ExampleItem, with draft: CardExampleDraft, cardId: String, ownerKey: String) throws {
        let draft = try draft.validated()
        try realm.write {
            switch item.origin {
            case .custom:
                let record = try ownedCustom(item.id, cardId: cardId, ownerKey: ownerKey)
                record.japanese = draft.japanese
                record.reading = draft.reading
                record.translation = draft.translation
                record.updatedAt = Date()
            case .server, .edited:
                let id = serverRecordId(ownerKey: ownerKey, cardId: cardId, serverId: item.id)
                let record = realm.object(ofType: RCardExample.self, forPrimaryKey: id) ?? RCardExample()
                if record.realm == nil { record.id = id }
                fill(record, cardId: cardId, ownerKey: ownerKey, kind: .edited, serverId: item.id, draft: draft)
                realm.add(record, update: .modified)
            }
        }
    }

    func remove(_ item: ExampleItem, cardId: String, ownerKey: String) throws {
        try realm.write {
            switch item.origin {
            case .custom:
                realm.delete(try ownedCustom(item.id, cardId: cardId, ownerKey: ownerKey))
            case .server, .edited:
                let id = serverRecordId(ownerKey: ownerKey, cardId: cardId, serverId: item.id)
                let record = realm.object(ofType: RCardExample.self, forPrimaryKey: id) ?? RCardExample()
                if record.realm == nil { record.id = id }
                // The learner's edited text is dropped with the sentence; only the fact that it is hidden is kept.
                fill(record, cardId: cardId, ownerKey: ownerKey, kind: .hidden, serverId: item.id, draft: CardExampleDraft())
                realm.add(record, update: .modified)
            }
        }
    }

    func restoreOriginal(of item: ExampleItem, cardId: String, ownerKey: String) throws {
        guard item.origin == .edited else { return }
        let id = serverRecordId(ownerKey: ownerKey, cardId: cardId, serverId: item.id)
        try realm.write {
            if let record = realm.object(ofType: RCardExample.self, forPrimaryKey: id), record.kind == RCardExample.Kind.edited.rawValue {
                realm.delete(record)
            }
        }
    }

    func restoreRemoved(cardId: String, ownerKey: String) throws {
        let hidden = records(cardId: cardId, ownerKey: ownerKey).filter("kind == %@", RCardExample.Kind.hidden.rawValue)
        guard !hidden.isEmpty else { return }
        try realm.write { realm.delete(hidden) }
    }

    // MARK: Helpers

    /// A sentence the learner wrote, found only for the same account and card: an id from elsewhere is not theirs to change.
    private func ownedCustom(_ id: String, cardId: String, ownerKey: String) throws -> RCardExample {
        guard let record = realm.object(ofType: RCardExample.self, forPrimaryKey: id), record.kind == RCardExample.Kind.custom.rawValue,
              record.cardId == cardId, record.ownerKey == ownerKey else { throw CardExampleError.notFound }
        return record
    }

    private func fill(_ record: RCardExample, cardId: String, ownerKey: String, kind: RCardExample.Kind, serverId: String, draft: CardExampleDraft) {
        let now = Date()
        if record.realm == nil { record.createdAt = now }
        record.cardId = cardId
        record.ownerKey = ownerKey
        record.kind = kind.rawValue
        record.serverExampleId = serverId
        record.japanese = draft.japanese
        record.reading = draft.reading
        record.translation = draft.translation
        record.updatedAt = now
    }
}
