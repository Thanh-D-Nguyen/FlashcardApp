//
//  CardRepositoryInterface.swift
//  FlashcardApp
//

import Foundation

protocol CardRepositoryInterface: AnyObject {
    func add(_ card: CardEntity, toDesk desk: DeskEntity) throws
    /// All cards or none: one transaction. Throws (never traps) when a card id is already stored.
    func add(_ cards: [CardEntity], toDesk desk: DeskEntity) throws
}